import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

void installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[Iris][FlutterError] ${details.exceptionAsString()}');
    debugPrint('${details.stack}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[Iris][PlatformError] $error');
    debugPrint('$stack');
    return true;
  };
}

void runGuarded(void Function() body) {
  runZonedGuarded(body, (error, stack) {
    debugPrint('[Iris][ZoneError] $error');
    debugPrint('$stack');
  });
}
