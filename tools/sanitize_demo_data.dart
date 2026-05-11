// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Sanitizes recorded API data by replacing real names with fake Danish names.
///
/// Usage:
///   dart run tools/sanitize_demo_data.dart `<input.json>` [output.json]
///
/// If output is not specified, writes to assets/demo_data.json

// Common Danish first names
const danishFirstNames = [
  'Anders', 'Anne', 'Bjørn', 'Camilla', 'Christian', 'Christina',
  'Daniel', 'Emma', 'Erik', 'Fie', 'Frederik', 'Hanne',
  'Henrik', 'Ida', 'Jakob', 'Jens', 'Karen', 'Kasper',
  'Katrine', 'Klaus', 'Lars', 'Laura', 'Lene', 'Louise',
  'Magnus', 'Maria', 'Martin', 'Mathilde', 'Mette', 'Michael',
  'Mikkel', 'Nanna', 'Niels', 'Oliver', 'Oscar', 'Peter',
  'Pia', 'Rasmus', 'Rikke', 'Signe', 'Simon', 'Sofie',
  'Søren', 'Thomas', 'Trine', 'Victor', 'Viktor', 'William',
];

// Common Danish last names
const danishLastNames = [
  'Andersen', 'Christensen', 'Hansen', 'Jensen', 'Johansen',
  'Larsen', 'Madsen', 'Mortensen', 'Nielsen', 'Olsen',
  'Pedersen', 'Petersen', 'Poulsen', 'Rasmussen', 'Sørensen',
  'Thomsen', 'Frederiksen', 'Henriksen', 'Jacobsen', 'Jørgensen',
  'Kristensen', 'Laursen', 'Mikkelsen', 'Møller', 'Eriksen',
];

// Fake school names
const fakeSchoolNames = [
  'Skovbrynet Skole',
  'Bakketoppen Skole',
  'Strandvejens Skole',
  'Møllevang Skole',
  'Engparken Skole',
];

// Fake institution codes
const fakeInstitutionCodes = [
  '123456',
  '234567',
  '345678',
];

class _FakeIdentity {
  final String first;
  final String last;
  _FakeIdentity(this.first, this.last);
}

class DataSanitizer {
  final Map<String, String> _firstNameMap = {};
  final Map<String, String> _lastNameMap = {};
  final Map<String, String> _fullNameMap = {};
  final Map<String, String> _institutionMap = {};
  final Map<String, String> _institutionCodeMap = {};
  final Map<int, int> _idMap = {};
  final Map<String, _FakeIdentity> _personMap = {};

  int _firstNameIndex = 0;
  int _lastNameIndex = 0;
  int _schoolIndex = 0;
  int _codeIndex = 0;
  int _nextId = 1000;

  // Matches any URL on an aula.dk subdomain (e.g. media-prod.aula.dk).
  // Used to scrub leaked media/asset URLs from recorded API data.
  static final RegExp _aulaUrlPattern = RegExp(
    r'https?://[a-zA-Z0-9.-]*aula\.dk/[^\s"<>]*',
    caseSensitive: false,
  );

  String _scrubUrls(String input) {
    if (!input.contains('aula.dk')) return input;
    return input.replaceAll(_aulaUrlPattern, 'https://example.invalid/demo-asset');
  }

  /// Pre-establish a single fake identity for a profile-like map so that
  /// firstName/lastName/fullName fields all resolve to the same fake person.
  void _establishProfileIdentity(Map<String, dynamic> data) {
    final realFirst = data['firstName'] is String ? data['firstName'] as String : null;
    final realLast = data['lastName'] is String ? data['lastName'] as String : null;
    final realFull = data['fullName'] is String ? data['fullName'] as String : null;

    final hasFirst = realFirst != null && realFirst.isNotEmpty;
    final hasLast = realLast != null && realLast.isNotEmpty;
    final hasFull = realFull != null && realFull.isNotEmpty;
    if (!hasFirst && !hasLast && !hasFull) return;

    final identityKey = '${realFirst ?? ''}|${realLast ?? ''}|${realFull ?? ''}';
    final identity = _personMap.putIfAbsent(identityKey, () {
      final fakeFirst = danishFirstNames[_firstNameIndex % danishFirstNames.length];
      _firstNameIndex++;
      final fakeLast = danishLastNames[_lastNameIndex % danishLastNames.length];
      _lastNameIndex++;
      return _FakeIdentity(fakeFirst, fakeLast);
    });

    if (hasFirst) _firstNameMap[realFirst] = identity.first;
    if (hasLast) _lastNameMap[realLast] = identity.last;
    if (hasFull) _fullNameMap[realFull] = '${identity.first} ${identity.last}';
  }

  /// Get a fake first name for a real first name (consistent mapping)
  String _mapFirstName(String realName) {
    if (realName.isEmpty) return realName;
    return _firstNameMap.putIfAbsent(realName, () {
      final fake = danishFirstNames[_firstNameIndex % danishFirstNames.length];
      _firstNameIndex++;
      return fake;
    });
  }

  /// Get a fake last name for a real last name (consistent mapping)
  String _mapLastName(String realName) {
    if (realName.isEmpty) return realName;
    return _lastNameMap.putIfAbsent(realName, () {
      final fake = danishLastNames[_lastNameIndex % danishLastNames.length];
      _lastNameIndex++;
      return fake;
    });
  }

  /// Get a fake full name for a real full name
  String _mapFullName(String realName) {
    if (realName.isEmpty) return realName;
    return _fullNameMap.putIfAbsent(realName, () {
      final parts = realName.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) return realName;
      if (parts.length == 1) {
        return _mapFirstName(parts[0]);
      }
      final fakeFirst = _mapFirstName(parts.first);
      final fakeLast = _mapLastName(parts.last);
      return '$fakeFirst $fakeLast';
    });
  }

  /// Get a fake school name
  String _mapInstitution(String realName) {
    if (realName.isEmpty) return realName;
    return _institutionMap.putIfAbsent(realName, () {
      final fake = fakeSchoolNames[_schoolIndex % fakeSchoolNames.length];
      _schoolIndex++;
      return fake;
    });
  }

  /// Get a fake institution code
  String _mapInstitutionCode(String realCode) {
    if (realCode.isEmpty) return realCode;
    return _institutionCodeMap.putIfAbsent(realCode, () {
      final fake = fakeInstitutionCodes[_codeIndex % fakeInstitutionCodes.length];
      _codeIndex++;
      return fake;
    });
  }

  /// Get a fake ID (consistent mapping)
  int _mapId(int realId) {
    if (realId == 0) return 0;
    return _idMap.putIfAbsent(realId, () => _nextId++);
  }

  /// Sanitize text content by replacing any known names (whole words only)
  String _sanitizeText(String text) {
    var result = text;

    // Sort by length descending to replace longest matches first
    final sortedFullNames = _fullNameMap.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    final sortedFirstNames = _firstNameMap.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    final sortedLastNames = _lastNameMap.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    final sortedInstitutions = _institutionMap.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    // Replace full names first (with word boundaries)
    for (final entry in sortedFullNames) {
      result = _replaceWholeWord(result, entry.key, entry.value);
    }
    // Then institutions (before individual names, as they may contain names)
    for (final entry in sortedInstitutions) {
      result = _replaceWholeWord(result, entry.key, entry.value);
    }
    // Then first names (only if 3+ chars to avoid false matches)
    for (final entry in sortedFirstNames) {
      if (entry.key.length >= 3) {
        result = _replaceWholeWord(result, entry.key, entry.value);
      }
    }
    // Then last names (only if 3+ chars)
    for (final entry in sortedLastNames) {
      if (entry.key.length >= 3) {
        result = _replaceWholeWord(result, entry.key, entry.value);
      }
    }
    return result;
  }

  /// Replace whole words only (not partial matches inside other words)
  String _replaceWholeWord(String text, String search, String replacement) {
    if (search.isEmpty) return text;
    // Use word boundary regex - handles Danish characters
    // Match if preceded by start/whitespace/punctuation and followed by end/whitespace/punctuation
    final pattern = RegExp(
      r'(?<=^|[\s,.\-:;!?()"<>])' + RegExp.escape(search) + r'(?=$|[\s,.\-:;!?()"<>])',
      caseSensitive: true,
    );
    return text.replaceAll(pattern, replacement);
  }

  /// First pass: collect all names to build the mapping
  void collectNames(dynamic data) {
    if (data is Map<String, dynamic>) {
      // Collect names from known fields
      _collectNameField(data, 'firstName', isFirstName: true);
      _collectNameField(data, 'lastName', isLastName: true);
      _collectNameField(data, 'fullName');
      _collectNameField(data, 'name');
      _collectNameField(data, 'teacherName');
      _collectInstitutionField(data, 'institutionName');
      _collectInstitutionField(data, 'institutionCode', isCode: true);

      // Recurse into nested structures
      for (final value in data.values) {
        collectNames(value);
      }
    } else if (data is List) {
      for (final item in data) {
        collectNames(item);
      }
    }
  }

  void _collectNameField(Map<String, dynamic> data, String key, {bool isFirstName = false, bool isLastName = false}) {
    final value = data[key];
    if (value is String && value.isNotEmpty) {
      if (isFirstName) {
        _mapFirstName(value);
      } else if (isLastName) {
        _mapLastName(value);
      } else {
        _mapFullName(value);
      }
    } else if (value is Map) {
      final name = value['name']?.toString() ?? value['text']?.toString();
      if (name != null && name.isNotEmpty) {
        _mapFullName(name);
      }
    }
  }

  void _collectInstitutionField(Map<String, dynamic> data, String key, {bool isCode = false}) {
    final value = data[key];
    if (value is String && value.isNotEmpty) {
      if (isCode) {
        _mapInstitutionCode(value);
      } else {
        _mapInstitution(value);
      }
    } else if (value is Map) {
      final name = value['name']?.toString();
      if (name != null && name.isNotEmpty) {
        _mapInstitution(name);
      }
    }
  }

  /// Second pass: sanitize all data
  dynamic sanitize(dynamic data) {
    if (data is Map<String, dynamic>) {
      // Lock in a single fake identity for this profile-like object before
      // we walk its fields, so firstName/lastName/fullName stay consistent.
      _establishProfileIdentity(data);
      final result = <String, dynamic>{};

      for (final entry in data.entries) {
        final key = entry.key;
        var value = entry.value;

        // Handle specific fields
        if (_isNameField(key)) {
          value = _sanitizeNameValue(value, key);
        } else if (_isInstitutionField(key)) {
          value = _sanitizeInstitutionValue(value, key);
        } else if (_isIdField(key) && value is int) {
          value = _mapId(value);
        } else if (_isProfilePictureField(key)) {
          value = null; // Remove profile pictures
        } else if (_isEmailField(key) && value is String) {
          value = 'demo@example.dk';
        } else if (_isTextField(key) && value is String) {
          value = _sanitizeText(value);
        } else if (_isHtmlTextField(key)) {
          value = _sanitizeHtmlValue(value);
        } else {
          value = sanitize(value);
        }

        result[key] = value;
      }

      return result;
    } else if (data is List) {
      return data.map((item) => sanitize(item)).toList();
    } else if (data is String) {
      return _scrubUrls(data);
    }

    return data;
  }

  bool _isNameField(String key) {
    return [
      'firstName', 'lastName', 'fullName', 'name', 'shortName',
      'teacherName', 'teacherInitials', 'displayName', 'username',
    ].contains(key);
  }

  bool _isInstitutionField(String key) {
    return ['institutionName', 'institutionCode', 'ownerInstitution'].contains(key);
  }

  bool _isIdField(String key) {
    // Don't change IDs - they're needed for API lookups
    return false;
  }

  bool _isProfilePictureField(String key) {
    return key == 'profilePicture' || key == 'profilePictureUrl' || key == 'avatarUrl';
  }

  bool _isEmailField(String key) {
    return key == 'email' || key == 'emailAddress';
  }

  bool _isTextField(String key) {
    // Don't auto-sanitize text content - it mangles words
    // Only sanitize explicit name fields
    return false;
  }

  bool _isHtmlTextField(String key) {
    // Don't auto-sanitize HTML content - it mangles words
    return false;
  }

  dynamic _sanitizeNameValue(dynamic value, String key) {
    if (value is String && value.isNotEmpty) {
      if (key == 'firstName') {
        return _mapFirstName(value);
      } else if (key == 'lastName') {
        return _mapLastName(value);
      } else if (key == 'teacherInitials') {
        // Generate initials from mapped name
        final mapped = _fullNameMap.entries.firstWhere(
          (e) => value.toLowerCase() == _getInitials(e.key).toLowerCase(),
          orElse: () => MapEntry(value, value),
        );
        return _getInitials(mapped.value);
      } else {
        return _mapFullName(value);
      }
    } else if (value is Map<String, dynamic>) {
      final name = value['name']?.toString() ?? value['text']?.toString();
      if (name != null) {
        return {'name': _mapFullName(name)};
      }
    }
    return sanitize(value);
  }

  String _getInitials(String name) {
    final parts = name.split(RegExp(r'\s+'));
    return parts.map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
  }

  dynamic _sanitizeInstitutionValue(dynamic value, String key) {
    if (value is String && value.isNotEmpty) {
      if (key == 'institutionCode') {
        return _mapInstitutionCode(value);
      }
      return _mapInstitution(value);
    } else if (value is Map<String, dynamic>) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        if (entry.key == 'name' && entry.value is String) {
          result['name'] = _mapInstitution(entry.value);
        } else if (entry.key == 'institutionCode' && entry.value is String) {
          result['institutionCode'] = _mapInstitutionCode(entry.value);
        } else {
          result[entry.key] = sanitize(entry.value);
        }
      }
      return result;
    }
    return sanitize(value);
  }

  dynamic _sanitizeHtmlValue(dynamic value) {
    if (value is String) {
      return _sanitizeText(value);
    } else if (value is Map<String, dynamic>) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        if (entry.key == 'html' && entry.value is String) {
          result['html'] = _sanitizeText(entry.value);
        } else {
          result[entry.key] = sanitize(entry.value);
        }
      }
      return result;
    }
    return value;
  }

  void printMappings() {
    print('\n=== Name Mappings ===');
    print('First names: ${_firstNameMap.length}');
    for (final e in _firstNameMap.entries) {
      print('  ${e.key} -> ${e.value}');
    }
    print('\nLast names: ${_lastNameMap.length}');
    for (final e in _lastNameMap.entries) {
      print('  ${e.key} -> ${e.value}');
    }
    print('\nFull names: ${_fullNameMap.length}');
    for (final e in _fullNameMap.entries) {
      print('  ${e.key} -> ${e.value}');
    }
    print('\nInstitutions: ${_institutionMap.length}');
    for (final e in _institutionMap.entries) {
      print('  ${e.key} -> ${e.value}');
    }
  }
}

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run tools/sanitize_demo_data.dart <input.json> [output.json]');
    print('');
    print('Input: Raw recorded API data (e.g., demo_data_raw.json)');
    print('Output: Sanitized demo data (default: assets/demo_data.json)');
    exit(1);
  }

  final inputPath = args[0];
  final outputPath = args.length > 1 ? args[1] : 'assets/demo_data.json';

  // Read input file
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    print('Error: Input file not found: $inputPath');
    exit(1);
  }

  print('Reading $inputPath...');
  final inputJson = inputFile.readAsStringSync();
  final data = jsonDecode(inputJson);

  // Create sanitizer
  final sanitizer = DataSanitizer();

  // First pass: collect all names
  print('Collecting names...');
  sanitizer.collectNames(data);

  // Print mappings for review
  sanitizer.printMappings();

  // Second pass: sanitize data
  print('\nSanitizing data...');
  final sanitized = sanitizer.sanitize(data);

  // Ensure output directory exists
  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);

  // Write output
  print('Writing $outputPath...');
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(sanitized),
  );

  print('\nDone! Sanitized data written to $outputPath');
  print('');
  print('Next steps:');
  print('1. Review the name mappings above');
  print('2. Check $outputPath for any remaining PII');
  print('3. Run: flutter run --dart-define=DEMO_MODE=true');
}
