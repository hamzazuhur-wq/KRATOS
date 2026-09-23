// ignore_for_file: public_member_api_docs
// Wave 20: Multimodal Vision & Streaming Tool-Calling Domain Models.
// References: 05-ai-architecture.md §13.2 (Streaming UX), §13.3 (Multi-modal), §13.4 (Floor fallback).

enum ImageMimeType {
  jpeg,
  png,
  webp,
}

class MultimodalInput {
  final String imagePath;
  final ImageMimeType mimeType;
  final String userPrompt;
  final int? maxTokens;

  const MultimodalInput({
    required this.imagePath,
    required this.userPrompt,
    this.mimeType = ImageMimeType.jpeg,
    this.maxTokens = 500,
  });
}

class VisionAnalysisResult {
  final String detectedActivity;
  final Map<String, dynamic> extractedMetrics;
  final int proposedXp;
  final String lifeAreaId;
  final double confidence;
  final String rawExplanation;

  const VisionAnalysisResult({
    required this.detectedActivity,
    required this.extractedMetrics,
    required this.proposedXp,
    required this.lifeAreaId,
    required this.confidence,
    required this.rawExplanation,
  });
}

class StreamingToolCallChunk {
  final String toolName;
  final String argumentDelta;
  final bool isComplete;

  const StreamingToolCallChunk({
    required this.toolName,
    required this.argumentDelta,
    this.isComplete = false,
  });
}

class ProviderFallbackPolicy {
  final double failureThreshold; // e.g. 0.30 (30%)
  int totalRequests = 0;
  int failedRequests = 0;

  ProviderFallbackPolicy({this.failureThreshold = 0.30});

  void recordSuccess() => totalRequests++;

  void recordFailure() {
    totalRequests++;
    failedRequests++;
  }

  double get failureRate => totalRequests == 0 ? 0.0 : failedRequests / totalRequests;

  /// Returns true if failure rate exceeds the 30% threshold, triggering cloud fallback.
  bool get shouldFallbackToCloud => totalRequests >= 5 && failureRate >= failureThreshold;

  void reset() {
    totalRequests = 0;
    failedRequests = 0;
  }
}
