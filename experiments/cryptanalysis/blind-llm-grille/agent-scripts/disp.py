from match import *
from collections import Counter
S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
C=Counter()
for k in sorted(G):
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    out=[]
    for i,j in pairs:
        if seq[i]+seq[j]>=1000:
            out.append(((i//n,i%n),(j//n,j%n)))
            C[j-i]+=1
    print(k,out)
print(sorted(C.items()))
