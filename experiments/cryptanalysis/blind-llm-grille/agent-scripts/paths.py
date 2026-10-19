import re,glob,os
from parse import *
def pinfo(d):
    subs=d.split('Z')[:2]
    pts=[[tuple(map(float,p.split())) for p in re.findall(r'[ML]([\d.]+ [\d.]+)',s)] for s in subs]
    head=pts[0]; shaft=pts[1]
    a,b,c=shaft
    start=((a[0]+c[0])/2,(a[1]+c[1])/2)
    return start,b,head
if __name__=='__main__':
    for fn in sorted(glob.glob(D+'/*.svg')):
        W,lines,paths=load(fn)
        same=rev=bad=0
        for l,p in zip(lines,paths):
            s,e,h=pinfo(p)
            x1,y1,x2,y2=l
            d1=abs(s[0]-x1)+abs(s[1]-y1)+abs(e[0]-x2)+abs(e[1]-y2)
            d2=abs(s[0]-x2)+abs(s[1]-y2)+abs(e[0]-x1)+abs(e[1]-y1)
            if d1<25: same+=1
            elif d2<25: rev+=1
            else: bad+=1
        print(os.path.basename(fn),same,rev,bad)
