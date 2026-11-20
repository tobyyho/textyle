"""Save the public app configuration locally; never use a service-role key."""
import base64
import json
from pathlib import Path
from urllib.parse import urlsplit

root=Path(__file__).resolve().parents[2]
url=input('Supabase Project URL: ').strip().rstrip('/')
key=input('Supabase publishable (or legacy anon) key: ').strip()
redirect=input('App URL [http://localhost:7357]: ').strip() or 'http://localhost:7357'
uri=urlsplit(url)
if uri.scheme!='https' or not uri.netloc or uri.username or uri.query or uri.fragment:
    raise SystemExit('Use your HTTPS Supabase Project URL.')
valid=key.startswith('sb_publishable_')
if not valid:
    try:
        value=key.split('.')[1];payload=json.loads(base64.urlsafe_b64decode(value+'='*(-len(value)%4)))
        valid=payload.get('role')=='anon'
    except Exception:pass
if not valid:raise SystemExit('Use a publishable/anon key. Secret and service-role keys must never go in the app.')
app=urlsplit(redirect)
if not app.netloc or app.username or app.query or app.fragment or not (
    app.scheme=='https' or app.scheme=='http' and app.hostname in ('localhost','127.0.0.1')):
    raise SystemExit('Use an HTTPS app URL, or localhost for development.')
config=root/'config/cloud.local.json';config.parent.mkdir(parents=True,exist_ok=True)
config.write_text(json.dumps({'SUPABASE_URL':url,'SUPABASE_PUBLISHABLE_KEY':key,'APP_URL':redirect},indent=2))
print('Configuration saved. Run: python3.12 tools/accounts/run_cloud.py')
