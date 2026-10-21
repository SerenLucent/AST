import 'package:flutter/services.dart';

class PlaybackNotification {
  static const channel = MethodChannel('nwc/playback_notification');
  static Future<void> show(String title, {bool paused = false}) async {
    try {
      await channel.invokeMethod<void>('show', {
        'title': title,
        'paused': paused,
      });
    } on MissingPluginException {
      // Non-Android previews have no native notifier.
    } on PlatformException {
      // Notification settings must never interrupt audio.
    }
  }

  static Future<void> clear() async {
    try {
      await channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // No Android implementation in browser previews.
    } on PlatformException {
      // Clearing an optional notification must not block audio cleanup.
    }
  }
}
