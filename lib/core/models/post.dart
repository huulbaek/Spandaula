import 'package:hive/hive.dart';
import 'message.dart';


@HiveType(typeId: 7)
class Post {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String body;

  @HiveField(3)
  final String? htmlBody;

  @HiveField(4)
  final PostAuthor author;

  @HiveField(5)
  final DateTime timestamp;

  @HiveField(6)
  final List<Attachment> attachments;

  @HiveField(7)
  final String? institutionName;

  @HiveField(8)
  final bool isPinned;

  @HiveField(9)
  final int? relatedChildId;

  Post({
    required this.id,
    required this.title,
    required this.body,
    this.htmlBody,
    required this.author,
    required this.timestamp,
    this.attachments = const [],
    this.institutionName,
    this.isPinned = false,
    this.relatedChildId,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    // Extract content - handle both String and Map formats
    final htmlContent = _extractContent(json);
    final plainText = _stripHtmlTags(htmlContent);

    // Parse author
    final ownerProfile = json['ownerProfile'] ?? json['author'] ?? {};
    final author = PostAuthor.fromJson(ownerProfile);

    // Parse timestamp
    final dateStr = json['createdAt'] ?? json['timestamp'] ?? json['publishAt'];
    final timestamp = dateStr != null
        ? DateTime.tryParse(dateStr) ?? DateTime.now()
        : DateTime.now();

    // Parse attachments
    final attachmentsList = json['attachments'] as List? ?? [];

    return Post(
      id: json['id'] ?? 0,
      title: _extractString(json['title']) ?? '',
      body: plainText,
      htmlBody: htmlContent,
      author: author,
      timestamp: timestamp,
      attachments: attachmentsList.map<Attachment>((a) => Attachment.fromJson(a)).toList(),
      institutionName: _extractInstitutionName(json),
      isPinned: json['isPinned'] ?? json['pinned'] ?? false,
      relatedChildId: json['relatedInstitutionProfileId'] ?? json['relatedChildId'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': {'html': htmlBody ?? body},
        'ownerProfile': author.toJson(),
        'createdAt': timestamp.toIso8601String(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'ownerInstitution': institutionName != null ? {'name': institutionName} : null,
        'isPinned': isPinned,
        'relatedInstitutionProfileId': relatedChildId,
      };

  static String? _extractString(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value['name']?.toString() ?? value['text']?.toString();
    return value?.toString();
  }

  static String _extractContent(Map<String, dynamic> json) {
    // Try content.html first
    final content = json['content'];
    if (content is Map) {
      final html = content['html'];
      if (html is String) return html;
    }

    // Try body
    final body = json['body'];
    if (body is String) return body;
    if (body is Map) return body['html']?.toString() ?? body['text']?.toString() ?? '';

    // Fallback to content if it's a string
    if (content is String) return content;

    return '';
  }

  static String? _extractInstitutionName(Map<String, dynamic> json) {
    // Try ownerInstitution.name first
    final ownerInstitution = json['ownerInstitution'];
    if (ownerInstitution is Map) {
      final name = ownerInstitution['name'];
      if (name is String) return name;
    }

    // Fallback to institutionName
    final institutionName = json['institutionName'];
    if (institutionName is String) return institutionName;
    if (institutionName is Map) return institutionName['name']?.toString();

    return null;
  }

  static String _stripHtmlTags(String htmlText) {
    final withoutTags = htmlText.replaceAll(RegExp(r'<[^>]*>'), ' ');
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
}

@HiveType(typeId: 8)
class PostAuthor {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? profilePicture;

  @HiveField(3)
  final String? role;

  PostAuthor({
    required this.id,
    required this.name,
    this.profilePicture,
    this.role,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    final fullName = _extractName(json);

    return PostAuthor(
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
