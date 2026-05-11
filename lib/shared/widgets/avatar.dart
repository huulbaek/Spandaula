import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;

  const AvatarWidget({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    final bgColor = backgroundColor ?? _getColorForName(name);

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(initials, bgColor),
          errorWidget: (context, url, error) => _buildPlaceholder(initials, bgColor),
        ),
      );
    }

    return _buildPlaceholder(initials, bgColor);
  }

  Widget _buildPlaceholder(String initials, Color bgColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: _getContrastingColor(bgColor),
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static final _whitespaceRegex = RegExp(r'\s+');
  static const _fallbackColors = [
    Colors.teal,
    Colors.indigo,
    Colors.deepOrange,
    Colors.pink,
    Colors.cyan,
    Colors.amber,
    Colors.deepPurple,
    Colors.lightBlue,
  ];

  String _getInitials(String name) {
    final parts = name.trim().split(_whitespaceRegex);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  Color _getColorForName(String name) {
    final index = name.hashCode.abs() % _fallbackColors.length;
    return _fallbackColors[index];
  }

  Color _getContrastingColor(Color color) {
    // Calculate luminance to determine if we need white or black text
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}
