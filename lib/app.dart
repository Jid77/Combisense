import 'package:flutter/material.dart';
import 'pages/home_page.dart';
// import 'pages/splash_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard Monitoring Utility',
      theme: ThemeData(
        fontFamily: 'TabacSans',
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      debugShowCheckedModeBanner: false,
      home: HomePage(),

      // home: SplashScreen(),
    );
  }
}
