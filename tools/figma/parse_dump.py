import sys,re,base64,os,collections
out=sys.argv[2]; os.makedirs(out,exist_ok=True)
parts=collections.defaultdict(dict)
for line in open(sys.argv[1],encoding='utf-8',errors='ignore'):
    i=line.find('FIGDUMP|')
    if i<0: continue
    f=line[i:].rstrip('\n').split('|')
    if len(f)<6: continue
    _,name,kind,idx,total,chunk=f[:6]
    parts[(name,kind)][int(idx)]=(int(total),chunk)
for (name,kind),d in parts.items():
    total=next(iter(d.values()))[0]
    if len(d)!=total: print('INCOMPLETE',name,kind,len(d),total); continue
    data=base64.b64decode(''.join(d[i][1] for i in range(total)))
    open(os.path.join(out,f'{name}.{kind}'),'wb').write(data)
    print('ok',name,kind,len(data))
