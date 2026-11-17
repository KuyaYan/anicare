import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Phone (status bar) notifications. Local only: no Firebase / push server needed.
class Notifier {
  final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Called when the user taps a notification (payload) or its "Extend plan" button.
  void Function(String? payload)? onTap;

  Future<void> init() async {
    try {
      await _p.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) => onTap?.call(r.actionId == 'extend' ? 'plan' : r.payload),
      );
      await _p
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {}
  }

  Future<void> show(int id, String title, String body, {String? payload, bool extend = false}) async {
    if (!_ready) return;
    try {
      await _p.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'anicare_main',
            'AniCare alerts',
            channelDescription: 'Subscription, product and payment alerts',
            importance: Importance.high,
            priority: Priority.high,
            actions: extend ? const [AndroidNotificationAction('extend', 'Extend plan', showsUserInterface: true)] : null,
          ),
        ),
        payload: payload,
      );
    } catch (_) {}
  }
}

final notifier = Notifier();
