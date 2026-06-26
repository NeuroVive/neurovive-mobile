import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_ble/universal_ble.dart';

import '../app_constants.dart';
import '../notifiers/smart_pen_notifier.dart';
import '../notifiers/voice_upload_notifier.dart';
import '../services/bluetooth_service.dart';
import '../services/smart_pen_service.dart';

final bluetoothServiceProvider = Provider<BluetoothSensorService>((ref) {
  final service = BluetoothSensorService();
  ref.onDispose(service.dispose);
  return service;
});

final scanResultsProvider = StreamProvider<List<BleDevice>>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  final controller = StreamController<List<BleDevice>>();

  final subscription = service.scanResults.listen((device) {
    controller.add([device]);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

final connectionStateProvider = StreamProvider<BluetoothConnectionState>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return (() async* {
    yield service.currentState;
    yield* service.connectionState;
  })();
});

final sensorPacketProvider = StreamProvider<SensorPacket?>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return (() async* {
    yield null;
    yield* service.packets;
  })();
});

class BluetoothConnectionPage extends ConsumerStatefulWidget {
  const BluetoothConnectionPage({super.key});

  @override
  ConsumerState<BluetoothConnectionPage> createState() =>
      _BluetoothConnectionPageState();
}

class _BluetoothConnectionPageState
    extends ConsumerState<BluetoothConnectionPage> {
  final List<BleDevice> _discoveredDevices = [];
  bool _isInitialized = false;
  bool _isCheckingConnection = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final service = ref.read(bluetoothServiceProvider);
    await service.initialize();
    await _checkExistingConnection(service);

    if (!AppConstants.useRealApplication) {
      final smartPenNotifier = ref.read(smartPenNotifierProvider.notifier);
      await smartPenNotifier.initialize();
    }

    if (!mounted) return;
    setState(() {
      _isInitialized = true;
      _isCheckingConnection = false;
    });
  }

  Future<void> _checkExistingConnection(BluetoothSensorService service) async {
    if (service.connectedDevice == null) return;

    try {
      final isConnected = await service.isDeviceConnected();
      if (!isConnected) {
        await service.disconnect();
      }
    } catch (e) {
      print('Error checking connection: $e');
      await service.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final packetAsync = ref.watch(sensorPacketProvider);
    final service = ref.watch(bluetoothServiceProvider);
    final smartPenState = ref.watch(smartPenNotifierProvider);
    final smartPenNotifier = ref.read(smartPenNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Pen'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (service.currentState == BluetoothConnectionState.connected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: () => _disconnect(service, smartPenNotifier),
              tooltip: 'Disconnect',
            ),
          if (service.connectedDevice != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Connected: ${service.connectedDevice!.name?.isNotEmpty == true ? service.connectedDevice!.name! : service.connectedDevice!.deviceId}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBodyContent(
        connectionStateAsync,
        packetAsync,
        service,
        smartPenState,
        smartPenNotifier,
      ),
    );
  }

  Widget _buildBodyContent(
    AsyncValue<BluetoothConnectionState> connectionStateAsync,
    AsyncValue<SensorPacket?> packetAsync,
    BluetoothSensorService service,
    SmartPenState smartPenState,
    SmartPenNotifier smartPenNotifier,
  ) {
    if (_isCheckingConnection) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking existing connections...'),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return connectionStateAsync.when(
      data: (state) {
        return Column(
          children: [
            _buildConnectionStatus(state, service),
            Expanded(
              child: _buildContentForState(
                state,
                packetAsync,
                service,
                smartPenState,
                smartPenNotifier,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildConnectionStatus(
    BluetoothConnectionState state,
    BluetoothSensorService service,
  ) {
    Color color;
    String text;
    IconData icon;

    switch (state) {
      case BluetoothConnectionState.connected:
        color = Colors.green;
        text = 'Connected and listening for pen data';
        icon = Icons.bluetooth_connected;
        break;
      case BluetoothConnectionState.connecting:
        color = Colors.orange;
        text = 'Connecting to smart pen...';
        icon = Icons.bluetooth_searching;
        break;
      case BluetoothConnectionState.scanning:
        color = Colors.blue;
        text = 'Scanning for nearby devices...';
        icon = Icons.bluetooth_searching;
        break;
      case BluetoothConnectionState.error:
        color = Colors.red;
        text = service.errorMessage ?? 'Bluetooth error';
        icon = Icons.error_outline;
        break;
      case BluetoothConnectionState.disconnected:
        color = Colors.grey;
        text = 'Disconnected';
        icon = Icons.bluetooth_disabled;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: color.withOpacity(0.1),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (service.connectedDevice != null)
                  Text(
                    'Device: ${service.connectedDevice!.name?.isNotEmpty == true ? service.connectedDevice!.name! : service.connectedDevice!.deviceId}',
                    style: TextStyle(color: color.withOpacity(0.85)),
                  ),
              ],
            ),
          ),
          if (state == BluetoothConnectionState.disconnected)
            ElevatedButton(
              onPressed: () => _startScan(service),
              child: const Text('Scan'),
            ),
          if (state == BluetoothConnectionState.scanning)
            ElevatedButton(
              onPressed: service.stopScan,
              child: const Text('Stop'),
            ),
        ],
      ),
    );
  }

  Widget _buildContentForState(
    BluetoothConnectionState state,
    AsyncValue<SensorPacket?> packetAsync,
    BluetoothSensorService service,
    SmartPenState smartPenState,
    SmartPenNotifier smartPenNotifier,
  ) {
    if (!AppConstants.useRealApplication) {
      return _buildMockConnectedView(smartPenState, smartPenNotifier, service);
    }

    if (service.connectedDevice != null) {
      return _buildConnectedView(
        packetAsync,
        service,
        smartPenState,
        smartPenNotifier,
      );
    }

    switch (state) {
      case BluetoothConnectionState.scanning:
        return _buildScanningView(service);
      case BluetoothConnectionState.connected:
        return _buildConnectedView(
          packetAsync,
          service,
          smartPenState,
          smartPenNotifier,
        );
      case BluetoothConnectionState.error:
        return _buildErrorView(service);
      case BluetoothConnectionState.disconnected:
      case BluetoothConnectionState.connecting:
        return _buildWelcomeView();
    }
  }

  Widget _buildWelcomeView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Smart Pen Connected',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan for the pen, connect to it, then wait for live data before starting a recording.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningView(BluetoothSensorService service) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
        Expanded(
          child: StreamBuilder<BleDevice>(
            stream: service.scanResults,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final device = snapshot.data!;
                if (!_discoveredDevices.any(
                  (known) => known.deviceId == device.deviceId,
                )) {
                  _discoveredDevices.add(device);
                }
              }

              if (_discoveredDevices.isEmpty) {
                return const Center(child: Text('No devices found yet...'));
              }

              return ListView.builder(
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(
                        device.name?.isNotEmpty == true
                            ? device.name!
                            : 'Unknown Device',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(device.deviceId),
                      trailing: ElevatedButton(
                        onPressed: () => _connectToDevice(service, device),
                        child: const Text('Connect'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedView(
    AsyncValue<SensorPacket?> packetAsync,
    BluetoothSensorService service,
    SmartPenState smartPenState,
    SmartPenNotifier smartPenNotifier,
  ) {
    return packetAsync.when(
      data: (packet) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFlowOverviewCard(),
              const SizedBox(height: 16),
              if (packet == null)
                _buildWaitingForLiveDataCard()
              else ...[
                _buildPenActivityCard(service),
                const SizedBox(height: 16),
                if (AppConstants.showRawSmartPenPackets) ...[
                  _buildLiveDataSection(packet),
                  const SizedBox(height: 16),
                ],
              ],
              _buildRecordingSection(
                service,
                smartPenState,
                smartPenNotifier,
                hasLivePacket: packet != null,
              ),
              const SizedBox(height: 16),
              _buildResultsSection(service, smartPenState, smartPenNotifier),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Waiting for data...'),
          ],
        ),
      ),
      error: (error, _) => Center(child: Text('Data error: $error')),
    );
  }

  Widget _buildFlowOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Recording Flow',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'The pen can keep streaming data after connection, but the app only saves samples while the user is actively recording. When recording stops, the captured samples are sent to the SmartPen FFI for feature extraction.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForLiveDataCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connected. Waiting for the pen to start sending live packets.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPenActivityCard(BluetoothSensorService service) {
    final isRecording = service.isRecordingSession;

    return Card(
      color: isRecording
          ? Colors.green.withOpacity(0.08)
          : Colors.blue.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (isRecording)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.edit_note, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isRecording
                    ? 'Recording smart pen data...'
                    : 'Smart pen is connected and ready to record.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveDataSection(SensorPacket packet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Debug Packet Data'),
        _buildDataCard('Packet type', packet.packetType.toString()),
        _buildDataCard('Sequence number', packet.seqNumber.toString()),
        _buildDataCard('Timestamp', '${packet.timestamp} ms'),
        _buildDataCard('Checksum', _formatChecksum(packet.checkSum)),
        _buildDataCard(
          'Checksum valid',
          packet.isChecksumValid
              ? 'Yes'
              : 'No (${_formatChecksum(packet.computedCheckSum)})',
        ),
        _buildDataCard(
          'Accel X / Y / Z',
          '${packet.axRaw} / ${packet.ayRaw} / ${packet.azRaw}',
        ),
        _buildDataCard(
          'Gyro X / Y / Z',
          '${packet.gxRaw} / ${packet.gyRaw} / ${packet.gzRaw}',
        ),
        _buildDataCard(
          'Pitch / Roll',
          '${packet.pitchDegrees.toStringAsFixed(2)} / ${packet.rollDegrees.toStringAsFixed(2)} deg',
        ),
        _buildDataCard('Tip FSR raw', packet.tipFsr400Raw.toString()),
        _buildDataCard(
          'Tip force',
          '${packet.tipForceGrams.toStringAsFixed(1)} g',
        ),
        _buildDataCard(
          'Grip A / B raw',
          '${packet.gripARaw} / ${packet.gripBRaw}',
        ),
        _buildDataCard(
          'Grip mean',
          '${packet.gripMeanGrams.toStringAsFixed(1)} g',
        ),
        _buildDataCard(
          'Tremor frequency',
          '${packet.tremorFreqHz.toStringAsFixed(2)} Hz',
        ),
        _buildDataCard(
          'Tremor RMS',
          packet.tremorRms.toStringAsFixed(3),
        ),
        _buildDataCard(
          'Jerk magnitude',
          packet.jerkMagnitude.toStringAsFixed(2),
        ),
        _buildDataCard('Pen state', _getPenStateString(packet.penState)),
        _buildDataCard('Lift count', packet.liftCount.toString()),
        _buildDataCard(
          'Cal Accel X / Y / Z',
          '${packet.calAx} / ${packet.calAy} / ${packet.calAz}',
        ),
        _buildDataCard(
          'Cal Gyro X / Y / Z',
          '${packet.calGx} / ${packet.calGy} / ${packet.calGz}',
        ),
      ],
    );
  }

  Widget _buildRecordingSection(
    BluetoothSensorService service,
    SmartPenState smartPenState,
    SmartPenNotifier smartPenNotifier, {
    required bool hasLivePacket,
  }) {
    final canStart =
        hasLivePacket &&
        !service.isRecordingSession &&
        !smartPenState.isComputing &&
        !smartPenState.isUploading &&
        service.connectedDevice != null;
    final canStop =
        service.isRecordingSession &&
        !smartPenState.isComputing &&
        !smartPenState.isUploading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recording Session'),
        _buildDataCard(
          'Status',
          service.isRecordingSession ? 'Recording' : 'Idle',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canStart
                    ? () => _startPenRecording(service, smartPenNotifier)
                    : null,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Start Recording'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canStop
                    ? () => _stopPenRecording(service, smartPenNotifier)
                    : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop Recording'),
              ),
            ),
          ],
        ),
        if (!hasLivePacket)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Recording stays disabled until live packets are arriving from the pen.',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
      ],
    );
  }

  Widget _buildResultsSection(
    BluetoothSensorService service,
    SmartPenState smartPenState,
    SmartPenNotifier smartPenNotifier,
  ) {
    if (!smartPenState.isComputing &&
        smartPenState.error == null &&
        smartPenState.features == null &&
        smartPenState.recordedSamples == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Processed Result'),
        if (smartPenState.isComputing || smartPenState.isUploading)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      smartPenState.isComputing
                          ? 'Analyzing smart pen recording...'
                          : 'Sending smart pen analysis...',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (smartPenState.error != null) _buildErrorCard(smartPenState.error!),
        if (smartPenState.features != null && !AppConstants.useRealApplication) ...[
          _buildDataCard(
            'Extracted features',
            smartPenState.features!.length.toString(),
          ),
          if (smartPenState.statistics != null)
            _buildDataCard(
              'Statistics values',
              smartPenState.statistics!.length.toString(),
            ),
          if (smartPenState.buttonStatus != null)
            _buildDataCard(
              'Button status samples',
              smartPenState.buttonStatus!.length.toString(),
            ),
          if (smartPenState.aiResult != null)
            _buildDataCard('AI status', smartPenState.aiResult!.status.name),
          const SizedBox(height: 8),
          ...smartPenState.features!
              .take(5)
              .toList()
              .asMap()
              .entries
              .map(
                (entry) => _buildDataCard(
                  'Feature ${entry.key + 1}',
                  entry.value.toStringAsFixed(4),
                ),
              ),
          const SizedBox(height: 16),
          Card(
            color: Colors.green.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Take one more test?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This clears the previous result and prepares the pen screen for another recording.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          smartPenState.isComputing || smartPenState.isUploading
                          ? null
                          : () =>
                                _prepareAnotherTest(service, smartPenNotifier),
                      child: const Text('Take One More Test'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildDataCard(String label, String value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      color: Colors.red.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockConnectedView(
    SmartPenState smartPenState,
    SmartPenNotifier smartPenNotifier,
    BluetoothSensorService service,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFlowOverviewCard(),
          const SizedBox(height: 16),
          _buildSectionHeader('Mock Mode'),
          _buildDataCard('Status', 'Mock connected'),
          _buildDataCard('Samples to process', '200'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: smartPenState.isComputing || smartPenState.isUploading
                ? null
                : () => _processMockRecording(smartPenNotifier),
            child: const Text('Process Mock Recording'),
          ),
          const SizedBox(height: 16),
          _buildResultsSection(service, smartPenState, smartPenNotifier),
        ],
      ),
    );
  }

  Widget _buildErrorView(BluetoothSensorService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              service.errorMessage ?? 'An error occurred',
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _discoveredDevices.clear();
                _startScan(service);
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startScan(BluetoothSensorService service) async {
    setState(_discoveredDevices.clear);
    await service.startScan();
  }

  Future<void> _connectToDevice(
    BluetoothSensorService service,
    BleDevice device,
  ) async {
    await service.connectToDevice(device);
  }

  Future<void> _disconnect(
    BluetoothSensorService service,
    SmartPenNotifier smartPenNotifier,
  ) async {
    await service.disconnect();
    smartPenNotifier.clearSession();
    if (!mounted) return;
    setState(_discoveredDevices.clear);
  }

  Future<void> _startPenRecording(
    BluetoothSensorService service,
    SmartPenNotifier smartPenNotifier,
  ) async {
    smartPenNotifier.clearSession();
    service.startRecordingSession();

    if (!mounted) return;
    setState(() {});
    _showMessage('Recording started. Data is now being saved.');
  }

  Future<void> _stopPenRecording(
    BluetoothSensorService service,
    SmartPenNotifier smartPenNotifier,
  ) async {
    try {
      final recording = service.stopRecordingSession();

      if (mounted) {
        setState(() {});
      }

      final result = await smartPenNotifier.processRecording(recording);
      if (!mounted || result == null) return;

      switch (result.status) {
        case JobStatus.success:
          _showMessage('Smart Pen data analyzed successfully.');
          context.go('/results', extra: result);
          break;
        case JobStatus.error:
          _showMessage(result.message ?? 'Smart Pen analysis failed.');
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        _showMessage(e.toString());
      }
    }
  }

  void _prepareAnotherTest(
    BluetoothSensorService service,
    SmartPenNotifier smartPenNotifier,
  ) {
    smartPenNotifier.clearSession();
    service.resetRecordingSession();
    setState(() {});
  }

  Future<void> _processMockRecording(SmartPenNotifier smartPenNotifier) async {
    final result = await smartPenNotifier.computeFeaturesWithMockData(200);
    if (!mounted || result == null) return;

    switch (result.status) {
      case JobStatus.success:
        _showMessage('Smart Pen data analyzed successfully.');
        context.go('/results', extra: result);
        break;
      case JobStatus.error:
        _showMessage(result.message ?? 'Smart Pen analysis failed.');
        break;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatChecksum(int checksum) {
    return '0x${checksum.toRadixString(16).toUpperCase().padLeft(2, '0')}';
  }

  String _getPenStateString(int penState) {
    switch (penState) {
      case 0:
        return 'Pen Up';
      case 1:
        return 'Pen Down';
      case 2:
        return 'Hovering';
      default:
        return 'Unknown ($penState)';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds.$milliseconds';
  }
}
