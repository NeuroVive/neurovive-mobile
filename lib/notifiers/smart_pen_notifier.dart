import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api.dart';
import '../services/bluetooth_service.dart';
import '../services/smart_pen_service.dart';
import 'voice_upload_notifier.dart';

const Object _smartPenStateUnset = Object();

// Provider for SmartPenService
final smartPenServiceProvider = Provider<SmartPenService>((ref) {
  return SmartPenService();
});

class SmartPenNotifier extends Notifier<SmartPenState> {
  late SmartPenService _service;

  @override
  SmartPenState build() {
    _service = ref.watch(smartPenServiceProvider);
    return const SmartPenState();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.initialize();
      state = state.copyWith(isInitialized: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<Response?> processRecording(PenRecordingData recording) async {
    final displayData = SmartPenDisplayData.fromRecording(recording);

    if (!state.isInitialized) {
      await initialize();
    }

    if (!state.isInitialized) {
      return null;
    }

    state = state.copyWith(
      isComputing: true,
      isUploading: false,
      error: null,
      features: null,
      statistics: null,
      buttonStatus: null,
      aiResult: null,
      recordedSamples: recording.sampleCount,
      recordingDuration: recording.duration,
      displayData: displayData,
    );

    try {
      List<double>? features;
      List<double>? statistics;
      List<int>? buttonStatus;
      final extractionErrors = <String>[];

      try {
        features = _service.computeFeatures(
          x: recording.x,
          y: recording.y,
          pressure: recording.pressure,
          azimuth: recording.azimuth,
          altitude: recording.altitude,
          accX: recording.accX,
          accY: recording.accY,
        );

        if (features == null) {
          extractionErrors.add(_service.getLastError());
        }
      } catch (e) {
        extractionErrors.add('features: $e');
      }

      try {
        statistics = _service.computeStatisticalSingle(recording.pressure);
      } catch (e) {
        extractionErrors.add('statistics: $e');
      }

      try {
        buttonStatus = _service.computeButtonStatus(recording.pressure);
      } catch (e) {
        extractionErrors.add('button_status: $e');
      }

      if (kDebugMode && recording.x.isNotEmpty && recording.y.isNotEmpty) {
        print('x: ${recording.x.last}, y: ${recording.y.last}');
      }

      final payload = <String, dynamic>{
        if (features != null) 'features': features,
        if (statistics != null) 'statistics': statistics,
        if (buttonStatus != null) 'button_status': buttonStatus,
      };

      if (payload.isEmpty) {
        state = state.copyWith(
          isComputing: false,
          error: extractionErrors.join('\n'),
        );
        return null;
      }

      state = state.copyWith(
        isComputing: false,
        features: features,
        statistics: statistics,
        buttonStatus: buttonStatus,
        error: extractionErrors.isEmpty ? null : extractionErrors.join('\n'),
      );

      state = state.copyWith(isUploading: true);
      final aiResult = await Api.sendPenData(payload);

      if (aiResult.status == JobStatus.error) {
        state = state.copyWith(
          isUploading: false,
          aiResult: null,
          error: aiResult.message ?? 'AI server returned an error.',
        );
        return null;
      }

      state = state.copyWith(
        isUploading: false,
        aiResult: aiResult,
        error: null,
      );
      return aiResult;
    } catch (e) {
      state = state.copyWith(
        isComputing: false,
        isUploading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<Response?> computeFeatures({
    required List<double> x,
    required List<double> y,
    required List<double> pressure,
    required List<double> azimuth,
    required List<double> altitude,
    required List<double> accX,
    required List<double> accY,
  }) async {
    return processRecording(
      PenRecordingData(
        x: x,
        y: y,
        pressure: pressure,
        azimuth: azimuth,
        altitude: altitude,
        accX: accX,
        accY: accY,
        sampleCount: x.length,
        duration: Duration.zero,
      ),
    );
  }

  Future<Response?> computeFeaturesWithMockData(int nSamples) async {
    final mockData = _service.generateMockData(nSamples);
    return computeFeatures(
      x: mockData['x']!,
      y: mockData['y']!,
      pressure: mockData['pressure']!,
      azimuth: mockData['azimuth']!,
      altitude: mockData['altitude']!,
      accX: mockData['accX']!,
      accY: mockData['accY']!,
    );
  }

  void computeStatistics(List<double> signal) {
    final stats = _service.computeStatisticalSingle(signal);
    state = state.copyWith(statistics: stats);
  }

  void computeButtonStatus(List<double> pressure) {
    final status = _service.computeButtonStatus(pressure);
    state = state.copyWith(buttonStatus: status);
  }

  void clearSession() {
    state = state.copyWith(
      isComputing: false,
      isUploading: false,
      features: null,
      statistics: null,
      buttonStatus: null,
      aiResult: null,
      error: null,
      recordedSamples: 0,
      recordingDuration: null,
      displayData: null,
    );
  }

  void reset() {
    state = const SmartPenState();
  }
}

class SmartPenState {
  const SmartPenState({
    this.isInitialized = false,
    this.isLoading = false,
    this.isComputing = false,
    this.isUploading = false,
    this.features,
    this.statistics,
    this.buttonStatus,
    this.aiResult,
    this.recordedSamples = 0,
    this.recordingDuration,
    this.displayData,
    this.error,
  });

  final bool isInitialized;
  final bool isLoading;
  final bool isComputing;
  final bool isUploading;
  final List<double>? features;
  final List<double>? statistics;
  final List<int>? buttonStatus;
  final Response? aiResult;
  final int recordedSamples;
  final Duration? recordingDuration;
  final SmartPenDisplayData? displayData;
  final String? error;

  SmartPenState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isComputing,
    bool? isUploading,
    Object? features = _smartPenStateUnset,
    Object? statistics = _smartPenStateUnset,
    Object? buttonStatus = _smartPenStateUnset,
    Object? aiResult = _smartPenStateUnset,
    int? recordedSamples,
    Object? recordingDuration = _smartPenStateUnset,
    Object? displayData = _smartPenStateUnset,
    Object? error = _smartPenStateUnset,
  }) {
    return SmartPenState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isComputing: isComputing ?? this.isComputing,
      isUploading: isUploading ?? this.isUploading,
      features: identical(features, _smartPenStateUnset)
          ? this.features
          : features as List<double>?,
      statistics: identical(statistics, _smartPenStateUnset)
          ? this.statistics
          : statistics as List<double>?,
      buttonStatus: identical(buttonStatus, _smartPenStateUnset)
          ? this.buttonStatus
          : buttonStatus as List<int>?,
      aiResult: identical(aiResult, _smartPenStateUnset)
          ? this.aiResult
          : aiResult as Response?,
      recordedSamples: recordedSamples ?? this.recordedSamples,
      recordingDuration: identical(recordingDuration, _smartPenStateUnset)
          ? this.recordingDuration
          : recordingDuration as Duration?,
      displayData: identical(displayData, _smartPenStateUnset)
          ? this.displayData
          : displayData as SmartPenDisplayData?,
      error: identical(error, _smartPenStateUnset)
          ? this.error
          : error as String?,
    );
  }
}

class SmartPenDisplayData {
  const SmartPenDisplayData({
    required this.pressureSeries,
    required this.accelerationSeries,
    required this.tremorSeries,
    required this.pressureIndex,
    required this.motionSmoothness,
    required this.tremorScore,
  });

  final List<double> pressureSeries;
  final List<double> accelerationSeries;
  final List<double> tremorSeries;
  final double pressureIndex;
  final double motionSmoothness;
  final double tremorScore;

  factory SmartPenDisplayData.fromRecording(PenRecordingData recording) {
    final acceleration = <double>[];
    for (var i = 0; i < recording.sampleCount; i++) {
      final ax = _safeValue(recording.accX, i);
      final ay = _safeValue(recording.accY, i);
      acceleration.add(math.sqrt((ax * ax) + (ay * ay)));
    }

    final tremor = <double>[];
    for (var i = 1; i < acceleration.length; i++) {
      tremor.add((acceleration[i] - acceleration[i - 1]).abs());
    }

    final pressureMean = _mean(recording.pressure);
    final pressureVariation = _standardDeviation(recording.pressure);
    final accMean = _mean(acceleration);
    final tremorMean = _mean(tremor);

    return SmartPenDisplayData(
      pressureSeries: _downsample(recording.pressure, maxPoints: 24),
      accelerationSeries: _downsample(acceleration, maxPoints: 24),
      tremorSeries: _downsample(tremor, maxPoints: 24),
      pressureIndex: pressureMean,
      motionSmoothness: (100 - (pressureVariation + tremorMean) * 100)
          .clamp(0, 100)
          .toDouble(),
      tremorScore: accMean == 0 ? 0 : (tremorMean / accMean) * 10,
    );
  }

  static double _safeValue(List<double> values, int index) {
    if (index < 0 || index >= values.length) {
      return 0;
    }
    return values[index];
  }

  static double _mean(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _standardDeviation(List<double> values) {
    if (values.length < 2) {
      return 0;
    }
    final avg = _mean(values);
    final variance = values
            .map((value) => math.pow(value - avg, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }

  static List<double> _downsample(List<double> values, {required int maxPoints}) {
    if (values.length <= maxPoints) {
      return values;
    }

    final step = values.length / maxPoints;
    return List.generate(maxPoints, (index) {
      return values[(index * step).floor().clamp(0, values.length - 1)];
    });
  }
}

final smartPenNotifierProvider =
    NotifierProvider<SmartPenNotifier, SmartPenState>(() {
      return SmartPenNotifier();
    });
