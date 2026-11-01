"""Check architectural boundaries that can be verified mechanically; design quality still requires review."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
errors = []
roles = {'Application', 'Domain', 'Infrastructure', 'Presentation'}
for product in ('Builder', 'Player', 'Shared'):
    for source in sorted((root / 'Sources' / product).rglob('*.swift')):
        relative = source.relative_to(root)
        parts = source.relative_to(root / 'Sources' / product).parts
        text = source.read_text()
        # Typed Intl resources are deliberately shared across policy errors and presentation.
        if parts[0] not in roles and not (product == 'Shared' and parts[0] == 'Intl'):
            errors.append(f'{relative}: Swift source must belong to an architectural role')
        if parts[0] == 'Domain':
            if re.search(r'^import (Cocoa|AppKit|WebKit|GameController)\b', text, re.M):
                errors.append(f'{relative}: domain rules must not import UI/hardware frameworks')
            if re.search(r'\b(FileManager|UserDefaults|URLSession|Bundle\.main)\b|Data\(contentsOf:', text):
                errors.append(f'{relative}: move persistence/platform access behind an infrastructure boundary')
        if re.search(r'\b(UnsafeMutablePointer|UnsafeMutableRawPointer|OpaquePointer)\b', text):
            if 'Infrastructure' not in parts:
                errors.append(f'{relative}: raw memory belongs to its owning infrastructure adapter')
        if parts[0] == 'Presentation' and re.search(r'\b(Process\(|URLSession\.)', text):
            errors.append(f'{relative}: presentation must delegate subprocess/network ownership')
        if parts[0] == 'Presentation' and re.search(r'\bAppDelegate\b|NSApp\.delegate', text):
            errors.append(f'{relative}: use an explicit presentation action/session interface')
        if '@main' in text and parts[0] != 'Application':
            errors.append(f'{relative}: application entry points belong in Application')

if errors:
    print('\n'.join(errors))
    sys.exit(1)
print('Passed: source roles, independent domain rules, private native-memory boundaries and platform ownership')
