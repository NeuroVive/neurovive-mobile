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
    );

    try {
      final features = _service.computeFeatures(
        x: recording.x,
        y: recording.y,
        pressure: recording.pressure,
        azimuth: recording.azimuth,
        altitude: recording.altitude,
        accX: recording.accX,
        accY: recording.accY,
      );

      if (kDebugMode) {
        print('x: ${recording.x.last}, y: ${recording.y.last}');
      }

      if (features == null) {
        state = state.copyWith(
          isComputing: false,
          error: _service.getLastError(),
        );
        return null;
      }

      final statistics = _service.computeStatisticalSingle(recording.pressure);
      final buttonStatus = _service.computeButtonStatus(recording.pressure);

      state = state.copyWith(
        isComputing: false,
        features: features,
        statistics: statistics,
        buttonStatus: buttonStatus,
        error: null,
      );

      state = state.copyWith(isUploading: true);
      final aiResult = await Api.sendPenFeatures(features);

      state = state.copyWith(
        isUploading: false,
        aiResult: aiResult,
        error: aiResult.status == JobStatus.error ? aiResult.message : null,
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
      error: identical(error, _smartPenStateUnset)
          ? this.error
          : error as String?,
    );
  }
}

final smartPenNotifierProvider =
    NotifierProvider<SmartPenNotifier, SmartPenState>(() {
      return SmartPenNotifier();
    });
