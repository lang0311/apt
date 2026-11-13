import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/overlays.dart';

/// 외부 링크(원본 SNS 게시물, 카카오맵 장소 페이지 등)를 브라우저나 해당 앱으로 연다.
/// 열 수 없으면 링크를 복사하고 안내한다.
Future<void> openExternalLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await _launch(uri)) return;
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) showAppSnackBar(context, '링크를 복사했어요. 브라우저에서 열어주세요.');
}

/// 전화 앱을 번호가 입력된 상태로 연다(바로 걸지 않는다). 열 수 없으면 번호를 복사한다.
Future<void> openDialer(BuildContext context, String phone) async {
  final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.isNotEmpty && await _launch(Uri(scheme: 'tel', path: number))) return;
  await Clipboard.setData(ClipboardData(text: phone));
  if (context.mounted) showAppSnackBar(context, '전화번호를 복사했어요.');
}

Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // 열 앱이 없거나 플랫폼이 지원하지 않는 경우
    return false;
  }
}
