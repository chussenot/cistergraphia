from match import *
import sys
S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
def rot(c,n,cw):
    i,j=c
    return (j,n-1-i) if cw else (n-1-j,i)
def run(k,cw,minsum=0):
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    pairs=[p for p in pairs if seq[p[0]]+seq[p[1]]>=minsum]
    orb={}
    reps=[(i,j) for i in range(n//2) for j in range(n//2)]
    for oi,c in enumerate(reps):
        x=c
        for m in range(4):
            orb[x[0]*n+x[1]]=(oi,m); x=rot(x,n,cw)
    cons=[]
    for a,(p,q) in enumerate(pairs):
        cons.append(('eq',p,q))
        for (p2,q2) in pairs[a+1:]:
            if not (q<p2 or q2<p):  # overlap
                cons.append(('ne',p,p2))
    # constraints in terms of orbits
    no=len(reps)
    r=[None]*no
    def lab(c):
        oi,m=orb[c]; return None if r[oi] is None else (m-r[oi])%4
    # order orbits by first appearance
    best=[10**9,None]
    import itertools
    involved={}
    for t,a,b in cons:
        for c in (a,b): involved.setdefault(orb[c][0],[]).append((t,a,b))
    order=sorted(range(no),key=lambda o:-len(involved.get(o,[])))
    assigned=set()
    def viol_new(o):
        v=0
        for t,a,b in involved.get(o,[]):
            la,lb=lab(a),lab(b)
            if la is None or lb is None: continue
            # count once: only if the other orbit already assigned (both now assigned)
            if (t=='eq')!=(la==lb): v+=1
        return v
    sys.setrecursionlimit(10000)
    def bt(i,v):
        if v>=best[0]: return
        if i==no:
            best[0]=v; best[1]=r[:]; return
        o=order[i]
        for val in range(4):
            r[o]=val
            dv=viol_new(o)
            bt(i+1,v+dv)
        r[o]=None
    bt(0,0)
    return best[0],len(cons)
for k in sys.argv[1:]:
    for cw in (True,False):
        print(k,cw,run(k,cw))
