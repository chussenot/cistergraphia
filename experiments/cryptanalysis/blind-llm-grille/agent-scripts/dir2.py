from paths import *
from collections import Counter
C=Counter()
for fn in sorted(glob.glob(D+'/*.svg')):
    W,lines,paths=load(fn)
    g=glyphs(lines)
    owner={}
    for st,ls in g.items():
        for l in ls: owner[l]=st
    for l,p in zip(lines,paths):
        s,e,h=pinfo(p)
        x1,y1,x2,y2=l
        if x1==x2 and abs(y2-y1)==150: continue
        sx,sy=owner[l]
        q,stroke=seg_digit(sx,sy,l)
        if stroke=='6':
            kind='down' if e[1]>s[1] else 'up'
        else:
            kind='out' if abs(s[0]-sx)<abs(e[0]-sx) else 'in'
        C[(q,stroke,kind)]+=1
for k in sorted(C): print(k,C[k])
