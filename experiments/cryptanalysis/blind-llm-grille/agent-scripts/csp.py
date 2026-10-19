from match import *
import itertools,sys
S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
def rot(c,n,cw):
    i,j=c
    return (j,n-1-i) if cw else (n-1-j,i)
def test(k,cw,minsum=1000):
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    pairs=[p for p in pairs if seq[p[0]]+seq[p[1]]>=minsum]
    # orbit id and offset m for each cell
    orb={};
    reps=[(i,j) for i in range(n//2) for j in range(n//2)]
    for oi,c in enumerate(reps):
        x=c
        for m in range(4):
            orb[x[0]*n+x[1]]=(oi,m); x=rot(x,n,cw)
    assert len(orb)==n*n
    no=len(reps)
    # label(cell)=(m - r[oi])%4
    cons=[]
    for p,q in pairs:
        cons.append(('eq',p,q))
        for c in range(p+1,q):
            cons.append(('ne',c,p))
    best=[0,None]
    r=[None]*no
    def lab(c):
        oi,m=orb[c]
        return None if r[oi] is None else (m-r[oi])%4
    def ok():
        bad=0
        for t,a,b in cons:
            la,lb=lab(a),lab(b)
            if la is None or lb is None: continue
            if (t=='eq')!=(la==lb): bad+=1
        return bad
    # count violations minimal via greedy search over all orbits (backtracking with bound)
    order=list(range(no))
    sol=[None,10**9]
    def bt(idx):
        v=ok()
        if v>=sol[1]: return
        if idx==no:
            sol[0]=r[:]; sol[1]=v; return
        for val in range(4):
            r[order[idx]]=val
            bt(idx+1)
        r[order[idx]]=None
    sys.setrecursionlimit(100000)
    bt(0)
    return sol[1],len(cons),len(pairs)
for k in sys.argv[1:]:
    for cw in (True,False):
        print(k,cw,test(k,cw))
