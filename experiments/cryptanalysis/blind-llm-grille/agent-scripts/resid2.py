from match import *
from collections import Counter
S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
C=Counter(); ex={}
for k in sorted(G):
    g=G[k]; seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    used=set(x for p in pairs for x in p)
    un=[i for i in range(len(seq)) if i not in used]
    for a in range(len(un)):
        for b in range(a+1,len(un)):
            if un[b]-un[a]>16: break
            s=seq[un[a]]+seq[un[b]]
            C[s]+=1; ex.setdefault(s,[]).append((k,un[a],un[b],seq[un[a]],seq[un[b]]))
print([(s,c) for s,c in C.most_common(30)])
for s in [x for x,c in C.most_common(8)]: print(s,ex[s][:8])
