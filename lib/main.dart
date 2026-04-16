import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'admin/admin_app.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/auth/auth_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/content/content_detail_screen.dart';
import 'ui/screens/chat/chat_room_screen.dart';
import 'ui/screens/subscription/subscription_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Must be registered before runApp — runs in a separate isolate when app is killed.
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.preventScreenshotOn();
    // await ScreenProtector.protectDataLeakageWithColor(Colors.white);

    try {
      await PushNotificationService().init();
    } catch (e, st) {
      debugPrint('PushNotificationService.init failed: $e\n$st');
    }
  }

  final isAdmin = kIsWeb && Uri.base.path.startsWith('/admin');
  runApp(isAdmin ? const AdminApp() : const DonskihApp());
}

class DonskihApp extends StatelessWidget {
  const DonskihApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Макияж для себя',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light.copyWith(
        textTheme: GoogleFonts.montserratTextTheme(AppTheme.light.textTheme),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      locale: const Locale('ru'),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
        '/content-detail': (context) => const ContentDetailScreen(),
        '/chat-room': (context) => const ChatRoomScreen(),
        '/subscription': (context) => const SubscriptionScreen(),
      },
    );
  }
}
