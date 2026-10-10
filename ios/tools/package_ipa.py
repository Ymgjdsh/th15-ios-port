"""Validate an ARM64 iOS 14 bundle and produce an ad-hoc signed private IPA."""
import argparse,hashlib,json,plistlib,re,shutil,subprocess,tempfile,zipfile
from pathlib import Path
def run(*args):return subprocess.check_output(args,text=True,stderr=subprocess.STDOUT).strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
parser=argparse.ArgumentParser();parser.add_argument('app',type=Path);parser.add_argument('output',type=Path);args=parser.parse_args()
app=args.app.resolve();output=args.output.resolve();info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='org.th15.native'
assert info['MinimumOSVersion']=='14.0'
assert info['TH15Diagnostics']=='OFF'
exe=app/info['CFBundleExecutable'];assert exe.parent==app and exe.is_file()
assert run('xcrun','lipo','-archs',str(exe)).split()==['arm64']
assert b'REGRESSION PASS' not in exe.read_bytes()
assert b'--settings-smoke' not in exe.read_bytes()
assert b'--autobomb-checks' not in exe.read_bytes()
commands=run('xcrun','otool','-l',str(exe))
assert re.search(r'platform\s+(2|IOS)\b',commands)
assert re.search(r'minos\s+14\.0\b',commands)
assert not re.search(r'(WebKit|JavaScriptCore)\.framework',run('xcrun','otool','-L',str(exe)))
for key in ('CFBundleIcons','CFBundleIcons~ipad'):
 assert info[key]['CFBundlePrimaryIcon']['CFBundleIconName']=='AppIcon'
assert (app/'Assets.car').is_file()
for p in app.rglob('*'):
 assert p.suffix.lower() not in {'.exe','.dll','.wasm','.html','.js','.mjs','.rpy','.rpyx'},str(p)
 assert not (p.name.startswith('score') and p.suffix=='.dat'),str(p)
assets=app/'assets';manifest=json.loads((assets/'manifest.json').read_text(encoding='utf-8'))
actual={p.relative_to(assets).as_posix() for p in assets.rglob('*') if p.is_file() and p!=assets/'manifest.json'}
assert actual==set(manifest['files']),actual.symmetric_difference(manifest['files'])
required={'th15.dat','fonts/cp932.bin','fonts/blend4444.bin'}|{'fonts/font%d.bin'%i for i in range(13)}
assert required<=actual
music=json.loads((assets/'music/manifest.json').read_text(encoding='utf-8'));assert len(music['tracks'])==18
for t in music['tracks']:assert 'music/'+Path(t['filename']).stem+'.ogg' in actual
for name,record in manifest['files'].items():
 p=assets/name;assert {'bytes':p.stat().st_size,'sha256':sha(p)}==record,name
output.parent.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='th15-ipa-') as temp:
 staging=Path(temp);bundle=staging/'Payload/th15.app';bundle.parent.mkdir();shutil.copytree(app,bundle)
 run('/usr/bin/codesign','--force','--sign','-','--timestamp=none',str(bundle));run('/usr/bin/codesign','--verify','--strict',str(bundle))
 partial=staging/'TH15.ipa'
 with zipfile.ZipFile(partial,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
  for p in sorted(bundle.rglob('*')):
   if p.is_file():archive.write(p,p.relative_to(staging).as_posix())
 with zipfile.ZipFile(partial) as archive:assert archive.testzip() is None
 signed_exe_sha=sha(bundle/info['CFBundleExecutable']);shutil.copyfile(partial,output)
report={'artifact':output.name,'sha256':sha(output),'bytes':output.stat().st_size,'bundleIdentifier':info['CFBundleIdentifier'],'version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],'minimumIOS':'14.0','architecture':'arm64','platform':'iphoneos','signature':'ad-hoc; intended for TrollStore or re-signing with the user Apple provisioning profile','executableSHA256':signed_exe_sha,'scriptedInputs':False,'language':'Original Japanese 1.00b game assets; Chinese native settings','features':['touch drag with configurable original speed cap','analog joystick with captured outside tracking and configurable dead zone','Z/X/S controls with optional Z and S toggle', 'automatic Bomb using original collision and stock rules', 'draggable per-orientation control layouts with save/reset/cancel', 'No Button mode with menu controls preserved','double-tap bomb','two-finger slow','settings persistence','portrait full-screen playfield and original HUD header','landscape full screen','optional developer floating panel with seven cheat actions','ymgjdsh permanent full unlock including Extra, practice and music','background and audio interruption suspension','sandbox score/replay/checkpoints','local diagnostic log export'],'scope':'Bundle, deployment target, resources, signatures and archive verified. iOS 14 physical-device performance and full-game acceptance require device testing.','assets':manifest['files']}
output.with_suffix('.manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:v for k,v in report.items() if k!='assets'},ensure_ascii=False,indent=2))
