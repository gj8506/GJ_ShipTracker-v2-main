import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_colors.dart';
import 'firebase_options.dart';
import 'app.dart';

// NEW: Top-level function to handle background/terminated notifications
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handled background message: ${message.messageId}');
}

// Global keys for foreground snackbars
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      String? token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    }
  });

  // Register foreground handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.notification!.title ?? 'New Alert',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(message.notification!.body ?? ''),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.navySecondary,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  });

  runApp(
    ProviderScope(
      child: ShipTrackerApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
      ),
    ),
  );
}
