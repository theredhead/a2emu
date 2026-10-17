#!/usr/bin/env python3
"""Validate .lproj tables, typed-wrapper coverage and translation placeholders."""
import json
import pathlib
import plistlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources/Localizations"
PAIR = re.compile(r'("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*")\s*;')


def read_strings(path):
    text = re.sub(r'/\*.*?\*/', '', path.read_text(), flags=re.S)
    values = {}
    for match in PAIR.finditer(text):
        key, value = (json.loads(part) for part in match.groups())
        if key in values:
            raise ValueError(f"{path}: duplicate key {key}")
        values[key] = value
    if PAIR.sub('', text).strip():
        raise ValueError(f"{path}: invalid strings syntax")
    return values


def placeholders(value):
    value = value.replace('%%', '')
    result = {}
    next_position = 1
    for match in re.finditer(r'%(?:(\d+)\$)?(ld|@)', value):
        position = int(match[1]) if match[1] else next_position
        result[position] = match[2]
        next_position += 1
    return result


def check():
    english = {p.stem: read_strings(p) for p in (RESOURCES / 'en.lproj').glob('*.strings')}
    referenced = set()
    for path in (ROOT / 'Sources/Shared/Intl').glob('*Intl.swift'):
        text = path.read_text()
        for key, table in re.findall(r'NSLocalizedString\(\s*"([^"]+)"\s*,\s*tableName:\s*"([^"]+)"', text):
            if key not in english.get(table, {}):
                raise ValueError(f"{path}: missing English resource {table}.{key}")
            referenced.add((table, key))
        for key, table, fallback in re.findall(
                r'NSLocalizedString\(\s*"([^"]+)"\s*,\s*tableName:\s*"([^"]+)"\s*,\s*bundle:\s*bundle,\s*value:\s*(.*?),\s*comment:', text, re.S):
            literals = re.findall(r'"(?:[^"\\]|\\.)*"', fallback)
            if not literals:
                raise ValueError(f"{path}: fallback must be explicit English text: {key}")
            value = json.loads(literals[-1])
            normalize = lambda item: re.sub(r'%(\d+)\$', '%', item)
            if normalize(value) != normalize(english[table][key]):
                raise ValueError(f"{path}: English fallback differs from {table}.{key}")
    for table, values in english.items():
        unused = {key for key in values if (table, key) not in referenced}
        if unused:
            raise ValueError(f"{table}: unused English keys: {sorted(unused)}")
    for path in (ROOT / 'Sources').rglob('*.swift'):
        if 'Intl' in path.parts:
            continue
        text = path.read_text()
        if 'NSLocalizedString(' in text:
            raise ValueError(f"{path}: localization lookup belongs in an Intl class")
        # MainMenu is an AppKit menu identity, not a displayed application label.
        text = text.replace('NSMenu(title: "MainMenu")', 'NSMenu(title: "")')
        ui_literal = re.compile(
            r'(?:\.(?:title|messageText|informativeText|toolTip|placeholderString|accessibilityDescription)\s*=|'
            r'(?:title|withTitle|labelWithString|wrappingLabelWithString|checkboxWithTitle|accessibilityDescription):|'
            r'setAccessibilityLabel\()\s*"[^"\n]*[A-Za-z]{2}[^"\n]*"')
        if ui_literal.search(text):
            raise ValueError(f"{path}: hard-coded UI text belongs in an Intl class")
    for locale in RESOURCES.glob('*.lproj'):
        for path in locale.glob('*.strings'):
            values = read_strings(path)
            for key, value in values.items():
                original = english.get(path.stem, {}).get(key)
                if original is None or placeholders(value) != placeholders(original):
                    raise ValueError(f"{path}: unknown key or changed placeholders: {key}")
        for path in locale.glob('*.stringsdict'):
            rules = plistlib.loads(path.read_bytes())
            for key, rule in rules.items():
                if key not in english.get(path.stem, {}):
                    raise ValueError(f"{path}: plural key has no string fallback: {key}")
                if rule.get('NSStringLocalizedFormatKey') != '%#@count@':
                    raise ValueError(f"{path}: invalid plural format: {key}")
                variants = rule['count']
                if variants.get('NSStringFormatSpecTypeKey') != 'NSStringPluralRuleType' or variants.get('NSStringFormatValueTypeKey') != 'ld':
                    raise ValueError(f"{path}: invalid plural type: {key}")
                if 'other' not in variants:
                    raise ValueError(f"{path}: missing other plural form: {key}")
                for category in ['zero', 'one', 'two', 'few', 'many', 'other']:
                    if category in variants and placeholders(variants[category]) != {1: 'ld'}:
                        raise ValueError(f"{path}: invalid count placeholder: {key}.{category}")
    print(f"Localization checks passed: {len(english)} tables, {len(referenced)} typed messages.")


if __name__ == '__main__':
    try:
        check()
    except (ValueError, KeyError, plistlib.InvalidFileException) as error:
        sys.exit(str(error))
