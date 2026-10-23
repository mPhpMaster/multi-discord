# Prints the useful part of a macOS crash report (.ips) - used by the macOS window test
import json
import sys

raw = open(sys.argv[1]).read()
body = raw.split('\n', 1)[1]
d = json.loads(body)
print(d.get('exception'), d.get('termination', {}).get('indicator'))
for k in ('asi', 'lastExceptionBacktrace'):
    if k in d:
        print(k, json.dumps(d[k])[:3000])
imgs = d.get('usedImages', [])
threads = [t for t in d.get('threads', []) if t.get('triggered')]
for fr in (threads[0]['frames'] if threads else [])[:30]:
    i = fr.get('imageIndex')
    img = imgs[i] if i is not None and i < len(imgs) else {}
    print(img.get('name', '?'), fr.get('symbol', ''), fr.get('symbolLocation', ''))
