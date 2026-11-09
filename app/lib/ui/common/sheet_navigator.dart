// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import 'smooth_size.dart';

///

class SheetNavigator extends StatefulWidget {
  const SheetNavigator({super.key, required this.root});

  final WidgetBuilder root;

  static SheetNavigatorState of(BuildContext context) {
    final state = context.findAncestorStateOfType<SheetNavigatorState>();
    // l10n:keep developer-only assertion
    assert(state != null, '这个 widget 不在 SheetNavigator 里');
    return state!;
  }

  static SheetNavigatorState? maybeOf(BuildContext context) => context.findAncestorStateOfType<SheetNavigatorState>();

  @override
  State<SheetNavigator> createState() => SheetNavigatorState();
}

class SheetNavigatorState extends State<SheetNavigator> {
  final List<WidgetBuilder> _stack = [];

  bool _forward = true;

  bool get canPop => _stack.isNotEmpty;

  void push(WidgetBuilder page) => setState(() {
    _forward = true;
    _stack.add(page);
  });

  void pop() {
    if (_stack.isEmpty) return;
    setState(() {
      _forward = false;
      _stack.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final builder = _stack.isEmpty ? widget.root : _stack.last;
    final duration = AppMotion.of(context, AppMotion.standard);
    final current = ValueKey(_stack.length);

    const travel = 0.12;
    final incomingFrom = Offset(_forward ? travel : -travel, 0);
    final outgoingTo = Offset(_forward ? -travel : travel, 0);
    return SmoothSize(
      duration: duration,
      curve: AppMotion.enter,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        transitionBuilder: (child, animation) {

          final incoming = child.key == current;
          return SlideTransition(
            position: Tween<Offset>(begin: incoming ? incomingFrom : outgoingTo, end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
        child: KeyedSubtree(
          key: ValueKey(_stack.length),
          child: Builder(builder: builder),
        ),
      ),
    );
  }
}
