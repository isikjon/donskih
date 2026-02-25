import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import 'screens/admin_content_list_screen.dart';
import 'screens/admin_content_edit_screen.dart';
import 'screens/admin_login_screen.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Donskih — Админка',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light.copyWith(
        textTheme: GoogleFonts.montserratTextTheme(AppTheme.light.textTheme),
      ),
      initialRoute: AdminLoginScreen.routeName,
      routes: {
        AdminLoginScreen.routeName: (context) => const AdminLoginScreen(),
        AdminContentListScreen.routeName: (context) => const AdminContentListScreen(),
        AdminContentEditScreen.routeName: (context) => const AdminContentEditScreen(),
      },
    );
  }
}
