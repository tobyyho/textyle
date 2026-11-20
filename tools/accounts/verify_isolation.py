"""Run against two confirmed test accounts after applying database/setup.sql.

Tests use reserved isolation_test records and a uniquely named temporary asset.
Passwords/tokens are never printed or saved. The test does not create accounts
or touch inventory/outfit records.
"""
import getpass,json,sys,uuid
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request,urlopen
root=Path(__file__).resolve().parents[2]
config=json.loads((root/'config/cloud.local.json').read_text())
base=config['SUPABASE_URL'].rstrip('/');key=config['SUPABASE_PUBLISHABLE_KEY']

def call(path,token=None,method='GET',data=None,binary=False):
    headers={'apikey':key}
    if token:headers['Authorization']='Bearer '+token
    if data is not None:
        headers['Content-Type']='application/octet-stream' if binary else 'application/json'
        payload=data if binary else json.dumps(data).encode()
    else:payload=None
    try:
        with urlopen(Request(base+path,data=payload,headers=headers,method=method),timeout=45) as r:
            raw=r.read();status=r.status
    except HTTPError as e:status=e.code;raw=e.read()
    if not binary:
        try:raw=json.loads(raw) if raw else None
        except ValueError:pass
    return status,raw

def sign_in(label):
    email=input(f'{label} test-account email: ').strip();password=getpass.getpass(f'{label} password: ')
    status,value=call('/auth/v1/token?grant_type=password',method='POST',data={'email':email,'password':password})
    if status!=200:raise SystemExit('Test-account sign-in failed. Check email confirmation and credentials.')
    return value['user']['id'],value['access_token']

def require(condition,message):
    if not condition:raise AssertionError(message)
    print('PASS:',message)

a,at=sign_in('A');b,bt=sign_in('B')
if a==b:raise SystemExit('Use two different test accounts.')
nonce=uuid.uuid4().hex;object_path=f'{a}/isolation-test/{nonce}.bin';uploaded=False
try:
    for uid,token in [(a,at),(b,bt)]:
        status,_=call(f'/rest/v1/textyle_documents?user_id=eq.{uid}&kind=eq.isolation_test',token,method='DELETE')
        require(status in (200,204),'Test fixture cleanup is owner-authorized')
    status,revision=call('/rest/v1/rpc/textyle_write_document',at,method='POST',
        data={'p_kind':'isolation_test','p_payload':{'nonce':nonce},'p_expected_revision':0})
    require(status==200 and revision==1,'Owner can write a document')
    status,value=call(f'/rest/v1/textyle_documents?user_id=eq.{a}&kind=eq.isolation_test',bt)
    require(status==200 and value==[],'Account B cannot read account A records')
    status,_=call('/rest/v1/textyle_documents',at,method='POST',
        data={'user_id':b,'kind':'isolation_test','payload':{'forged':True},'revision':1})
    require(status in (401,403),'Forged owner ID is rejected')
    selector=f'/rest/v1/textyle_documents?user_id=eq.{a}&kind=eq.isolation_test'
    status,_=call(selector,bt,method='PATCH',data={'payload':{'tampered':True}})
    require(status in (200,204,401,403),'Cross-account update is filtered or rejected')
    status,_=call(selector,bt,method='DELETE')
    require(status in (200,204,401,403),'Cross-account delete is filtered or rejected')
    status,value=call(selector,at)
    require(status==200 and len(value)==1 and value[0]['payload']=={'nonce':nonce},'Owner record survives attempted cross-account changes')
    status,_=call('/rest/v1/rpc/textyle_write_document',at,method='POST',
        data={'p_kind':'isolation_test','p_payload':{'stale':True},'p_expected_revision':0})
    require(status==409,'Stale device revision cannot overwrite saved data')
    status,value=call('/rest/v1/textyle_documents?kind=eq.isolation_test')
    require(status in (401,403) or status==200 and value==[],'Anonymous reads expose no account records')
    status,_=call('/storage/v1/object/textyle-private-media/'+quote(object_path,safe='/'),at,
        method='POST',data=b'textyle-isolation-test',binary=True)
    require(status in (200,201),'Owner can upload a private asset');uploaded=True
    path='/storage/v1/object/authenticated/textyle-private-media/'+quote(object_path,safe='/')
    status,raw=call(path,at,binary=True)
    require(status==200 and raw==b'textyle-isolation-test','Owner can download their asset')
    status,_=call(path,bt,binary=True)
    require(status in (400,401,403,404),'Account B cannot download account A asset')
    status,_=call(path,binary=True)
    require(status in (400,401,403,404),'Anonymous requests cannot download private assets')
    public='/storage/v1/object/public/textyle-private-media/'+quote(object_path,safe='/')
    status,_=call(public,binary=True)
    require(status in (400,401,403,404),'Bucket does not serve assets through public URLs')
    print('Account isolation checks passed.')
finally:
    for uid,token in [(a,at),(b,bt)]:
        call(f'/rest/v1/textyle_documents?user_id=eq.{uid}&kind=eq.isolation_test',token,method='DELETE')
    if uploaded:
        call('/storage/v1/object/textyle-private-media',at,method='DELETE',data={'prefixes':[object_path]})
