import json,sys
G=json.load(open('/tmp/claude-0/attack-work/grids.json'))
def spiral(g):
    n=len(g); res=[]; t,b,l,r=0,n-1,0,n-1
    while t<=b and l<=r:
        for c in range(l,r+1): res.append(g[t][c])
        for rr in range(t+1,b+1): res.append(g[rr][r])
        if t<b:
            for c in range(r-1,l-1,-1): res.append(g[b][c])
        if l<r:
            for rr in range(b-1,t,-1): res.append(g[rr][l])
        t+=1;b-=1;l+=1;r-=1
    return res
S={}
for fn,g in sorted(G.items()):
    n=sum(1 for row in g if any(v!='0000' for v in row)); n=max(n, max(i+1 for row in g for i,v in enumerate(row) if v!='0000'))
    g=[row[:n] for row in g[:n]]
    s=[int(v) for v in spiral(g)]
    S[fn]=s
    print(fn,len(s),s)
json.dump(S,open('/tmp/claude-0/attack-work/spiral.json','w'))
