import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum JobStatus {
  success, // 0
  error, // 1
}

class Response {
  final JobStatus status;
  final String? prediction;
  final double? confidence;
  final String? message;

  // Pen AI-specific values.
  final double? pressureIndex;
  final double? motionSmoothness;
  final double? tremorScore;
  final List<double>? pressureSeries;
  final List<double>? accelerationSeries;
  final List<double>? tremorSeries;
  final List<double>? radarValues;

  Response({
    required this.status,
    this.prediction,
    this.confidence,
    this.message,
    this.pressureIndex,
    this.motionSmoothness,
    this.tremorScore,
    this.pressureSeries,
    this.accelerationSeries,
    this.tremorSeries,
    this.radarValues,
  });

  @override
  String toString() {
    switch (status) {
      case JobStatus.success:
        return "the results are \r\n "
            "Prediction: $prediction \r\n"
            "Confidence: $confidence \r\n";
      case JobStatus
          .error: // this will not occuire since we will go back to the send voice screen instead of here
        return "error happened \r\n "
            "Error: $message \r\n";
    }
  }

  factory Response.fromJson(Map<String, dynamic> json) {
    final statusValue = json['status'];
    final status = statusValue == null
        ? JobStatus.success
        : switch (statusValue) {
            'success' => JobStatus.success,
            'error' => JobStatus.error,
            _ => JobStatus.error,
          };

    return Response(
      status: status,
      prediction: (json['label'] ?? json['prediction']) as String?,
      confidence: ((json['probability'] ?? json['confidence']) as num?)
          ?.toDouble(),
      message: json['message'] as String?,
      pressureIndex: _tryParseDouble(json['pressureIndex'] ?? json['pressure_index']),
      motionSmoothness:
          _tryParseDouble(json['motionSmoothness'] ?? json['motion_smoothness']),
      tremorScore: _tryParseDouble(json['tremorScore'] ?? json['tremor_score']),
      pressureSeries: _tryParseDoubleList(
          json['pressureSeries'] ?? json['pressure_series']),
      accelerationSeries: _tryParseDoubleList(
          json['accelerationSeries'] ?? json['acceleration_series']),
      tremorSeries:
          _tryParseDoubleList(json['tremorSeries'] ?? json['tremor_series']),
      radarValues: _tryParseDoubleList(
          json['radarValues'] ?? json['radar_values'] ?? json['values'] ?? json['radar']),
    );
  }

  static double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<double>? _tryParseDoubleList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => _tryParseDouble(e) ?? 0.0)
          .toList(growable: false);
    }
    return null;
  }
}

final fileUploadProvider = AsyncNotifierProvider<FileUploadNotifier, Response?>(
  FileUploadNotifier.new,
);

class FileUploadNotifier extends AsyncNotifier<Response?> {
  @override
  Future<Response?> build() async {
    return null; // idle
  }

  /// Generic upload function
  Future<void> upload({
    required String path,
    required Future<Response> Function(String path) uploadFunction,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      if (kIsWeb) {
        return Response(
          status: JobStatus.success,
          prediction: "Demo result",
          confidence: 0.9,
        );
      }

      // Call the API-specific upload function
      final parsedResponse = await uploadFunction(path);

      return parsedResponse;
    });
  }
}
