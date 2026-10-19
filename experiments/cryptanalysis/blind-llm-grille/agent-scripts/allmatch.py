from match import *
from collections import Counter
S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
tot=Counter()
for k in sorted(G):
    g=G[k]; seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    used=set(x for p in pairs for x in p)
    un=[(i,seq[i]) for i in range(len(seq)) if i not in used]
    c=Counter(seq[i]+seq[j] for i,j in pairs); tot+=c
    print(k,len(seq),'pairs',sc,'unmatched',len(un),sorted(c.items()))
    print('   unmatched:',un)
print(sorted(tot.items()))
