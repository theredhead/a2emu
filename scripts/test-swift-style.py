#!/usr/bin/env python3
"""Exercise style checks using disposable Swift fixtures, outside production sources."""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def lint(path):
    result = subprocess.run(
        ["swiftlint", "lint", "--config", str(ROOT / ".swiftlint.yml"),
         "--strict", "--no-cache", "--quiet", "--reporter", "json", str(path)],
        cwd=ROOT, capture_output=True, text=True,
    )
    if result.returncode not in (0, 2):
        raise RuntimeError(result.stderr)
    return result.returncode, {item["rule_id"] for item in json.loads(result.stdout)}


with tempfile.TemporaryDirectory(prefix="a2-swift-style-") as directory:
    fixture = Path(directory) / "Fixture.swift"
    cases = [
        ("/// Purpose.\n\nfunc example() {}\n", "detached_documentation"),
        ("/// Purpose.\n\n@MainActor\nfunc example() {}\n", "detached_documentation"),
        ("@MainActor\n/// Purpose.\nfunc example() {}\n", "documentation_below_attribute"),
        ("import Foundation\nimport Foundation\n", "duplicate_imports"),
    ]
    for source, expected in cases:
        fixture.write_text(source)
        status, rules = lint(fixture)
        assert status != 0 and expected in rules, (expected, status, rules)

    fixture.write_text(
        "/// First line.\n/// Second line.\n@MainActor\nfunc example() {}\n\n"
        "// Implementation note.\nfunc another() {}\n"
    )
    assert lint(fixture) == (0, set()), "Attached documentation should pass"

    fixture.write_text("func example() { let first = 1; print(first) }\n")
    command = ["xcrun", "swift-format", "lint", "--strict", "--configuration",
               str(ROOT / ".swift-format"), str(fixture)]
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode != 0, "Compressed semicolon-separated statements should fail"
    subprocess.run(
        ["xcrun", "swift-format", "format", "--in-place", "--configuration",
         str(ROOT / ".swift-format"), str(fixture)], check=True,
    )
    subprocess.run(command, check=True)
    formatted = fixture.read_text()
    assert ";" not in formatted, "Formatting must remove semicolons"
    assert "\n    let first" in formatted, "Formatting must use four-space indentation"
    subprocess.run(
        ["xcrun", "swift-format", "format", "--in-place", "--configuration",
         str(ROOT / ".swift-format"), str(fixture)], check=True,
    )
    assert fixture.read_text() == formatted, "Formatting must be idempotent"

print("Style fixtures passed (detached docs, attributes, duplicate imports, and semicolons).")
