import json,sys
from functools import lru_cache
G=json.load(open('grids.json'))
def solve(seq,S,W=16):
    n=len(seq)
    sys.setrecursionlimit(10000)
    @lru_cache(maxsize=None)
    def f(i,mask):
        # mask: bit t means cell i+t used
        if i>=n: return (0,())
        if mask&1: return f(i+1,mask>>1)
        best=f(i+1,mask>>1)  # leave unmatched
        best=(best[0],best[1])
        for t in range(1,W+1):
            j=i+t
            if j>=n: break
            if mask>>t &1: continue
            s=seq[i]+seq[j]
            if s in S:
                r=f(i+1,(mask|(1<<t))>>1)
                if r[0]+S[s]>best[0]: best=(r[0]+S[s],((i,j),)+r[1])
        return best
    return f(0,0)
if __name__=='__main__':
    S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
    for k in sys.argv[1:]:
        g=G[k]; seq=[v for r in g for v in r]
        sc,pairs=solve(seq,S)
        used=set(x for p in pairs for x in p)
        print(k,sc,'unmatched',[ (i,seq[i]) for i in range(len(seq)) if i not in used])
        print(' ',[(i,j,seq[i]+seq[j]) for i,j in pairs])
