// lib/src/app_lifecycle/app_lifecycle_observer.dart
import 'package:flutter/widgets.dart';

abstract class AppLifecycleHooks {
  void onResume() {}
  void onPause() {}
  void onInactive() {}
  void onDetach() {}
}

class AppLifecycleObserver with WidgetsBindingObserver {
  final AppLifecycleHooks hooks;
  AppLifecycleObserver(this.hooks);

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        hooks.onResume();
        break;
      case AppLifecycleState.inactive:
        hooks.onInactive();
        break;
      case AppLifecycleState.paused:
        hooks.onPause();
        break;
      case AppLifecycleState.detached:
        hooks.onDetach();
        break;
      case AppLifecycleState.hidden:
        hooks.onPause();
        break; // web/desktop
    }
  }
}
