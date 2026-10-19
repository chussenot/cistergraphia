from v4 import *
def pscore(vals):
    a=sum(1 for t in range(0,len(vals)-1,2) if vals[t]+vals[t+1] in SS)
    b=sum(1 for t in range(1,len(vals)-1,2) if vals[t]+vals[t+1] in SS)
    return max(a,b)
def text(vals):
    best=None
    for par in (0,1):
        out=''.join(L.get(vals[t]+vals[t+1],'.') for t in range(par,len(vals)-1,2))
        sc=sum(c!='.' for c in out)
        if best is None or sc>best[0]: best=(sc,out)
    return best[1]
def opt5(k,iters,seed,init='uf'):
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    orb,no=orbmap(n,True)
    def ev(r):
        cells={}
        for cell,(oi,m) in orb.items(): cells.setdefault((m-r[oi])%4,[]).append(cell)
        parts=[[seq[x] for x in sorted(cells[Lp]) if seq[x]!=9999] for Lp in range(4)]
        sc=max(pscore(sum(parts[s:]+parts[:s],[])) for s in range(4))
        return sc,parts
    rnd=random.Random(seed)
    if init=='uf':
        sc,pairs=solve(seq,S)
        c=comps(pairs,orb,no)
        roots=sorted(set(r for r,x in c.values()))
        best=None
        for offs in itertools.product(range(4),repeat=len(roots)-1):
            od=dict(zip(roots,(0,)+offs))
            r=[(c[o][1]+od[c[o][0]])%4 for o in range(no)]
            s=ev(r)[0]
            if best is None or s>best[0]: best=(s,r)
        cur,r=best; r=r[:]
    else:
        r=[rnd.randrange(4) for _ in range(no)]; cur=ev(r)[0]
    T=1.5; bs,br=cur,r[:]
    for it in range(iters):
        o=rnd.randrange(no); old=r[o]; r[o]=(old+rnd.randrange(1,4))%4
        s=ev(r)[0]
        if s>=cur or rnd.random()<math.exp((s-cur)/T): cur=s
        else: r[o]=old
        T=max(0.05,T*0.9997)
        if cur>bs: bs,br=cur,r[:]
    return bs,br,ev(br)[1]
if __name__=='__main__':
    k=sys.argv[1]; R=int(sys.argv[2]); init=sys.argv[3]
    res=[opt5(k,15000,s,init) for s in range(R)]
    res.sort(key=lambda t:-t[0])
    print(k,[x[0] for x in res])
    bs,br,parts=res[0]
    print('  r=',br)
    for st in range(4):
        print('   start',st,'|'+text(sum(parts[st:]+parts[:st],[]))+'|')
