import 'package:hive/hive.dart';


@HiveType(typeId: 4)
class Message {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String text;

  @HiveField(2)
  final String? htmlText;

  @HiveField(3)
  final MessageSender sender;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final List<Attachment> attachments;

  @HiveField(6)
  final int? threadId;

  @HiveField(7)
  final bool isRead;

  Message({
    required this.id,
    required this.text,
    this.htmlText,
    required this.sender,
    required this.timestamp,
    this.attachments = const [],
    this.threadId,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Extract plain text from HTML if needed - text can be String or {html: "..."}
    final htmlContent = _extractText(json);
    final plainText = _stripHtmlTags(htmlContent);

    // Parse sender
    final senderData = json['sender'] ?? json['creator'] ?? json;
    final sender = MessageSender.fromJson(senderData);

    // Parse timestamp
    final dateStr =
        json['sendDateTime'] ?? json['createdAt'] ?? json['timestamp'];
    final timestamp = dateStr != null
        ? DateTime.tryParse(dateStr) ?? DateTime.now()
        : DateTime.now();

    // Parse attachments
    final attachmentsList = json['attachments'] as List? ?? [];

    return Message(
      id: json['id']?.toString() ?? '',
      text: plainText,
      htmlText: htmlContent,
      sender: sender,
      timestamp: timestamp,
      attachments: attachmentsList
          .map<Attachment>((a) => Attachment.fromJson(a))
          .toList(),
      threadId: json['threadId'],
      isRead: json['isRead'] ?? json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': htmlText ?? text,
    'sender': sender.toJson(),
    'sendDateTime': timestamp.toIso8601String(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'threadId': threadId,
    'read': isRead,
  };

  /// Strip HTML tags from text
  static String _stripHtmlTags(String htmlText) {
    // Remove HTML tags
    final withoutTags = htmlText.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Decode common HTML entities
    return withoutTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _extractText(Map<String, dynamic> json) {
    final text = json['text'];
    if (text is String) return text;
    if (text is Map) return text['html']?.toString() ?? '';

    final message = json['message'];
    if (message is Map) {
      final msgText = message['text'];
      if (msgText is String) return msgText;
      if (msgText is Map) return msgText['html']?.toString() ?? '';
    }

    return '';
  }
}

@HiveType(typeId: 5)
class MessageSender {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? profilePicture;

  MessageSender({required this.id, required this.name, this.profilePicture});

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    final fullName = _extractName(json);

    // Extract ID - check mailBoxOwner for nested structure
    final mailBoxOwner = json['mailBoxOwner'] as Map<String, dynamic>?;
    final id = json['id'] ??
        json['institutionProfileId'] ??
        mailBoxOwner?['id'] ??
        mailBoxOwner?['profileId'] ??
        0;

    return MessageSender(
      id: id is int ? id : int.tryParse(id.toString()) ?? 0,
      name: fullName.isNotEmpty ? fullName : 'Unknown',
      profilePicture: _extractProfilePicture(json['profilePicture']),
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
  };
}

@HiveType(typeId: 6)
class Attachment {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? url;

  @HiveField(3)
  final String? mimeType;

  @HiveField(4)
  final int? size;

  Attachment({
    required this.id,
    required this.name,
    this.url,
    this.mimeType,
    this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] ?? 0,
      name: _extractString(json['name']) ?? _extractString(json['fileName']) ?? 'Attachment',
      url: _extractString(json['url']) ?? _extractString(json['downloadUrl']),
      mimeType: _extractString(json['mimeType']) ?? _extractString(json['contentType']),
      size: json['size'] is int ? json['size'] : json['fileSize'] is int ? json['fileSize'] : null,
    );
  }

  static String? _extractString(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value['name']?.toString() ?? value['url']?.toString();
    return value?.toString();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'mimeType': mimeType,
    'size': size,
  };

  bool get isImage =>
      mimeType?.startsWith('image/') == true ||
      name.toLowerCase().endsWith('.jpg') ||
      name.toLowerCase().endsWith('.jpeg') ||
      name.toLowerCase().endsWith('.png') ||
      name.toLowerCase().endsWith('.gif');
}
