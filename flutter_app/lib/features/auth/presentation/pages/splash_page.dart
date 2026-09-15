import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _splashBackgroundColor = Color(0xFF0062FB);

const _splashSystemUiStyle = SystemUiOverlayStyle(
  statusBarColor: _splashBackgroundColor,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: _splashBackgroundColor,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _splashSystemUiStyle,
      child: Scaffold(
        backgroundColor: _splashBackgroundColor,
        body: const Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}
