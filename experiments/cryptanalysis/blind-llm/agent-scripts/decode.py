import re,sys,os,collections,json
B=sys.argv[1]
SEG={frozenset({(0,0),(1,0)}):1,frozenset({(0,1),(1,1)}):2,frozenset({(0,0),(1,1)}):3,frozenset({(0,1),(1,0)}):4,frozenset({(1,0),(1,1)}):6}
DIG={frozenset():0,frozenset({1}):1,frozenset({2}):2,frozenset({3}):3,frozenset({4}):4,frozenset({1,4}):5,frozenset({6}):6,frozenset({1,6}):7,frozenset({2,6}):8,frozenset({1,2,6}):9}
out={}
for i in range(1,11):
    fn='msg%02d.svg'%i
    s=open(os.path.join(B,fn)).read()
    W,H=map(int,re.search(r'width="(\d+)" height="(\d+)"',s).groups())
    L=[tuple(map(int,m)) for m in re.findall(r'x1="(-?\d+)" y1="(-?\d+)" x2="(-?\d+)" y2="(-?\d+)"',s)]
    n=(W-100)//120+1
    cells=collections.defaultdict(lambda: collections.defaultdict(set))
    bad=[]
    for (x1,y1,x2,y2) in L:
        if x1==x2 and abs(y2-y1)==150 and (x1-100)%120==0: continue
        xs=[x1,x2]; ys=[y1,y2]
        c=round((sum(xs)/2-100)/120); r=None
        x0=100+120*c
        r=int((min(ys)-50)//170); y0=50+170*r
        side='R' if max(xs)>x0 or (min(xs)==x0 and max(xs)>x0) else 'L'
        if all(x<=x0 for x in xs) and any(x<x0 for x in xs): side='L'
        top = max(ys)<=y0+50
        bot = min(ys)>=y0+100
        if not(top or bot): bad.append((x1,y1,x2,y2)); continue
        pts=frozenset(( abs(x-x0)//50, (y-y0)//50 if top else (y0+150-y)//50) for x,y in zip(xs,ys))
        q={('R',True):'u',('L',True):'t',('R',False):'h',('L',False):'k'}[(side,top)]
        if pts not in SEG: bad.append((x1,y1,x2,y2,'seg')); continue
        cells[(r,c)][q].add(SEG[pts])
    grid=[[None]*n for _ in range(n)]
    for r in range(n):
        for c in range(n):
            d=cells[(r,c)]
            v=[]
            for q in 'khtu':
                v.append(DIG.get(frozenset(d[q]),'?'))
            grid[r][c]=''.join(map(str,v))
    out[fn]=grid
    print(fn,'bad',bad)
    for row in grid: print(' '.join(row))
json.dump(out,open('/tmp/claude-0/attack-work/grids.json','w'))
