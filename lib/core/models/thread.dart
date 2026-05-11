import 'package:hive/hive.dart';
import 'message.dart';


@HiveType(typeId: 2)
class Thread {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String subject;

  @HiveField(2)
  final List<ThreadParticipant> participants;

  @HiveField(3)
  final Message? latestMessage;

  @HiveField(4)
  final bool hasUnread;

  @HiveField(5)
  final DateTime? lastMessageDate;

  @HiveField(6)
  final int messageCount;

  @HiveField(7)
  final bool isArchived;

  Thread({
    required this.id,
    required this.subject,
    this.participants = const [],
    this.latestMessage,
    this.hasUnread = false,
    this.lastMessageDate,
    this.messageCount = 0,
    this.isArchived = false,
  });

  factory Thread.fromJson(Map<String, dynamic> json) {
    final recipients = json['recipients'] as List? ?? [];
    final creator = json['creator'];
    final latestMessage = json['latestMessage'] ?? json['latestReply'];

    // Parse participants from recipients and creator
    final participantsList = <ThreadParticipant>[];
    for (final r in recipients) {
      participantsList.add(ThreadParticipant.fromJson(r));
    }
    if (creator != null) {
      final creatorParticipant = ThreadParticipant.fromJson(creator);
      if (!participantsList.any((p) => p.id == creatorParticipant.id)) {
        participantsList.add(creatorParticipant);
      }
    }

    // Parse latest message
    Message? latest;
    if (latestMessage != null) {
      latest = Message.fromJson(latestMessage);
    }

    // Parse date - try multiple possible fields
    DateTime? lastDate;
    final lastDateStr = json['lastMessageDate'] ??
        latestMessage?['sendDateTime'] ??
        json['startedTime'];
    if (lastDateStr != null) {
      lastDate = DateTime.tryParse(lastDateStr);
    }

    return Thread(
      id: json['id'] ?? 0,
      subject: json['subject'] ?? '',
      participants: participantsList,
      latestMessage: latest,
      hasUnread: json['read'] == false,
      lastMessageDate: lastDate,
      messageCount: json['messageCount'] ?? json['numberOfMessages'] ?? 0,
      isArchived: json['isArchived'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'recipients': participants.map((p) => p.toJson()).toList(),
        'latestReply': latestMessage?.toJson(),
        'read': !hasUnread,
        'lastMessageDate': lastMessageDate?.toIso8601String(),
        'numberOfMessages': messageCount,
        'isArchived': isArchived,
      };

  Thread copyWith({
    int? id,
    String? subject,
    List<ThreadParticipant>? participants,
    Message? latestMessage,
    bool? hasUnread,
    DateTime? lastMessageDate,
    int? messageCount,
    bool? isArchived,
  }) {
    return Thread(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      participants: participants ?? this.participants,
      latestMessage: latestMessage ?? this.latestMessage,
      hasUnread: hasUnread ?? this.hasUnread,
      lastMessageDate: lastMessageDate ?? this.lastMessageDate,
      messageCount: messageCount ?? this.messageCount,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

@HiveType(typeId: 3)
class ThreadParticipant {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? profilePicture;

  @HiveField(3)
  final String? role;

  ThreadParticipant({
    required this.id,
    required this.name,
    this.profilePicture,
    this.role,
  });

  factory ThreadParticipant.fromJson(Map<String, dynamic> json) {
    final fullName = _extractName(json);

    return ThreadParticipant(
      id: json['id'] ?? json['institutionProfileId'] ?? 0,
      name: fullName.isNotEmpty ? fullName : 'Unknown',
      profilePicture: _extractProfilePicture(json['profilePicture']),
      role: json['role'] is String ? json['role'] : null,
    );
  }

  static String _extractName(Map<String, dynamic> json) {
    final fullName = json['fullName'];
    if (fullName is String) return fullName;

    final name = json['name'];
    if (name is String) return name;

    final firstName = json['firstName'];
    final lastName = json['lastName'];
    return '${firstName is String ? firstName : ''} ${lastName is String ? lastName : ''}'.trim();
  }

  static String? _extractProfilePicture(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value['url']?.toString();
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': name,
        'profilePicture': profilePicture != null ? {'url': profilePicture} : null,
        'role': role,
      };
}
