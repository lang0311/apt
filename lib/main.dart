import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/widgets/map/naver_map_sdk.dart';
import 'features/auth/data/social_auth_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SdkSocialAuthProvider.initSdks();
  await NaverMapSdk.init();
  runApp(const AptRoot());
}
