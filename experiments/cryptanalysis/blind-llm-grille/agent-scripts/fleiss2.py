import json,random,sys,math
G=json.load(open('grids.json'))
S={10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000}
def rot(c,n,cw):
    i,j=c
    return (j,n-1-i) if cw else (n-1-j,i)
def setup(k,cw):
    g=G[k]; n=len(g)
    reps=[(i,j) for i in range(n//2) for j in range(n//2)]
    orbits=[]
    for c in reps:
        o=[c]
        for _ in range(3): o.append(rot(o[-1],n,cw))
        orbits.append(o)
    return g,n,orbits
def score(g,orbits,r):
    tot=0
    for L in range(4):
        holes=sorted(o[(ro+L)%4] for o,ro in zip(orbits,r))
        st=[g[i][j] for i,j in holes]
        # count within-pass pairs, allowing either parity (pass may start mid-pair)
        a=sum(1 for t in range(0,len(st)-1,2) if st[t]+st[t+1] in S)
        b=sum(1 for t in range(1,len(st)-1,2) if st[t]+st[t+1] in S)
        tot+=max(a,b)
    return tot
def anneal(k,cw,iters,seed):
    g,n,orbits=setup(k,cw)
    rnd=random.Random(seed)
    r=[rnd.randrange(4) for _ in orbits]
    cur=score(g,orbits,r); best=cur; br=r[:]
    T=3.0
    for it in range(iters):
        o=rnd.randrange(len(r)); old=r[o]; r[o]=(old+rnd.randrange(1,4))%4
        s=score(g,orbits,r)
        if s>=cur or rnd.random()<math.exp((s-cur)/T): cur=s
        else: r[o]=old
        T=max(0.1,T*0.9995)
        if cur>best: best=cur; br=r[:]
    return best,br
k=sys.argv[1]
for cw in (True,False):
    res=[anneal(k,cw,30000,s)[0] for s in range(4)]
    print(k,cw,res)
