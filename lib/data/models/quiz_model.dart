import '../../domain/entities/quiz.dart';

class QuizModel extends Quiz {
  const QuizModel({
    required super.id,
    required super.title,
    super.description,
    super.passingScore,
    super.isFinal,
    super.totalPoints,
    super.durationMinutes,
    required super.questions,
    required super.courseId,
    super.moduleId,
    super.attemptsAllowed,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    var rawQuestions = json['questions'] as List? ?? json['preguntas'] as List? ?? [];
    List<QuizQuestion> questionsList = rawQuestions
        .map((q) => QuizQuestionModel.fromJson(q as Map<String, dynamic>))
        .toList();

    final isFinal = json['is_final'] == true || json['isFinal'] == true || json['es_final'] == true;
    final attempts = json['attempts_allowed'] as int? ?? json['attemptsAllowed'] as int? ?? (isFinal ? 5 : null);

    return QuizModel(
      id: json['id']?.toString() ?? 'quiz-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? json['titulo']?.toString() ?? 'Evaluación de Conocimientos',
      description: json['description']?.toString() ?? json['descripcion']?.toString(),
      passingScore: json['passing_score'] as int? ?? json['passingScore'] as int? ?? json['nota_minima'] as int? ?? 75,
      isFinal: isFinal,
      attemptsAllowed: attempts,
      totalPoints: json['total_points'] as int? ?? json['totalPoints'] as int? ?? 100,
      durationMinutes: json['duration_minutes'] as int? ?? json['durationMinutes'] as int? ?? 20,
      questions: questionsList,
      courseId: json['course_id'] is int
          ? json['course_id'] as int
          : int.tryParse(json['course_id']?.toString() ?? '1') ?? 1,
      moduleId: json['module_id'] is int
          ? json['module_id'] as int
          : int.tryParse(json['module_id']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'passing_score': passingScore,
      'is_final': isFinal,
      'attempts_allowed': attemptsAllowed,
      'total_points': totalPoints,
      'duration_minutes': durationMinutes,
      'course_id': courseId,
      'module_id': moduleId,
      'questions': questions.map((q) => (q as QuizQuestionModel).toJson()).toList(),
    };
  }
}

class QuizQuestionModel extends QuizQuestion {
  const QuizQuestionModel({
    required super.id,
    required super.text,
    required super.weightPoints,
    required super.options,
    super.explanation,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    var rawOptions = json['options'] as List? ?? json['opciones'] as List? ?? [];
    List<QuizOption> optionsList = rawOptions
        .map((opt) => QuizOptionModel.fromJson(opt as Map<String, dynamic>))
        .toList();

    return QuizQuestionModel(
      id: json['id']?.toString() ?? 'q-${DateTime.now().millisecondsSinceEpoch}',
      text: json['text']?.toString() ?? json['texto']?.toString() ?? json['question']?.toString() ?? '',
      weightPoints: json['weight_points'] as int? ?? json['weightPoints'] as int? ?? json['puntos'] as int? ?? 25,
      options: optionsList,
      explanation: json['explanation']?.toString() ?? json['explicacion']?.toString() ?? json['retroalimentacion']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'weight_points': weightPoints,
      'explanation': explanation,
      'options': options.map((opt) => (opt as QuizOptionModel).toJson()).toList(),
    };
  }
}

class QuizOptionModel extends QuizOption {
  const QuizOptionModel({
    required super.id,
    required super.text,
    required super.isCorrect,
  });

  factory QuizOptionModel.fromJson(Map<String, dynamic> json) {
    return QuizOptionModel(
      id: json['id']?.toString() ?? 'opt-${DateTime.now().millisecondsSinceEpoch}',
      text: json['text']?.toString() ?? json['texto']?.toString() ?? '',
      isCorrect: json['is_correct'] == true || json['isCorrect'] == true || json['es_correcta'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'is_correct': isCorrect,
    };
  }
}

class QuizAttemptModel extends QuizAttempt {
  const QuizAttemptModel({
    required super.quizId,
    required super.score,
    required super.percentage,
    required super.isPassed,
    required super.timestamp,
    required super.selectedOptionIds,
    super.attemptNumber,
    super.attemptsAllowed,
    super.remainingAttempts,
    super.courseReset,
    super.requiresRepurchase,
    super.resultMessage,
  });

  factory QuizAttemptModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> answers = {};
    if (json['selected_options'] is Map) {
      (json['selected_options'] as Map).forEach((key, value) {
        answers[key.toString()] = value.toString();
      });
    }

    return QuizAttemptModel(
      quizId: json['quiz_id']?.toString() ?? '',
      score: json['score'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      isPassed: json['is_passed'] == true,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      selectedOptionIds: answers,
      attemptNumber: json['attempt_number'] as int? ?? 1,
      attemptsAllowed: json['attempts_allowed'] as int?,
      remainingAttempts: json['remaining_attempts'] as int?,
      courseReset: json['course_reset'] == true,
      requiresRepurchase: json['requires_repurchase'] == true,
      resultMessage: json['result_message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'score': score,
      'percentage': percentage,
      'is_passed': isPassed,
      'timestamp': timestamp.toIso8601String(),
      'selected_options': selectedOptionIds,
      'attempt_number': attemptNumber,
      'attempts_allowed': attemptsAllowed,
      'remaining_attempts': remainingAttempts,
      'course_reset': courseReset,
      'requires_repurchase': requiresRepurchase,
      'result_message': resultMessage,
    };
  }
}
