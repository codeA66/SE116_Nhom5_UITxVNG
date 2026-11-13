"""List untranslated Vietnamese candidates with their source locations."""

import ast
from pathlib import Path
import re
import sys
import warnings


ROOT = Path(__file__).resolve().parents[2]
LITERAL = re.compile(r'"(?:[^"\\]|\\.)*"')
VIETNAMESE = re.compile(r"[À-ỹĐđ]")
RESOURCE_FIELD = re.compile(
    r"^\s*(?:text|tooltip_text|placeholder_text|title|subtitle|display_name|"
    r"description|category|summary|prompt_template|acquire_verb|acquire_prompt|"
    r"page_title|speaker|interaction_prompt)\s*=|^\s*\"(?:heading|text)\"\s*:"
)
DEBUG = re.compile(r"\b(?:print\w*|push_error|push_warning|assert|_check)\s*\(")


def quoted_strings(line):
    for match in LITERAL.finditer(line):
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", SyntaxWarning)
                yield ast.literal_eval(match.group())
        except (SyntaxError, ValueError):
            continue


def main():
    catalogue = ROOT / "resources/localization/en.po"
    entries = set()
    for line in catalogue.read_text(encoding="utf-8").splitlines():
        if line.startswith("msgid "):
            entries.update(quoted_strings(line))
    missing = 0
    for folder in ("abilities", "autoload", "components", "entities", "levels", "objects", "resources", "ui"):
        for path in sorted((ROOT / folder).rglob("*")):
            if path.suffix not in {".gd", ".tscn", ".tres"}:
                continue
            if "review" in path.parts or path.stem.endswith(("_test", "_tests")):
                continue
            editor_warnings = False
            for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
                if path.suffix == ".gd":
                    if line.startswith("func "):
                        editor_warnings = line.startswith("func _get_configuration_warnings(")
                    if editor_warnings:
                        continue
                    line = re.split(r'("(?:[^"\\]|\\.)*")|(#.*)', line)
                    code = "".join(part for part in line if part is not None and not part.startswith("#"))
                    if DEBUG.search(code) or code.lstrip().startswith("@export_group"):
                        continue
                else:
                    code = line
                    if not RESOURCE_FIELD.search(code):
                        continue
                for value in quoted_strings(code):
                    if path.name == "settings_data.gd" and value == "Tiếng Việt":
                        continue
                    if VIETNAMESE.search(value) and value not in entries:
                        print(f"{path.relative_to(ROOT).as_posix()}:{number}: {value}")
                        missing += 1
    print(f"Untranslated candidates: {missing}")
    return int(missing > 0)


if __name__ == "__main__":
    sys.exit(main())
