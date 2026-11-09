// Portions derived from DS Bot (https://github.com/Fei2411/DeepSeek-Bot), Apache-2.0, Copyright 2026 Fei2411 and the DS Bot contributors. See THIRD_PARTY_NOTICES.md.
// Modified: `views.js` normalisation, checks and summary translated to Dart;
// lenient instead of strict (unknown properties ignored, a broken child becomes
// a placeholder, limits truncate); a smaller catalog plus `compare` and
// `steps`; phone-sized limits; Chinese messages.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../l10n/l10n.dart';
import '../../../plugins/native/native_icons.dart' show nativeIcon;
import 'dsh_ui_bind.dart';
import 'dsh_ui_dialect_genui.dart';
import 'dsh_ui_plugin_formula.dart';

part 'dsh_ui_plugin_model.dart';
part 'dsh_ui_plugin_styles_model.dart';
part 'dsh_ui_plugin_controls_model.dart';

abstract final class DshUiLimits {

  static const softBytes = 4096;

  static const hardBytes = 16384;
  static const nodes = 40;
  static const depth = 6;
  static const children = 16;
  static const series = 6;
  static const points = 60;
  static const compareItems = 4;
  static const compareRows = 8;
  static const options = 8;
  static const steps = 12;
  static const text = 2000;
  static const label = 200;
  static const title = 80;
}

final class DshUiIssue {
  const DshUiIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => appL10n.viewLabeledValue(path, message);

  @override
  bool operator ==(Object other) => other is DshUiIssue && other.path == path && other.message == message;

  @override
  int get hashCode => Object.hash(path, message);
}

sealed class DshUiNode {
  const DshUiNode({required this.path, this.truncation});

  final String path;
  final String? truncation;
}

final class DshUiLayout extends DshUiNode {
  const DshUiLayout({required super.path, required this.row, required this.children, super.truncation});

  final bool row;
  final List<DshUiNode> children;
}

final class DshUiText extends DshUiNode {
  const DshUiText({
    required super.path,
    required this.text,
    this.muted = false,
    this.restricted = false,
    super.truncation,
  });

  final String text;
  final bool muted;

  final bool restricted;
}

enum DshUiTone { good, warn, bad, info, muted }

final class DshUiMetric extends DshUiNode {
  const DshUiMetric({
    required super.path,
    required this.label,
    required this.value,
    this.tone,
    this.caption,
    this.trend,
  });

  final String label;
  final String value;
  final DshUiTone? tone;
  final String? caption;

  /// v2 `trend`: 2–30 points under the value (null keeps a gap); null when
  /// the view has none.
  final List<double?>? trend;
}

enum DshUiChartKind { bar, hbar, line, donut }

final class DshUiSeries {
  const DshUiSeries({this.name, required this.values});

  final String? name;
  final List<double?> values;
}

final class DshUiChart extends DshUiNode {
  const DshUiChart({
    required super.path,
    required this.kind,
    required this.categories,
    required this.series,
    this.unit,
    this.caption,
    super.truncation,
  });

  final DshUiChartKind kind;
  final List<String> categories;
  final List<DshUiSeries> series;
  final String? unit;
  final String? caption;
}

final class DshUiCompareItem {
  const DshUiCompareItem({required this.title, this.badge, required this.rows});

  final String title;
  final String? badge;

  final List<(String, String)> rows;
}

final class DshUiCompare extends DshUiNode {
  const DshUiCompare({required super.path, required this.items, super.truncation});

  final List<DshUiCompareItem> items;
}

enum DshUiStepStatus { done, current, todo, failed }

final class DshUiStep {
  const DshUiStep({required this.label, required this.status, this.detail});

  final String label;
  final DshUiStepStatus status;
  final String? detail;
}

final class DshUiSteps extends DshUiNode {
  const DshUiSteps({required super.path, required this.items, super.truncation});

  final List<DshUiStep> items;
}

enum DshUiCalloutTone { info, good, warn, bad }

final class DshUiCallout extends DshUiNode {
  const DshUiCallout({
    required super.path,
    required this.text,
    this.tone = DshUiCalloutTone.info,
    this.restricted = false,
    super.truncation,
  });

  final String text;
  final DshUiCalloutTone tone;

  final bool restricted;
}

final class DshUiOption {
  const DshUiOption({required this.label, this.description, this.value});

  final String label;
  final String? description;

  final String? value;

  String get key => value ?? label;
}

final class DshUiOptions extends DshUiNode {
  const DshUiOptions({
    required super.path,
    required this.id,
    required this.options,
    this.multi = false,
    this.freetext = false,
    this.freetextHint,
    this.selected = const [],
    super.truncation,
  });

  final String id;
  final List<DshUiOption> options;
  final bool multi;

  final bool freetext;

  final String? freetextHint;

  final List<String> selected;

  List<String> get labels => [for (final o in options) o.label];
}

final class DshUiConfirm extends DshUiNode {
  const DshUiConfirm({required super.path, required this.id, this.confirmLabel, this.cancelLabel});

  static String get defaultConfirm => appL10n.commonConfirm;
  static String get defaultCancel => appL10n.commonCancel;

  final String id;

  final String? confirmLabel;
  final String? cancelLabel;

  String get confirmText => confirmLabel ?? defaultConfirm;
  String get cancelText => cancelLabel ?? defaultCancel;
}

final class DshUiPlaceholder extends DshUiNode {
  const DshUiPlaceholder({required super.path, required this.issue, this.type});

  final String? type;
  final DshUiIssue issue;
}

final class DshUiView {
  const DshUiView({
    required this.root,
    this.title,
    this.issues = const [],
    this.bytes = 0,
    this.version = 1,
    this.styles = const {},
    this.dialect,
  });

  /// The fence came in another plugin's format and was mapped onto a
  /// read-only plugin view (`genui`); null for the app's own format.
  final String? dialect;

  /// This view, marked as mapped from [name]'s format.
  DshUiView asDialect(String name, {List<DshUiIssue> notes = const []}) => DshUiView(
    root: root,
    title: title,
    issues: List.unmodifiable([...issues, ...notes]),
    bytes: bytes,
    version: version,
    styles: styles,
    dialect: name,
  );

  /// Only an explicit plugin-view v2 enables author styles. Model cards and
  /// old plugin views retain the exact v1 rendering path.
  final int version;
  final Map<String, DshUiPluginStyle> styles;

  final DshUiNode root;
  final String? title;

  final List<DshUiIssue> issues;

  final int bytes;

  Iterable<DshUiNode> get nodes sync* {
    Iterable<DshUiNode> walk(DshUiNode node) sync* {
      yield node;
      if (node is DshUiLayout) {
        for (final child in node.children) {
          yield* walk(child);
        }
      } else if (node is DshUiControlContainer) {
        for (final child in node.children) {
          yield* walk(child);
        }
      }
    }

    yield* walk(root);
  }

  List<DshUiNode> get answerNodes => [
    for (final node in nodes)
      if (node is DshUiOptions || node is DshUiConfirm) node,
  ];

  bool get interactive => answerNodes.isNotEmpty;

  bool get truncated => nodes.any((n) => n.truncation != null);
}

sealed class DshUiParse {
  const DshUiParse();
}

final class DshUiParsed extends DshUiParse {
  const DshUiParsed(this.view);

  final DshUiView view;
}

final class DshUiInvalid extends DshUiParse {
  const DshUiInvalid(this.error, {this.dialect});

  final DshUiIssue error;

  /// Set for another plugin's format (`genui`): nothing to resend, the
  /// block is fine where it came from.
  final String? dialect;

  String get resendText => dshUiResendText(error);
}

String dshUiResendText(DshUiIssue error) => appL10n.viewUiResendMessage(error);

DshUiParse parseDshUi(String source) => _cache.get(source);

DshUiParse parseDshUiUncached(String source) {
  final bytes = utf8.encode(source).length;
  if (bytes > DshUiLimits.hardBytes) {
    // Only a genui block may use the larger panel budget (§3.2 of
    // plugin-ui-v3.md); anything else is too big exactly as before.
    if (bytes <= DshUiProfile.panel.bytes) {
      Object? big;
      try {
        big = jsonDecode(source.trim());
      } on FormatException {
        big = null;
      }
      if (isGenuiDialect(big)) return _parseGenui(big);
    }
    return DshUiInvalid(DshUiIssue('view', appL10n.viewUiBytesLimit(bytes, DshUiLimits.hardBytes)));
  }
  final text = source.trim();
  if (text.isEmpty) {
    return DshUiInvalid(DshUiIssue('view', appL10n.viewUiEmptyCode));
  }
  Object? json;
  final repairs = <DshUiIssue>[];
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {

    final relaxed = _relaxJson(text);
    Object? retry = _notJson;
    if (relaxed != text) {
      try {
        retry = jsonDecode(relaxed);
      } on FormatException {

      }
    }
    if (identical(retry, _notJson)) {
      final message = e.offset == null
          ? appL10n.viewUiInvalidJson(e.message)
          : appL10n.viewUiInvalidJsonOffset(e.message, e.offset!);
      return DshUiInvalid(DshUiIssue('view', message));
    }
    json = retry;
    repairs.add(DshUiIssue('view', appL10n.viewUiJsonRepaired));
  }

  final size = measureDshUiJson(json, maxBytes: DshUiLimits.hardBytes * 2, maxDepth: DshUiProfile.jsonNesting);
  if (size.tooDeep) {
    return DshUiInvalid(DshUiIssue('view', appL10n.plugViewTooDeep(DshUiProfile.jsonNesting)));
  }
  if (isGenuiDialect(json)) return _parseGenui(json);
  return dshUiFromJson(json, bytes: bytes, issues: repairs);
}

/// A genui block (docs/design/plugin-ui-v3.md §3.2): mapped to a read-only
/// plugin view under the panel budget. Never offers a resend.
DshUiParse _parseGenui(Object? json) {
  final mapping = genuiToPluginView(json);
  final notes = [for (final path in mapping.notes) DshUiIssue(path, appL10n.viewUiDialectNote)];
  final view = mapping.view;
  if (view == null) {
    return DshUiInvalid(DshUiIssue('view', appL10n.viewUiDialectInvalid), dialect: 'genui');
  }
  return switch (parseDshUiPluginUncached(view)) {
    DshUiParsed(view: final parsed) => DshUiParsed(parsed.asDialect('genui', notes: notes)),
    DshUiInvalid(:final error) => DshUiInvalid(error, dialect: 'genui'),
  };
}

const _notJson = Object();

DshUiParse dshUiFromJson(
  Object? json, {
  int bytes = 0,
  List<DshUiIssue> issues = const [],
  DshUiProfile profile = DshUiProfile.model,
}) {
  var value = profile.plugin ? json : normalizeDshUi(json);

  if (value is List) {
    value = <String, Object?>{'type': 'stack', 'children': value};
  }
  if (value is! Map<String, Object?>) {
    return DshUiInvalid(DshUiIssue('view', appL10n.viewUiExpectedObject));
  }
  final ctx = _Ctx(profile)..issues.addAll(issues);
  if (profile.plugin) _initPluginStyles(value, ctx);
  final root = _node(value, 'view', 1, ctx);
  if (root is DshUiPlaceholder) return DshUiInvalid(root.issue);
  if (root is DshUiLayout && root.children.isNotEmpty && root.children.every((c) => c is DshUiPlaceholder)) {
    return DshUiInvalid((root.children.first as DshUiPlaceholder).issue);
  }
  if (root is DshUiControlContainer && root.children.isNotEmpty && root.children.every((c) => c is DshUiPlaceholder)) {
    return DshUiInvalid((root.children.first as DshUiPlaceholder).issue);
  }
  final rawTitle = value['title'];
  final title = rawTitle is DshUiMissing ? null : _clip(_string(rawTitle)?.trim(), DshUiLimits.title);
  return DshUiParsed(
    DshUiView(
      root: root,
      title: title == null || title.isEmpty ? null : title,
      issues: List.unmodifiable(ctx.issues),
      bytes: bytes,
      version: ctx.version,
      styles: Map.unmodifiable(ctx.styles),
    ),
  );
}

Object? normalizeDshUi(Object? value) {
  if (value is List) return [for (final item in value) normalizeDshUi(item)];
  if (value is! Map) return value;
  if (value.length == 1 && value.containsKey('item')) {
    final inner = normalizeDshUi(value['item']);
    if (inner is List) return inner;
  }
  final out = <String, Object?>{};
  for (final entry in value.entries) {
    out['${entry.key}'] = normalizeDshUi(entry.value);
  }
  for (final field in _numericFields) {
    if (out.containsKey(field)) out[field] = _numeric(out[field]);
  }
  final values = out['values'];
  if (values is List) out['values'] = [for (final v in values) _numeric(v)];
  return out;
}

const _numericFields = ['value', 'percent', 'min', 'max', 'step', 'height'];

Object? _numeric(Object? value) {
  if (value is! String || value.trim().isEmpty) return value;
  final parsed = num.tryParse(value.trim());
  return parsed == null || parsed.isNaN ? value : parsed;
}

const _types = ['stack', 'row', 'text', 'metric', 'chart', 'compare', 'steps', 'callout', 'options', 'confirm'];

class _Ctx {
  _Ctx([this.p = DshUiProfile.model]);

  final DshUiProfile p;
  int nodes = 0;
  int version = 1;
  int accent = DshUiPluginPalette.defaultAccent;
  int richSpans = 0;
  DshUiColorPair styleBackground = DshUiPluginPalette.surface;
  final styles = <String, DshUiPluginStyle>{};
  final contrastNotes = <String>{};
  int inputFields = 0;
  bool inForm = false;
  final inputBindings = <String>{};

  bool primaryUsed = false;
  final issues = <DshUiIssue>[];

  DshUiPlaceholder broken(String path, String message, {String? type}) {
    final issue = DshUiIssue(path, message);
    issues.add(issue);
    return DshUiPlaceholder(path: path, issue: issue, type: type);
  }

  void note(String path, String message) => issues.add(DshUiIssue(path, message));
}

DshUiNode _node(Object? raw, String path, int depth, _Ctx ctx) {

  ctx.nodes += 1;
  if (raw is! Map<String, Object?>) {
    return ctx.broken(path, appL10n.viewUiExpectedObject);
  }
  if (depth > ctx.p.depth) {
    return ctx.broken(path, appL10n.viewUiDepthLimit(depth, ctx.p.depth));
  }
  final type = raw['type'];
  final types = ctx.p.plugin ? (ctx.version >= 2 ? dshUiPluginComponents : _pluginTypes) : _types;
  if (type is! String || !types.contains(type)) {
    final shown = type == null || type is DshUiMissing || type is Map
        ? appL10n.viewUiMissingType
        : appL10n.viewUiUnknownComponent(_show(type));
    return ctx.broken('$path.type', appL10n.viewUiAvailableTypes(shown, types.join(', ')));
  }
  if (ctx.version == 2 && _pluginReservedRoles.contains(raw['role'])) {
    return ctx.broken('$path.role', appL10n.plugViewStyleReserved, type: type);
  }
  final previousBackground = ctx.styleBackground;
  if (ctx.version == 2) {
    final style = _readPluginStyle(raw, path, ctx);
    ctx.styles[path] = style;
    ctx.styleBackground = style.background;
  }
  try {
    if (ctx.p.plugin) {
      if (_pluginNode(type, raw, path, depth, ctx) case final node?) return node;
    }
    return switch (type) {
      'stack' || 'row' => _layout(raw, path, depth, ctx, row: type == 'row'),
      'text' => _text(raw, path, ctx),
      'metric' => _metric(raw, path, ctx),
      'chart' => _chart(raw, path, ctx),
      'compare' => _compare(raw, path, ctx),
      'steps' => _steps(raw, path, ctx),
      'callout' => _callout(raw, path, ctx),
      'options' => _options(raw, path, ctx),
      _ => _confirm(raw, path, ctx),
    };
  } finally {
    ctx.styleBackground = previousBackground;
  }
}

DshUiNode _layout(Map<String, Object?> raw, String path, int depth, _Ctx ctx, {required bool row}) {
  final children = raw['children'];
  if (ctx.p.plugin && _isEmpty(children)) {
    return DshUiEmpty(path: path, type: row ? 'row' : 'stack');
  }
  if (children is! List || children.isEmpty) {
    return ctx.broken('$path.children', appL10n.viewUiExpectedChildren(ctx.p.children), type: row ? 'row' : 'stack');
  }
  final built = <DshUiNode>[];
  var dropped = 0;
  for (var i = 0; i < children.length; i++) {
    if (i >= ctx.p.children || ctx.nodes >= ctx.p.nodes) {
      dropped = children.length - i;
      break;
    }
    built.add(_node(children[i], '$path.children[$i]', depth + 1, ctx));
  }
  String? truncation;
  if (dropped > 0) {
    truncation = appL10n.viewUiHiddenItems(dropped);
    ctx.note(
      '$path.children',
      ctx.nodes >= ctx.p.nodes
          ? appL10n.viewUiNodeLimit(ctx.p.nodes, dropped)
          : appL10n.viewUiChildLimit(ctx.p.children, dropped),
    );
  }
  return DshUiLayout(path: path, row: row, children: List.unmodifiable(built), truncation: truncation);
}

DshUiNode _text(Map<String, Object?> raw, String path, _Ctx ctx) {
  final text = _string(raw['text']);
  if (text == null) {
    return ctx.broken('$path.text', appL10n.viewUiExpectedString, type: 'text');
  }
  final max = ctx.p.text;
  final clipped = text.length > max;
  if (clipped) {
    ctx.note('$path.text', appL10n.viewUiTextLimit(text.length, max));
  }
  final tone = raw['tone'];
  return DshUiText(
    path: path,
    text: clipped ? '${text.substring(0, max)}…' : text,
    muted: tone == 'muted' || (ctx.p.plugin && (tone == 'secondary')),
    restricted: ctx.p.plugin,
    truncation: clipped ? appL10n.viewUiTextTruncated : null,
  );
}

DshUiNode _metric(Map<String, Object?> raw, String path, _Ctx ctx) {
  final label = _string(raw['label']);
  if (label == null) {
    return ctx.broken('$path.label', appL10n.viewUiExpectedString, type: 'metric');
  }
  final value = raw['value'];
  final String shown;
  if (value is num) {
    if (!value.isFinite) {
      return ctx.broken('$path.value', appL10n.viewUiExpectedFinite, type: 'metric');
    }
    shown = formatDshUiValue(value.toDouble());
  } else if (value is String) {
    shown = value;
  } else if (value is bool) {
    shown = value ? appL10n.viewUiYes : appL10n.viewUiNo;
  } else if (value is DshUiMissing) {
    shown = dshUiMissingText;
  } else {
    return ctx.broken('$path.value', appL10n.viewUiExpectedStringNumber, type: 'metric');
  }
  return DshUiMetric(
    path: path,
    label: _clip(label, DshUiLimits.label)!,
    value: _clip(shown, DshUiLimits.label)!,
    tone: ctx.p.plugin
        ? _pluginTone(raw['tone'], '$path.tone', ctx, muted: false)
        : _tone(raw['tone'], '$path.tone', ctx),
    caption: _clip(_string(raw['caption']), DshUiLimits.label),
    trend: ctx.p.plugin && ctx.version >= 2 ? _metricTrend(raw['trend'], '$path.trend', ctx) : null,
  );
}

/// v2 `metric.trend`: 2–30 finite numbers or nulls; anything else is a note
/// and no line.
List<double?>? _metricTrend(Object? raw, String path, _Ctx ctx) {
  if (raw == null || raw is DshUiMissing) return null;
  if (raw is! List || raw.length < 2 || raw.length > DshUiControlLimits.trendPoints) {
    ctx.note(path, appL10n.plugViewBadTrend(DshUiControlLimits.trendPoints));
    return null;
  }
  final points = <double?>[];
  for (final v in raw) {
    if (v == null || v is DshUiMissing) {
      points.add(null);
    } else if (v is num && v.isFinite) {
      points.add(v.toDouble());
    } else {
      ctx.note(path, appL10n.plugViewBadTrend(DshUiControlLimits.trendPoints));
      return null;
    }
  }
  if (points.whereType<double>().length < 2) {
    ctx.note(path, appL10n.plugViewBadTrend(DshUiControlLimits.trendPoints));
    return null;
  }
  return List.unmodifiable(points);
}

DshUiTone? _tone(Object? raw, String path, _Ctx ctx) {
  if (raw == null || raw is DshUiMissing) return null;
  final tone = switch (raw) {
    'good' || 'success' || 'positive' => DshUiTone.good,
    'warn' || 'warning' || 'caution' => DshUiTone.warn,
    'bad' || 'danger' || 'error' || 'negative' => DshUiTone.bad,
    _ => null,
  };
  if (tone == null) {
    ctx.note(path, appL10n.viewUiUnknownTone(_show(raw)));
  }
  return tone;
}

DshUiNode _chart(Map<String, Object?> raw, String path, _Ctx ctx) {
  final rawKind = raw['kind'];
  var kind = switch (rawKind) {
    null || DshUiMissing() || 'bar' || 'column' || 'columns' => DshUiChartKind.bar,
    'hbar' || 'barh' || 'horizontal' || 'horizontalBar' => DshUiChartKind.hbar,
    'line' || 'area' || 'spline' => DshUiChartKind.line,
    'donut' || 'pie' || 'doughnut' || 'ring' => DshUiChartKind.donut,
    _ => null,
  };
  if (kind == null) {
    ctx.note('$path.kind', appL10n.viewUiUnknownChart(_show(rawKind)));
    kind = DshUiChartKind.bar;
  }

  final rawCategories = raw['categories'];
  if (ctx.p.plugin && (_isEmpty(rawCategories) || _isEmpty(raw['series']))) {
    return DshUiEmpty(path: path, type: 'chart');
  }
  if (rawCategories is! List || rawCategories.isEmpty) {
    return ctx.broken('$path.categories', appL10n.viewUiExpectedCategories, type: 'chart');
  }
  final notes = <String>[];
  var categories = [for (final c in rawCategories.take(DshUiLimits.points + 1)) _clip(_string(c) ?? '', 40)!];
  if (categories.length > DshUiLimits.points) {
    ctx.note('$path.categories', appL10n.viewUiCategoryLimit(rawCategories.length, DshUiLimits.points));
    categories = categories.sublist(0, DshUiLimits.points);
    notes.add(appL10n.viewUiFirstPoints(DshUiLimits.points));
  }

  var rawSeries = raw['series'];
  if (rawSeries is Map) rawSeries = [rawSeries];

  if (rawSeries is List && rawSeries.isNotEmpty && rawSeries.every((e) => e == null || e is num || e is String)) {
    rawSeries = [
      {'values': rawSeries},
    ];
  }
  if (rawSeries == null && raw['values'] is List) {
    rawSeries = [
      {'values': raw['values']},
    ];
  }
  if (rawSeries is! List || rawSeries.isEmpty) {
    return ctx.broken('$path.series', appL10n.viewUiExpectedSeries('{name?, values}'), type: 'chart');
  }
  final series = <DshUiSeries>[];
  for (var i = 0; i < rawSeries.length; i++) {
    final item = rawSeries[i];
    final at = '$path.series[$i]';

    final Object? values = item is Map ? item['values'] : item;
    if (values is! List) {
      ctx.note('$at.values', appL10n.viewUiSkippedSeries);
      continue;
    }
    if (values.length != categories.length && values.length != rawCategories.length) {
      ctx.note('$at.values', appL10n.viewUiValuesCategories(values.length, rawCategories.length));
    }
    var bad = 0;
    final parsed = <double?>[
      for (var j = 0; j < categories.length; j++)
        if (j < values.length) _chartValue(values[j], () => bad++) else null,
    ];
    if (bad > 0) ctx.note('$at.values', appL10n.viewUiNonFiniteValues(bad));
    series.add(
      DshUiSeries(name: item is Map ? _clip(_string(item['name']), 40) : null, values: List.unmodifiable(parsed)),
    );
  }
  if (series.isEmpty) {
    return ctx.broken('$path.series', appL10n.viewUiNoSeries, type: 'chart');
  }
  var kept = series;
  if (kind == DshUiChartKind.donut && kept.length > 1) {
    ctx.note('$path.series', appL10n.viewUiDonutSeries(kept.length - 1));
    kept = kept.sublist(0, 1);
    notes.add(appL10n.viewUiFirstSeries);
  } else if (kept.length > DshUiLimits.series) {
    ctx.note('$path.series', appL10n.viewUiSeriesLimit(kept.length, DshUiLimits.series));
    kept = kept.sublist(0, DshUiLimits.series);
    notes.add(appL10n.viewUiFirstSeriesCount(DshUiLimits.series));
  }
  if (kept.every((s) => s.values.every((v) => v == null))) {
    if (ctx.p.plugin) return DshUiEmpty(path: path, type: 'chart');
    return ctx.broken('$path.series', appL10n.viewUiNoFiniteValues, type: 'chart');
  }
  return DshUiChart(
    path: path,
    kind: kind,
    categories: List.unmodifiable(categories),
    series: List.unmodifiable(kept),
    unit: _clip(_string(raw['unit'])?.trim(), 12),
    caption: _clip(_string(raw['caption']), DshUiLimits.label),
    truncation: notes.isEmpty ? null : appL10n.viewUiTruncated(notes.join(appL10n.viewListSeparator)),
  );
}

double? _chartValue(Object? value, void Function() onBad) {
  if (value is DshUiMissing) return null;
  if (value is num) {
    if (value.isFinite) return value.toDouble();
    onBad();
    return null;
  }
  if (value is String) {
    var s = value.trim().replaceAll(',', '').replaceAll('_', '');
    if (s.endsWith('%')) s = s.substring(0, s.length - 1).trim();
    final parsed = double.tryParse(s);
    if (parsed != null && parsed.isFinite) return parsed;
  }
  if (value != null) onBad();
  return null;
}

DshUiNode _compare(Map<String, Object?> raw, String path, _Ctx ctx) {
  final rawItems = raw['items'];
  if (ctx.p.plugin && _isEmpty(rawItems)) {
    return DshUiEmpty(path: path, type: 'compare');
  }
  if (rawItems is! List || rawItems.isEmpty) {
    return ctx.broken(
      '$path.items',
      appL10n.viewUiExpectedCompare(DshUiLimits.compareItems, '{title, badge?, rows}'),
      type: 'compare',
    );
  }
  final notes = <String>[];
  final items = <DshUiCompareItem>[];
  var rowsCut = false;
  for (var i = 0; i < rawItems.length; i++) {
    final item = rawItems[i];
    final at = '$path.items[$i]';
    if (items.length >= DshUiLimits.compareItems) {
      ctx.note('$path.items', appL10n.viewUiItemLimit(rawItems.length, DshUiLimits.compareItems));
      notes.add(appL10n.viewUiFirstItems(DshUiLimits.compareItems));
      break;
    }
    if (item is! Map) {
      ctx.note(at, appL10n.viewUiSkippedCompare('{title, badge?, rows}'));
      continue;
    }
    final title = _string(item['title']);
    if (title == null || title.trim().isEmpty) {
      ctx.note('$at.title', appL10n.viewUiSkippedItemLabel);
      continue;
    }
    final rows = <(String, String)>[];
    final rawRows = item['rows'];
    final List<Object?> entries = switch (rawRows) {
      final List<Object?> list => list,

      final Map<String, Object?> map => [
        for (final e in map.entries) [e.key, e.value],
      ],
      _ => const [],
    };
    for (var r = 0; r < entries.length; r++) {
      if (rows.length >= DshUiLimits.compareRows) {
        ctx.note('$at.rows', appL10n.viewUiRowLimit(entries.length, DshUiLimits.compareRows));
        rowsCut = true;
        break;
      }
      final row = _pair(entries[r]);
      if (row == null) {
        ctx.note('$at.rows[$r]', appL10n.viewUiSkippedRow);
        continue;
      }
      rows.add(row);
    }
    items.add(
      DshUiCompareItem(
        title: _clip(title.trim(), 40)!,
        badge: _clip(_string(item['badge'])?.trim(), 12),
        rows: List.unmodifiable(rows),
      ),
    );
  }
  if (items.isEmpty) {
    return ctx.broken('$path.items', appL10n.viewUiNoItems, type: 'compare');
  }
  if (rowsCut) notes.add(appL10n.viewUiFirstRows(DshUiLimits.compareRows));
  return DshUiCompare(
    path: path,
    items: List.unmodifiable(items),
    truncation: notes.isEmpty ? null : appL10n.viewUiTruncated(notes.join(appL10n.viewListSeparator)),
  );
}

(String, String)? _pair(Object? raw) {
  if (raw is List && raw.isNotEmpty) {
    final name = _string(raw[0]);
    if (name == null) return null;
    final value = raw.length > 1 ? _string(raw[1]) ?? '' : '';
    return (_clip(name, 40)!, _clip(value, 80)!);
  }
  if (raw is Map) {
    final name = _string(raw['label'] ?? raw['name']);
    if (name == null) return null;
    return (_clip(name, 40)!, _clip(_string(raw['value']) ?? '', 80)!);
  }
  return null;
}

DshUiNode _steps(Map<String, Object?> raw, String path, _Ctx ctx) {
  final rawItems = raw['items'];
  if (ctx.p.plugin && _isEmpty(rawItems)) {
    return DshUiEmpty(path: path, type: 'steps');
  }
  if (rawItems is! List || rawItems.isEmpty) {
    return ctx.broken('$path.items', appL10n.viewUiExpectedSteps('{label, status, detail?}'), type: 'steps');
  }
  final items = <DshUiStep>[];
  String? truncation;
  for (var i = 0; i < rawItems.length; i++) {
    if (items.length >= DshUiLimits.steps) {
      ctx.note('$path.items', appL10n.viewUiStepLimit(rawItems.length, DshUiLimits.steps));
      truncation = appL10n.viewUiFirstSteps(DshUiLimits.steps);
      break;
    }
    final item = rawItems[i];
    final at = '$path.items[$i]';
    if (item is String) {
      items.add(DshUiStep(label: _clip(item, DshUiLimits.label)!, status: DshUiStepStatus.todo));
      continue;
    }
    if (item is! Map) {
      ctx.note(at, appL10n.viewUiSkippedStep('{label, status, detail?}'));
      continue;
    }
    final label = _string(item['label'] ?? item['title']);
    if (label == null) {
      ctx.note('$at.label', appL10n.viewUiSkippedStepLabel);
      continue;
    }
    final rawStatus = item['status'];
    var status = switch (rawStatus) {
      'done' || 'completed' || 'complete' || 'success' => DshUiStepStatus.done,
      'current' || 'active' || 'doing' || 'in_progress' || 'running' => DshUiStepStatus.current,
      null || DshUiMissing() || 'todo' || 'pending' || 'waiting' => DshUiStepStatus.todo,
      'failed' || 'error' || 'blocked' => DshUiStepStatus.failed,
      _ => null,
    };
    if (status == null) {
      ctx.note('$at.status', appL10n.viewUiUnknownStatus(_show(rawStatus)));
      status = DshUiStepStatus.todo;
    }
    items.add(
      DshUiStep(
        label: _clip(label, DshUiLimits.label)!,
        status: status,
        detail: _clip(_string(item['detail']), DshUiLimits.label),
      ),
    );
  }
  if (items.isEmpty) {
    return ctx.broken('$path.items', appL10n.viewUiNoSteps, type: 'steps');
  }
  return DshUiSteps(path: path, items: List.unmodifiable(items), truncation: truncation);
}

DshUiNode _callout(Map<String, Object?> raw, String path, _Ctx ctx) {
  final text = _string(raw['text']);
  if (text == null) {
    return ctx.broken('$path.text', appL10n.viewUiExpectedString, type: 'callout');
  }
  final rawTone = raw['tone'];
  var tone = switch (rawTone) {
    null || DshUiMissing() || 'info' || 'note' => DshUiCalloutTone.info,
    'good' || 'success' || 'tip' => DshUiCalloutTone.good,
    'warn' || 'warning' || 'caution' => DshUiCalloutTone.warn,
    'bad' || 'danger' || 'error' => DshUiCalloutTone.bad,
    _ => null,
  };
  if (tone == null) {
    ctx.note('$path.tone', appL10n.viewUiUnknownCalloutTone(_show(rawTone)));
    tone = DshUiCalloutTone.info;
  }
  final max = ctx.p.text;
  final clipped = text.length > max;
  if (clipped) {
    ctx.note('$path.text', appL10n.viewUiTextLimit(text.length, max));
  }
  return DshUiCallout(
    path: path,
    text: clipped ? '${text.substring(0, max)}…' : text,
    tone: tone,
    restricted: ctx.p.plugin,
    truncation: clipped ? appL10n.viewUiTextTruncated : null,
  );
}

DshUiNode _options(Map<String, Object?> raw, String path, _Ctx ctx) {
  final rawOptions = raw['options'];
  if (ctx.p.plugin && _isEmpty(rawOptions)) {
    return DshUiEmpty(path: path, type: 'options');
  }
  if (rawOptions is! List || rawOptions.isEmpty) {
    return ctx.broken(
      '$path.options',
      appL10n.viewUiExpectedOptions(DshUiLimits.options, '{label, description?}'),
      type: 'options',
    );
  }
  final options = <DshUiOption>[];
  final seen = <String>{};
  String? truncation;
  for (var i = 0; i < rawOptions.length; i++) {
    if (options.length >= DshUiLimits.options) {
      ctx.note('$path.options', appL10n.viewUiOptionLimit(rawOptions.length, DshUiLimits.options));
      truncation = appL10n.viewUiFirstOptions(DshUiLimits.options);
      break;
    }
    final item = rawOptions[i];
    final at = '$path.options[$i]';
    final label = _string(item is Map ? item['label'] : item)?.trim();
    if (label == null || label.isEmpty) {
      ctx.note('$at.label', appL10n.viewUiSkippedItemLabel);
      continue;
    }

    final rawValue = ctx.p.plugin && item is Map ? item['value'] : null;
    final value = rawValue is String && rawValue.isNotEmpty ? _clip(rawValue, DshUiLimits.label) : null;

    if (!seen.add(value ?? label)) {
      ctx.note('$at.label', appL10n.viewUiDuplicateLabel(_show(label)));
      continue;
    }
    options.add(
      DshUiOption(
        label: _clip(label, 80)!,
        description: item is Map ? _clip(_string(item['description'])?.trim(), DshUiLimits.label) : null,
        value: value,
      ),
    );
  }
  if (options.isEmpty) {
    return ctx.broken('$path.options', appL10n.viewUiNoOptions, type: 'options');
  }
  final multi = raw['multi'];

  final rawFreetext = raw['freetext'];
  final hint = rawFreetext is String ? _clip(rawFreetext.trim(), DshUiLimits.label) : null;
  final freetext = rawFreetext == true || rawFreetext == 'true' || (hint != null && hint.isNotEmpty);
  return DshUiOptions(
    path: path,
    id: ctx.p.plugin ? _pluginActionId(raw['id'], '$path.id', ctx) ?? '' : _string(raw['id']) ?? 'options',
    options: List.unmodifiable(options),
    multi: multi == true || multi == 'true',
    freetext: freetext,
    freetextHint: hint == null || hint.isEmpty ? null : hint,
    selected: ctx.p.plugin ? _selected(raw['selected']) : const [],
    truncation: truncation,
  );
}

DshUiNode _confirm(Map<String, Object?> raw, String path, _Ctx ctx) {
  String? label(Object? v) {
    if (v is DshUiMissing) return null;
    final s = _clip(_string(v)?.trim(), 12);
    return s == null || s.isEmpty ? null : s;
  }

  return DshUiConfirm(
    path: path,
    id: ctx.p.plugin ? _pluginActionId(raw['id'], '$path.id', ctx) ?? '' : _string(raw['id']) ?? 'confirm',
    confirmLabel: label(raw['confirmLabel']),
    cancelLabel: label(raw['cancelLabel']),
  );
}

String? _string(Object? value) => switch (value) {
  final String s => s,
  DshUiMissing() => dshUiMissingText,
  final num n when n.isFinite => formatDshUiValue(n.toDouble()),
  final bool b => '$b',
  _ => null,
};

String _show(Object? value) => switch (value) {
  DshUiMissing() => dshUiMissingText,
  Map() => '{…}',
  List() => '[…]',
  final String s => jsonEncode(s.length <= 40 ? s : '${s.substring(0, 40)}…'),
  final num n => '$n',
  _ => '$value',
};

String? _clip(String? text, int max) {
  if (text == null || text.length <= max) return text;
  return '${text.substring(0, max)}…';
}

String formatDshUiValue(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    final whole = value.round();
    return whole.abs() >= 10000 ? _group(whole.toString()) : '$whole';
  }
  final fixed = value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return value.abs() >= 10000 ? _group(fixed) : fixed;
}

String _group(String digits) {
  final negative = digits.startsWith('-');
  final body = negative ? digits.substring(1) : digits;
  final dot = body.indexOf('.');
  final whole = dot < 0 ? body : body.substring(0, dot);
  final frac = dot < 0 ? '' : body.substring(dot);
  final out = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  return '${negative ? '-' : ''}$out$frac';
}

String _relaxJson(String text) {
  final out = StringBuffer();
  var i = 0;
  var inString = false;
  int? pendingComma;
  final buffer = <int>[];

  void flushComma() {
    if (pendingComma != null) {
      out.writeCharCode(pendingComma!);
      pendingComma = null;
    }
    for (final c in buffer) {
      out.writeCharCode(c);
    }
    buffer.clear();
  }

  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (inString) {
      out.writeCharCode(c);
      if (c == 0x5C && i + 1 < text.length) {
        out.writeCharCode(text.codeUnitAt(i + 1));
        i += 2;
        continue;
      }
      if (c == 0x22) inString = false;
      i++;
      continue;
    }
    if (c == 0x2F && i + 1 < text.length) {
      final next = text.codeUnitAt(i + 1);
      if (next == 0x2F) {
        while (i < text.length && text.codeUnitAt(i) != 0x0A) {
          i++;
        }
        continue;
      }
      if (next == 0x2A) {
        final end = text.indexOf('*/', i + 2);
        i = end < 0 ? text.length : end + 2;
        continue;
      }
    }
    if (c == 0x2C) {
      flushComma();
      pendingComma = c;
      i++;
      continue;
    }
    if (pendingComma != null && (c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09)) {
      buffer.add(c);
      i++;
      continue;
    }
    if (pendingComma != null && (c == 0x7D || c == 0x5D)) {
      pendingComma = null;
    }
    flushComma();
    if (c == 0x22) inString = true;
    out.writeCharCode(c);
    i++;
  }
  flushComma();
  return out.toString();
}

const _summaryPart = 40;
const _summaryCount = 8;

///

String dshUiSummary(DshUiView view) {
  final parts = <String>[];
  void visit(DshUiNode node) {
    if (parts.length >= _summaryCount) return;
    final line = _componentSummary(node);
    if (line != null) parts.add(_summaryClip(line));
    if (node is DshUiLayout) {
      for (final child in node.children) {
        if (parts.length >= _summaryCount) return;
        visit(child);
      }
    } else if (node is DshUiControlContainer) {
      for (final child in node.children) {
        if (parts.length >= _summaryCount) return;
        visit(child);
      }
    }
  }

  visit(view.root);
  final title = view.title;
  final body = parts.join(appL10n.viewSemicolonSeparator);
  if (title == null) return appL10n.viewUiSummaryBody(body);
  return body.isEmpty ? appL10n.viewUiSummaryBody(title) : appL10n.viewUiSummaryTitleBody(title, body);
}

String dshUiSummaryOf(String source) => switch (parseDshUi(source)) {
  DshUiParsed(:final view) => dshUiSummary(view),
  DshUiInvalid() => appL10n.viewUiSummaryInvalid,
};

String _summaryClip(String text) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= _summaryPart ? flat : flat.substring(0, _summaryPart);
}

String? _componentSummary(DshUiNode node) {
  String withUnit(double? v, String? unit) {
    if (v == null) return '—';
    final n = formatDshUiNumber(v);
    if (unit == null || unit.isEmpty) return n;
    return unit == '%' ? '$n%' : '$n $unit';
  }

  return switch (node) {
    DshUiLayout() || DshUiControlContainer() => null,
    DshUiInput(:final label) => label,
    DshUiControlDisplay(:final text) => text,
    DshUiText(:final text) => appL10n.viewUiSummaryText(text.trim()),
    DshUiMetric(:final label, :final value) => '$label=$value',
    DshUiChart(:final categories, :final series, :final unit) => appL10n.viewUiSummaryChart(
      [for (var i = 0; i < categories.length; i++) '${categories[i]}=${withUnit(series.first.values[i], unit)}']
          .join(', '),
    ),
    DshUiCompare(:final items) => appL10n.viewUiSummaryCompare(items.map((i) => i.title).join('/')),
    DshUiSteps(:final items) => appL10n.viewUiSummarySteps(items.map((i) => i.label).join('/')),
    DshUiCallout(:final text) => appL10n.viewUiSummaryCallout(text.trim()),
    DshUiOptions(:final options) => appL10n.viewUiSummaryOptions(options.map((o) => o.label).join('/')),
    final DshUiConfirm c => appL10n.viewUiSummaryConfirm(c.confirmText, c.cancelText),
    DshUiPlaceholder() || DshUiEmpty() || DshUiActions() || DshUiImage() => null,
    DshUiEmptyState(:final title) => title,
    DshUiGallery(:final items) => [for (final i in items) ?i.image.alt].join('/'),
    DshUiList(:final items) => items.map((i) => i.title).join('/'),
    DshUiKeyValue(:final items) => [
      for (final i in items) '${i.label}=${i.value}',
    ].join(appL10n.viewSemicolonSeparator),
    DshUiProgress(:final label, :final shown) => label == null ? shown : '$label=$shown',
    DshUiTable(:final columns) => columns.map((c) => c.label).join('/'),
  };
}

String formatDshUiNumber(double value) {
  if (!value.isFinite) return '—';
  final abs = value.abs();
  if (abs >= 1e15) return value.toStringAsExponential(1);
  final digits = abs >= 100 ? 0 : (abs >= 10 ? 1 : 2);
  var fixed = value.toStringAsFixed(digits);
  if (digits > 0) fixed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  if (fixed == '-0') fixed = '0';
  return _group(fixed);
}

String formatDshUiCompact(double value) {
  if (!value.isFinite) return '—';
  final abs = value.abs();
  if (abs >= 1e16) return value.toStringAsExponential(0);
  if (AppLocale.isEnglish) {
    if (abs >= 1e9) {
      return appL10n.viewUiHundredMillion(formatDshUiNumber(value / 1e9));
    }
    if (abs >= 1e6) {
      return appL10n.viewUiMillion(formatDshUiNumber(value / 1e6));
    }
    if (abs >= 1e3) {
      return appL10n.viewUiTenThousand(formatDshUiNumber(value / 1e3));
    }
  } else {
    if (abs >= 1e8) {
      return appL10n.viewUiHundredMillion(formatDshUiNumber(value / 1e8));
    }
    if (abs >= 1e4) {
      return appL10n.viewUiTenThousand(formatDshUiNumber(value / 1e4));
    }
  }
  return formatDshUiNumber(value);
}

String dshUiPlainText(String markdown) {
  final repaired = fenceBareDshUiViews(markdown);
  if (!repaired.contains('dsh-ui')) return repaired;
  final lines = repaired.split('\n');
  final out = <String>[];
  var i = 0;
  final open = RegExp(r'^(\s{0,3})(`{3,}|~{3,})\s*dsh-ui\s*$');
  final anyOpen = RegExp(r'^\s{0,3}(`{3,}|~{3,})');
  while (i < lines.length) {
    final line = lines[i];
    final match = open.firstMatch(line);
    if (match == null) {

      final other = anyOpen.firstMatch(line);
      out.add(line);
      i++;
      if (other != null) {
        final fence = other.group(1)!;
        while (i < lines.length) {
          out.add(lines[i]);
          if (_closes(lines[i], fence)) {
            i++;
            break;
          }
          i++;
        }
      }
      continue;
    }
    final fence = match.group(2)!;
    final body = <String>[];
    i++;
    while (i < lines.length && !_closes(lines[i], fence)) {
      body.add(lines[i]);
      i++;
    }
    if (i < lines.length) i++;
    out.add('${match.group(1)}${dshUiSummaryOf(body.join('\n'))}');
  }
  return out.join('\n');
}

bool _closes(String line, String fence) {
  final t = line.trim();
  if (t.length < fence.length) return false;
  final ch = fence[0];
  return t.split('').every((c) => c == ch);
}

///

String fenceBareDshUiViews(String markdown) {
  if (!markdown.contains('{')) return markdown;
  final lines = markdown.split('\n');
  final out = <String>[];
  var i = 0;
  while (i < lines.length) {
    final fence = _openingFence(lines[i]);
    if (fence != null) {

      out.add(lines[i]);
      i++;
      while (i < lines.length) {
        out.add(lines[i]);
        final closed = _closes(lines[i], fence);
        i++;
        if (closed) break;
      }
      continue;
    }
    if (lines[i].trimLeft().startsWith('{')) {
      final block = _jsonBlockAt(lines, i);
      if (block != null && parseDshUi(block.source) is DshUiParsed) {
        out.add('```dsh-ui');
        out.add(block.source);
        out.add('```');
        i = block.end;
        continue;
      }
    }
    out.add(lines[i]);
    i++;
  }
  return out.join('\n');
}

String? _openingFence(String line) {
  final match = RegExp(r'^\s{0,3}(`{3,}|~{3,})').firstMatch(line);
  return match?.group(1);
}

const _bareViewScanLimit = 64 * 1024;

({String source, int end})? _jsonBlockAt(List<String> lines, int start) {
  final buffer = StringBuffer();
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < lines.length; i++) {
    final line = i == start ? lines[i].trimLeft() : lines[i];
    var consumed = line.length;
    for (var j = 0; j < line.length; j++) {
      final unit = line.codeUnitAt(j);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (unit == 0x5C) {
          escaped = true;
        } else if (unit == 0x22) {
          inString = false;
        }
        continue;
      }
      if (unit == 0x22) {
        inString = true;
      } else if (unit == 0x7B) {
        depth++;
      } else if (unit == 0x7D) {
        depth--;
        if (depth == 0) {
          consumed = j + 1;
          break;
        }
      }
    }
    if (i > start) buffer.write('\n');
    buffer.write(line);
    if (depth == 0 && !inString) {

      if (line.substring(consumed).trim().isNotEmpty) return null;
      final source = buffer.toString().substring(0, buffer.length - (line.length - consumed)).trimRight();
      return (source: source, end: i + 1);
    }
    if (buffer.length > _bareViewScanLimit) return null;
  }
  return null;
}

final _cache = _ParseCache(48);

class _ParseCache {
  _ParseCache(this.capacity);

  final int capacity;

  final _entries = <String, DshUiParse>{};
  String? _language;

  DshUiParse get(String source) {
    final language = AppLocale.current.languageCode;
    if (_language != language) {
      _entries.clear();
      _language = language;
    }
    final hit = _entries.remove(source);
    if (hit != null) {
      _entries[source] = hit;
      return hit;
    }
    final parsed = parseDshUiUncached(source);
    _entries[source] = parsed;
    if (_entries.length > capacity) _entries.remove(_entries.keys.first);
    return parsed;
  }
}
