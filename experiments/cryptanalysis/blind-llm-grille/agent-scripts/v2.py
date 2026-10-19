from annot import *
import anneal2
def strip(vals): return [v for v in vals if v!=9999]
def optimize2(k,iters=30000,seed=1,Sset=None):
    Sset=Sset or set(S)
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    orb,no=orbmap(n,True)
    c=comps(pairs,orb,no)
    roots=sorted(set(r for r,x in c.values()))
    best=None
    for offs in itertools.product(range(4),repeat=len(roots)-1):
        od=dict(zip(roots,(0,)+offs))
        r=[(c[o][1]+od[c[o][0]])%4 for o in range(no)]
        vals=strip([seq[x] for x in streams(seq,n,orb,no,r,0)])
        s=gscore(vals,Sset)
        if best is None or s>best[0]: best=(s,r)
    cur,r=best; r=r[:]
    rnd=random.Random(seed); T=1.0; bs,br=cur,r[:]
    for it in range(iters):
        o=rnd.randrange(no); old=r[o]; r[o]=(old+rnd.randrange(1,4))%4
        vals=strip([seq[x] for x in streams(seq,n,orb,no,r,0)])
        s=gscore(vals,Sset)
        if s>=cur or rnd.random()<math.exp((s-cur)/T): cur=s
        else: r[o]=old
        T=max(0.05,T*0.9997)
        if cur>bs: bs,br=cur,r[:]
    vals=strip([seq[x] for x in streams(seq,n,orb,no,br,0)])
    return bs,br,vals
if __name__=='__main__':
    for k in sys.argv[1:]:
        bs,br,vals=optimize2(k,iters=int(sys.argv[0:1] and 20000))
        print(k,bs,greedy(vals,Sx)); print(annot(vals,Sx))
