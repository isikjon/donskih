import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import 'screens/admin_content_edit_screen.dart';
import 'screens/admin_content_list_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_main_screen.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Donskih — Админка',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      theme: AppTheme.light.copyWith(
        textTheme: GoogleFonts.montserratTextTheme(AppTheme.light.textTheme),
      ),
      initialRoute: AdminLoginScreen.routeName,
      routes: {
        AdminLoginScreen.routeName: (_) => const AdminLoginScreen(),
        AdminMainScreen.routeName: (_) => const AdminMainScreen(),
        // Legacy redirect: old bookmarks/links go to main screen
        AdminContentListScreen.routeName: (_) => const AdminMainScreen(),
        AdminContentEditScreen.routeName: (_) => const AdminContentEditScreen(),
      },
    );
  }
}
