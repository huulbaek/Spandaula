import 'package:flutter/material.dart';

enum PageTransitionType {
  fade,
  slideRight,
  slideUp,
  scale,
}

/// Push a route with a custom transition
Route<T> pushTransition<T>({
  required PageTransitionType type,
  required Widget child,
  Duration duration = const Duration(milliseconds: 300),
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (type) {
        case PageTransitionType.fade:
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        case PageTransitionType.slideRight:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        case PageTransitionType.slideUp:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        case PageTransitionType.scale:
          return ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
      }
    },
  );
}
