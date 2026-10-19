from ils import *
if __name__=='__main__':
    k=sys.argv[1]
    bs,br,parts=opt(k,10000,0)
    (sc,r),txt=ils(k,br,10,0)
    print(k,sc,r); print('|'+txt+'|')
    import ann2; print(ann2.annotate(k,r))
