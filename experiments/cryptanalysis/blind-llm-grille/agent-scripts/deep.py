from ils import *
def anneal_dp(k,iters,seed,r0=None):
    ev,no=make_ev(k); rnd=random.Random(seed)
    r=r0[:] if r0 else [rnd.randrange(4) for _ in range(no)]
    cur=ev(r)[0]; bs,br=cur,r[:]; T=2.0
    for it in range(iters):
        o=rnd.randrange(no); old=r[o]; r[o]=(old+rnd.randrange(1,4))%4
        s=ev(r)[0]
        if s>=cur or rnd.random()<math.exp((s-cur)/T): cur=s
        else: r[o]=old
        T=max(0.05,T*0.99985)
        if cur>bs: bs,br=cur,r[:]
    return bs,br
if __name__=='__main__':
    k=sys.argv[1]; seed=int(sys.argv[2])
    bs,br=anneal_dp(k,40000,seed)
    (sc,r),txt=ils(k,br,8,seed)
    print(k,seed,sc,r); print('|'+txt+'|')
