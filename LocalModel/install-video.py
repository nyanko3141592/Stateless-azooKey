"""Install the recording-only presentation; leave the normal IME/demo apps unchanged."""
import argparse, plistlib, shutil, subprocess, tempfile
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('built_app',type=Path)
p.add_argument('--identity',default='-')
a=p.parse_args()
assert (a.built_app/'Contents/MacOS/azooKeyMac').is_file()
dst=Path.home()/'Applications/Stateless-azooKey Video.app'
if dst.exists():shutil.rmtree(dst)
shutil.copytree(a.built_app,dst,symlinks=True)
info=dst/'Contents/Info.plist';d=plistlib.loads(info.read_bytes())
d.update(CFBundleIdentifier='dev.naoki.StatelessAzooKeyVideo',CFBundleName='Stateless-azooKey Video',CFBundleDisplayName='Stateless-azooKey Video',StatelessDemoDefault=True,SegmentationVideoDefault=True,LSUIElement=False,LSBackgroundOnly=False)
for k in ['ComponentInputModeDict','InputMethodConnectionName','InputMethodServerControllerClass','tsInputMethodCharacterRepertoireKey']:d.pop(k,None)
info.write_bytes(plistlib.dumps(d))
(dst/'Contents/Resources/en.lproj/InfoPlist.strings').write_text('CFBundleDisplayName = "Stateless-azooKey Video";\nCFBundleName = "Stateless-azooKey Video";\n',encoding='utf-16')
with tempfile.NamedTemporaryFile(suffix='.plist') as tmp:
 Path(tmp.name).write_bytes(plistlib.dumps({'com.apple.security.app-sandbox':True}))
 subprocess.run(['codesign','--force','--deep','--timestamp=none','--sign',a.identity,'--entitlements',tmp.name,str(dst)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(dst)],check=True)
print(dst)
