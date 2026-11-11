import 'package:flutter/material.dart';
import 'package:flowers/app/app.dart';
import 'package:flowers/app/di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Di.I.configure();
  runApp(const FlowersApp());
}
