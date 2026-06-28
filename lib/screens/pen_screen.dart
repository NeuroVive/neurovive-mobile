import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../notifiers/smart_pen_notifier.dart';
import '../services/bluetooth_service.dart';
import '../widgets/ai_risk_gauge.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          _buildStatusHeader(connectionState, service, l10n),
          const SizedBox(height: 16),
          _buildRecordingCard(connectionState, service, l10n),
          const SizedBox(height: 16),
          _buildGraphsCard(smartPenState, l10n),
          const SizedBox(height: 16),
          _buildResultsCard(smartPenState, l10n),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(
    BluetoothConnectionState state,
    BluetoothSensorService service,
    AppLocalizations l10n,
  ) {
    final isConnected = state == BluetoothConnectionState.connected;
    final isBusy = state == BluetoothConnectionState.scanning ||
        state == BluetoothConnectionState.connecting;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.smartPenTitle,
                style: const TextStyle(
                  color: Color(0xFF1F3E6C),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
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
                  const SizedBox(width: 8),
                  const Text(
                    'BLE',
                    style: TextStyle(
                      color: Color(0xFF1F3E6C),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.signal_cellular_alt,
                    size: 14,
                    color: Color(0xFF1F3E6C),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: isBusy
                ? null
                : () async {
                    if (isConnected) {
                      await service.disconnect();
                    } else {
                      await _resetAndAutoConnect();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected
                  ? const Color(0xFFBC4B4B)
                  : const Color(0xFF5D9ECC),
              foregroundColor: Colors.white,
              disabledBackgroundColor: isConnected
                  ? const Color(0xFFBC4B4B).withOpacity(0.45)
                  : const Color(0xFF5D9ECC).withOpacity(0.45),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              isConnected ? l10n.disconnect : l10n.connect,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
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
    final smartPenState = ref.watch(smartPenNotifierProvider);
    final isBusy = smartPenState.isComputing || smartPenState.isUploading;
    final canInteract = isConnected && !isBusy;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: canInteract
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isBusy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Icon(isRecording ? Icons.stop : Icons.play_arrow, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    isBusy
                        ? (smartPenState.isUploading ? 'Uploading…' : 'Processing…')
                        : (isRecording ? l10n.stopRecording : l10n.startRecording),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildGraphsCard(SmartPenState state, AppLocalizations l10n) {
    if (state.aiResult == null) {
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
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            Text(
              l10n.waitingForAiResponse,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final pressureSeries = state.aiResult?.pressureSeries ?? const [];
    final accelerationSeries = state.aiResult?.accelerationSeries ?? const [];
    final tremorSeries = state.aiResult?.tremorSeries ?? const [];
    final radarValues = state.aiResult?.radarValues ?? const [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F3E6C).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniChart(
                  l10n.pressure,
                  pressureSeries,
                  const Color(0xFF46D1C0),
                  l10n: l10n,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniChart(
                  l10n.acceleration,
                  accelerationSeries,
                  const Color(0xFF46D1C0),
                  l10n: l10n,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniChart(
                  l10n.motionTremor,
                  tremorSeries,
                  const Color(0xFF46D1C0),
                  l10n: l10n,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildRadarChart(
                  l10n.pressureStability,
                  radarValues,
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
        const SizedBox(height: 6),
        SizedBox(
          height: 70,
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
        const SizedBox(height: 6),
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
    List<double> values, {
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
                values: values,
                color: const Color(0xFF46D1C0),
                textDirection: Directionality.of(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsCard(SmartPenState state, AppLocalizations l10n) {
    if (state.aiResult == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1F3E6C).withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            l10n.waitingForAiResponse,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    final score = ((state.aiResult!.confidence ?? 0.0) * 100).toInt();
    final riskLabel = score > 80
        ? l10n.highRisk
        : score > 50
            ? l10n.moderateRisk
            : score > 35
                ? l10n.slightRisk
                : l10n.noRisk;

    final gaugeSize = math.min(MediaQuery.of(context).size.width - 96, 180.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F3E6C).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          GaugeWithCenterWidget(
            width: gaugeSize,
            height: gaugeSize,
            progress: state.aiResult!.confidence!.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFE5EDF4),
            progressColor: const Color(0xFF1F3E6C),
            strokeWidth: 24,
            centerWidget: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score/100',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F3E6C),
                  ),
                ),
                const SizedBox(height: 0),
                Text(
                  riskLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F3E6C),
                  ),
                ),
              ],
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

  List<double> _fallbackRadarValues(SmartPenDisplayData? displayData) {
    if (displayData == null) {
      return List<double>.filled(8, 0.0);
    }
    return [
      displayData.pressureIndex,
      displayData.motionSmoothness,
      displayData.tremorScore,
      0,
      0,
      0,
      0,
      0,
    ];
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
    required this.values,
    required this.color,
    required this.textDirection,
  });

  final List<double> values;
  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final count = values.length;
    final angleStep = 2 * math.pi / count;

    final maxValue = values
            .map((e) => e.abs())
            .fold<double>(0.0, (prev, value) => value > prev ? value : prev)
        .clamp(0.0, double.infinity);
    final scale = maxValue == 0 ? 1.0 : radius / maxValue;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 1; i <= 3; i++) {
      final r = radius * (i / 3);
      canvas.drawCircle(center, r, gridPaint);
    }

    final axisPaint = Paint()
      ..color = Colors.grey.withOpacity(0.28)
      ..strokeWidth = 1;

    for (var i = 0; i < count; i++) {
      final angle = angleStep * i;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(center, end, axisPaint);
    }

    final points = List.generate(count, (index) {
      final value = values[index].clamp(0.0, double.infinity);
      final radiusPoint = value * scale;
      final angle = angleStep * index;
      return center + Offset(math.cos(angle), math.sin(angle)) * radiusPoint;
    });

    final shapePath = Path();
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        shapePath.moveTo(points[i].dx, points[i].dy);
      } else {
        shapePath.lineTo(points[i].dx, points[i].dy);
      }
    }
    shapePath.close();

    final fillPaint = Paint()
      ..color = color.withOpacity(0.22)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(shapePath, fillPaint);
    canvas.drawPath(shapePath, strokePaint);

    for (var point in points) {
      canvas.drawCircle(point, 3.2, pointPaint);
    }

    const labelStyle = TextStyle(color: Colors.grey, fontSize: 10);
    for (var i = 0; i < points.length; i++) {
      final angle = angleStep * i;
      final labelValue = values[i];
      final labelText = _formatLabel(labelValue);
      final labelPainter = TextPainter(
        text: TextSpan(text: labelText, style: labelStyle),
        textDirection: textDirection,
      )..layout();

      final labelOffset = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius + 8) -
          Offset(labelPainter.width / 2, labelPainter.height / 2);
      labelPainter.paint(canvas, labelOffset);
    }
  }

  String _formatLabel(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.textDirection != textDirection;
  }
}
