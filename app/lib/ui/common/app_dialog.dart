import 'package:flutter/material.dart';

import '../theme/motion.dart';

///

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (!AppMotion.fluid(context)) {
    return showDialog<T>(context: context, builder: builder, barrierDismissible: barrierDismissible);
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    animationStyle: AnimationStyle(
      duration: AppMotion.popCurve.duration,
      reverseDuration: AppMotion.quick,

      curve: const Interval(0, 0.35, curve: Curves.easeOut),
      reverseCurve: Curves.easeOut,
    ),
    builder: (context) => _DialogPop(child: Builder(builder: builder)),
  );
}

class _DialogPop extends StatefulWidget {
  const _DialogPop({required this.child});

  final Widget child;

  @override
  State<_DialogPop> createState() => _DialogPopState();
}

class _DialogPopState extends State<_DialogPop> {
  static const _from = 0.9;

  CurvedAnimation? _curved;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context)?.animation;
    if (route == null || _curved?.parent == route) return;
    _curved?.dispose();
    _curved = CurvedAnimation(parent: route, curve: AppMotion.popCurve, reverseCurve: Curves.easeOut);
  }

  @override
  void dispose() {
    _curved?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = _curved;
    if (curved == null) return widget.child;
    return ScaleTransition(
      scale: Tween(begin: _from, end: 1.0).animate(curved),
      child: widget.child,
    );
  }
}
