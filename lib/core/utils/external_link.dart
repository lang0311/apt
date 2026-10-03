import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../widgets/overlays.dart';

/// 외부 링크(원본 SNS 게시물 등) 열기.
/// TODO(url_launcher): 패키지 도입 후 외부 앱/브라우저로 연다. 지금은 링크를 복사한다.
Future<void> openExternalLink(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) showAppSnackBar(context, '링크를 복사했어요. 브라우저에서 열어주세요.');
}
