import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 디자인 규칙 검사: 화면 코드는 글자 크기를 토큰으로만 쓴다
void main() {
  test('화면 코드는 글자 크기를 숫자로 덮어쓰지 않는다 (07 D63, 토큰만 · 위젯 크기 비례는 예외)', () {
    final literal = RegExp(r'fontSize:\s*\d');
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && !f.path.replaceAll(r'\', '/').contains('lib/app/theme/'))
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (literal.hasMatch(line)) '${f.path}:${i + 1}',
    ];
    expect(offenders, isEmpty);
  });
}
