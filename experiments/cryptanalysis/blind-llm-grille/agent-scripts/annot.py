from anneal2 import *
def annot(vals,Sx):
    out=[];t=0
    while t<len(vals):
        if t+1<len(vals) and vals[t]+vals[t+1] in Sx:
            s=vals[t]+vals[t+1]; out.append('%s(%d+%d)'%(M.get(s,'['+str(s)+']'),vals[t],vals[t+1])); t+=2
        else:
            out.append('<%d>'%vals[t]); t+=1
    return ' '.join(out)
if __name__=='__main__':
    for k in sys.argv[1:]:
        bs,br,vals=optimize(k,iters=1)
        print(k,annot(vals,Sx))
