"""Independently verify a copied IPA against its delivery manifest."""
import argparse, hashlib, json, plistlib, struct, zipfile
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('ipa',type=Path)
parser.add_argument('manifest',type=Path)
args=parser.parse_args()
report=json.loads(args.manifest.read_text(encoding='utf-8'))
with args.ipa.open('rb') as stream:
    digest=hashlib.sha256()
    for chunk in iter(lambda:stream.read(1024*1024),b''):digest.update(chunk)
assert digest.hexdigest()==report['sha256']
assert args.ipa.stat().st_size==report['bytes']
with zipfile.ZipFile(args.ipa) as archive:
    assert archive.testzip() is None
    root='Payload/th15.app/'
    info=plistlib.loads(archive.read(root+'Info.plist'))
    assert info['CFBundleVersion']==report['build']
    assert info['MinimumOSVersion']=='14.0' and info['TH15Diagnostics']=='OFF'
    assert info['CFBundleIdentifier']==report['bundleIdentifier']
    executable=archive.read(root+info['CFBundleExecutable'])
    assert hashlib.sha256(executable).hexdigest()==report['executableSHA256']
    magic,cpu,subtype,kind,count,size,flags,reserved=struct.unpack_from('<8I',executable)
    assert magic==0xfeedfacf and cpu==0x100000c and kind==2
    offset=32;deployment=False
    for _ in range(count):
        command,length=struct.unpack_from('<II',executable,offset)
        assert length>=8 and offset+length<=len(executable)
        if command==0x32:
            platform,minimum=struct.unpack_from('<II',executable,offset+8)
            assert platform==2 and minimum==0x000e0000
            deployment=True
        offset+=length
    assert deployment
    assert b'REGRESSION PASS' not in executable and b'--settings-smoke' not in executable
    for name,record in report['assets'].items():
        data=archive.read(root+'assets/'+name)
        assert len(data)==record['bytes'] and hashlib.sha256(data).hexdigest()==record['sha256'],name
print(json.dumps({'verified':True,'artifact':args.ipa.name,'build':report['build'],
                  'sha256':report['sha256'],'bytes':report['bytes'],
                  'minimumIOS':'14.0','architecture':'arm64','assets':len(report['assets'])},indent=2))
