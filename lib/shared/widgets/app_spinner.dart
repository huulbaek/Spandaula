import 'package:flutter/material.dart';

class AppSpinner extends StatefulWidget {
  final double size;

  const AppSpinner({super.key, this.size = 96});

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleController.repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.6, end: 2.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInBack,
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: RotationTransition(
        turns: CurvedAnimation(
          parent: _rotationController,
          curve: Curves.linear,
        ),
        child: Image.asset(
          'assets/spinner.png',
          width: widget.size,
          height: widget.size,
        ),
      ),
    );
  }
}
