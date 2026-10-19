import json,random
G=json.load(open('grids.json'))
def feasible(seq,M,ok,maxk=3):
    n=len(seq); reach=[False]*(n+1); reach[0]=True
    for i in range(n):
        if not reach[i]: continue
        s=0
        for k in range(1,maxk+1):
            if i+k>n: break
            s+=seq[i+k-1]
            if (s%M) in ok: reach[i+k]=True
    return reach[n], sum(reach)
for M,ok,name in [(1000,set(range(0,27)),'0-26'),(1000,set(range(32,127)),'ascii'),(10000,set(range(32,127)),'ascii10k'),(100,set(range(0,27)),'mod100 0-26'),(1000,set(range(65,91))|set(range(97,123))|{32},'letters')]:
    res=[]
    for k,g in G.items():
        seq=[v for r in g for v in r]
        for order in ('row','col'):
            if order=='col': seq=[g[i][j] for j in range(len(g)) for i in range(len(g))]
            f,c=feasible(seq,M,ok)
            sh=seq[:]; random.shuffle(sh); f2,c2=feasible(sh,M,ok)
            res.append((k,order,f,c,f2,c2))
    print(name,res)
