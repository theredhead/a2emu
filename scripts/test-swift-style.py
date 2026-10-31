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

    for source in ["func snake_case_name() {}\n", "let snake_case_value = 1\n"]:
        fixture.write_text(source)
        result = subprocess.run(command, capture_output=True, text=True)
        assert result.returncode != 0 and "AlwaysUseLowerCamelCase" in result.stderr, result.stderr

    fixture.write_text("func useCore() {\n    _ = video_get_kimage(0)\n    _ = g_limit_speed\n}\n")
    subprocess.run(command, check=True)

print("Style fixtures passed (documentation, imports, semicolons, Swift naming, and imported C names).")

# Exercise the adopted ElseBox checker without touching production source files.
with tempfile.TemporaryDirectory(prefix="a2-readability-") as directory:
    root = Path(directory)
    (root / "Sources").mkdir()
    (root / "scripts").mkdir()
    checker = root / "scripts" / "check-readability.py"
    checker.write_text((ROOT / "scripts" / "check-readability.py").read_text())
    fixture = root / "Sources" / "Fixture.swift"

    def check_readability(*arguments):
        return subprocess.run(
            ["python3", str(checker), *arguments], capture_output=True, text=True)

    fixture.write_text("@main final class Example {\n    func first() {}\n    func second() {}\n}\n")
    result = check_readability()
    assert result.returncode != 0 and "needs a purpose doc comment" in result.stdout
    assert "separate declarations" in result.stdout
    result = check_readability("--fix")
    assert result.returncode != 0, "Whitespace fixes must not invent a class purpose"
    assert "func first() {}\n\n    func second()" in fixture.read_text()
    fixture.write_text("/// Owns the fixture workflow.\n" + fixture.read_text())
    assert check_readability().returncode == 0
    fixture.write_text("/// Owns the fixture workflow.\n\n@main final class Example {}\n")
    assert check_readability().returncode != 0, "Detached purpose comments must fail"
    fixture.write_text("/// Owns the fixture workflow.\n@MainActor\nfinal class Example {}\n")
    assert check_readability().returncode == 0
    helper = root / "scripts" / "Helper.swift"
    helper.write_text("private final class Helper {}\n")
    assert check_readability().returncode != 0, "Private helper classes in scripts need documentation too"
    helper.write_text("/// Owns a helper resource.\nprivate final class Helper {}\n")
    assert check_readability().returncode == 0

print("Passed: purpose comments, inline attributes, helper coverage and whitespace-only readability fixes")
