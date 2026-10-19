import v2, greedy, decode, solve10, uf, match, sys, itertools, random, math
from v2 import *
L={10:'a',20:'b',30:'c',40:'d',50:'e',60:'f',70:'g',80:'h',90:'i',100:'j',110:'k',120:'l',130:'m',140:'n',150:'o',160:'p',170:'q',180:'Q',190:'r',1000:'s',2000:'t',3000:'u',4000:'v',5000:'w',6000:'x',7000:'y',8000:'z',9000:' '}
for d in (M,): d.clear(); d.update(L)
SS=set(L)
def run(k,iters=20000):
    bs,br,vals=optimize2(k,iters=iters,Sset=SS)
    return bs,vals
if __name__=='__main__':
    for k in sys.argv[1:]:
        bs,vals=run(k)
        print(k,bs,'|'+greedy(vals,SS)+'|')
