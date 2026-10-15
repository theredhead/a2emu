#!/usr/bin/env python3
from pathlib import Path
import subprocess,sys,plistlib,zipfile,hashlib,shutil
root=Path(__file__).resolve().parent.parent
stage=root/'releases/Apple-II-Wrapper-Builder-0.4.2-universal'
if stage.exists(): shutil.rmtree(stage)
stage.mkdir(parents=True)
subprocess.run([sys.executable,str(root/'scripts/bundle-source.py')],check=True)
player=stage/'PlayerTemplate.app'
subprocess.run(['ditto',str(root/'build/release-arm64/Apple II Player.app'),str(player)],check=True)
subprocess.run(['lipo','-create',str(root/'build/release-arm64/Apple II Player.app/Contents/MacOS/Apple II Player'),str(root/'build/release-x86_64/Apple II Player.app/Contents/MacOS/Apple II Player'),'-output',str(player/'Contents/MacOS/Apple II Player')],check=True)
subprocess.run(['ditto',str(root/'build/Player-Source.zip'),str(player/'Contents/Resources/Player-Source.zip')],check=True)
subprocess.run(['codesign','--force','--sign','-',str(player)],check=True)
builder=stage/'Apple II Wrapper Builder.app'
subprocess.run(['ditto',str(root/'build/release-arm64/Apple II Wrapper Builder.app'),str(builder)],check=True)
exe='Contents/MacOS/Apple II Wrapper Builder'
subprocess.run(['lipo','-create',str(root/'build/release-arm64/Apple II Wrapper Builder.app'/exe),str(root/'build/release-x86_64/Apple II Wrapper Builder.app'/exe),'-output',str(builder/exe)],check=True)
for depfile in (builder/'Contents/MacOS').glob('*.d'):depfile.unlink()
resources=builder/'Contents/Resources';resources.mkdir(exist_ok=True)
subprocess.run(['ditto',str(root/'Assets/Builder.icns'),str(resources/'Builder.icns')],check=True)
subprocess.run(['ditto',str(player),str(resources/'PlayerTemplate.app')],check=True)
subprocess.run(['ditto',str(root/'LICENSE'),str(resources/'LICENSE.txt')],check=True)
subprocess.run(['codesign','--force','--deep','--sign','-',str(builder)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(builder)],check=True)
assert set(subprocess.check_output(['lipo','-archs',str(builder/exe)],text=True).split())=={'arm64','x86_64'}
(stage/'Read me.txt').write_text('Apple II Wrapper Builder 0.4.2\nmacOS 13+, Intel and Apple Silicon. Locally signed, not notarized.\n\nChoose disk images, edit the app name, choose initial drive assignments and the startup slot, then Create Player. Extra images remain in the library for Emulation > Disks swapping.\nSlot 6: 5.25-inch disks. Slot 5: 3.5-inch disks. Slot 7: hard disks.\nThe exported player loads its KEGS configuration normally; there is no injected PR#6 command.\nROM setup is offered on first launch. No ROM is bundled.\nChoose Player Icon searches DuckDuckGo for apple ][ and the disk name. Click an image result (or its larger preview), drag and zoom the square crop, then Use This Crop. Local images are supported too. Gamepad mapping remains pending.\nGPL source, licenses and credits are embedded in the player (About > More).\n')
# The template is inside the builder; do not include a duplicate standalone template.
import shutil
shutil.rmtree(player)
z=Path(str(stage)+'.zip');subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(stage),str(z)],check=True)
Path(str(stage)+'.sha256').write_text(hashlib.sha256(z.read_bytes()).hexdigest()+'  '+z.name+'\n')
print(z)
