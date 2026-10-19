from match import *
S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
for k in sorted(G):
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    depth=[0]*len(seq)
    for i,j in pairs:
        for t in range(i,j+1): depth[t]+=1
    print(k,max(depth),''.join(str(min(d,9)) for d in depth))
