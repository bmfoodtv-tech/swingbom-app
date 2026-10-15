/// 스윙봄(SwingBom) — 골프 스윙 연습 앱
/// ⓒ 찐골프(JJIN Golf) / 개발자 : 찬이작업실
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/constants.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SwingBomApp());
}

class SwingBomApp extends StatelessWidget {
  const SwingBomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
          ),
          scaffoldBackgroundColor: AppColors.surface,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
