import json,random,itertools
from collections import Counter
G=json.load(open('grids.json'))
W=8
def count(seq,targets):
    n=len(seq);c=Counter()
    for i in range(n):
        for j in range(i+1,min(n,i+W)):
            for l in range(j+1,min(n,i+W)):
                s=seq[i]+seq[j]+seq[l]
                if s in targets: c[s]+=1
    return c
T={9000,2000,1000,3000,5000,190,150,50,10,40,4000,6000,7000,8000,100,200,300,500,900}
obs=Counter();base=Counter()
for k,g in G.items():
    seq=[v for r in g for v in r]
    obs+=count(seq,T)
    for _ in range(5):
        s=seq[:];random.shuffle(s);c=count(s,T)
        for x in c: base[x]+=c[x]/5
for t in sorted(T): print(t,obs[t],round(base[t],1))
