#!/usr/bin/env python3
"""Generate HS256 tokens using stdlib; staging secret is entered without echo."""
import base64, getpass, hashlib, hmac, json, pathlib, time
p=pathlib.Path(__file__).resolve().parent.parent/'config'
users=json.loads((p/'users.json').read_text())
secret_text=getpass.getpass('Staging JWT_SECRET (base64, hidden): ').strip()
try:
    secret=base64.b64decode(secret_text,validate=True)
except Exception as e:
    raise SystemExit(f'Invalid base64 JWT_SECRET: {e}')
if len(secret)<16: raise SystemExit('JWT secret unexpectedly short; verify the Staging value.')
def b64url(x): return base64.urlsafe_b64encode(x).rstrip(b'=').decode()
now=int(time.time())
header=b64url(json.dumps({'alg':'HS256','typ':'JWT'},separators=(',',':')).encode())
for user in users:
    payload=b64url(json.dumps({'userId':user['userId'],'iat':now,'exp':now+3*3600},separators=(',',':')).encode())
    signing=f'{header}.{payload}'.encode()
    user['accessToken']=f'{header}.{payload}.{b64url(hmac.new(secret,signing,hashlib.sha256).digest())}'
out=p/'users.json'
out.write_text(json.dumps(users,ensure_ascii=False,indent=2))
out.chmod(0o600)
print(f'Generated {len(users)} JWTs (3-hour validity). Secret was not saved.')
