// ignore_for_file: public_member_api_docs
// Wave 11: AI Domain Models — according to 05-ai-architecture.md.
// Invariant #11: AI is not source-of-truth; all calls are auditable in ai_artifacts.

enum AICapability {
  chat,
  proposeCategory,
  proposeAction,
  summarizeSession,
  suggestGoal,
  draftReflection,
  transcribeAudio,
}

enum AIRole {
  system,
  user,
  assistant,
}

class AIMessage {
  final AIRole role;
  final String content;

  const AIMessage({required this.role, required this.content});

  factory AIMessage.user(String content) =>
      AIMessage(role: AIRole.user, content: content);

  factory AIMessage.system(String content) =>
      AIMessage(role: AIRole.system, content: content);

  factory AIMessage.assistant(String content) =>
      AIMessage(role: AIRole.assistant, content: content);
}

class ContextBundle {
  final String? activeLifeAreaId;
  final String? activeGoalTitle;
  final String? activeTaskTitle;
  final int? recentXpTotal;
  final Map<String, dynamic> metadata;

  const ContextBundle({
    this.activeLifeAreaId,
    this.activeGoalTitle,
    this.activeTaskTitle,
    this.recentXpTotal,
    this.metadata = const {},
  });
}

class AICompletion {
  final String text;
  final String modelId;
  final int tokensIn;
  final int tokensOut;
  final String? structuredProposalJson;

  const AICompletion({
    required this.text,
    required this.modelId,
    required this.tokensIn,
    required this.tokensOut,
    this.structuredProposalJson,
  });
}

class TranscriptionResult {
  final String text;
  final int durationMs;
  final double confidence;

  const TranscriptionResult({
    required this.text,
    required this.durationMs,
    this.confidence = 0.95,
  });
}
