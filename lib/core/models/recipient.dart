import 'package:hive/hive.dart';


@HiveType(typeId: 9)
class Recipient {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? profilePicture;

  @HiveField(3)
  final String? role;

  @HiveField(4)
  final String? institutionName;

  @HiveField(5)
  final RecipientType type;

  Recipient({
    required this.id,
    required this.name,
    this.profilePicture,
    this.role,
    this.institutionName,
    this.type = RecipientType.person,
  });

  factory Recipient.fromJson(Map<String, dynamic> json) {
    final fullName = _extractName(json);

    // Determine type
    RecipientType type = RecipientType.person;
    if (json['type'] == 'group' || json['isGroup'] == true) {
      type = RecipientType.group;
    } else if (json['type'] == 'institution' || json['isInstitution'] == true) {
      type = RecipientType.institution;
    }

    return Recipient(
      id: _parseId(json['id']) ?? _parseId(json['institutionProfileId']) ?? 0,
      name: fullName.isNotEmpty ? fullName : 'Unknown',
      profilePicture: _extractProfilePicture(json['profilePicture']),
      role: _extractString(json['role']) ?? _extractString(json['title']),
      institutionName: _extractInstitutionName(json),
      type: type,
    );
  }

  static int? _parseId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
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

  static String? _extractString(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value['name']?.toString();
    return null;
  }

  static String? _extractProfilePicture(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value['url']?.toString();
    return null;
  }

  static String? _extractInstitutionName(Map<String, dynamic> json) {
    final institutionName = json['institutionName'];
    if (institutionName is String) return institutionName;
    if (institutionName is Map) return institutionName['name']?.toString();

    final institution = json['institution'];
    if (institution is Map) {
      final name = institution['name'];
      if (name is String) return name;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': name,
        'profilePicture': profilePicture != null ? {'url': profilePicture} : null,
        'role': role,
        'institutionName': institutionName,
        'type': type.name,
      };
}

@HiveType(typeId: 10)
enum RecipientType {
  @HiveField(0)
  person,
  @HiveField(1)
  group,
  @HiveField(2)
  institution,
}
