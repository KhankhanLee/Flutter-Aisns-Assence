import 'package:flutter/material.dart';
import 'package:assence/app.dart';
import 'package:assence/services/gemini_service.dart';
import 'package:assence/services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final LocalStore local = await LocalStore.open();
  runApp(AssenceApp(
    stores: AppStores.create(local, GeminiService.fromEnvironment()),
  ));
}
