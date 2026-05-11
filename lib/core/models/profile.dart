import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class Profile {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String firstName;

  @HiveField(2)
  final String lastName;

  @HiveField(3)
  final String? profilePicture;

  @HiveField(4)
  final List<int> institutionProfileIds;

  @HiveField(5)
  final List<ChildProfile> children;

  @HiveField(6)
  final String? email;

  @HiveField(7)
  final List<String> institutionCodes;

  Profile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.institutionProfileIds = const [],
    this.children = const [],
    this.email,
    this.institutionCodes = const [],
  });

  String get fullName => '$firstName $lastName';

  factory Profile.fromJson(Map<String, dynamic> json) {
    final institutionProfiles = json['institutionProfiles'] as List? ?? [];
    final childrenList = json['children'] as List? ?? [];

    // Extract institution codes from institutionProfiles
    final codes = <String>[];
    for (final ip in institutionProfiles) {
      final code = ip['institutionCode']?.toString();
      if (code != null && code.isNotEmpty && !codes.contains(code)) {
        codes.add(code);
      }
    }

    // v23: firstName/lastName may be in institutionProfiles[0], displayName at top level
    final firstIp = institutionProfiles.isNotEmpty ? institutionProfiles[0] : null;
    final displayName = json['displayName']?.toString() ?? '';

    return Profile(
      id: json['id'] ?? json['profileId'] ?? 0,
      firstName: _extractString(json['firstName'])
          ?? _extractString(firstIp?['firstName'])
          ?? displayName.split(' ').first,
      lastName: _extractString(json['lastName'])
          ?? _extractString(firstIp?['lastName'])
          ?? displayName.split(' ').skip(1).join(' '),
      profilePicture: _extractProfilePicture(json['profilePicture']),
      institutionProfileIds: institutionProfiles
          .map<int>((p) => p['id'] as int? ?? 0)
          .where((id) => id > 0)
          .toList(),
      children: childrenList
          .map<ChildProfile>((c) => ChildProfile.fromJson(c))
          .toList(),
      email: _extractString(json['email']),
      institutionCodes: codes,
    );
  }

  static String? _extractString(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value['name']?.toString() ?? value['text']?.toString();
    return null;
  }

  static String? _extractProfilePicture(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value['url']?.toString();
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'profilePicture': profilePicture != null ? {'url': profilePicture} : null,
        'institutionProfiles': institutionProfileIds.asMap().entries.map((e) => {
          'id': e.value,
          if (e.key < institutionCodes.length) 'institutionCode': institutionCodes[e.key],
        }).toList(),
        'children': children.map((c) => c.toJson()).toList(),
        'email': email,
      };
}

@HiveType(typeId: 1)
class ChildProfile {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String firstName;

  @HiveField(2)
  final String lastName;

  @HiveField(3)
  final String? profilePicture;

  @HiveField(4)
  final int? institutionProfileId;

  @HiveField(5)
  final String? institutionName;

  ChildProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.institutionProfileId,
    this.institutionName,
  });

  String get fullName => '$firstName $lastName';

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    // Try to get firstName/lastName from top level, then institutionProfile, then split 'name'
    final instProfile = json['institutionProfile'] as Map<String, dynamic>?;

    String firstName = _extractString(json['firstName']) ??
        _extractString(instProfile?['firstName']) ?? '';
    String lastName = _extractString(json['lastName']) ??
        _extractString(instProfile?['lastName']) ?? '';

    // If still empty, try splitting the 'name' field
    if (firstName.isEmpty && lastName.isEmpty) {
      final fullName = json['name']?.toString() ??
          instProfile?['fullName']?.toString() ?? '';
      final parts = fullName.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.skip(1).join(' ');
        }
      }
    }

    return ChildProfile(
      id: json['id'] ?? 0,
      firstName: firstName,
      lastName: lastName,
      profilePicture: _extractProfilePicture(json['profilePicture']),
      institutionProfileId: instProfile?['id'],
      institutionName: _extractInstitutionName(json),
    );
  }

  static String? _extractString(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value['name']?.toString() ?? value['text']?.toString();
    return null;
  }

  static String? _extractProfilePicture(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value['url']?.toString();
    return null;
  }

  static String? _extractInstitutionName(Map<String, dynamic> json) {
    final institutionProfile = json['institutionProfile'];
    if (institutionProfile is Map) {
      final name = institutionProfile['institutionName'];
      if (name is String) return name;
      if (name is Map) return name['name']?.toString();
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'profilePicture': profilePicture != null ? {'url': profilePicture} : null,
        'institutionProfile': institutionProfileId != null
            ? {'id': institutionProfileId, 'institutionName': institutionName}
            : null,
      };
}
