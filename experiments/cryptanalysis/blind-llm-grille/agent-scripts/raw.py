from decode import *
k=sys.argv[1]; offs=tuple(map(int,sys.argv[2].split(','))) if sys.argv[2] else (); start=int(sys.argv[3])
g=G[k]; n=len(g); seq=[v for r in g for v in r]
sc,pairs=solve(seq,S)
orb,no=orbmap(n,True)
c=comps(pairs,orb,no)
roots=sorted(set(r for r,x in c.values()))
od=dict(zip(roots,(0,)+offs))
r=[(c[o][1]+od[c[o][0]])%4 for o in range(no)]
st=streams(seq,n,orb,no,r,start)
vals=[seq[x] for x in st]
print(vals)
out=[]
for t in range(0,len(vals)-1,2):
    s=vals[t]+vals[t+1]; out.append(M.get(s,str(s)))
print(' '.join(out))
