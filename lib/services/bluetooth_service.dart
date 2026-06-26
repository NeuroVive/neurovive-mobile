import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

// Connection states for UI
enum BluetoothConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class BluetoothSensorService {
  bool _isDisposed = false;
  final PacketParser _parser = PacketParser();
  final StreamController<SensorPacket> _packetController =
      StreamController<SensorPacket>.broadcast();
  late StreamController<BleDevice> _scanResultsController =
      StreamController<BleDevice>.broadcast();
  final StreamController<BluetoothConnectionState> _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();

  // Add a buffer for incoming bytes to handle MTU splitting
  final List<int> _receiveBuffer = [];
  final List<SensorPacket> _recordedPackets = [];

  // Streams for UI updates
  Stream<SensorPacket> get packets => _packetController.stream;
  Stream<BleDevice> get scanResults => _scanResultsController.stream;
  Stream<BluetoothConnectionState> get connectionState =>
      _connectionStateController.stream;

  BleDevice? connectedDevice;
  BleCharacteristic? characteristic;
  StreamSubscription? _scanSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _notificationSub;
  bool _isScanning = false;
  bool _shouldBeScanning = false;
  bool _isConnecting = false;
  bool _isRecordingSession = false;
  DateTime? _recordingStartedAt;
  DateTime? _recordingStoppedAt;

  BluetoothConnectionState _currentState =
      BluetoothConnectionState.disconnected;
  String? _errorMessage;

  BluetoothConnectionState get currentState => _currentState;
  String? get errorMessage => _errorMessage;
  bool get isScanning => _isScanning;
  bool get isRecordingSession => _isRecordingSession;
  int get recordedSampleCount => _recordedPackets.length;
  DateTime? get recordingStartedAt => _recordingStartedAt;

  Duration get currentRecordingDuration {
    if (_recordingStartedAt == null) {
      return Duration.zero;
    }

    final endTime = _isRecordingSession
        ? DateTime.now()
        : (_recordingStoppedAt ?? DateTime.now());
    return endTime.difference(_recordingStartedAt!);
  }

  Future<void> initialize() async {
    if (_isDisposed) return;
    _currentState = BluetoothConnectionState.disconnected;
    _updateState(_currentState);
  }

  void _updateState(BluetoothConnectionState state) {
    _currentState = state;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(_currentState);
    }
  }

  Future<bool> checkAndRequestPermissions() async {
    try {
      final bleState = await UniversalBle.getBluetoothAvailabilityState();
      if (bleState == AvailabilityState.unsupported) {
        _errorMessage = 'Bluetooth is not available on this device';
        _updateState(BluetoothConnectionState.error);
        return false;
      }

      if (bleState != AvailabilityState.poweredOn) {
        _errorMessage = 'Please enable Bluetooth';
        _updateState(BluetoothConnectionState.error);
        return false;
      }

      var status = await UniversalBle.hasPermissions();
      if (status != true) {
        await UniversalBle.requestPermissions();
        status = await UniversalBle.hasPermissions();
        if (status != true) {
          _errorMessage = 'Bluetooth permissions denied';
          _updateState(BluetoothConnectionState.error);
          return false;
        }
      }

      return true;
    } catch (e) {
      _errorMessage = 'Permission check failed: $e';
      _updateState(BluetoothConnectionState.error);
      return false;
    }
  }

  Future<bool> isDeviceConnected() async {
    if (connectedDevice == null) return false;

    try {
      return connectedDevice!.isConnected;
    } catch (e) {
      print('Device connection check failed: $e');
      return false;
    }
  }

  Future<void> startScan({String? targetName}) async {
    if (_isDisposed) return;
    print('BluetoothSensorService: startScan (Target: $targetName)');

    _shouldBeScanning = true;
    if (!await checkAndRequestPermissions()) {
      return;
    }

    if (!_shouldBeScanning || _isDisposed) return;

    try {
      // Force stop any existing scan or connection attempts
      await _stopHardwareScan();
      if (!_shouldBeScanning || _isDisposed) return;

      // First, check if already connected by the OS
      if (targetName != null) {
        try {
          final connectedDevices = await UniversalBle.getSystemDevices(
            timeout: const Duration(seconds: 5),
          );
          for (var device in connectedDevices) {
            if (device.name == targetName) {
              print('BluetoothSensorService: Target device already connected to OS, connecting in app...');
              await connectToDevice(device);
              return;
            }
          }
        } catch (e) {
          print('BluetoothSensorService: Error checking connected devices: $e');
        }
      }

      if (!_shouldBeScanning || _isDisposed) return;

      _isScanning = true;
      _updateState(BluetoothConnectionState.scanning);

      _scanResultsController = StreamController<BleDevice>.broadcast();

      await _scanSub?.cancel();
      _scanSub = UniversalBle.scanStream.listen(
        (BleDevice bleDevice) {
          if (!_shouldBeScanning || _isDisposed) return;
          
          if (!_scanResultsController.isClosed) {
            _scanResultsController.add(bleDevice);
          }
          
          if (targetName != null && bleDevice.name == targetName) {
            print('BluetoothSensorService: Target device found during scan: ${bleDevice.name}');
            connectToDevice(bleDevice);
          }
        },
        onError: (error) {
          if (_isDisposed) return;
          _errorMessage = 'Scan error: $error';
          _updateState(BluetoothConnectionState.error);
        },
      );

      await UniversalBle.startScan();
    } catch (e) {
      if (_isDisposed) return;
      _isScanning = false;
      _errorMessage = 'Failed to start scan: $e';
      _updateState(BluetoothConnectionState.error);
    }
  }

  Future<void> stopScan() async {
    print('BluetoothSensorService: stopScan');
    _shouldBeScanning = false;

    await _stopHardwareScan();
  }

  Future<void> _stopHardwareScan() async {
    await _scanSub?.cancel();
    _scanSub = null;

    // Force stop hardware scan always when requested
    try {
      await UniversalBle.stopScan();
    } catch (_) {}

    if (!_isScanning) return;

    _isScanning = false;
    if (!_isDisposed && _currentState == BluetoothConnectionState.scanning) {
      _updateState(BluetoothConnectionState.disconnected);
    }
  }

  Future<void> connectToDevice(BleDevice device) async {
    if (_isDisposed || _isConnecting) return;
    
    // Prevent re-connecting to the same device if already connected
    if (_currentState == BluetoothConnectionState.connected && connectedDevice?.deviceId == device.deviceId) {
      print('BluetoothSensorService: Already connected to this device');
      return;
    }

    _isConnecting = true;
    try {
      print('BluetoothSensorService: Connecting to ${device.name} (${device.deviceId})');
      _shouldBeScanning = false;
      _errorMessage = null;
      _updateState(BluetoothConnectionState.connecting);

      await stopScan();
      if (_isDisposed) return;

      await device.connect();
      if (_isDisposed) {
        await device.disconnect();
        return;
      }

      connectedDevice = device;
      print('BluetoothSensorService: Device connected');

      // MTU Negotiation
      try {
        await device.requestMtu(64);
      } catch (_) {}

      // Monitor connection state
      await _connectionSub?.cancel();
      _connectionSub = device.connectionStream.listen(
        (isConnected) {
          if (_isDisposed) return;
          print('BluetoothSensorService: Connection state changed: $isConnected');
          if (isConnected) {
            _updateState(BluetoothConnectionState.connected);
          } else {
            _handleDisconnection();
          }
        },
        onError: (error) {
          if (_isDisposed) return;
          print('BluetoothSensorService: Connection error stream: $error');
          _errorMessage = 'Connection error: $error';
          _updateState(BluetoothConnectionState.error);
          _handleDisconnection();
        },
      );

      print('BluetoothSensorService: Discovering services...');
      final services = await device.discoverServices();
      if (_isDisposed) return;

      characteristic = null;
      for (final service in services) {
        for (final char in service.characteristics) {
          // Look for notifying characteristic
          if (char.properties.contains(CharacteristicProperty.notify)) {
            characteristic = char;

            await _notificationSub?.cancel();
            _notificationSub = characteristic!.onValueReceived.listen(
              _handleBytes,
              onError: (error) {
                print('BluetoothSensorService: Data reception error: $error');
              },
            );

            print('BluetoothSensorService: Subscribing to notifications for ${char.uuid}');
            await characteristic!.notifications.subscribe();
            break;
          }
        }
        if (characteristic != null) break;
      }

      if (_isDisposed) {
        await disconnect();
        return;
      }

      if (characteristic == null) {
        print('BluetoothSensorService: ERROR - No notify characteristic found');
        _errorMessage = 'No compatible data service found';
        _updateState(BluetoothConnectionState.error);
        await device.disconnect();
      } else {
        _updateState(BluetoothConnectionState.connected);
      }
    } catch (e) {
      if (_isDisposed) return;
      print('BluetoothSensorService: Connection failed with exception: $e');
      _errorMessage = 'Connection failure: $e';
      _updateState(BluetoothConnectionState.error);
      _handleDisconnection();
    } finally {
      _isConnecting = false;
    }
  }

  void _handleDisconnection() {
    connectedDevice = null;
    characteristic = null;
    _receiveBuffer.clear();
    resetRecordingSession();
    if (!_isDisposed) {
      _updateState(BluetoothConnectionState.disconnected);
    }
  }

  void startRecordingSession() {
    _recordedPackets.clear();
    _isRecordingSession = true;
    _recordingStartedAt = DateTime.now();
    _recordingStoppedAt = null;
  }

  PenRecordingData stopRecordingSession() {
    if (!_isRecordingSession) {
      throw StateError('Recording has not started.');
    }

    _isRecordingSession = false;
    _recordingStoppedAt = DateTime.now();

    if (_recordedPackets.isEmpty) {
      throw StateError('No pen data was recorded.');
    }

    return PenRecordingData.fromPackets(
      List<SensorPacket>.unmodifiable(_recordedPackets),
      startedAt: _recordingStartedAt,
      stoppedAt: _recordingStoppedAt,
    );
  }

  void resetRecordingSession() {
    _isRecordingSession = false;
    _recordedPackets.clear();
    _recordingStartedAt = null;
    _recordingStoppedAt = null;
  }

  void _handleBytes(List<int> bytes) {
    // Only process if still connected and not disposed
    if (_isDisposed || _currentState != BluetoothConnectionState.connected) return;
    
    _receiveBuffer.addAll(bytes);

    while (_receiveBuffer.length >= PacketParser.packetSize) {
      final packetBytes = _receiveBuffer.sublist(0, PacketParser.packetSize);
      _receiveBuffer.removeRange(0, PacketParser.packetSize);

      final packets = _parser.feed(packetBytes);
      for (final packet in packets) {
        if (_isRecordingSession) {
          _recordedPackets.add(packet);
        }
        if (!_packetController.isClosed) {
          _packetController.add(packet);
        }
      }
    }
  }

  Future<void> disconnect() async {
    if (_isDisposed) return;
    print('BluetoothSensorService: Explicit disconnect started');
    
    _shouldBeScanning = false;
    
    // Stop receiving data immediately by cancelling subscription
    await _notificationSub?.cancel();
    _notificationSub = null;
    
    // Stop scanning immediately
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await UniversalBle.stopScan();
    } catch (_) {}

    // Clean up notifications subscription on hardware level
    if (characteristic != null) {
      try {
        await characteristic!.notifications.unsubscribe();
      } catch (_) {}
    }

    // Disconnect device
    if (connectedDevice != null) {
      try {
        print('BluetoothSensorService: Sending disconnect to hardware...');
        await connectedDevice!.disconnect();
      } catch (e) {
        print('BluetoothSensorService: Hardware disconnect error: $e');
      }
    }
    
    // Clean up internal references
    await _connectionSub?.cancel();
    _connectionSub = null;
    
    _handleDisconnection();
    print('BluetoothSensorService: Explicit disconnect complete');
  }

  void dispose() {
    if (_isDisposed) return;
    print('BluetoothSensorService: DISPOSING service instance');
    _isDisposed = true;
    _shouldBeScanning = false;
    
    // Immediate cancellation of all logic streams
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _notificationSub?.cancel();
    
    // Fire off hardware disconnect (non-blocking)
    disconnect();
    
    _packetController.close();
    _scanResultsController.close();
    _connectionStateController.close();
  }
}

class PenRecordingData {
  const PenRecordingData({
    required this.x,
    required this.y,
    required this.pressure,
    required this.azimuth,
    required this.altitude,
    required this.accX,
    required this.accY,
    required this.sampleCount,
    required this.duration,
  });

  final List<double> x;
  final List<double> y;
  final List<double> pressure;
  final List<double> azimuth;
  final List<double> altitude;
  final List<double> accX;
  final List<double> accY;
  final int sampleCount;
  final Duration duration;

  factory PenRecordingData.fromPackets(
    List<SensorPacket> packets, {
    DateTime? startedAt,
    DateTime? stoppedAt,
  }) {
    final accX = packets.map((packet) => packet.axRaw.toDouble()).toList();
    final accY = packets.map((packet) => packet.ayRaw.toDouble()).toList();

    final x = _integrateSignal(accX);
    final y = _integrateSignal(accY);

    final pressure = _normalizePositiveSignal(
      packets.map((packet) => packet.tipForceX10.toDouble()).toList(),
    );

    return PenRecordingData(
      x: x,
      y: y,
      pressure: pressure,
      azimuth: packets.map((packet) => packet.rollDegrees).toList(),
      altitude: packets.map((packet) => packet.pitchDegrees).toList(),
      accX: accX,
      accY: accY,
      sampleCount: packets.length,
      duration: _deriveDuration(packets, startedAt, stoppedAt),
    );
  }

  static Duration _deriveDuration(
    List<SensorPacket> packets,
    DateTime? startedAt,
    DateTime? stoppedAt,
  ) {
    if (packets.isEmpty) return Duration.zero;
    final firstTimestamp = packets.first.timestamp;
    final lastTimestamp = packets.last.timestamp;

    if (lastTimestamp >= firstTimestamp) {
      final duration = Duration(milliseconds: lastTimestamp - firstTimestamp);
      if (duration > Duration.zero) {
        return duration;
      }
    }

    if (startedAt != null &&
        stoppedAt != null &&
        !stoppedAt.isBefore(startedAt)) {
      return stoppedAt.difference(startedAt);
    }

    return Duration.zero;
  }

  static List<double> _integrateSignal(
    List<double> signal, {
    double dt = 1.0 / 150.0,
  }) {
    var position = 0.0;
    final integrated = <double>[];

    for (final value in signal) {
      position += value * dt;
      integrated.add(position);
    }

    return integrated;
  }

  static List<double> _normalizePositiveSignal(List<double> signal) {
    if (signal.isEmpty) return [];
    final maxValue = signal.fold<double>(
      0,
      (currentMax, value) => value > currentMax ? value : currentMax,
    );

    if (maxValue <= 0) {
      return List<double>.filled(signal.length, 0);
    }

    return signal.map((value) => (value / maxValue).clamp(0.0, 1.0)).toList();
  }
}

class SensorPacket {
  final int packetType;
  final int seqNumber;
  final int timestamp;
  final int axRaw;
  final int ayRaw;
  final int azRaw;
  final int gxRaw;
  final int gyRaw;
  final int gzRaw;
  final int pitchX100;
  final int rollX100;
  final int tipFsr400Raw;
  final int tipForceX10;
  final int gripARaw;
  final int gripBRaw;
  final int gripMeanX10;
  final int tremorFreqX100;
  final int tremorRmsX1000;
  final int jerkMagX100;
  final int penState;
  final int liftCount;
  final int calAx;
  final int calAy;
  final int calAz;
  final int calGx;
  final int calGy;
  final int calGz;
  final int checkSum;
  final int computedCheckSum;

  double get pitchDegrees => pitchX100 / 100.0;
  double get rollDegrees => rollX100 / 100.0;
  double get tipForceGrams => tipForceX10 / 10.0;
  double get gripMeanGrams => gripMeanX10 / 10.0;
  double get tremorFreqHz => tremorFreqX100 / 100.0;
  double get tremorRms => tremorRmsX1000 / 1000.0;
  double get jerkMagnitude => jerkMagX100 / 100.0;
  bool get isChecksumValid => checkSum == computedCheckSum;

  SensorPacket({
    required this.packetType,
    required this.seqNumber,
    required this.timestamp,
    required this.axRaw,
    required this.ayRaw,
    required this.azRaw,
    required this.gxRaw,
    required this.gyRaw,
    required this.gzRaw,
    required this.pitchX100,
    required this.rollX100,
    required this.tipFsr400Raw,
    required this.tipForceX10,
    required this.gripARaw,
    required this.gripBRaw,
    required this.gripMeanX10,
    required this.tremorFreqX100,
    required this.tremorRmsX1000,
    required this.jerkMagX100,
    required this.penState,
    required this.liftCount,
    required this.calAx,
    required this.calAy,
    required this.calAz,
    required this.calGx,
    required this.calGy,
    required this.calGz,
    required this.checkSum,
    required this.computedCheckSum,
  });

  @override
  String toString() {
    return 'packetType: $packetType, seqNumber: $seqNumber, timestamp: $timestamp, '
        'axRaw: $axRaw, ayRaw: $ayRaw, azRaw: $azRaw, gxRaw: $gxRaw, gyRaw: $gyRaw, gzRaw: $gzRaw, '
        'pitchX100: $pitchX100, rollX100: $rollX100, tipFsr400Raw: $tipFsr400Raw, '
        'tipForceX10: $tipForceX10, gripARaw: $gripARaw, gripBRaw: $gripBRaw, '
        'gripMeanX10: $gripMeanX10, tremorFreqX100: $tremorFreqX100, '
        'tremorRmsX1000: $tremorRmsX1000, jerkMagX100: $jerkMagX100, '
        'penState: $penState, liftCount: $liftCount, calAx: $calAx, calAy: $calAy, '
        'calAz: $calAz, calGx: $calGx, calGy: $calGy, calGz: $calGz, '
        'checkSum: $checkSum, computedCheckSum: $computedCheckSum, '
        'isChecksumValid: $isChecksumValid';
  }
}

class PacketParser {
  static const int packetSize = 53;

  final List<int> _buffer = [];

  List<SensorPacket> feed(List<int> incoming) {
    _buffer.addAll(incoming);
    final packets = <SensorPacket>[];

    while (_buffer.length >= packetSize) {
      final raw = _buffer.sublist(0, packetSize);
      _buffer.removeRange(0, packetSize);
      packets.add(_parsePacket(raw));
    }

    return packets;
  }

  SensorPacket _parsePacket(List<int> data) {
    final byteData = Uint8List.fromList(data).buffer.asByteData();
    final computedCheckSum = data
        .take(packetSize - 1)
        .fold<int>(0, (checksum, byte) => checksum ^ byte);
    var offset = 0;

    final packetType = byteData.getUint8(offset);
    offset += 1;

    final seqNumber = byteData.getUint8(offset);
    offset += 1;

    final timestamp = byteData.getUint32(offset, Endian.big);
    offset += 4;

    final axRaw = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final ayRaw = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final azRaw = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final gxRaw = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final gyRaw = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final gzRaw = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final pitchX100 = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final rollX100 = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final tipFsr400Raw = byteData.getUint16(offset, Endian.big);
    offset += 2;

    final tipForceX10 = byteData.getUint16(offset, Endian.big);
    offset += 2;

    final gripARaw = byteData.getUint16(offset, Endian.big);
    offset += 2;

    final gripBRaw = byteData.getUint16(offset, Endian.big);
    offset += 2;

    final gripMeanX10 = byteData.getUint16(offset, Endian.big);
    offset += 2;

    final tremorFreqX100 = byteData.getUint16(offset, Endian.big);
    offset += 2;

    final tremorRmsX1000 = byteData.getUint16(offset, Endian.big);
    offset += 2;

    final jerkMagX100 = byteData.getUint16(offset, Endian.big);
    offset += 2;

    final penState = byteData.getUint8(offset);
    offset += 1;

    final liftCount = byteData.getUint8(offset);
    offset += 1;

    final calAx = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final calAy = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final calAz = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final calGx = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final calGy = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final calGz = byteData.getInt16(offset, Endian.big);
    offset += 2;

    final checkSum = byteData.getUint8(offset);

    return SensorPacket(
      packetType: packetType,
      seqNumber: seqNumber,
      timestamp: timestamp,
      axRaw: axRaw,
      ayRaw: ayRaw,
      azRaw: azRaw,
      gxRaw: gxRaw,
      gyRaw: gyRaw,
      gzRaw: gzRaw,
      pitchX100: pitchX100,
      rollX100: rollX100,
      tipFsr400Raw: tipFsr400Raw,
      tipForceX10: tipForceX10,
      gripARaw: gripARaw,
      gripBRaw: gripBRaw,
      gripMeanX10: gripMeanX10,
      tremorFreqX100: tremorFreqX100,
      tremorRmsX1000: tremorRmsX1000,
      jerkMagX100: jerkMagX100,
      penState: penState,
      liftCount: liftCount,
      calAx: calAx,
      calAy: calAy,
      calAz: calAz,
      calGx: calGx,
      calGy: calGy,
      calGz: calGz,
      checkSum: checkSum,
      computedCheckSum: computedCheckSum,
    );
  }
}
