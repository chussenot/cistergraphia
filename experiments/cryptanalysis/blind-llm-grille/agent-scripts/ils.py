from v4 import *
import json
def make_ev(k):
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    orb,no=orbmap(n,True)
    def ev(r):
        cells={}
        for cell,(oi,m) in orb.items(): cells.setdefault((m-r[oi])%4,[]).append(cell)
        parts=[[seq[x] for x in sorted(cells[Lp]) if seq[x]!=9999] for Lp in range(4)]
        best=None
        for st in range(4):
            vals=sum(parts[st:]+parts[:st],[])
            s,txt=dp(vals,SS)
            pen=txt.count('.')
            sc=s-0.25*pen
            if best is None or sc>best[0]: best=(sc,txt)
        return best
    return ev,no
def ils(k,r0,rounds,seed):
    ev,no=make_ev(k); rnd=random.Random(seed)
    r=r0[:]; cur=ev(r)[0]; best=(cur,r[:])
    for rd in range(rounds):
        improved=True
        while improved:
            improved=False
            for o in rnd.sample(range(no),no):
                for v in range(4):
                    if v==r[o]: continue
                    old=r[o]; r[o]=v; s=ev(r)[0]
                    if s>cur+1e-9: cur=s; improved=True
                    else: r[o]=old
            # pair moves
            if not improved:
                for _ in range(300):
                    o1,o2=rnd.sample(range(no),2); a,b=r[o1],r[o2]
                    r[o1]=rnd.randrange(4); r[o2]=rnd.randrange(4)
                    s=ev(r)[0]
                    if s>cur+1e-9: cur=s; improved=True; break
                    r[o1],r[o2]=a,b
        if cur>best[0]: best=(cur,r[:])
        # perturb
        r=best[1][:]
        for o in rnd.sample(range(no),4): r[o]=rnd.randrange(4)
        cur=ev(r)[0]
    return best,ev(best[1])[1]
if __name__=='__main__':
    k=sys.argv[1]; r0=json.loads(sys.argv[2])
    (sc,r),txt=ils(k,r0,int(sys.argv[3]),0)
    print(k,sc,r); print('|'+txt+'|')
