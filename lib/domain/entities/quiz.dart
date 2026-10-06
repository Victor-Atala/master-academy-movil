class Quiz {
  final String id;
  final String title;
  final String? description;
  final int passingScore;
  final bool isFinal;
  final int totalPoints;
  final int durationMinutes;
  final List<QuizQuestion> questions;
  final int courseId;
  final int? moduleId;
  final int? attemptsAllowed; // null = ilimitados (módulos), 5 = certificación

  const Quiz({
    required this.id,
    required this.title,
    this.description,
    this.passingScore = 75,
    this.isFinal = false,
    this.totalPoints = 100,
    this.durationMinutes = 20,
    required this.questions,
    required this.courseId,
    this.moduleId,
    this.attemptsAllowed,
  });

  bool get requiresCertificate => isFinal;
  bool get hasUnlimitedAttempts => !isFinal || attemptsAllowed == null;
  int get maxAttempts => isFinal ? (attemptsAllowed ?? 5) : 0;
}

class QuizQuestion {
  final String id;
  final String text;
  final int weightPoints;
  final List<QuizOption> options;
  final String? explanation;

  const QuizQuestion({
    required this.id,
    required this.text,
    required this.weightPoints,
    required this.options,
    this.explanation,
  });
}

class QuizOption {
  final String id;
  final String text;
  final bool isCorrect;

  const QuizOption({
    required this.id,
    required this.text,
    required this.isCorrect,
  });
}

class QuizAttempt {
  final String quizId;
  final int score;
  final double percentage;
  final bool isPassed;
  final DateTime timestamp;
  final Map<String, String> selectedOptionIds; // questionId -> optionId
  final int attemptNumber;
  final int? attemptsAllowed;
  final int? remainingAttempts;
  final bool courseReset;
  final bool requiresRepurchase;
  final String? resultMessage;

  const QuizAttempt({
    required this.quizId,
    required this.score,
    required this.percentage,
    required this.isPassed,
    required this.timestamp,
    required this.selectedOptionIds,
    this.attemptNumber = 1,
    this.attemptsAllowed,
    this.remainingAttempts,
    this.courseReset = false,
    this.requiresRepurchase = false,
    this.resultMessage,
  });
}
