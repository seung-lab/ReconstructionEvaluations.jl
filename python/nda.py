import json
from urllib.request import Request, urlopen
from datajoint import blob
from collections import OrderedDict

def request(path, api_key):
    req = Request('https://nda.seunglab.org/' + path)
    req.add_header('Authorization', api_key)

    res = urlopen(req)

    if (res.info().get_content_type() == 'application/json'):
        res2 = res.read()
        return json.loads(res2.decode(res.info().get_param('charset') or 'utf-8'), object_pairs_hook=OrderedDict)
    else:
        return blob.unpack(res.read())
