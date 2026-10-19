from solve10 import *
import itertools
def streams(seq,n,orb,no,r,start=0):
    cells={}
    for cell,(oi,m) in orb.items():
        cells.setdefault((m-r[oi])%4,[]).append(cell)
    st=[]
    for L in range(4):
        st+=sorted(cells[(L+start)%4])
    return st
def score_text(seq,st):
    sc=0; txt=[]
    for t in range(0,len(st)-1,2):
        s=seq[st[t]]+seq[st[t+1]]
        if s in S: sc+=1; txt.append(M[s])
        else: txt.append('?')
    return sc,''.join(txt)
def run(k,verbose=True):
    g=G[k]; n=len(g); seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    orb,no=orbmap(n,True)
    c=comps(pairs,orb,no)
    roots=sorted(set(r for r,x in c.values()))
    best=[]
    for offs in itertools.product(range(4),repeat=len(roots)-1):
        od=dict(zip(roots,(0,)+offs))
        r=[(c[o][1]+od[c[o][0]])%4 for o in range(no)]
        for start in range(4):
            st=streams(seq,n,orb,no,r,start)
            s,txt=score_text(seq,st)
            best.append((s,txt,offs,start))
    best.sort(key=lambda t:-t[0])
    return best
if __name__=='__main__':
    for k in sys.argv[1:]:
        b=run(k)
        print(k,len(b))
        for s,txt,offs,start in b[:6]: print('  ',s,offs,start,txt)
