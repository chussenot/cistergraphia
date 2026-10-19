from ils import *
if __name__=='__main__':
    k=sys.argv[1]; r0=json.loads(sys.argv[2]); seed=int(sys.argv[3])
    rnd=random.Random(seed)
    if seed>0:
        r0=[x if rnd.random()<0.6 else rnd.randrange(4) for x in r0]
    (sc,r),txt=ils(k,r0,25,seed)
    print(k,seed,sc,r); print('|'+txt+'|')
