#!/usr/bin/env python3
"""Exercise the localization guard against representative translation mistakes."""
import importlib.util
import pathlib
import shutil
import tempfile

spec = importlib.util.spec_from_file_location('localization', pathlib.Path(__file__).with_name('check-localization.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
original_root = module.ROOT
with tempfile.TemporaryDirectory() as directory:
    root = pathlib.Path(directory)
    shutil.copytree(original_root / 'Sources', root / 'Sources')
    shutil.copytree(original_root / 'Resources/Localizations', root / 'Resources/Localizations')
    module.ROOT = root
    module.RESOURCES = root / 'Resources/Localizations'
    table = module.RESOURCES / 'en.lproj/Builder.strings'
    original = table.read_text()
    fixtures = [
        original + '\n"chooseDisks" = "duplicate";\n',
        original.replace('"chooseDisks" = "Choose Disks…";', ''),
    ]
    for fixture in fixtures:
        table.write_text(fixture)
        try:
            module.check()
        except ValueError:
            pass
        else:
            raise AssertionError('Duplicate or missing key was not detected')
    table.write_text(original)
    bad_ui = root / 'Sources/BadLocalizationFixture.swift'
    for source in ['let button = NSButton(title: "Untranslated", target: nil, action: nil)',
                   'let title = NSLocalizedString("raw.key", comment: "Wrong layer")']:
        bad_ui.write_text(source)
        try:
            module.check()
        except ValueError:
            pass
        else:
            raise AssertionError('Hard-coded UI text or lookup outside Intl was not detected')
    bad_ui.unlink()
    pseudo = module.RESOURCES / 'test.lproj'
    pseudo.mkdir()
    (pseudo / 'Builder.strings').write_text('"diskImagesSelected" = "%1$@ disks";')
    try:
        module.check()
    except ValueError:
        pass
    else:
        raise AssertionError('Changed placeholder type was not detected')
print('PASS localization checks reject missing/duplicate keys, changed placeholders and UI lookups outside Intl')
