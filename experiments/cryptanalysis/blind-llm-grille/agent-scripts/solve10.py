from uf import *
M={10:'a',40:'d',50:'e',80:'h',90:'i',120:'l',140:'n',150:'o',160:'p',190:'s',9000:'_',2000:'T',1000:'R',3000:'U',4000:'V',5000:'W',7000:'Y'}
def comps(pairs,orb,no):
    par=list(range(no)); off=[0]*no
    def find(x):
        if par[x]==x: return x,0
        r,o=find(par[x]); par[x]=r; off[x]=(off[x]+o)%4; return r,off[x]
    for p,q in pairs:
        (op,mp),(oq,mq)=orb[p],orb[q]
        d=(mq-mp)%4
        rp,xp=find(op); rq,xq=find(oq)
        if rp!=rq: par[rq]=rp; off[rq]=(xp+d-xq)%4
    res={}
    for o in range(no):
        r,x=find(o); res[o]=(r,x)
    return res
if __name__=='__main__':
    k=sys.argv[1]
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    orb,no=orbmap(n,True)
    c=comps(pairs,orb,no)
    roots=sorted(set(r for r,x in c.values()))
    print('components',len(roots),[sum(1 for o in c if c[o][0]==r) for r in roots])
    # label of each cell assuming root offset 0
    lab={}
    for cell,(oi,m) in orb.items():
        r,x=c[oi]; lab[cell]=(m-x)%4
    for i in range(n):
        print(' '.join('%5d %s%s'%(seq[i*n+j],lab[i*n+j],'*' if c[orb[i*n+j][0]][0]==roots[0] else ' ') for j in range(n)))
