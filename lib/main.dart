import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/db/app_database.dart';
import 'presentation/state/providers.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // DB drift offline (không có backend/network — ràng buộc 100% offline).
  final db = await openAppDatabase();
  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const GradeVNApp(),
  ));
}
