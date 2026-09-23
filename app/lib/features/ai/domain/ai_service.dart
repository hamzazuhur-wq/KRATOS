// ignore_for_file: public_member_api_docs
// Wave 11: AIService Interface per 05-ai-architecture.md §2.1.
// Defines typed capabilities, chat completion, audio transcription, and audit logging.

import 'ai_models.dart';

abstract class AIService {
  /// Complete a prompt with capability-specific context.
  Future<AICompletion> complete({
    required AICapability capability,
    required List<AIMessage> messages,
    required ContextBundle context,
    String? relatedEntityId,
    String? relatedEntityKind,
  });

  /// Transcribe audio buffer or path via Whisper.
  Future<TranscriptionResult> transcribe({
    required String audioPath,
    int? durationMs,
  });
}
