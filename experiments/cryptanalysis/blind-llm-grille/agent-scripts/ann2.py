from ils import *
def annotate(k,r):
    g=G[k]; n=len(g); seq=[v for row in g for v in row]
    orb,no=orbmap(n,True)
    cells={}
    for cell,(oi,m) in orb.items(): cells.setdefault((m-r[oi])%4,[]).append(cell)
    parts=[[seq[x] for x in sorted(cells[Lp]) if seq[x]!=9999] for Lp in range(4)]
    best=None
    for st in range(4):
        vals=sum(parts[st:]+parts[:st],[])
        s,txt=dp(vals,SS); sc=s-0.25*txt.count('.')
        if best is None or sc>best[0]: best=(sc,vals)
    vals=best[1]
    n=len(vals); f=[0]*(n+2); ch=[None]*(n+2)
    for t in range(n-1,-1,-1):
        f[t]=f[t+1]; ch[t]=1
        if t+1<n and vals[t]+vals[t+1] in SS and f[t+2]+1>f[t]: f[t]=f[t+2]+1; ch[t]=2
    out=[];t=0
    while t<n:
        if ch[t]==2: out.append(L[vals[t]+vals[t+1]]); t+=2
        else: out.append('<%d>'%vals[t]); t+=1
    return ' '.join(out)
if __name__=='__main__':
    print(annotate(sys.argv[1],json.loads(sys.argv[2])))
