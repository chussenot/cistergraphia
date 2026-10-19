from v3 import *
def dp(vals,Sset):
    n=len(vals); f=[0]*(n+2); ch=[None]*(n+2)
    for t in range(n-1,-1,-1):
        f[t]=f[t+1]; ch[t]=1
        if t+1<n and vals[t]+vals[t+1] in Sset and f[t+2]+1>f[t]: f[t]=f[t+2]+1; ch[t]=2
    out=[];t=0
    while t<n:
        if ch[t]==2: out.append(L[vals[t]+vals[t+1]]); t+=2
        else: out.append('.'); t+=1
    return f[0],''.join(out)
def opt(k,iters,seed,Sset=SS):
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    orb,no=orbmap(n,True)
    c=comps(pairs,orb,no)
    roots=sorted(set(r for r,x in c.values()))
    def ev(r):
        cells={}
        for cell,(oi,m) in orb.items(): cells.setdefault((m-r[oi])%4,[]).append(cell)
        parts=[[seq[x] for x in sorted(cells[Lp]) if seq[x]!=9999] for Lp in range(4)]
        vals=sum(parts,[])
        return dp(vals,Sset)[0],parts
    best=None
    for offs in itertools.product(range(4),repeat=len(roots)-1):
        od=dict(zip(roots,(0,)+offs))
        r=[(c[o][1]+od[c[o][0]])%4 for o in range(no)]
        s=ev(r)[0]
        if best is None or s>best[0]: best=(s,r)
    cur,r=best; r=r[:]
    rnd=random.Random(seed); T=1.0; bs,br=cur,r[:]
    for it in range(iters):
        o=rnd.randrange(no); old=r[o]; r[o]=(old+rnd.randrange(1,4))%4
        s=ev(r)[0]
        if s>=cur or rnd.random()<math.exp((s-cur)/T): cur=s
        else: r[o]=old
        T=max(0.05,T*0.9997)
        if cur>bs: bs,br=cur,r[:]
    return bs,br,ev(br)[1]
if __name__=='__main__':
    for k in sys.argv[1:]:
        res=[opt(k,15000,s) for s in range(3)]
        res.sort(key=lambda t:-t[0])
        bs,br,parts=res[0]
        print(k,[x[0] for x in res])
        for st in range(4):
            vals=sum(parts[st:]+parts[:st],[])
            print('   start',st,'|'+dp(vals,SS)[1]+'|')
