#!/usr/bin/env python3
from pathlib import Path
import zipfile
import sys
root=Path(__file__).resolve().parent.parent
out=Path(sys.argv[1]) if len(sys.argv)>1 else root/'build/Player-Source.zip'
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as archive:
    for name in ['CMakeLists.txt','SOURCE-README.md','LICENSE','MODIFICATIONS.txt','Sources','scripts','Vendor/gsplus']:
        path=root/name
        for file in ([path] if path.is_file() else path.rglob('*')):
            if file.is_file() and '.git' not in file.relative_to(root).parts:
                archive.write(file,'Apple-II-Player-Source/'+str(file.relative_to(root)))
    for name in ['Player.icns', 'PlayerIcon.png', 'Builder.icns', 'BuilderIcon.png', 'Builder-Icon-Prompt.txt']:
        archive.write(root/'Assets'/name, 'Apple-II-Player-Source/Assets/'+name)
    archive.writestr('Apple-II-Player-Source/BUILDING.txt',
        'Requires Xcode command line tools, CMake, Ninja, Python 3 and SDL3 for upstream configuration.\n'
        'Configure separate arm64 and x86_64 build directories, build a2emu-player and a2emu-builder, then run scripts/package-builder.py.\n'
        'The player template contains no disk or firmware; the builder supplies a selected disk and machine profile when exporting.\n'
        'GSplus source revision: 41e71031debbde98e66ea5c5c67498e9b4726a6d.\n')
print(out)
