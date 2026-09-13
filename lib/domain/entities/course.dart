class Course {
  final String id;
  final String title;
  final String description;
  final String category;
  final String instructor;
  final double price;
  final double rating;
  final int studentsCount;
  final String duration;
  final String thumbnail;
  final String? level;
  final int lessonsCount;
  final bool isEnrolled;
  final double progressPercentage;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.instructor,
    required this.price,
    required this.rating,
    required this.studentsCount,
    required this.duration,
    required this.thumbnail,
    this.level,
    this.lessonsCount = 0,
    this.isEnrolled = false,
    this.progressPercentage = 0.0,
  });

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? instructor,
    double? price,
    double? rating,
    int? studentsCount,
    String? duration,
    String? thumbnail,
    String? level,
    int? lessonsCount,
    bool? isEnrolled,
    double? progressPercentage,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      instructor: instructor ?? this.instructor,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      studentsCount: studentsCount ?? this.studentsCount,
      duration: duration ?? this.duration,
      thumbnail: thumbnail ?? this.thumbnail,
      level: level ?? this.level,
      lessonsCount: lessonsCount ?? this.lessonsCount,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      progressPercentage: progressPercentage ?? this.progressPercentage,
    );
  }
}

class Category {
  final int id;
  final String name;
  final String slug;
  final String? icon;
  final int coursesCount;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.coursesCount = 0,
  });
}
