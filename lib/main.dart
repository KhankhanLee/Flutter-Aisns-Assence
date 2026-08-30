import 'package:flutter/material.dart';
import 'package:assence/assence_home.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Colors.black,
        // buttonColor 대신 colorScheme을 사용합니다.
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
          primary: Colors.black,
        ),
        primaryIconTheme: const IconThemeData(color: Colors.black),
        // bodyText1 -> bodyLarge로 변경합니다.
        primaryTextTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black, fontFamily: "Aveny"),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
        ),
      ),
      home: const AssenceHome(),
    );
  }
}
