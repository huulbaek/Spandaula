import 'package:intl/intl.dart';

/// Utility class for formatting dates in Danish
class DateFormatUtils {
  static final DateFormat _fullDate = DateFormat('d. MMMM yyyy', 'da_DK');
  static final DateFormat _shortDate = DateFormat('d. MMM', 'da_DK');
  static final DateFormat _dateWithYear = DateFormat('d. MMM yyyy', 'da_DK');
  static final DateFormat _time = DateFormat('HH:mm', 'da_DK');
  static final DateFormat _dayOfWeek = DateFormat('EEEE', 'da_DK');
  static final DateFormat _fullDateTime = DateFormat('EEEE d. MMMM yyyy HH:mm', 'da_DK');

  /// Format as full date: "15. januar 2024"
  static String fullDate(DateTime date) => _fullDate.format(date);

  /// Format as short date: "15. jan"
  static String shortDate(DateTime date) => _shortDate.format(date);

  /// Format as date with year: "15. jan 2024"
  static String dateWithYear(DateTime date) => _dateWithYear.format(date);

  /// Format as time: "14:30"
  static String time(DateTime date) => _time.format(date);

  /// Format as day of week: "mandag"
  static String dayOfWeek(DateTime date) => _dayOfWeek.format(date);

  /// Format as full date and time: "mandag 15. januar 2024 14:30"
  static String fullDateTime(DateTime date) => _fullDateTime.format(date);

  /// Smart relative formatting based on how recent the date is
  static String relative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Lige nu';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes min. siden';
    } else if (difference.inHours < 24 && _isSameDay(date, now)) {
      return time(date);
    } else if (difference.inDays == 1 || _isYesterday(date, now)) {
      return 'I går ${time(date)}';
    } else if (difference.inDays < 7) {
      return '${dayOfWeek(date)} ${time(date)}';
    } else if (date.year == now.year) {
      return shortDate(date);
    } else {
      return dateWithYear(date);
    }
  }

  /// Format for message list (shows time if today, date otherwise)
  static String messageDate(DateTime date) {
    final now = DateTime.now();

    if (_isSameDay(date, now)) {
      return time(date);
    } else if (_isYesterday(date, now)) {
      return 'I går';
    } else if (date.year == now.year) {
      return shortDate(date);
    } else {
      return dateWithYear(date);
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _isYesterday(DateTime date, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return _isSameDay(date, yesterday);
  }
}
