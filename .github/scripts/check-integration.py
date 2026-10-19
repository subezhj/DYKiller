"""Static integration checks; does not replace Theos compilation or device tests."""
from collections import Counter
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
sources = {
    p: p.read_text(encoding="utf-8")
    for p in (root / "src").rglob("*")
    if p.suffix in {".h", ".m", ".mm", ".xm", ".c"}
}
errors = []
registrations = []
all_text = "\n".join(sources.values())
layout = (root / "src/Settings/DKSettingsLayout.m").read_text(encoding="utf-8")
keys_text = (root / "src/Shared/DKKeys.h").read_text(encoding="utf-8")
keys = re.findall(r"static NSString \*const (DKKey\w+)", keys_text)

for path, text in sources.items():
    name = path.relative_to(root)
    if re.search(r"^(<<<<<<<|=======|>>>>>>>)", text, re.M):
        errors.append(f"{name}: unresolved merge marker")
    if re.search(r"\b(?:DKSettingsRegisterItem|DKMakeChoiceWithMessage|DKMakeButton)\s*\(", text):
        errors.append(f"{name}: obsolete settings API")
    registrations.extend(re.findall(r"DKSettingsRegister\((DKKey\w+)", text))
    if re.search(r"DKSettingsRegister\(key\s*,", text):
        registrations.extend(re.findall(r"@\[\s*(DKKey\w+)\s*,", text))
        registrations.extend(re.findall(r"DKRegisterTitle\((DKKey\w+)\s*,", text))
    for include in re.findall(r'#(?:import|include) "([^"]+)"', text):
        if not (path.parent / include).is_file() and not any(p.name == include for p in sources):
            errors.append(f"{name}: missing local header {include}")
    clean = re.sub(r'//[^\n]*|/\*.*?\*/|@?"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', "", text, flags=re.S)
    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for char in re.findall(r"[()\[\]{}]", clean):
        if char in "([{":
            stack.append(char)
        elif not stack or stack.pop() != pairs[char]:
            errors.append(f"{name}: mismatched delimiter")
            break
    else:
        if stack:
            errors.append(f"{name}: unclosed delimiters")
    if path.suffix == ".xm":
        scopes = []
        for kind in re.findall(r"%(hook|group|subclass|end)\b", clean):
            if kind != "end":
                scopes.append(kind)
            elif scopes:
                scopes.pop()
            else:
                errors.append(f"{name}: unexpected %end")
        if scopes:
            errors.append(f"{name}: unclosed Logos scopes")

for key, count in Counter(keys).items():
    if count > 1:
        errors.append(f"Duplicate settings key declaration: {key}")
for key, count in Counter(registrations).items():
    if count > 1:
        errors.append(f"Duplicate settings registration: {key}")
    if key not in keys:
        errors.append(f"Undeclared registered key: {key}")
    if not re.search(r"DKRow\(" + key + r"\s*,", layout):
        errors.append(f"Missing layout row: {key}")
for key in re.findall(r"DKRow\((DKKey\w+)\s*,", layout):
    if key not in registrations:
        errors.append(f"Layout row has no registered builder: {key}")
headers = (root / "src/Headers/DouyinHeaders.h").read_text(encoding="utf-8")
for name, count in Counter(re.findall(r"@interface\s+(\w+)", headers)).items():
    if count > 1:
        errors.append(f"Duplicate private interface: {name}")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print(f"PASS: {len(sources)} source/header files, {len(registrations)} settings registrations; "
      "merge markers, delimiters, Logos scopes, local headers, declarations and layout checked.")
