from parse import *
import json
def grids():
    R={}
    for fn in sorted(glob.glob(D+'/*.svg')):
        W,lines,paths=load(fn)
        g=glyphs(lines); n=(W-100)//170
        grid=[[None]*n for _ in range(n)]
        for (sx,sy),ls in g.items():
            v,_=value(sx,sy,ls)
            grid[(sy-60)//170][(sx-135)//170]=v
        R[os.path.basename(fn)[:5]]=grid
    return R
if __name__=='__main__':
    json.dump(grids(),open('grids.json','w'))
