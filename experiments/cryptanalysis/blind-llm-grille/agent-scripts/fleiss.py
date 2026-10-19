import json,random,sys,math
G=json.load(open('grids.json'))
S={10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000}
def rot(c,n,cw):
    i,j=c
    return (j,n-1-i) if cw else (n-1-j,i)
def run(k,cw,iters=20000,seed=0):
    g=G[k]; n=len(g)
    reps=[(i,j) for i in range(n//2) for j in range(n//2)]
    orbits=[]
    for c in reps:
        o=[c]
        for _ in range(3): o.append(rot(o[-1],n,cw))
        orbits.append(o)
    rnd=random.Random(seed)
    r=[rnd.randrange(4) for _ in orbits]
    def score(r):
        stream=[]
        for L in range(4):
            holes=sorted(o[(ro+L)%4] for o,ro in zip(orbits,r))
            stream+= [g[i][j] for i,j in holes]
        return sum(1 for t in range(0,len(stream)-1,2) if stream[t]+stream[t+1] in S),stream
    cur,_=score(r); best=cur; bestr=r[:]
    T=2.0
    for it in range(iters):
        o=rnd.randrange(len(r)); old=r[o]; r[o]=rnd.randrange(4)
        s,_=score(r)
        if s>=cur or rnd.random()<math.exp((s-cur)/T): cur=s
        else: r[o]=old
        T=max(0.05,T*0.9997)
        if cur>best: best=cur; bestr=r[:]
    return best,bestr,score(bestr)[1]
for k in sys.argv[1:]:
    for cw in (True,False):
        b,r,st=run(k,cw)
        print(k,cw,b,len(st)//2)
