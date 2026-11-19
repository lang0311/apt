import glob, os, sys
sys.path.insert(0, 'tools')
from taps import process
for p in sorted(glob.glob('final/*.json')):
    n = os.path.basename(p)[:-5]
    d, taps = process(n)
    items = []
    for i, t in enumerate(taps, 1):
        lab = t['label'].split(' ')[0][:9] if t['label'] else ''
        c = (t['cmp'][:1] or [''])[0]
        extra = f"x{t['n']}" if t.get('n') else ''
        items.append(f"{i}:{c[:11]}:{lab or t.get('tip','')[:6]}{extra}")
    print(n[:22], ' | '.join(items))
