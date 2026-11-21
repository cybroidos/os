/// Plugin surface mirroring the action catalogue served by cybroidos-control.
///
/// Implementations in 0.1.0 are stubs so the Flutter app can render and wire a
/// UI without implying that KDE Connect packets are actually sent.
abstract class ControlPlugin {
  const ControlPlugin();

  String get id;
  Set<String> get actions;
  Future<Map<String, Object?>> invoke(String action, Map<String, Object?> args);
}

/// Raised when a plugin does not advertise an action.
class PluginException implements Exception {
  const PluginException(this.message);

  final String message;

  @override
  String toString() => 'PluginException: $message';
}

/// Routes action names to the plugin that owns them.
class PluginRegistry {
  final Map<String, ControlPlugin> _plugins = <String, ControlPlugin>{};

  void register(ControlPlugin plugin) {
    _plugins[plugin.id] = plugin;
  }

  List<String> get actionIds {
    final ids = <String>{};
    for (final plugin in _plugins.values) {
      ids.addAll(plugin.actions);
    }
    return ids.toList()..sort();
  }

  bool supports(String action) => _plugins.values.any((plugin) => plugin.actions.contains(action));

  Future<Map<String, Object?>> dispatch(
    String action, [
    Map<String, Object?> args = const <String, Object?>{},
  ]) async {
    for (final plugin in _plugins.values) {
      if (plugin.actions.contains(action)) {
        return plugin.invoke(action, args);
      }
    }
    throw PluginException('no plugin registered for action: $action');
  }
}

/// Stub for lock / open URL / notification actions.
class StubActionsPlugin implements ControlPlugin {
  const StubActionsPlugin();

  @override
  String get id => 'cybroidos.actions';

  @override
  Set<String> get actions => const <String>{'lock', 'open_url', 'notify'};

  @override
  Future<Map<String, Object?>> invoke(String action, Map<String, Object?> args) async {
    return <String, Object?>{
      'status': 'unimplemented',
      'plugin': id,
      'action': action,
      'implemented': false,
    };
  }
}

/// Stub for KRDP full-screen start/stop actions.
class StubFullscreenPlugin implements ControlPlugin {
  const StubFullscreenPlugin();

  @override
  String get id => 'cybroidos.fullscreen';

  @override
  Set<String> get actions => const <String>{'fullscreen.start', 'fullscreen.stop'};

  @override
  Future<Map<String, Object?>> invoke(String action, Map<String, Object?> args) async {
    return <String, Object?>{
      'status': 'unimplemented',
      'plugin': id,
      'action': action,
      'implemented': false,
    };
  }
}
