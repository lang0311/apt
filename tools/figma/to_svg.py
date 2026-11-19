# 덤프(JSON+PNG) -> SVG 변환기. 사용: python to_svg.py <dump_dir> <out_dir> [이름...]
import base64, io, json, os, sys
from xml.sax.saxutils import escape
from PIL import Image
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

import shutil
_fr = os.environ.get('FLUTTER_ROOT') or os.path.dirname(os.path.dirname(os.path.realpath(shutil.which('flutter') or '')))
FONT = os.path.join(_fr, 'bin', 'cache', 'artifacts', 'material_fonts', 'materialicons-regular.otf')
_f = TTFont(FONT)
_cmap = _f.getBestCmap()
_gs = _f.getGlyphSet()
_upm = _f['head'].unitsPerEm
_icon_cache = {}


def icon_path(code):
    if code in _icon_cache:
        return _icon_cache[code]
    g = _cmap.get(code)
    if not g:
        _icon_cache[code] = None
        return None
    pen = SVGPathPen(_gs, ntos=lambda v: ('%.1f' % v).rstrip('0').rstrip('.'))
    _gs[g].draw(pen)
    d = pen.getCommands()
    _icon_cache[code] = (d, _gs[g].width)
    return _icon_cache[code]


def f(v):
    return ('%.2f' % v).rstrip('0').rstrip('.')


def rad(n):
    r = n.get('radius')
    if n.get('circle'):
        return ('circle', min(n['w'], n['h']) / 2)
    if not r:
        return None
    vals = [r['tl'], r['tr'], r['br'], r['bl']]
    if max(vals) <= 0:
        return None
    return ('r', vals)


def rrect_path(x, y, w, h, vals):
    tl, tr, br, bl = [min(v, w / 2, h / 2) for v in vals]
    return (f'M{f(x+tl)} {f(y)}H{f(x+w-tr)}A{f(tr)} {f(tr)} 0 0 1 {f(x+w)} {f(y+tr)}V{f(y+h-br)}'
            f'A{f(br)} {f(br)} 0 0 1 {f(x+w-br)} {f(y+h)}H{f(x+bl)}A{f(bl)} {f(bl)} 0 0 1 {f(x)} {f(y+h-bl)}'
            f'V{f(y+tl)}A{f(tl)} {f(tl)} 0 0 1 {f(x+tl)} {f(y)}Z')


def shape_el(x, y, w, h, n, attrs):
    r = rad(n)
    if r and r[0] == 'circle':
        if abs(w - h) < 0.6:
            return f'<ellipse cx="{f(x+w/2)}" cy="{f(y+h/2)}" rx="{f(w/2)}" ry="{f(h/2)}" {attrs}/>'
        return f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="{f(min(w,h)/2)}" {attrs}/>'
    if r and r[0] == 'r':
        v = r[1]
        if len(set(v)) == 1:
            return f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="{f(min(v[0], w/2, h/2))}" {attrs}/>'
        return f'<path d="{rrect_path(x, y, w, h, v)}" {attrs}/>'
    return f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" {attrs}/>'


def weight(w):
    if w is None:
        return 400
    if w >= 600:
        return 700
    if w >= 500:
        return 500
    if w <= 300:
        return 300
    return 400


def png_data_uri(img):
    b = io.BytesIO()
    img.save(b, 'PNG', optimize=True)
    return 'data:image/png;base64,' + base64.b64encode(b.getvalue()).decode()


def convert(dump_dir, name, out_dir):
    d = json.load(open(os.path.join(dump_dir, name + '.json'), encoding='utf-8'))
    W, H, dpr = d['size']['w'], d['size']['h'], d['size']['dpr']
    shot_path = os.path.join(dump_dir, name + '.png')
    shot = Image.open(shot_path).convert('RGB') if os.path.exists(shot_path) else None
    defs, body, clips = [], [], []
    shadow_i = [0]
    clip_i = [0]
    nodes = d['nodes']
    warn = []

    def crop(n):
        if not shot:
            return None
        box = tuple(int(round(v * dpr)) for v in (n['x'], n['y'], n['x'] + n['w'], n['y'] + n['h']))
        box = (max(0, box[0]), max(0, box[1]), min(shot.width, box[2]), min(shot.height, box[3]))
        if box[2] <= box[0] or box[3] <= box[1]:
            return None
        return shot.crop(box)

    last_group = None
    gstack = []  # 클립 안쪽으로 들어갈 때 바깥 그룹 상태를 보관
    for idx, n in enumerate(nodes):
        t = n['t']
        if t == 'clipb':
            if last_group is not None:
                body.append('</g>')
            gstack.append(last_group)
            last_group = None
            cid = f'k{n["cid"]}'
            r = n.get('radius')
            if r and max(r.values()) > 0:
                shp = f'<path d="{rrect_path(n["x"], n["y"], n["w"], n["h"], [r["tl"], r["tr"], r["br"], r["bl"]])}"/>'
            else:
                shp = f'<rect x="{f(n["x"])}" y="{f(n["y"])}" width="{f(n["w"])}" height="{f(n["h"])}"/>'
            defs.append(f'<clipPath id="{cid}">{shp}</clipPath>')
            body.append(f'<g id="{escape((n.get("cmp") or ["clip"])[0])}" clip-path="url(#{cid})">')
            continue
        if t == 'clipe':
            if last_group is not None:
                body.append('</g>')
            body.append('</g>')
            last_group = gstack.pop() if gstack else None
            if last_group is not None:
                body.append(f'<g id="{escape(last_group or "layer")}">')
            continue
        x, y, w, h = n['x'], n['y'], n['w'], n['h']
        op = n.get('op', 1)
        grp = (n.get('cmp') or [''])[0]
        el = None
        if t == 'box':
            fill = n.get('fill')
            fa = n.get('fillA', 1) * op
            has_border = 'border' in n
            has_shadow = bool(n.get('shadows'))
            if (fill is None or fa == 0) and not has_border and not has_shadow:
                continue
            attrs = []
            if fill and fa > 0:
                attrs.append(f'fill="{fill}"' + (f' fill-opacity="{f(fa)}"' if fa < 1 else ''))
            else:
                attrs.append('fill="none"')
            bx, by, bw, bh = x, y, w, h
            if has_border and 'all' in n['border']:
                b = n['border']['all']
                half = b['w'] / 2
                bx, by, bw, bh = x + half, y + half, w - b['w'], h - b['w']
                attrs.append(f'stroke="{b["c"]}" stroke-width="{f(b["w"])}"' + (f' stroke-opacity="{f(b["a"]*op)}"' if b['a'] * op < 1 else ''))
                rr = n.get('radius')
                if rr:
                    n = dict(n)
                    n['radius'] = {k: max(0, v - half) for k, v in rr.items()}
            if has_shadow:
                s = n['shadows'][0]
                shadow_i[0] += 1
                fid = f'sh{shadow_i[0]}'
                defs.append(
                    f'<filter id="{fid}" x="-50%" y="-50%" width="200%" height="200%"><feDropShadow dx="{f(s["dx"])}" dy="{f(s["dy"])}" '
                    f'stdDeviation="{f(s["blur"]/2)}" flood-color="{s["c"]}" flood-opacity="{f(s["a"]*op)}"/></filter>')
                attrs.append(f'filter="url(#{fid})"')
            el = shape_el(bx, by, bw, bh, n, ' '.join(attrs))
            if has_border and any(k in n['border'] for k in 'trbl') and 'all' not in n['border']:
                parts = [el] if fill and fa > 0 else []
                for k, b in n['border'].items():
                    bwid = b['w']
                    rect = {'t': (x, y, w, bwid), 'b': (x, y + h - bwid, w, bwid), 'l': (x, y, bwid, h), 'r': (x + w - bwid, y, bwid, h)}[k]
                    parts.append(f'<rect x="{f(rect[0])}" y="{f(rect[1])}" width="{f(rect[2])}" height="{f(rect[3])}" fill="{b["c"]}"' + (f' fill-opacity="{f(b["a"]*op)}"' if b['a'] * op < 1 else '') + '/>')
                el = ''.join(parts)
        elif t == 'clip':
            continue
        elif t == 'image':
            uri = None
            p = os.path.join(dump_dir, f'{name}__img{n["img"]}.png') if 'img' in n else None
            if p and os.path.exists(p):
                uri = png_data_uri(Image.open(p).convert('RGBA'))
            else:
                c = crop(n)
                if c:
                    uri = png_data_uri(c)
                    warn.append(f'image crop fallback @{f(x)},{f(y)}')
            if not uri:
                continue
            # 이 이미지를 감싼 clip(둥근 모서리) 찾기
            cr = None
            for m in reversed(nodes[:idx]):
                if m['t'] == 'clip' and m['x'] <= x + 1 and m['y'] <= y + 1 and m['x'] + m['w'] >= x + w - 1 and m['y'] + m['h'] >= y + h - 1:
                    cr = m
                    break
            clip_attr = ''
            if cr and (cr.get('radius') or cr.get('circle')):
                clip_i[0] += 1
                cid = f'c{clip_i[0]}'
                shp = shape_el(cr['x'], cr['y'], cr['w'], cr['h'], cr, '')
                defs.append(f'<clipPath id="{cid}">{shp}</clipPath>')
                clip_attr = f' clip-path="url(#{cid})"'
            el = f'<image x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" preserveAspectRatio="none" href="{uri}"' + clip_attr + (f' opacity="{f(op)}"' if op < 1 else '') + '/>'
        elif t in ('platform', 'paint'):
            if n.get('painter') in ('_ShapeBorderPainter',):
                continue
            pp = os.path.join(dump_dir, f'{name}__paint{n["pimg"]}.png') if 'pimg' in n else None
            if pp and os.path.exists(pp):
                im = Image.open(pp).convert('RGBA')
                if im.getbbox() is None:
                    continue  # 완전히 투명
                el = f'<image x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" preserveAspectRatio="none" href="{png_data_uri(im)}"' + (f' opacity="{f(op)}"' if op < 1 else '') + '/>'
            else:
                c = crop(n)
                if not c:
                    continue
                warn.append(f'{t} crop fallback {n.get("painter","")} @{f(x)},{f(y)} {f(w)}x{f(h)}')
                el = f'<image x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" preserveAspectRatio="none" href="{png_data_uri(c)}"/>'
        elif t == 'icon':
            root = n.get('root', {})
            r = icon_path(n['code'])
            if not r:
                warn.append(f'icon missing {n["code"]}')
                continue
            dpath, adv = r
            size = root.get('size', 24)
            s = size / _upm
            by = y + n['bl']
            col = root.get('c', '#000000')
            a = root.get('a', 1) * op
            el = (f'<path transform="translate({f(x)} {f(by)}) scale({s:.5f} {-s:.5f})" d="{dpath}" fill="{col}"' + (f' fill-opacity="{f(a)}"' if a < 1 else '') + f' id="icon_{n["code"]:x}"/>')
        elif t == 'text':
            root = n.get('root', {})
            lines = n.get('lines') or []
            if not lines:
                continue
            text = n['text']
            runs = n.get('runs', [])
            l0y = lines[0]['y']
            out = []
            for li, ln in enumerate(lines):
                seg_s, seg_e = ln['s'], ln['e']
                piece = text[seg_s:seg_e].rstrip('\n')
                if li == len(lines) - 1 and n.get('ell'):
                    piece = piece.rstrip() + '…'
                if not piece.strip():
                    continue
                # 스타일 구간
                spans = []
                cuts = sorted({seg_s, seg_e, *[r['s'] for r in runs if seg_s < r['s'] < seg_e], *[r['e'] for r in runs if seg_s < r['e'] < seg_e]})
                for a_, b_ in zip(cuts, cuts[1:]):
                    st = dict(root)
                    for r in runs:
                        if r['s'] <= a_ and b_ <= r['e']:
                            st.update({k: v for k, v in r.items() if k not in ('s', 'e')})
                    txt = text[a_:b_]
                    if li == len(lines) - 1 and n.get('ell') and b_ == cuts[-1]:
                        txt = txt.rstrip() + '…'
                    spans.append((txt, st))
                if not spans:
                    spans = [(piece, root)]
                by = y + n['bl'] + (ln['y'] - l0y)
                first = spans[0][1]
                ts = []
                for txt, st in spans:
                    attrs = [f'fill="{st.get("c", "#000000")}"']
                    sa = st.get('a', 1) * op
                    if sa < 1:
                        attrs.append(f'fill-opacity="{f(sa)}"')
                    attrs.append(f'font-size="{f(st.get("size", 14))}"')
                    attrs.append(f'font-weight="{weight(st.get("w"))}"')
                    if st.get('ls'):
                        attrs.append(f'letter-spacing="{f(st["ls"])}"')
                    if 'deco' in st and 'underline' in st['deco']:
                        attrs.append('text-decoration="underline"')
                    ts.append(f'<tspan {" ".join(attrs)}>{escape(txt)}</tspan>')
                out.append(f'<text x="{f(ln["x"])}" y="{f(by)}" font-family="Noto Sans KR" xml:space="preserve">{"".join(ts)}</text>')
            el = ''.join(out)
        if not el:
            continue
        if grp != last_group:
            if last_group is not None:
                body.append('</g>')
            body.append(f'<g id="{escape(grp or "layer")}">')
            last_group = grp
        body.append(el)
    if last_group is not None:
        body.append('</g>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{f(W)}" height="{f(H)}" viewBox="0 0 {f(W)} {f(H)}">'
           f'<defs>{"".join(defs)}</defs>{"".join(body)}</svg>')
    os.makedirs(out_dir, exist_ok=True)
    open(os.path.join(out_dir, name + '.svg'), 'w', encoding='utf-8').write(svg)
    return len(svg), warn


if __name__ == '__main__':
    dd, od = sys.argv[1], sys.argv[2]
    names = sys.argv[3:] or [fn[:-5] for fn in os.listdir(dd) if fn.endswith('.json')]
    for nm in names:
        size, warn = convert(dd, nm, od)
        print(nm, size, 'bytes', len(warn), 'warnings')
        for w_ in warn[:8]:
            print('  ', w_)
