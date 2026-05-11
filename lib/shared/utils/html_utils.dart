/// Utility class for HTML text processing
class HtmlUtils {
  /// Strip HTML tags from text and decode common entities
  static String stripTags(String htmlText) {
    if (htmlText.isEmpty) return '';

    // Remove HTML tags
    var text = htmlText.replaceAll(RegExp(r'<[^>]*>'), ' ');

    // Decode common HTML entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '...')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&euro;', '€')
        .replaceAll('&pound;', '£');

    // Decode numeric entities
    text = text.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '');
        if (code != null) {
          return String.fromCharCode(code);
        }
        return match.group(0) ?? '';
      },
    );

    // Decode hex entities
    text = text.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '', radix: 16);
        if (code != null) {
          return String.fromCharCode(code);
        }
        return match.group(0) ?? '';
      },
    );

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Wrap plain text in a simple div for sending to Aula
  static String wrapForSending(String plainText) {
    // Escape HTML special characters
    final escaped = plainText
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');

    // Replace newlines with <br> tags
    final withBreaks = escaped.replaceAll('\n', '<br>');

    return '<div>$withBreaks</div>';
  }

  /// Extract plain text preview from HTML (limited length)
  static String preview(String htmlText, {int maxLength = 100}) {
    final plain = stripTags(htmlText);
    if (plain.length <= maxLength) return plain;
    return '${plain.substring(0, maxLength)}...';
  }
}
