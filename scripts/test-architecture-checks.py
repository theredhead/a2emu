"""Prove architecture guards reject boundary regressions using disposable, non-production Swift files."""
from pathlib import Path
import subprocess
import tempfile

repository = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='a2-architecture-fixtures-') as directory:
    root = Path(directory)
    (root / 'scripts').mkdir()
    for product in ('Builder', 'Player', 'Shared'):
        (root / 'Sources' / product).mkdir(parents=True)
    checker = root / 'scripts' / 'check-architecture.py'
    checker.write_text((repository / 'scripts' / 'check-architecture.py').read_text())
    cases = [
        ('Builder/Domain/Policy.swift', 'import Foundation\nstruct Policy {}\n', True),
        ('Builder/Domain/Policy.swift', 'import Cocoa\nstruct Policy {}\n', False),
        ('Builder/Domain/Policy.swift', 'import Foundation\nlet settings = UserDefaults.standard\n', False),
        ('Player/Presentation/Frame.swift', 'import Foundation\nvar pixels: UnsafeMutableRawPointer?\n', False),
        ('Player/Infrastructure/Frame.swift', 'import Foundation\nprivate var pixels: UnsafeMutableRawPointer?\n', True),
        ('Builder/Presentation/Download.swift', 'import Foundation\nlet session = URLSession.shared\n', False),
        ('Builder/Presentation/Launch.swift', 'import Foundation\nlet process = Process()\n', False),
        ('Player/Presentation/Session.swift', 'import Cocoa\nlet player = NSApp.delegate as? AppDelegate\n', False),
        ('Builder/Misc.swift', 'import Foundation\nstruct Misc {}\n', False),
        ('Builder/Presentation/Main.swift', 'import Cocoa\n@main struct Main {}\n', False),
    ]
    for relative, contents, succeeds in cases:
        fixture = root / 'Sources' / relative
        fixture.parent.mkdir(parents=True, exist_ok=True)
        fixture.write_text(contents)
        result = subprocess.run(['python3', str(checker)], capture_output=True, text=True)
        assert (result.returncode == 0) == succeeds, (relative, result.stdout, result.stderr)
        fixture.unlink()
print('Passed: architecture guards reject UI/persistence in domain, leaked pointers, UI networking/processes and unowned sources')
