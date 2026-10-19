from match import *
import sys,itertools
S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
def rot(c,n,cw):
    i,j=c
    return (j,n-1-i) if cw else (n-1-j,i)
def orbmap(n,cw,flip=None):
    orb={}
    reps=[(i,j) for i in range(n//2) for j in range(n//2)]
    for oi,c in enumerate(reps):
        x=c
        for m in range(4):
            orb[x[0]*n+x[1]]=(oi,m); x=rot(x,n,cw)
    return orb,len(reps)
def check(pairs,orb,no):
    par=list(range(no)); off=[0]*no
    def find(x):
        if par[x]==x: return x,0
        r,o=find(par[x]); par[x]=r; off[x]=(off[x]+o)%4; return r,off[x]
    conf=0; cyc=0
    for p,q in pairs:
        (op,mp),(oq,mq)=orb[p],orb[q]
        # r_oq = r_op + mq - mp
        d=(mq-mp)%4
        rp,xp=find(op); rq,xq=find(oq)   # r_op = r_rp + xp
        if rp==rq:
            cyc+=1
            if (xq-xp)%4!=d: conf+=1
        else:
            par[rq]=rp; off[rq]=(xp+d-xq)%4
    return conf,cyc
for k in sorted(G):
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    big=[p for p in pairs if seq[p[0]]+seq[p[1]]>=1000]
    for cw in (True,False):
        orb,no=orbmap(n,cw)
        print(k,cw,'all',check(pairs,orb,no),'big',check(big,orb,no))
