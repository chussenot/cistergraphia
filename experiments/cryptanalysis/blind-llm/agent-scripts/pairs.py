import json,collections
S=json.load(open('/tmp/claude-0/attack-work/spiral.json'))
C=collections.Counter()
for fn,s in sorted(S.items()):
    P=[(s[i],s[i+1]) for i in range(0,len(s)-1,2)]
    print(fn,' '.join(('%d+%d'%p if 9999 in p else str(p[0]+p[1])) for p in P))
    for p in P:
        if 9999 not in p: C[p[0]+p[1]]+=1
print(sorted(C.items()))
