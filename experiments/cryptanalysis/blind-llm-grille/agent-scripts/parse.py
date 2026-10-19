import re,sys,glob,os
D='/tmp/claude-0/-home-user-cistergraphia/b3a61d06-86b2-58b0-9e26-b55ab4b93334/scratchpad/blind-grille'
def load(fn):
    s=open(fn).read()
    W=int(re.search(r'width="(\d+)"',s).group(1))
    lines=[tuple(map(int,m)) for m in re.findall(r'<line x1="(\d+)" y1="(\d+)" x2="(\d+)" y2="(\d+)"/>',s)]
    paths=re.findall(r'<path d="([^"]+)"/>',s)
    return W,lines,paths
def glyphs(lines):
    # group by stems: vertical lines of length 150
    stems=[(x1,y1) for (x1,y1,x2,y2) in lines if x1==x2 and abs(y2-y1)==150]
    out={}
    for sx,sy in stems:
        out[(sx,sy)]=[]
    for l in lines:
        x1,y1,x2,y2=l
        if x1==x2 and abs(y2-y1)==150: continue
        # find stem
        best=None
        for sx,sy in stems:
            if all(sx-60<=x<=sx+60 and sy-5<=y<=sy+155 for x,y in [(x1,y1),(x2,y2)]):
                best=(sx,sy)
        out[best].append(l)
    return out
def seg_digit(sx,sy,l):
    x1,y1,x2,y2=l
    pts=sorted([(x1-sx,y1-sy),(x2-sx,y2-sy)])
    # determine quadrant
    xs=[p[0] for p in pts]; ys=[p[1] for p in pts]
    side = 1 if max(xs)>0 else -1
    top = max(ys)<=50
    # normalize to upper-right frame: x'=x*side, y'= y if top else 150-y
    q=tuple(sorted((x*side, y if top else 150-y) for x,y in pts))
    stroke={((0,0),(50,0)):'1',((0,50),(50,50)):'2',((0,0),(50,50)):'3',((0,50),(50,0)):'4',((50,0),(50,50)):'6'}[q]
    quad={(1,True):0,(-1,True):1,(1,False):2,(-1,False):3}[(side,top)]
    return quad,stroke
COMB={'':0,'1':1,'2':2,'3':3,'4':4,'14':5,'6':6,'16':7,'26':8,'126':9}
def value(sx,sy,ls):
    q=[[],[],[],[]]
    for l in ls:
        a,b=seg_digit(sx,sy,l); q[a].append(b)
    d=[COMB[''.join(sorted(x))] for x in q]
    return d[0]+10*d[1]+100*d[2]+1000*d[3], q
if __name__=='__main__':
    for fn in sorted(glob.glob(D+'/*.svg')):
        W,lines,paths=load(fn)
        g=glyphs(lines)
        print(os.path.basename(fn),W,len(lines),len(paths),len(g))
        n=(W-100)//170
        grid=[['    .']*n for _ in range(n)]
        for (sx,sy),ls in sorted(g.items(),key=lambda t:(t[0][1],t[0][0])):
            v,_=value(sx,sy,ls)
            c=(sx-135)//170; r=(sy-60)//170
            grid[r][c]='%5d'%v
        for row in grid: print(''.join(row))
