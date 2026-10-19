from match import *
import itertools
S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
for k in sorted(G):
    g=G[k]; seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    used=set(x for p in pairs for x in p)
    un=[(i,seq[i]) for i in range(len(seq)) if i not in used and seq[i]!=9999]
    found=[]
    for r in (2,3):
        for comb in itertools.combinations(un,r):
            if comb[-1][0]-comb[0][0]>24: continue
            s=sum(v for _,v in comb)
            if s%1000==0 or s%10000 in S: found.append((s,comb))
    print(k,[ (s,[i for i,_ in c]) for s,c in found])
