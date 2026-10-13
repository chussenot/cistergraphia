import json,string
S=json.load(open('/tmp/claude-0/attack-work/spiral.json'))
M={}
L=string.ascii_uppercase
for i in range(9): M[(i+1)*10]=L[i]; M[110+i*10]=L[9+i]
for i in range(8): M[1000*(i+1)]=L[18+i]
M[9000]=' '
for fn,s in sorted(S.items()):
    out=''
    for i in range(0,len(s)-1,2):
        a,b=s[i],s[i+1]
        if b==9999 or a==9999: out+='_'; continue
        out+=M.get(a+b,'[%d]'%(a+b))
    print(fn,out)
