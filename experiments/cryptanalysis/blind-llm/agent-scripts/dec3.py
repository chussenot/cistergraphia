import json,string
S=json.load(open('/tmp/claude-0/attack-work/spiral.json'))
M={}
L=string.ascii_uppercase
for i in range(9): M[(i+1)*10]=L[i]          # A..I = 10..90
M[100]='J'
for i,c in enumerate('KLMNOP'): M[110+10*i]=c
M[180]='Q'; M[190]='R'
for i in range(8): M[1000*(i+1)]=L[18+i]     # S..Z
M[9000]=' '
for fn,s in sorted(S.items()):
    out=''; raw=[]
    for i in range(0,len(s)-1,2):
        a,b=s[i],s[i+1]
        if b==9999: out+='·'; continue
        out+=M.get(a+b,'[%d]'%(a+b))
    print(fn,out.replace('·',''),'   |',out)
