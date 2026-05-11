/// Model for Aula calendar events
class CalendarEvent {
  final int id;
  final String title;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String type;
  final Lesson? lesson;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startDateTime,
    required this.endDateTime,
    required this.type,
    this.lesson,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      startDateTime: _parseDateTime(json['startDateTime']),
      endDateTime: _parseDateTime(json['endDateTime']),
      type: json['type'] ?? '',
      lesson: json['lesson'] != null ? Lesson.fromJson(json['lesson']) : null,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

/// Model for lesson details within a calendar event
class Lesson {
  final int lessonId;
  final String? lessonStatus;
  final List<LessonParticipant> participants;

  Lesson({
    required this.lessonId,
    this.lessonStatus,
    this.participants = const [],
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final participantsList = json['participants'] as List? ?? [];
    return Lesson(
      lessonId: json['lessonId'] ?? 0,
      lessonStatus: json['lessonStatus'],
      participants: participantsList
          .map<LessonParticipant>((p) => LessonParticipant.fromJson(p))
          .toList(),
    );
  }

  /// Get the primary teacher for this lesson
  LessonParticipant? get primaryTeacher {
    try {
      return participants.firstWhere(
        (p) => p.participantRole == 'primaryTeacher',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Model for lesson participant (teacher, substitute, etc.)
class LessonParticipant {
  final int teacherId;
  final String? teacherName;
  final String? teacherInitials;
  final String participantRole;

  LessonParticipant({
    required this.teacherId,
    this.teacherName,
    this.teacherInitials,
    required this.participantRole,
  });

  factory LessonParticipant.fromJson(Map<String, dynamic> json) {
    return LessonParticipant(
      teacherId: json['teacherId'] ?? 0,
      teacherName: json['teacherName'],
      teacherInitials: json['teacherInitials'],
      participantRole: json['participantRole'] ?? '',
    );
  }
}
