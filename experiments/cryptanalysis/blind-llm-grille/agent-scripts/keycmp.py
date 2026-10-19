from v4 import *
import json
out={}
for k in sys.argv[1:]:
    bs,br,parts=opt(k,8000,0)
    out[k]=(bs,br)
    print(k,bs,br,flush=True)
json.dump(out,open('keys_%s.json'%'_'.join(sys.argv[1:]),'w'))
