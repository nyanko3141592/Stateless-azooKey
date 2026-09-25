"""Install an already-built offline fork. No credentials are read or copied."""
import argparse,plistlib,shutil,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('built_app',type=Path);p.add_argument('--identity',default='-');a=p.parse_args()
assert (a.built_app/'Contents/MacOS/azooKeyMac').is_file()
for demo in [False,True]:
 dst=Path.home()/('Applications/Stateless-azooKey Demo.app' if demo else 'Library/Input Methods/Stateless-azooKey.app')
 # Replace only the separately named local-fork installation.
 if dst.exists():shutil.rmtree(dst)
 dst.parent.mkdir(parents=True,exist_ok=True);shutil.copytree(a.built_app,dst,symlinks=True)
 info=dst/'Contents/Info.plist';d=plistlib.loads(info.read_bytes())
 bundle='dev.naoki.StatelessAzooKeyDemo' if demo else 'dev.naoki.inputmethod.StatelessAzooKey'
 d.update(CFBundleIdentifier=bundle,CFBundleDisplayName='Stateless-azooKey',CFBundleName='Stateless-azooKey')
 if demo:
  d.update(StatelessDemoDefault=True,LSUIElement=False,LSBackgroundOnly=False)
  for key in ['ComponentInputModeDict','InputMethodConnectionName','InputMethodServerControllerClass','tsInputMethodCharacterRepertoireKey']:d.pop(key,None)
 else:d['InputMethodConnectionName']=bundle+'_Connection'
 info.write_bytes(plistlib.dumps(d))
 localization=dst/'Contents/Resources/en.lproj/InfoPlist.strings'
 localization.write_text('CFBundleDisplayName = "Stateless-azooKey";\nCFBundleName = "Stateless-azooKey";\n',encoding='utf-16')
 ent={'com.apple.security.app-sandbox':True}
 if not demo:ent['com.apple.security.temporary-exception.mach-register.global-name']=bundle+'_Connection'
 with tempfile.NamedTemporaryFile(suffix='.plist') as tmp:
  Path(tmp.name).write_bytes(plistlib.dumps(ent))
  subprocess.run(['codesign','--force','--deep','--timestamp=none','--sign',a.identity,'--entitlements',tmp.name,str(dst)],check=True)
 subprocess.run(['codesign','--verify','--deep','--strict',str(dst)],check=True)
 print(dst)
