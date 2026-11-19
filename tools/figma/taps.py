import json, glob, os
RANK = {'IconButton': 3, 'InkWell': 2, 'GestureDetector': 1}

def contains(a, b, tol=1.5):
    return a['x'] <= b['x'] + tol and a['y'] <= b['y'] + tol and a['x'] + a['w'] >= b['x'] + b['w'] - tol and a['y'] + a['h'] >= b['y'] + b['h'] - tol

def _dark(h):
    h = h.lstrip('#')
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) < 90


def area(r): return r['w'] * r['h']

def label_of(t, texts, icons):
    inside = [n for n in texts if t['x'] - 1 <= n['x'] + n['w'] / 2 <= t['x'] + t['w'] + 1 and t['y'] - 1 <= n['y'] + n['h'] / 2 <= t['y'] + t['h'] + 1]
    inside.sort(key=lambda n: (round(n['y'] / 6), n['x']))
    s = ' '.join(n['text'].replace('\n', ' ') for n in inside)
    return s.strip()

def process(name, dump_dir='final'):
    d = json.load(open(f'{dump_dir}/{name}.json', encoding='utf-8'))
    W, H = d['size']['w'], d['size']['h']
    texts = [n for n in d['nodes'] if n['t'] == 'text']
    # 시트·대화상자: 스크림 뒤 화면의 버튼은 빼고 앞쪽 패널 안의 것만 남긴다
    fg = None
    scrim_i = None
    for i, n in enumerate(d['nodes']):
        if n['t'] == 'box' and n['w'] >= W - 1 and n['h'] >= H * 0.85 and n.get('fillA', 1) < 0.9 and _dark(n.get('fill', '#ffffff')):
            scrim_i = i
    if scrim_i is not None:
        for n in d['nodes'][scrim_i + 1:]:
            r = n.get('radius') or {}
            if n['t'] == 'box' and n.get('fillA', 1) >= 0.95 and n['w'] >= 200 and n['h'] >= 100 and (r.get('tl', 0) >= 14 or r.get('tr', 0) >= 14):
                fg = n; break
    d['_fg'] = fg
    if fg is not None:
        texts = [n for n in texts if n['o'] >= fg['o']]
    out = []
    for t in d['taps']:
        if fg is not None and t['cmp'][:1] == ['AppBottomNav']:
            continue
        if fg is not None and 'DeepLinkCoordinator' not in t['cmp']:
            continue
        if fg is not None and not (t['x'] >= fg['x'] - 2 and t['y'] >= fg['y'] - 2 and t['x'] + t['w'] <= fg['x'] + fg['w'] + 2 and t['y'] + t['h'] <= fg['y'] + fg['h'] + 2):
            continue
        if t['w'] > W * 0.98 and t['h'] > H * 0.6:
            continue  # 바깥 영역(스크림) 등
        out.append(dict(t))
    # 거의 같은 사각형은 하나로
    out.sort(key=lambda t: (-area(t)))
    keep = []
    for t in out:
        dup = False
        for k in keep:
            if contains(k, t) and area(t) >= 0.85 * area(k) or contains(t, k) and area(k) >= 0.85 * area(t):
                if RANK.get(t['kind'], 0) > RANK.get(k['kind'], 0): k.update(t)
                if 'tip' in t and 'tip' not in k: k['tip'] = t['tip']
                dup = True
                break
        if not dup: keep.append(t)
    # 같은 중심의 작은 사각형(아이콘 버튼 안의 InkWell)은 큰 쪽으로 합친다
    merged = []
    for t in sorted(keep, key=lambda t: -area(t)):
        host = None
        for k in merged:
            if contains(k, t) and abs((k['x'] + k['w'] / 2) - (t['x'] + t['w'] / 2)) < 6 and abs((k['y'] + k['h'] / 2) - (t['y'] + t['h'] / 2)) < 6 and area(k) < 6000:
                host = k; break
        if host is None: merged.append(t)
        elif 'tip' in t and 'tip' not in host: host['tip'] = t['tip']
    keep = merged
    # 지도 핀(PreviewMap)은 하나로
    pm = [t for t in keep if t['cmp'][:1] == ['PreviewMap']]
    keep = [t for t in keep if t['cmp'][:1] != ['PreviewMap']]
    if pm:
        x0 = min(t['x'] for t in pm); y0 = min(t['y'] for t in pm); x1 = max(t['x'] + t['w'] for t in pm); y1 = max(t['y'] + t['h'] for t in pm)
        keep.append({'kind': 'GestureDetector', 'x': x0, 'y': y0, 'w': x1 - x0, 'h': y1 - y0, 'cmp': ['PreviewMap'], 'label': '지도 핀', 'group': True, 'n': len(pm)})
    # 하단 탭은 하나로
    nav = [t for t in keep if t['cmp'][:1] == ['AppBottomNav']]
    keep = [t for t in keep if t['cmp'][:1] != ['AppBottomNav']]
    if nav:
        x0 = min(t['x'] for t in nav); y0 = min(t['y'] for t in nav); x1 = max(t['x'] + t['w'] for t in nav); y1 = max(t['y'] + t['h'] for t in nav)
        keep.append({'kind': 'InkWell', 'x': x0, 'y': y0, 'w': x1 - x0, 'h': y1 - y0, 'cmp': ['AppBottomNav'], 'label': '하단 탭', 'group': True})
    # 같은 모양 반복 항목은 묶는다 (목록 행 · 가로 카드)
    keep.sort(key=lambda t: (t['cmp'][:1], t['kind'], round(t['y']), round(t['x'])))
    out2, used = [], set()
    cand = [t for t in keep if 'label' not in t]
    for t in cand:
        t['label'] = label_of(t, texts, None)
    for i, t in enumerate(keep):
        if i in used or t.get('group'): 
            if t.get('group') and i not in used: out2.append(t)
            continue
        grp = [i]
        for j in range(i + 1, len(keep)):
            u = keep[j]
            if j in used or u.get('group'): continue
            last = keep[grp[-1]]
            vgap = u['y'] - (last['y'] + last['h']); hgap = u['x'] - (last['x'] + last['w'])
            near = (abs(u['x'] - last['x']) <= 3 and -3 <= vgap <= 44) or (abs(u['y'] - last['y']) <= 3 and -3 <= hgap <= 44)
            if not near: continue
            if u['cmp'][:1] == t['cmp'][:1] and u['kind'] == t['kind'] and abs(u['w'] - t['w']) <= 3 and abs(u['h'] - t['h']) <= 3 and (abs(u['x'] - t['x']) <= 3 or abs(u['y'] - t['y']) <= 3) and t['cmp'] and t['cmp'][0] not in ('PlainHeader', 'AuthHeader', 'SegmentedTabs', 'AppBottomNav'):
                grp.append(j)
        if len(grp) > 1:
            for j in grp: used.add(j)
            xs = [keep[j]['x'] for j in grp]; ys = [keep[j]['y'] for j in grp]
            xe = [keep[j]['x'] + keep[j]['w'] for j in grp]; ye = [keep[j]['y'] + keep[j]['h'] for j in grp]
            first = keep[grp[0]]
            out2.append({'kind': first['kind'], 'x': min(xs), 'y': min(ys), 'w': max(xe) - min(xs), 'h': max(ye) - min(ys), 'cmp': first['cmp'], 'label': '', 'group': True, 'n': len(grp)})
        else:
            used.add(i); out2.append(t)
    keep = out2
    for t in keep:
        if 'label' not in t: t['label'] = label_of(t, texts, None)
    keep.sort(key=lambda t: (round(t['y'] / 24), t['x']))
    return d, keep

if __name__ == '__main__':
    import sys
    for p in sorted(glob.glob('final/*.json')):
        n = os.path.basename(p)[:-5]
        d, taps = process(n)
        print(n, len(taps))
        for i, t in enumerate(taps, 1):
            print(f"  {i} {t['kind'][:4]} {t['cmp'][:1]} [{int(t['x'])},{int(t['y'])},{int(t['w'])}x{int(t['h'])}] '{t['label'][:34]}' tip={t.get('tip','')}")
