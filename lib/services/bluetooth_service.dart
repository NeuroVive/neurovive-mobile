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
    _currentState = BluetoothConnectionState.disconnected;
    _connectionStateController.add(_currentState);
  }

  Future<bool> checkAndRequestPermissions() async {
    try {
      final bleState = await UniversalBle.getBluetoothAvailabilityState();
      if (bleState == AvailabilityState.unsupported) {
        _errorMessage = 'Bluetooth is not available on this device';
        _currentState = BluetoothConnectionState.error;
        _connectionStateController.add(_currentState);
        return false;
      }

      if (bleState != AvailabilityState.poweredOn) {
        _errorMessage = 'Please enable Bluetooth';
        _currentState = BluetoothConnectionState.error;
        _connectionStateController.add(_currentState);
        return false;
      }

      var status = await UniversalBle.hasPermissions();
      if (status != true) {
        await UniversalBle.requestPermissions();
        status = await UniversalBle.hasPermissions();
        if (status != true) {
          _errorMessage = 'Bluetooth permissions denied';
          _currentState = BluetoothConnectionState.error;
          _connectionStateController.add(_currentState);
          return false;
        }
      }

      return true;
    } catch (e) {
      _errorMessage = 'Permission check failed: $e';
      _currentState = BluetoothConnectionState.error;
      _connectionStateController.add(_currentState);
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

  Future<void> startScan() async {
    if (!await checkAndRequestPermissions()) {
      return;
    }

    try {
      _isScanning = true;
      _currentState = BluetoothConnectionState.scanning;
      _connectionStateController.add(_currentState);

      _scanResultsController = StreamController<BleDevice>.broadcast();
      print('Started scanning');

      _scanSub = UniversalBle.scanStream.listen(
        (BleDevice bleDevice) {
          print('Found device: ${bleDevice.name} (${bleDevice.deviceId})');
          _scanResultsController.add(bleDevice);
        },
        onError: (error) {
          _errorMessage = 'Scan error: $error';
          _currentState = BluetoothConnectionState.error;
          _connectionStateController.add(_currentState);
        },
      );

      await UniversalBle.startScan();

      Future.delayed(const Duration(seconds: 50), () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      _errorMessage = 'Failed to start scan: $e';
      _currentState = BluetoothConnectionState.error;
      _connectionStateController.add(_currentState);
    }
  }

  Future<void> stopScan() async {
    _isScanning = false;
    await UniversalBle.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;

    if (_currentState == BluetoothConnectionState.scanning) {
      _currentState = BluetoothConnectionState.disconnected;
      _connectionStateController.add(_currentState);
    }
  }

  Future<void> connectToDevice(BleDevice device) async {
    try {
      _errorMessage = null;
      _currentState = BluetoothConnectionState.connecting;
      _connectionStateController.add(_currentState);

      await stopScan();
      await device.connect();
      connectedDevice = device;

      print('Requesting MTU 64...');
      try {
        final mtu = await device.requestMtu(64);
        print('MTU negotiated to: $mtu bytes');
        if (mtu < PacketParser.packetSize) {
          print('WARNING: MTU $mtu is less than packet size ${PacketParser.packetSize}');
        }
      } catch (e) {
        print('MTU request failed: $e - continuing with default MTU');
      }

      _connectionSub = device.connectionStream.listen(
        (isConnected) {
          print('Connection state changed: $isConnected');
          if (isConnected) {
            _currentState = BluetoothConnectionState.connected;
          } else {
            _currentState = BluetoothConnectionState.disconnected;
            connectedDevice = null;
            resetRecordingSession();
          }
          _connectionStateController.add(_currentState);
        },
        onError: (error) {
          _errorMessage = 'Connection lost: $error';
          _currentState = BluetoothConnectionState.error;
          _connectionStateController.add(_currentState);
        },
      );

      print('Discovering services...');
      final services = await device.discoverServices();

      for (final service in services) {
        print('Found service: ${service.uuid}');
        for (final char in service.characteristics) {
          print(
            '  Characteristic: ${char.uuid} - Properties: ${char.properties}',
          );

          if (char.properties.contains(CharacteristicProperty.notify)) {
            characteristic = char;

            _notificationSub = characteristic!.onValueReceived.listen(
              _handleBytes,
              onError: (error) {
                print('Notification error: $error');
              },
            );

            await characteristic!.notifications.subscribe();
            print('Subscribed to notifications for ${char.uuid}');
            break;
          }
        }
      }

      _currentState = BluetoothConnectionState.connected;
      _connectionStateController.add(_currentState);
    } catch (e) {
      _errorMessage = 'Connection failed: $e';
      _currentState = BluetoothConnectionState.error;
      _connectionStateController.add(_currentState);
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
    _receiveBuffer.addAll(bytes);

    print(
      'Received ${bytes.length} bytes, buffer now ${_receiveBuffer.length}',
    );
    print(
      'Hex: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    while (_receiveBuffer.length >= PacketParser.packetSize) {
      final packetBytes = _receiveBuffer.sublist(0, PacketParser.packetSize);
      _receiveBuffer.removeRange(0, PacketParser.packetSize);

      print('Processing full packet of ${packetBytes.length} bytes');

      final packets = _parser.feed(packetBytes);
      for (final packet in packets) {
        if (_isRecordingSession) {
          _recordedPackets.add(packet);
        }
        _packetController.add(packet);
        print('Parsed packet seq: ${packet.seqNumber}');
      }
    }

    if (_receiveBuffer.isNotEmpty) {
      print('Waiting for more data, ${_receiveBuffer.length} bytes in buffer');
    }
  }

  Future<void> disconnect() async {
    try {
      await _notificationSub?.cancel();
      await characteristic?.unsubscribe();
      await connectedDevice?.disconnect();
      await _connectionSub?.cancel();

      connectedDevice = null;
      characteristic = null;
      _receiveBuffer.clear();
      resetRecordingSession();

      _currentState = BluetoothConnectionState.disconnected;
      _connectionStateController.add(_currentState);
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  void dispose() {
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _notificationSub?.cancel();
    _packetController.close();
    _scanResultsController.close();
    _connectionStateController.close();
    _receiveBuffer.clear();
    _recordedPackets.clear();
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

    // The current packet schema does not expose PMW3901 x/y channels directly.
    // Approximate them from integrated acceleration until the firmware sends the
    // dedicated coordinate fields.
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
