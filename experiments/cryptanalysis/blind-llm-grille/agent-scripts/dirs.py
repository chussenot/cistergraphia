from paths import *
from collections import Counter
for fn in sorted(glob.glob(D+'/*.svg')):
    W,lines,paths=load(fn)
    C=Counter()
    for l,p in zip(lines,paths):
        s,e,h=pinfo(p)
        x1,y1,x2,y2=l
        same = abs(s[0]-x1)+abs(s[1]-y1) < abs(s[0]-x2)+abs(s[1]-y2)
        stem = x1==x2 and abs(y2-y1)==150
        # line direction class
        C[('stem' if stem else 'seg', 'lineDown' if y2>y1 else ('lineUp' if y2<y1 else 'horiz'), 'path=line' if same else 'path=rev')]+=1
    print(os.path.basename(fn)); 
    for k,v in sorted(C.items()): print('  ',k,v)
