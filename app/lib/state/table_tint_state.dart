import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

///

enum TableTint {

  follow,

  fill,

  none,
}

///

({Color header, Color? stripe}) tableTintFills(
  TableTint tint, {
  required Color headerColor,
  required Color stripeColor,
}) => switch (tint) {
  TableTint.follow => (header: headerColor, stripe: null),
  TableTint.fill => (header: headerColor, stripe: stripeColor),
  TableTint.none => (header: transparentFill, stripe: null),
};

const transparentFill = Color(0x00000000);

class TableTintController extends Notifier<TableTint> {
  static const key = 'chat.table_tint';

  @override
  TableTint build() {
    unawaited(_read());
    return TableTint.follow;
  }

  Future<void> _read() async {
    final TableTint? stored;
    try {
      final prefs = await SharedPreferences.getInstance();
      stored = TableTint.values.asNameMap()[prefs.getString(key)];
    } catch (_) {

      return;
    }
    if (stored != null && stored != state) state = stored;
  }

  Future<void> set(TableTint tint) async {
    if (tint == state) return;
    state = tint;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, tint.name);
    } catch (_) {

    }
  }
}

final tableTintProvider = NotifierProvider<TableTintController, TableTint>(TableTintController.new);
