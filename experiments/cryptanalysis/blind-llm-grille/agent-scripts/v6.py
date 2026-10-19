from v4 import *
if __name__=='__main__':
    k=sys.argv[1]; R=int(sys.argv[2]); it=int(sys.argv[3])
    res=[opt(k,it,s) for s in range(R)]
    res.sort(key=lambda t:-t[0])
    print(k,[x[0] for x in res])
    for bs,br,parts in res[:2]:
        print(' score',bs,'r=',br)
        for st in range(4):
            vals=sum(parts[st:]+parts[:st],[])
            print('   start',st,'|'+dp(vals,SS)[1]+'|')
