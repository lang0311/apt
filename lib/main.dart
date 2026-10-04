import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/widgets/map/naver_map_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.init();
  runApp(const AptRoot());
}
