import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin/admin_app.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/auth/auth_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/content/content_detail_screen.dart';
import 'ui/screens/chat/chat_room_screen.dart';
import 'ui/screens/subscription/subscription_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  final isAdmin = kIsWeb && Uri.base.path.startsWith('/admin');
  runApp(isAdmin ? const AdminApp() : const DonskihApp());
}

class DonskihApp extends StatelessWidget {
  const DonskihApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Donskih',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light.copyWith(
        textTheme: GoogleFonts.montserratTextTheme(AppTheme.light.textTheme),
      ),
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
