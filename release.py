
from json import loads
from subprocess import call, check_output
import re
import os

os.remove('dub.selections.json')

ws_search = check_output(['dub', 'search', 'ws']).decode('utf-8')
ws_dep = re.search(r'ws \(([0-9\.]+)\)', ws_search).group(1)

with open('dub.json') as f:
    json = loads(f.read())
if not ws_dep:
    ws_dep = json['dependencies']['ws']
else:
    if ws_dep != json['dependencies']['ws']:
        raise Exception('dependency ws %s does not match remote %s' % (json['dependencies']['ws'], ws_dep))

result = call(['dub', 'build'])
if result:
    raise Exception(2)

print('Everything looks a-ok')
