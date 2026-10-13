import re,sys,os,collections
B=sys.argv[1]
def load(fn):
    s=open(os.path.join(B,fn)).read()
    W,H=map(int,re.search(r'width="(\d+)" height="(\d+)"',s).groups())
    L=[tuple(map(int,m)) for m in re.findall(r'x1="(-?\d+)" y1="(-?\d+)" x2="(-?\d+)" y2="(-?\d+)"',s)]
    return W,H,L
for i in range(1,11):
    fn='msg%02d.svg'%i
    W,H,L=load(fn)
    stems=[l for l in L if l[0]==l[2] and abs(l[3]-l[1])==150]
    xs=sorted(set(l[0] for l in L)); ys=sorted(set(l[1] for l in L)|set(l[3] for l in L))
    print(fn,W,H,len(L),'stems',len(stems), 'stemxs',sorted(set(s[0] for s in stems)),'stemys',sorted(set(min(s[1],s[3]) for s in stems)))
