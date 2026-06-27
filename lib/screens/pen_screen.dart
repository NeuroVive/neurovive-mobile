import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../notifiers/smart_pen_notifier.dart';
import '../services/bluetooth_service.dart';

final bluetoothServiceProvider = Provider.autoDispose<BluetoothSensorService>((
  ref,
) {
  final service = BluetoothSensorService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final connectionStateProvider =
    StreamProvider.autoDispose<BluetoothConnectionState>((ref) {
      final service = ref.watch(bluetoothServiceProvider);
      return (() async* {
        yield service.currentState;
        yield* service.connectionState;
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
  Timer? _stopwatchTimer;
  Duration _elapsedTime = Duration.zero;
  String? _selectedTask;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetAndAutoConnect();
    });
  }

  Future<void> _resetAndAutoConnect() async {
    if (!mounted) return;
    final service = ref.read(bluetoothServiceProvider);
    // Reset connection on open
    await service.disconnect();
    // Auto connect to "SmartPen-PD"
    await service.startScan(targetName: 'SmartPen-PD');
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    // The provider is autoDispose, so it will call service.dispose() automatically.
    // However, calling disconnect here ensures it starts immediately.
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _elapsedTime = Duration.zero;
    });
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedTime += const Duration(seconds: 1);
        });
      }
    });
  }

  void _stopTimer() {
    _stopwatchTimer?.cancel();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connectionState =
        ref.watch(connectionStateProvider).value ??
        BluetoothConnectionState.disconnected;
    final service = ref.read(bluetoothServiceProvider);
    final smartPenState = ref.watch(smartPenNotifierProvider);

    _selectedTask ??= l10n.spiralTest;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatusHeader(connectionState, l10n),
          if (connectionState != BluetoothConnectionState.connected) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    connectionState == BluetoothConnectionState.connecting ||
                        connectionState == BluetoothConnectionState.scanning
                    ? null
                    : _resetAndAutoConnect,
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(l10n.connectToSmartPen),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D9ECC),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF5D9ECC,
                  ).withOpacity(0.45),
                  disabledForegroundColor: Colors.white.withOpacity(0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildRecordingCard(connectionState, service, l10n),
          const SizedBox(height: 20),
          _buildGraphsCard(smartPenState, l10n),
          const SizedBox(height: 20),
          _buildResultsCard(smartPenState, l10n),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(
    BluetoothConnectionState state,
    AppLocalizations l10n,
  ) {
    final isConnected = state == BluetoothConnectionState.connected;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isConnected
                ? const Color(0xFF46D1C0).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isConnected ? const Color(0xFF46D1C0) : Colors.grey,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? const Color(0xFF46D1C0) : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConnected
                    ? l10n.connected
                    : (state == BluetoothConnectionState.connecting
                          ? l10n.connecting
                          : l10n.disconnected),
                style: TextStyle(
                  color: isConnected ? const Color(0xFF46D1C0) : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          "BLE",
          style: TextStyle(
            color: Color(0xFF1F3E6C),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.signal_cellular_alt,
          size: 16,
          color: Color(0xFF1F3E6C),
        ),
        const Spacer(),
        // const Text("77%", style: TextStyle(color: Colors.grey, fontSize: 12)),
        //const SizedBox(width: 4),
        //Transform.rotate(
        // angle: 1.5708 * 2,
        //child: const Icon(Icons.battery_5_bar, size: 24, color: Color(0xFF1F3E6C)),
        //),
      ],
    );
  }

  Widget _buildRecordingCard(
    BluetoothConnectionState state,
    BluetoothSensorService service,
    AppLocalizations l10n,
  ) {
    final isConnected = state == BluetoothConnectionState.connected;
    final isRecording = service.isRecordingSession;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F3E6C).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            _formatDuration(_elapsedTime),
            style: const TextStyle(
              color: Color(0xFF1F3E6C),
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isConnected
                  ? () async {
                      if (isRecording) {
                        try {
                          final data = service.stopRecordingSession();
                          _stopTimer();
                          if (mounted) setState(() {});

                          final result = await ref
                              .read(smartPenNotifierProvider.notifier)
                              .processRecording(data);

                          if (!mounted) return;
                          if (result == null) {
                            final error = ref
                                .read(smartPenNotifierProvider)
                                .error;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  error ?? 'Failed to process pen data.',
                                ),
                              ),
                            );
                            return;
                          }

                          context.push('/results', extra: result);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      } else {
                        service.startRecordingSession();
                        _startTimer();
                        if (mounted) setState(() {});
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecording
                    ? const Color(0xFFBC4B4B)
                    : const Color(0xFF5D9ECC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isRecording ? Icons.stop : Icons.play_arrow, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    isRecording ? l10n.stopRecording : l10n.startRecording,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.selectTask,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF5D9ECC).withOpacity(0.5),
                  ),
                ),
                child: DropdownButton<String>(
                  value: _selectedTask,
                  underline: const SizedBox(),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF1F3E6C),
                  ),
                  items: [l10n.spiralTest].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Color(0xFF1F3E6C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedTask = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraphsCard(SmartPenState state, AppLocalizations l10n) {
    final displayData = state.displayData;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F3E6C).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniChart(
                  l10n.pressure,
                  displayData?.pressureSeries ?? const [],
                  const Color(0xFF46D1C0),
                  l10n: l10n,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMiniChart(
                  l10n.acceleration,
                  displayData?.accelerationSeries ?? const [],
                  const Color(0xFF46D1C0),
                  l10n: l10n,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMiniChart(
                  l10n.motionTremor,
                  displayData?.tremorSeries ?? const [],
                  const Color(0xFF46D1C0),
                  l10n: l10n,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRadarChart(
                  l10n.pressureStability,
                  displayData,
                  l10n: l10n,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChart(
    String title,
    List<double> data,
    Color color, {
    required AppLocalizations l10n,
  }) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1F3E6C),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: data.isEmpty
              ? const Center(
                  child: Text(
                    '-',
                    style: TextStyle(color: Colors.grey, fontSize: 20),
                  ),
                )
              : Row(
                  textDirection: Directionality.of(context),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isRtl)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            l10n.valueAxis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: CustomPaint(
                        painter: LineChartPainter(data: data, color: color),
                        child: Container(),
                      ),
                    ),
                    if (isRtl)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            l10n.valueAxis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
          child: Text(
            l10n.timeAxis,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildRadarChart(
    String title,
    SmartPenDisplayData? displayData, {
    required AppLocalizations l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1F3E6C),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: Center(
            child: CustomPaint(
              size: const Size(80, 80),
              painter: RadarChartPainter(
                pressure: displayData?.pressureIndex ?? 0,
                smoothness: displayData?.motionSmoothness ?? 0,
                tremor: displayData?.tremorScore ?? 0,
                pressureLabel: l10n.pressure,
                smoothnessLabel: l10n.motionSmoothness,
                tremorLabel: l10n.tremorScore,
                textDirection: Directionality.of(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _buildRadarLegend(l10n.pressure, const Color(0xFF46D1C0)),
            _buildRadarLegend(l10n.motionSmoothness, const Color(0xFF5D9ECC)),
            _buildRadarLegend(l10n.tremorScore, const Color(0xFFBC4B4B)),
          ],
        ),
      ],
    );
  }

  Widget _buildResultsCard(SmartPenState state, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F3E6C).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildResultItem(
                l10n.tremorScore,
                _formatMetric(state.displayData?.tremorScore),
                const Color(0xFF46D1C0),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.withOpacity(0.3),
              ),
              _buildResultItem(
                l10n.motionSmoothness,
                _formatPercent(state.displayData?.motionSmoothness),
                const Color(0xFF46D1C0),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.withOpacity(0.3),
              ),
              _buildResultItem(
                l10n.pressureIndex,
                _formatMetric(state.displayData?.pressureIndex),
                const Color(0xFF46D1C0),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: state.aiResult != null
                  ? () {
                      ref.context.push('/results', extra: state.aiResult);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: state.aiResult != null
                    ? const Color(0xFF5D9ECC)
                    : const Color(0xFF5D9ECC).withOpacity(0.5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.viewFullReport,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMetric(double? value) {
    if (value == null) {
      return '-';
    }
    return value.toStringAsFixed(2);
  }

  String _formatPercent(double? value) {
    if (value == null) {
      return '-';
    }
    return '${value.clamp(0, 100).toStringAsFixed(0)}%';
  }

  Widget _buildRadarLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF1F3E6C), fontSize: 11),
        ),
      ],
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  LineChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final double dx = data.length == 1 ? 0 : size.width / (data.length - 1);

    final maxVal = data.map((e) => e.abs()).reduce((a, b) => a > b ? a : b);
    final scale = maxVal == 0 ? 1.0 : (size.height / 2) / maxVal;

    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height / 2 - (data[i] * scale);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);

      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }

    canvas.drawPath(path, paint);

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), axisPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class RadarChartPainter extends CustomPainter {
  const RadarChartPainter({
    required this.pressure,
    required this.smoothness,
    required this.tremor,
    required this.pressureLabel,
    required this.smoothnessLabel,
    required this.tremorLabel,
    required this.textDirection,
  });

  final double pressure;
  final double smoothness;
  final double tremor;
  final String pressureLabel;
  final String smoothnessLabel;
  final String tremorLabel;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 1; i <= 3; i++) {
      final r = radius * (i / 3);
      canvas.drawCircle(center, r, gridPaint);
    }

    final pressureRadius = (pressure.clamp(0, 1) as double) * radius;
    final smoothnessRadius =
        (smoothness.clamp(0, 100) as double) / 100 * radius;
    final tremorRadius = (tremor.clamp(0, 10) as double) / 10 * radius;

    final pressureEnd = Offset(center.dx, center.dy - pressureRadius);
    final smoothnessEnd = Offset(
      center.dx + smoothnessRadius * 0.85,
      center.dy + smoothnessRadius * 0.25,
    );
    final tremorEnd = Offset(
      center.dx - tremorRadius * 0.85,
      center.dy + tremorRadius * 0.25,
    );

    final pressurePaint = Paint()
      ..color = const Color(0xFF46D1C0)
      ..strokeWidth = 1.5;
    final smoothnessPaint = Paint()
      ..color = const Color(0xFF5D9ECC)
      ..strokeWidth = 1.5;
    final tremorPaint = Paint()
      ..color = const Color(0xFFBC4B4B)
      ..strokeWidth = 1.5;

    canvas.drawLine(center, pressureEnd, pressurePaint);
    canvas.drawLine(center, smoothnessEnd, smoothnessPaint);
    canvas.drawLine(center, tremorEnd, tremorPaint);

    final shapePath = Path()
      ..moveTo(pressureEnd.dx, pressureEnd.dy)
      ..lineTo(smoothnessEnd.dx, smoothnessEnd.dy)
      ..lineTo(tremorEnd.dx, tremorEnd.dy)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0xFF46D1C0).withOpacity(0.22)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF46D1C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(shapePath, fillPaint);
    canvas.drawPath(shapePath, strokePaint);

    final pressurePointPaint = Paint()
      ..color = const Color(0xFF46D1C0)
      ..style = PaintingStyle.fill;
    final smoothnessPointPaint = Paint()
      ..color = const Color(0xFF5D9ECC)
      ..style = PaintingStyle.fill;
    final tremorPointPaint = Paint()
      ..color = const Color(0xFFBC4B4B)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pressureEnd, 3.2, pressurePointPaint);
    canvas.drawCircle(smoothnessEnd, 3.2, smoothnessPointPaint);
    canvas.drawCircle(tremorEnd, 3.2, tremorPointPaint);

    final axisPaint = Paint()
      ..color = Colors.grey.withOpacity(0.28)
      ..strokeWidth = 1;

    final topLabel = Offset(center.dx, center.dy - radius - 16);
    final rightLabel = Offset(center.dx + radius * 0.9, center.dy - 8);
    final leftLabel = Offset(center.dx - radius * 0.9 - 28, center.dy - 8);

    canvas.drawLine(center, Offset(center.dx, center.dy - radius), axisPaint);
    canvas.drawLine(
      center,
      Offset(center.dx + radius * 0.85, center.dy - radius * 0.25),
      axisPaint,
    );
    canvas.drawLine(
      center,
      Offset(center.dx - radius * 0.85, center.dy - radius * 0.25),
      axisPaint,
    );

    const labelStyle = TextStyle(color: Colors.grey, fontSize: 10);
    _drawLabel(canvas, topLabel, pressureLabel, labelStyle);
    _drawLabel(canvas, rightLabel, smoothnessLabel, labelStyle);
    _drawLabel(canvas, leftLabel, tremorLabel, labelStyle);
  }

  void _drawLabel(
    Canvas canvas,
    Offset position,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
    )..layout();
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) {
    return oldDelegate.pressure != pressure ||
        oldDelegate.smoothness != smoothness ||
        oldDelegate.tremor != tremor ||
        oldDelegate.pressureLabel != pressureLabel ||
        oldDelegate.smoothnessLabel != smoothnessLabel ||
        oldDelegate.tremorLabel != tremorLabel ||
        oldDelegate.textDirection != textDirection;
  }
}
