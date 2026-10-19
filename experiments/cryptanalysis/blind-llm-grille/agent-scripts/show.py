from match import *
S={v:1 for v in [10,40,50,80,90,120,140,150,160,190,1000,2000,3000,4000,5000,7000,9000]}
M={10:'a',40:'d',50:'e',80:'h',90:'i',120:'l',140:'n',150:'o',160:'p',190:'s',9000:'_',2000:'T',1000:'U',3000:'V',4000:'W',5000:'X',7000:'Y'}
for k in sorted(G):
    g=G[k]; seq=[v for r in g for v in r]
    sc,pairs=solve(seq,S)
    a=''.join(M[seq[i]+seq[j]] for i,j in sorted(pairs))
    b=''.join(M[seq[i]+seq[j]] for i,j in sorted(pairs,key=lambda p:p[1]))
    c=''.join(M[seq[i]+seq[j]] for i,j in sorted(pairs,key=lambda p:p[0]+p[1]))
    print(k); print('  first:',a); print('  second:',b); print('  mid:',c)
