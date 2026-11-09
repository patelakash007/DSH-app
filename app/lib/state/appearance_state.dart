import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../ui/theme/accent.dart';

enum AccentSource {

  preset,

  custom,

  wallpaper,
}

class AppearanceSettings {
  const AppearanceSettings({
    this.source = AccentSource.preset,
    this.presetId = 'mist',
    this.customColor = defaultCustom,
    this.loaded = false,
  });

  final AccentSource source;

  final String presetId;

  final int customColor;
  final bool loaded;

  static const defaultCustom = 0xFF5F7A55;

  AppearanceSettings copyWith({AccentSource? source, String? presetId, int? customColor, bool? loaded}) =>
      AppearanceSettings(
        source: source ?? this.source,
        presetId: presetId ?? this.presetId,
        customColor: customColor ?? this.customColor,
        loaded: loaded ?? this.loaded,
      );
}

class AppearanceController extends Notifier<AppearanceSettings> {
  static const _sourceKey = 'appearance.accent_source';
  static const _presetKey = 'appearance.preset';
  static const _customKey = 'appearance.custom_color';

  static const notifyColorKey = 'appearance.notify_color';

  late Future<void> _loaded;

  @override
  AppearanceSettings build() {
    _loaded = _load();
    return const AppearanceSettings();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final source = AccentSource.values.asNameMap()[prefs.getString(_sourceKey)] ?? AccentSource.preset;
      state = AppearanceSettings(
        source: source,
        presetId: AppAccent.preset(prefs.getString(_presetKey)).id,
        customColor: prefs.getInt(_customKey) ?? AppearanceSettings.defaultCustom,
        loaded: true,
      );
    } catch (_) {
      // No preferences backend (tests): the default palette.
      state = state.copyWith(loaded: true);
    }
  }

  Future<void> _save(AppearanceSettings next, Future<void> Function(SharedPreferences prefs) write) async {
    await _loaded;
    state = next.copyWith(loaded: true);
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Kept for this run only.
    }
  }

  Future<void> selectPreset(String id) => _save(state.copyWith(source: AccentSource.preset, presetId: id), (p) async {
    await p.setString(_sourceKey, AccentSource.preset.name);
    await p.setString(_presetKey, id);
  });

  Future<void> selectCustom([int? color]) =>
      _save(state.copyWith(source: AccentSource.custom, customColor: color), (p) async {
        await p.setString(_sourceKey, AccentSource.custom.name);
        if (color != null) await p.setInt(_customKey, color);
      });

  Future<void> selectWallpaper() => _save(
    state.copyWith(source: AccentSource.wallpaper),
    (p) => p.setString(_sourceKey, AccentSource.wallpaper.name),
  );

  Future<void> leaveWallpaper() => selectPreset(state.presetId);
}

final appearanceProvider = NotifierProvider<AppearanceController, AppearanceSettings>(AppearanceController.new);

class DynamicColorChannel {
  const DynamicColorChannel([this._methods = const MethodChannel('dsh/dynamic_color')]);

  final MethodChannel _methods;

  Future<Color?> wallpaperAccent() async {
    try {
      final palette = await _methods.invokeMapMethod<String, Object?>('palette');
      final value = palette?['accent'] ?? palette?['accentLight'];
      return value is int ? Color(value) : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

final dynamicColorChannelProvider = Provider<DynamicColorChannel>((ref) => const DynamicColorChannel());

final wallpaperAccentProvider = FutureProvider<Color?>((ref) {
  final listener = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(listener.dispose);
  return ref.watch(dynamicColorChannelProvider).wallpaperAccent();
});

final accentProvider = Provider<AppAccent>((ref) {
  final s = ref.watch(appearanceProvider);
  final preset = AppAccent.preset(s.presetId);
  final accent = switch (s.source) {
    AccentSource.preset => preset,
    AccentSource.custom => AppAccent.derive(Color(s.customColor)),
    AccentSource.wallpaper => switch (ref.watch(wallpaperAccentProvider).value) {
      final c? => AppAccent.derive(c, id: AppAccent.wallpaperId, label: appL10n.stateWallpaper),
      null => preset,
    },
  };
  if (s.loaded) unawaited(_publishNotifyColor(accent));
  return accent;
});

int? _published;

Future<void> _publishNotifyColor(AppAccent accent) async {
  final argb = accent.seed.toARGB32();
  if (_published == argb) return;
  _published = argb;
  try {
    await (await SharedPreferences.getInstance()).setInt(AppearanceController.notifyColorKey, argb);
  } catch (_) {
    // Tests: no backend.
  }
}
