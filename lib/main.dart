import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'core/widgets/map/naver_map_sdk.dart';
import 'features/auth/data/social_auth_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 글꼴은 앱에 넣은 파일만 쓴다(assets/google_fonts). 네트워크가 없어도 시안 글꼴로 나온다
  GoogleFonts.config.allowRuntimeFetching = false;
  SdkSocialAuthProvider.initSdks();
  await NaverMapSdk.init();
  runApp(const AptRoot());
}
