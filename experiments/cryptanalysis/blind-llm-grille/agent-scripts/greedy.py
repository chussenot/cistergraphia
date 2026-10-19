from decode import *
def greedy(vals,Sx):
    out=[];t=0
    while t<len(vals):
        if t+1<len(vals) and vals[t]+vals[t+1] in Sx:
            s=vals[t]+vals[t+1]; out.append(M.get(s,'['+str(s)+']')); t+=2
        else:
            out.append('.' if vals[t]!=9999 else '#'); t+=1
    return ''.join(out)
Sx=set(range(10,300,10))|set(range(1000,10000,1000))
def allstreams(k):
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    orb,no=orbmap(n,True)
    c=comps(pairs,orb,no)
    roots=sorted(set(r for r,x in c.values()))
    res=[]
    for offs in itertools.product(range(4),repeat=len(roots)-1):
        od=dict(zip(roots,(0,)+offs))
        r=[(c[o][1]+od[c[o][0]])%4 for o in range(no)]
        st=streams(seq,n,orb,no,r,0)
        vals=[seq[x] for x in st]
        txt=greedy(vals,set(S))
        res.append((sum(ch.isalpha() or ch=='_' for ch in txt),offs,greedy(vals,Sx)))
    res.sort(key=lambda t:-t[0])
    return res,len(roots)
if __name__=='__main__':
    for k in sys.argv[1:]:
        res,nr=allstreams(k)
        print(k,'components',nr)
        for r in res[:4]: print('  ',r)
