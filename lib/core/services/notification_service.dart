import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chemistry_high_importance',
    'Chemistry Coaching',
    description: 'Important notifications from Chemistry Coaching',
    importance: Importance.max,
  );

  // ============================================================
  // BACKGROUND MESSAGE
  // ============================================================

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint(
        'Background Firebase error: $e',
      );
    }

    debugPrint(
      'Background notification received',
    );

    debugPrint(
      'Title: ${message.notification?.title}',
    );

    debugPrint(
      'Body: ${message.notification?.body}',
    );
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  static Future<void> initialize() async {
    try {
      // ----------------------------------------------------------
      // LOCAL NOTIFICATION
      // ----------------------------------------------------------

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
      );

      // ----------------------------------------------------------
      // ANDROID CHANNEL
      // ----------------------------------------------------------

      if (!kIsWeb) {
        final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        await androidPlugin?.createNotificationChannel(
          _channel,
        );

        await androidPlugin?.requestNotificationsPermission();
      }

      // ----------------------------------------------------------
      // FIREBASE PERMISSION
      // ----------------------------------------------------------

      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        'Notification permission: '
        '${settings.authorizationStatus}',
      );

      // ----------------------------------------------------------
      // BACKGROUND HANDLER
      // ----------------------------------------------------------

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      // ----------------------------------------------------------
      // GET + SAVE TOKEN
      // ----------------------------------------------------------

      await _getAndSaveFCMToken();

      // ----------------------------------------------------------
      // TOKEN REFRESH
      // ----------------------------------------------------------

      _messaging.onTokenRefresh.listen(
        (String newToken) async {
          debugPrint(
            '====================================',
          );

          debugPrint(
            'NEW FCM TOKEN',
          );

          debugPrint(newToken);

          debugPrint(
            '====================================',
          );

          await _saveFCMToken(
            newToken,
          );
        },
      );

      // ----------------------------------------------------------
      // FOREGROUND MESSAGE
      // ----------------------------------------------------------

      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          debugPrint(
            '====================================',
          );

          debugPrint(
            'FOREGROUND NOTIFICATION',
          );

          debugPrint(
            'Title: ${message.notification?.title}',
          );

          debugPrint(
            'Body: ${message.notification?.body}',
          );

          debugPrint(
            'Data: ${message.data}',
          );

          debugPrint(
            '====================================',
          );

          await _showLocalNotification(
            message,
          );
        },
      );

      // ----------------------------------------------------------
      // BACKGROUND CLICK
      // ----------------------------------------------------------

      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          debugPrint(
            'Notification opened',
          );

          debugPrint(
            'Data: ${message.data}',
          );
        },
      );

      // ----------------------------------------------------------
      // TERMINATED APP
      // ----------------------------------------------------------

      final RemoteMessage? initialMessage =
          await _messaging.getInitialMessage();

      if (initialMessage != null) {
        debugPrint(
          'App opened from notification',
        );

        debugPrint(
          'Data: ${initialMessage.data}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        '====================================',
      );

      debugPrint(
        'NOTIFICATION ERROR',
      );

      debugPrint(e.toString());

      debugPrint(
        stackTrace.toString(),
      );

      debugPrint(
        '====================================',
      );
    }
  }

  // ============================================================
  // GET FCM TOKEN + SAVE
  // ============================================================

  static Future<String?> _getAndSaveFCMToken() async {
    try {
      final String? token = await _messaging.getToken();

      debugPrint(
        '====================================',
      );

      debugPrint(
        'FCM TOKEN',
      );

      debugPrint(
        token ?? 'TOKEN NULL',
      );

      debugPrint(
        '====================================',
      );

      if (token != null && token.isNotEmpty) {
        await _saveFCMToken(
          token,
        );
      }

      return token;
    } catch (e) {
      debugPrint(
        'FCM token error: $e',
      );

      return null;
    }
  }

  // ============================================================
  // SAVE TOKEN TO FIRESTORE
  // ============================================================

  static Future<void> _saveFCMToken(
    String token,
  ) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          'FCM token not saved: user not logged in',
        );
        return;
      }

      await _db.collection('users').doc(user.uid).set(
        {
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      debugPrint(
        '====================================',
      );

      debugPrint(
        'FCM TOKEN SAVED TO FIRESTORE',
      );

      debugPrint(
        'User UID: ${user.uid}',
      );

      debugPrint(
        '====================================',
      );
    } catch (e) {
      debugPrint(
        'FCM token Firestore save error: $e',
      );
    }
  }

  // ============================================================
  // SHOW FOREGROUND NOTIFICATION
  // ============================================================

  static Future<void> _showLocalNotification(
    RemoteMessage message,
  ) async {
    try {
      final RemoteNotification? notification = message.notification;

      final String title = notification?.title ??
          message.data['title']?.toString() ??
          'Chemistry Coaching';

      final String body = notification?.body ??
          message.data['body']?.toString() ??
          'You have a new notification';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'chemistry_high_importance',
        'Chemistry Coaching',
        channelDescription: 'Important notifications from Chemistry Coaching',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: null,
      );
    } catch (e) {
      debugPrint(
        'Local notification error: $e',
      );
    }
  }
}
