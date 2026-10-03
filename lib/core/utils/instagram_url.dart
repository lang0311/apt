/// 공유/입력된 텍스트에서 인스타그램 게시물 URL을 찾는다.
/// 지원: instagram.com/reel/…, /reels/…, /p/… (docs/02 §5.1)
/// 공유 시 텍스트에 다른 문구가 섞여 오는 경우가 있어 본문 안에서 URL을 추출한다.
abstract final class InstagramUrl {
  static final _pattern = RegExp(
    r'https?://(?:www\.)?instagram\.com/(?:reels?|p)/[A-Za-z0-9_\-]+/?(?:\?[^\s]*)?',
    caseSensitive: false,
  );

  /// 텍스트에서 첫 번째 인스타그램 게시물 URL. 없으면 null.
  static String? extract(String? text) {
    if (text == null) return null;
    return _pattern.firstMatch(text.trim())?.group(0);
  }

  static bool isValid(String? text) => extract(text) != null;

  /// 표시용: instagram.com/p/C3k9...
  static String shortLabel(String url, {int maxLength = 24}) {
    final noScheme = url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
    return noScheme.length <= maxLength ? noScheme : '${noScheme.substring(0, maxLength)}...';
  }
}
