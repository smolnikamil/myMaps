import 'package:flutter/material.dart';

import 'trekking_screen.dart';

const mapyApiKey = String.fromEnvironment('MAPY_API_KEY');

void main() {
  runApp(const TrekMapsApp());
}

class TrekMapsApp extends StatelessWidget {
  const TrekMapsApp({super.key, this.apiKey = mapyApiKey});

  final String apiKey;

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF174E3A);

    return MaterialApp(
      title: 'Trek Maps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: forest,
          primary: forest,
          surface: const Color(0xFFF9F8F3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F8F3),
        fontFamily: 'Roboto',
      ),
      home: TrekkingScreen(apiKey: apiKey),
    );
  }
}
