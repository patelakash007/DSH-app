// Plugin-view entry points on top of the dsh-ui parser
// (docs/design/native-plugins-views.md §5, §9): budgets, the cached parse,
// and what a tap hands to the app.

import 'package:flutter/painting.dart' show ImageProvider;

import '../../../l10n/l10n.dart';
import 'dsh_ui_model.dart';

const toolCardViewKey = 'dsh-go/view';

enum PluginViewBudget {

  toolCard(DshUiProfile.toolCard),

  panel(DshUiProfile.panel),

  strip(DshUiProfile.strip);

  const PluginViewBudget(this.profile);

  final DshUiProfile profile;
}

enum PluginActionSource { button, row, option, confirm, change, submit }

final class PluginAction {
  const PluginAction({
    required this.id,
    this.args = const {},
    required this.source,
    required this.path,
    this.gestureAt,
  });

  final String id;

  final Map<String, Object?> args;
  final PluginActionSource source;

  /// Host-only time of the originating user gesture, captured before queuing.
  /// Never read from plugin JSON or forwarded as plugin-provided arguments.
  final DateTime? gestureAt;

  PluginAction withGestureAt(DateTime time) =>
      PluginAction(id: id, args: args, source: source, path: path, gestureAt: time);

  final String path;

  @override
  bool operator ==(Object other) =>
      other is PluginAction &&
      other.id == id &&
      other.source == source &&
      other.path == path &&
      other.gestureAt == gestureAt &&
      _sameJson(other.args, args);

  @override
  int get hashCode => Object.hash(id, source, path, gestureAt);

  @override
  String toString() => 'PluginAction($id, $args, ${source.name}, $path)';
}

bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !_sameJson(e.value, b[e.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameJson(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

typedef PluginActionHandler = Future<bool> Function(PluginAction action);

typedef PluginImageResolver = ImageProvider? Function(String src);

DshUiParse parsePluginView(Object? view, {Object? data, PluginViewBudget budget = PluginViewBudget.panel}) =>
    _cache.get(view, data, budget.profile);

final _cache = _PluginParseCache(64);

final class _Key {
  _Key(this.view, this.data, this.profile);

  final Object? view;
  final Object? data;
  final DshUiProfile profile;

  static bool _same(Object? a, Object? b) => a is String && b is String ? a == b : identical(a, b);

  static int _hash(Object? v) => v is String ? v.hashCode : identityHashCode(v);

  @override
  bool operator ==(Object other) =>
      other is _Key && identical(other.profile, profile) && _same(other.view, view) && _same(other.data, data);

  @override
  int get hashCode => Object.hash(_hash(view), _hash(data), profile);
}

class _PluginParseCache {
  _PluginParseCache(this.capacity);

  final int capacity;
  final _entries = <_Key, DshUiParse>{};
  String? _language;
  int _accent = DshUiAppAccent.revision;

  DshUiParse get(Object? view, Object? data, DshUiProfile profile) {
    final language = AppLocale.current.languageCode;
    if (_language != language || _accent != DshUiAppAccent.revision) {
      _entries.clear();
      _language = language;
      _accent = DshUiAppAccent.revision;
    }
    final key = _Key(view, data, profile);
    final hit = _entries.remove(key);
    if (hit != null) {
      _entries[key] = hit;
      return hit;
    }
    DshUiParse parsed;
    try {
      parsed = parseDshUiPluginUncached(view, data: data, profile: profile);
    } on Object {

      parsed = DshUiInvalid(DshUiIssue('view', appL10n.plugViewInvalid));
    }
    _entries[key] = parsed;
    if (_entries.length > capacity) _entries.remove(_entries.keys.first);
    return parsed;
  }
}
