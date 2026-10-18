import 'package:flutter/material.dart';
import 'controller.dart';
import 'ui/earbud_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = EarbudController();
  await controller.load();
  runApp(EarbudApp(model: controller));
}
