from match import *
import sys
S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
M={10:'a',40:'d',50:'e',80:'h',90:'i',120:'l',140:'n',150:'o',160:'p',190:'s',9000:'_',2000:'T',1000:'R',3000:'U',4000:'V',5000:'W',7000:'Y'}
k=sys.argv[1]
g=G[k]; n=len(g); seq=[v for r in g for v in r]
sc,pairs=solve(seq,S)
lab={}
for idx,(i,j) in enumerate(sorted(pairs)):
    ch=M[seq[i]+seq[j]]
    lab[i]='%2d%s>'%(idx,ch); lab[j]='%2d%s<'%(idx,ch)
for r in range(n):
    print(' '.join('%5d %4s'%(seq[r*n+c],lab.get(r*n+c,'  ..')) for c in range(n)))
