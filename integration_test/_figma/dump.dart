// 임시 도구 (커밋 안 함): 화면의 렌더 트리를 JSON으로 뽑는다. Figma 흐름도 제작용.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
double _a(Color c) => c.a;
double _r(double v) => (v * 100).round() / 100;

Map<String, dynamic> _rect(Rect r) => {'x': _r(r.left), 'y': _r(r.top), 'w': _r(r.width), 'h': _r(r.height)};

/// 앱이 만든 위젯 클래스 이름(lib/ 안). 파일 `app_classes.txt`에서 읽는다.
Set<String> appClasses = {};

List<String> _componentChain(RenderObject ro) {
  final creator = ro.debugCreator;
  if (creator is! DebugCreator) return const [];
  final out = <String>[];
  creator.element.visitAncestorElements((e) {
    final n = e.widget.runtimeType.toString();
    if (appClasses.contains(n)) out.add(n);
    return out.length < 4;
  });
  return out;
}

Map<String, dynamic>? _radius(BorderRadiusGeometry? br) {
  if (br is BorderRadius) {
    return {'tl': _r(br.topLeft.x), 'tr': _r(br.topRight.x), 'br': _r(br.bottomRight.x), 'bl': _r(br.bottomLeft.x)};
  }
  return null;
}

Map<String, dynamic> _boxDeco(BoxDecoration d) {
  final m = <String, dynamic>{};
  if (d.color != null) {
    m['fill'] = _hex(d.color!);
    m['fillA'] = _a(d.color!);
  }
  if (d.gradient is LinearGradient) {
    final g = d.gradient as LinearGradient;
    m['gradient'] = {
      'colors': g.colors.map(_hex).toList(),
      'alphas': g.colors.map(_a).toList(),
      'stops': g.stops,
      'begin': [g.begin.resolve(TextDirection.ltr).x, g.begin.resolve(TextDirection.ltr).y],
      'end': [g.end.resolve(TextDirection.ltr).x, g.end.resolve(TextDirection.ltr).y],
    };
  }
  if (d.shape == BoxShape.circle) m['circle'] = true;
  final rad = _radius(d.borderRadius);
  if (rad != null) m['radius'] = rad;
  final b = d.border;
  if (b is Border) {
    final sides = {'t': b.top, 'r': b.right, 'b': b.bottom, 'l': b.left};
    final vis = sides.entries.where((e) => e.value.style != BorderStyle.none && e.value.width > 0).toList();
    if (vis.isNotEmpty) {
      m['border'] = {
        for (final e in vis) e.key: {'w': _r(e.value.width), 'c': _hex(e.value.color), 'a': _a(e.value.color)}
      };
    }
  }
  if (d.boxShadow != null && d.boxShadow!.isNotEmpty) {
    m['shadows'] = d.boxShadow!
        .map((s) => {'c': _hex(s.color), 'a': _a(s.color), 'dx': _r(s.offset.dx), 'dy': _r(s.offset.dy), 'blur': _r(s.blurRadius), 'spread': _r(s.spreadRadius)})
        .toList();
  }
  return m;
}


Map<String, dynamic> _shape(ShapeBorder? sh, Size size) {
  final m = <String, dynamic>{};
  if (sh is RoundedRectangleBorder) {
    final r = _radius(sh.borderRadius);
    if (r != null) m['radius'] = r;
  } else if (sh is StadiumBorder) {
    m['radius'] = {'tl': size.shortestSide / 2, 'tr': size.shortestSide / 2, 'br': size.shortestSide / 2, 'bl': size.shortestSide / 2};
  } else if (sh is CircleBorder) {
    m['circle'] = true;
  } else if (sh is OutlinedBorder) {
    m['unknownShape'] = sh.runtimeType.toString();
  }
  if (sh is OutlinedBorder && sh.side.style != BorderStyle.none && sh.side.width > 0) {
    m['border'] = {'all': {'w': _r(sh.side.width), 'c': _hex(sh.side.color), 'a': _a(sh.side.color)}};
  }
  return m;
}

class _Ctx {
  _Ctx(this.nodes, this.viewport);
  final List<Map<String, dynamic>> nodes;
  final Rect viewport;
  int order = 0;
  int clipId = 0;
  final Set<RenderObject> visited = {};
  final List<RenderImage> images = [];
  final List<RenderCustomPaint> paints = [];
  final List<bool> paintFg = [];
}

void _walk(RenderObject ro, _Ctx ctx, double opacity) {
  ctx.visited.add(ro);
  if (ro is RenderOffstage && ro.offstage) return;
  var op = opacity;
  if (ro is RenderOpacity) {
    op *= ro.opacity;
    if (ro.opacity == 0) return;
  }
  if (ro is RenderAnimatedOpacity) {
    op *= ro.opacity.value;
    if (ro.opacity.value == 0) return;
  }
  if (ro is RenderBox && ro.hasSize && ro.attached) {
    Rect? rect;
    try {
      rect = MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);
    } catch (_) {}
    if (rect != null && rect.overlaps(ctx.viewport)) {
      final comp = _componentChain(ro);
      Map<String, dynamic> base(String t) => {'t': t, 'o': ctx.order++, ...(_rect(rect!)), if (op < 1) 'op': _r(op), if (comp.isNotEmpty) 'cmp': comp};
      if (ro is RenderDecoratedBox && ro.decoration is ShapeDecoration) {
        final d = ro.decoration as ShapeDecoration;
        final m = <String, dynamic>{..._shape(d.shape, ro.size)};
        if (d.color != null) {
          m['fill'] = _hex(d.color!);
          m['fillA'] = _a(d.color!);
        }
        if (d.shadows != null && d.shadows!.isNotEmpty) {
          m['shadows'] = d.shadows!.map((x) => {'c': _hex(x.color), 'a': _a(x.color), 'dx': _r(x.offset.dx), 'dy': _r(x.offset.dy), 'blur': _r(x.blurRadius), 'spread': _r(x.spreadRadius)}).toList();
        }
        if (m.isNotEmpty) ctx.nodes.add({...base('box'), ...m});
      } else if (ro is RenderDecoratedBox && ro.decoration is BoxDecoration) {
        final d = _boxDeco(ro.decoration as BoxDecoration);
        if (d.isNotEmpty && ro.position == DecorationPosition.background) ctx.nodes.add({...base('box'), ...d});
      } else if (ro is RenderPhysicalShape || ro is RenderPhysicalModel) {
        if (ro is RenderPhysicalModel) {
          final br = ro.borderRadius;
          ctx.nodes.add({...base('box'), 'fill': _hex(ro.color), 'fillA': _a(ro.color), if (_radius(br) != null) 'radius': _radius(br), if (ro.shape == BoxShape.circle) 'circle': true, 'elev': _r(ro.elevation)});
        } else if (ro is RenderPhysicalShape) {
          final cl = ro.clipper;
          ctx.nodes.add({...base('box'), 'fill': _hex(ro.color), 'fillA': _a(ro.color), 'elev': _r(ro.elevation), if (cl is ShapeBorderClipper) ..._shape(cl.shape, ro.size)});
        }
      } else if (ro.runtimeType.toString() == '_RenderColoredBox') {
        final c = (ro as dynamic).color as Color;
        if (c.a > 0) ctx.nodes.add({...base('box'), 'fill': _hex(c), 'fillA': _a(c)});
      } else if (ro is RenderClipRRect && ro.borderRadius != BorderRadius.zero) {
        ctx.nodes.add({...base('clip'), if (_radius(ro.borderRadius) != null) 'radius': _radius(ro.borderRadius)});
      } else if (ro is RenderClipOval) {
        ctx.nodes.add({...base('clip'), 'circle': true});
      } else if (ro is RenderImage) {
        final id = ctx.images.length;
        ctx.images.add(ro);
        ctx.nodes.add({...base('image'), 'img': id, if (ro.fit != null) 'fit': ro.fit!.name});
      } else if (ro is RenderParagraph) {
        _paragraph(ro, rect, base, ctx);
      } else if (ro.runtimeType.toString().contains('PlatformView') || ro.runtimeType.toString().contains('Texture')) {
        ctx.nodes.add(base('platform'));
      } else if (ro is RenderCustomPaint && (ro.painter != null || ro.foregroundPainter != null)) {
        if (ro.painter != null) {
          ctx.nodes.add({...base('paint'), 'painter': ro.painter.runtimeType.toString(), 'pimg': ctx.paints.length});
          ctx.paints.add(ro);
          ctx.paintFg.add(false);
        }
        if (ro.foregroundPainter != null) {
          ctx.nodes.add({...base('paint'), 'painter': ro.foregroundPainter.runtimeType.toString(), 'pimg': ctx.paints.length, 'fg': true});
          ctx.paints.add(ro);
          ctx.paintFg.add(true);
        }
      }
    }
  }
  // Overlay(Navigator)는 가려진 아래쪽 화면도 자식으로 두므로, 실제로 그려지는(onstage) 자식만 따라간다.
  // 스크롤 영역 · ClipRect/ClipRRect는 자식을 잘라 그린다 → 시작/끝 표시를 남긴다.
  Map<String, dynamic>? clipNode;
  if (ro is RenderBox && ro.hasSize && ro.attached) {
    Clip? cb;
    Map<String, dynamic>? rad;
    if (ro is RenderViewportBase) {
      cb = ro.clipBehavior;
    } else if (ro.runtimeType.toString() == '_RenderSingleChildViewport') {
      try {
        cb = (ro as dynamic).clipBehavior as Clip;
      } catch (_) {
        cb = Clip.hardEdge;
      }
    } else if (ro is RenderClipRect && ro.clipper == null) {
      cb = ro.clipBehavior;
    } else if (ro is RenderClipRRect && ro.clipper == null) {
      cb = ro.clipBehavior;
      rad = _radius(ro.borderRadius);
    }
    if (cb != null && cb != Clip.none) {
      try {
        final r = MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);
        if (r.overlaps(ctx.viewport)) {
          final id = ctx.clipId++;
          clipNode = {'id': id};
          ctx.nodes.add({'t': 'clipb', 'o': ctx.order++, ..._rect(r), 'cid': id, if (rad != null) 'radius': rad, 'cmp': _componentChain(ro)});
        }
      } catch (_) {}
    }
  }
  if (ro.runtimeType.toString() == '_RenderTheater') {
    ro.visitChildrenForSemantics((c) => _walk(c, ctx, op));
  } else {
    ro.visitChildren((c) => _walk(c, ctx, op));
  }
  if (clipNode != null) ctx.nodes.add({'t': 'clipe', 'o': ctx.order++, 'cid': clipNode['id'], 'x': 0, 'y': 0, 'w': 0, 'h': 0});
}

void _paragraph(RenderParagraph p, Rect rect, Map<String, dynamic> Function(String) base, _Ctx ctx) {
  final span = p.text;
  final plain = span.toPlainText(includeSemanticsLabels: false, includePlaceholders: false);
  if (plain.trim().isEmpty) return;
  // 스타일 구간
  final runs = <Map<String, dynamic>>[];
  var offset = 0;
  span.visitChildren((s) {
    if (s is TextSpan) {
      final t = s.text ?? '';
      if (t.isNotEmpty) {
        final st = s.style ?? const TextStyle();
        runs.add({'s': offset, 'e': offset + t.length, ..._style(st)});
        offset += t.length;
      }
    }
    return true;
  });
  final root = span is TextSpan ? span.style : null;
  final rootStyle = _style(root ?? const TextStyle());
  // 줄 나누기: 전체 선택 박스를 y 기준으로 묶는다
  final lines = <Map<String, dynamic>>[];
  final all = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: plain.length));
  final groups = <int, List<TextBox>>{};
  for (final bx in all) {
    groups.putIfAbsent(((bx.top + bx.bottom) / 2).round(), () => []).add(bx);
  }
  final keys = groups.keys.toList()..sort();
  final starts = <int>[];
  final geo = <Rect>[];
  for (final k in keys) {
    final g = groups[k]!;
    var left = g.first.left, right = g.first.right, top = g.first.top, bottom = g.first.bottom;
    for (final bx in g) {
      if (bx.left < left) left = bx.left;
      if (bx.right > right) right = bx.right;
      if (bx.top < top) top = bx.top;
      if (bx.bottom > bottom) bottom = bx.bottom;
    }
    geo.add(Rect.fromLTRB(left, top, right, bottom));
    starts.add(starts.isEmpty ? 0 : p.getPositionForOffset(Offset(left + 0.5, (top + bottom) / 2)).offset);
  }
  for (var i = 0; i < geo.length; i++) {
    var e = i + 1 < geo.length ? starts[i + 1] : plain.length;
    if (i == geo.length - 1 && p.didExceedMaxLines) {
      e = p.getPositionForOffset(Offset(geo[i].right - 0.5, (geo[i].top + geo[i].bottom) / 2)).offset;
    }
    final g = geo[i];
    lines.add({'s': starts[i], 'e': e, 'x': _r(rect.left + g.left), 'y': _r(rect.top + g.top), 'w': _r(g.width), 'h': _r(g.height)});
  }
  final family = (rootStyle['family'] ?? '') as String;
  final isIcon = family.contains('MaterialIcons') || family.contains('Icons') || (runs.isNotEmpty && (runs.first['family'] ?? '').toString().contains('Icons'));
  ctx.nodes.add({
    ...base(isIcon ? 'icon' : 'text'),
    'text': plain,
    'root': rootStyle,
    'runs': runs,
    'lines': lines,
    if (p.maxLines != null) 'maxLines': p.maxLines,
    if (p.didExceedMaxLines) 'ell': true,
    // ignore: invalid_use_of_protected_member
    'bl': _r(p.computeDistanceToActualBaseline(TextBaseline.alphabetic)),
    'align': p.textAlign.name,
    if (isIcon) 'code': plain.runes.first,
  });
}

Map<String, dynamic> _style(TextStyle s) => {
      if (s.color != null) 'c': _hex(s.color!),
      if (s.color != null) 'a': _a(s.color!),
      if (s.fontSize != null) 'size': _r(s.fontSize!),
      if (s.fontWeight != null) 'w': s.fontWeight!.value,
      if (s.fontFamily != null) 'family': s.fontFamily,
      if (s.height != null) 'lh': s.height,
      if (s.letterSpacing != null) 'ls': s.letterSpacing,
      if (s.decoration != null && s.decoration != TextDecoration.none) 'deco': s.decoration.toString(),
    };

/// 앱이 만든 위젯 단위 사각형 (컴포넌트 후보)
void _components(Element root, _Ctx ctx, List<Map<String, dynamic>> out) {
  void visit(Element e) {
    final n = e.widget.runtimeType.toString();
    if (appClasses.contains(n)) {
      final ro = e.renderObject ?? _firstRender(e);
      if (ro is RenderBox && ro.hasSize && ro.attached && ctx.visited.contains(ro)) {
        try {
          final r = MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);
          if (r.overlaps(ctx.viewport) && r.width > 0 && r.height > 0) out.add({'cls': n, ..._rect(r)});
        } catch (_) {}
      }
    }
    e.visitChildren(visit);
  }

  visit(root);
}


/// 누를 수 있는 위젯 (InkWell · GestureDetector · 버튼류)
void _taps(Element root, _Ctx ctx, List<Map<String, dynamic>> out) {
  void visit(Element e) {
    final w = e.widget;
    String? kind;
    String? tip;
    if (w is InkWell && (w.onTap != null || w.onLongPress != null)) {
      kind = 'InkWell';
    } else if (w is GestureDetector && (w.onTap != null || w.onLongPress != null)) {
      kind = 'GestureDetector';
    } else if (w is IconButton && w.onPressed != null) {
      kind = 'IconButton';
      tip = w.tooltip;
    } else if (w is ButtonStyleButton && w.onPressed != null) {
      kind = w.runtimeType.toString();
    } else if (w is Tooltip) {
      tip = w.message;
    }
    if (kind != null) {
      final ro = e.renderObject;
      if (ro is RenderBox && ro.hasSize && ro.attached && ctx.visited.contains(ro)) {
        try {
          final r = MatrixUtils.transformRect(ro.getTransformTo(null), Offset.zero & ro.size);
          if (r.overlaps(ctx.viewport) && r.width >= 12 && r.height >= 12) {
            final chain = <String>[];
            e.visitAncestorElements((a) {
              final n = a.widget.runtimeType.toString();
              if (appClasses.contains(n)) chain.add(n);
              return chain.length < 3;
            });
            // 툴팁 (바로 위 Tooltip)
            String? tt = tip;
            if (tt == null) {
              e.visitAncestorElements((a) {
                final aw = a.widget;
                if (aw is Tooltip) tt = aw.message;
                return false;
              });
            }
            out.add({'kind': kind, ..._rect(r), 'cmp': chain, if (tt != null) 'tip': tt});
          }
        } catch (_) {}
      }
    }
    e.visitChildren(visit);
  }

  visit(root);
}

RenderObject? _firstRender(Element e) {
  RenderObject? found;
  void v(Element c) {
    if (found != null) return;
    if (c.renderObject != null) {
      found = c.renderObject;
      return;
    }
    c.visitChildren(v);
  }

  e.visitChildren(v);
  return found;
}

/// 현재 화면을 JSON 파일과 PNG로 저장한다. 파일은 앱 캐시 폴더에 쓰고 adb로 가져간다.
/// 네트워크 이미지가 실제로 받아질 때까지 실시간으로 기다린다.
Future<void> settle(WidgetTester tester, {int seconds = 4}) async {
  for (var i = 0; i < seconds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> dumpScreen(WidgetTester tester, IntegrationTestWidgetsFlutterBinding binding, String name, {Map<String, dynamic>? extra, bool png = true, int settleSec = 0}) async {
  if (settleSec > 0) {
    await settle(tester, seconds: settleSec);
  } else {
    await tester.pump(const Duration(milliseconds: 200));
  }
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  final viewport = Offset.zero & size;
  final nodes = <Map<String, dynamic>>[];
  final ctx = _Ctx(nodes, viewport);
  final root = WidgetsBinding.instance.rootElement!;
  _walk(WidgetsBinding.instance.renderViews.first, ctx, 1);
  final comps = <Map<String, dynamic>>[];
  _components(root, ctx, comps);
  final taps = <Map<String, dynamic>>[];
  _taps(root, ctx, taps);
  for (var i = 0; i < ctx.paints.length; i++) {
    final ro = ctx.paints[i];
    final fg = ctx.paintFg[i];
    if (!ro.hasSize || ro.size.isEmpty) continue;
    try {
      final bytes = await tester.runAsync(() async {
        final sc = math.min(3.0, 900 / math.max(ro.size.width, ro.size.height));
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        canvas.scale(sc);
        (fg ? ro.foregroundPainter! : ro.painter!).paint(canvas, ro.size);
        final out = await rec.endRecording().toImage((ro.size.width * sc).ceil(), (ro.size.height * sc).ceil());
        final bd = await out.toByteData(format: ui.ImageByteFormat.png);
        return bd?.buffer.asUint8List();
      });
      if (bytes != null) _emit('${name}__paint$i', 'png', bytes);
    } catch (e) {
      debugPrint('paint fail $name $i: $e');
    }
  }
  for (var i = 0; i < ctx.images.length; i++) {
    final ro = ctx.images[i];
    final img = ro.image;
    if (img == null || !ro.hasSize || ro.size.isEmpty) continue;
    final bytes = await tester.runAsync(() async {
      final sc = math.min(2.0, 360 / math.max(ro.size.width, ro.size.height));
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.scale(sc);
      paintImage(canvas: canvas, rect: Offset.zero & ro.size, image: img, fit: ro.fit ?? BoxFit.fill, alignment: ro.alignment.resolve(TextDirection.ltr), filterQuality: FilterQuality.medium);
      final out = await rec.endRecording().toImage((ro.size.width * sc).ceil(), (ro.size.height * sc).ceil());
      final bd = await out.toByteData(format: ui.ImageByteFormat.png);
      return bd?.buffer.asUint8List();
    });
    if (bytes != null) _emit('${name}__img$i', 'png', bytes);
  }
  final mq = MediaQuery.of(tester.element(find.byType(Scaffold).first));
  final data = {
    'name': name,
    'size': {'w': _r(size.width), 'h': _r(size.height), 'dpr': view.devicePixelRatio},
    'padding': {'top': _r(mq.padding.top), 'bottom': _r(mq.padding.bottom)},
    'nodes': nodes,
    'components': comps,
    'taps': taps,
    if (extra != null) ...extra,
  };
  _emit(name, 'json', utf8.encode(jsonEncode(data)));
  if (png) {
    try {
      final bytes = await binding.takeScreenshot(name);
      _emit(name, 'png', bytes);
    } catch (e) {
      debugPrint('screenshot fail $name: $e');
    }
  }
  debugPrint('DUMPED $name nodes=${nodes.length} comps=${comps.length}');
}

/// 표준출력으로 내보낸다: FIGDUMP|이름|종류|번호|전체|base64
void _emit(String name, String kind, List<int> bytes) {
  final b64 = base64.encode(bytes);
  const n = 700;
  final total = (b64.length / n).ceil();
  for (var i = 0; i < total; i++) {
    // ignore: avoid_print
    print('FIGDUMP|$name|$kind|$i|$total|${b64.substring(i * n, ((i + 1) * n).clamp(0, b64.length))}');
  }
}

/// 테스트 맨 앞에서 한 번 부른다 (안드로이드 스크린샷 준비).
Future<void> prepareCapture(IntegrationTestWidgetsFlutterBinding binding, WidgetTester tester) async {
  await binding.convertFlutterSurfaceToImage();
  await tester.pump();
}
