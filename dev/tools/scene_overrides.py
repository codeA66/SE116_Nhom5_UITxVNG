"""Tim (va sua) cho ghi de node con cua scene nhung ma thieu [editable path=...] trong file .tscn.

Ghi de thuoc tinh len node con cua mot scene nhung (instance) chi duoc giu lai khi export neu instance do
nam trong danh sach [editable path=...]. Editor doc thang .tscn nen van ap dung, ban release thi mat
(loi da gap 28/11/2026: nguoi cheo do phong 10 khong tang bua o ban release).

Chay:  python dev/tools/scene_overrides.py            -> liet ke cho thieu
       python dev/tools/scene_overrides.py --fix      -> them [editable] con thieu vao cuoi file
       python dev/tools/scene_overrides.py --json out -> ghi danh sach ghi de (scene, node, thuoc tinh) ra JSON
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SKIP_DIRS = ("docs", "output", ".godot", "addons", "test_logs")
NODE_RE = re.compile(r"^\[node ([^\]]*)\]", re.M)
EXT_RE = re.compile(r'^\[ext_resource ([^\]]*)\]', re.M)
EDITABLE_RE = re.compile(r'^\[editable path="([^"]+)"\]', re.M)


def attr(a, key):
    m = re.search(r'\b%s="([^"]*)"' % key, a)
    return m.group(1) if m else None


def parse(path):
    """Tra ve (nodes, editable, text). nodes: list dict(name, path, parent, type, instance, props, start, end)."""
    with open(path, encoding="utf-8", errors="ignore") as f:
        text = f.read()
    ext = {}
    for m in EXT_RE.finditer(text):
        a = m.group(1)
        ext[attr(a, "id")] = attr(a, "path")
    nodes = []
    matches = list(NODE_RE.finditer(text))
    for i, m in enumerate(matches):
        a = m.group(1)
        name = attr(a, "name")
        parent = attr(a, "parent")
        inst = re.search(r'instance=ExtResource\("([^"]+)"\)', a)
        body_end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[m.end():body_end]
        # Chi lay thuoc tinh cua chinh node (dung truoc khoi [ ... ] tiep theo)
        body = body.split("\n[", 1)[0]
        props = [ln.split(" = ", 1)[0] for ln in body.splitlines() if " = " in ln and not ln.startswith(("[", " ", "\t", '"'))]
        if parent is None:
            npath = "."
        elif parent == ".":
            npath = name
        else:
            npath = parent + "/" + name
        nodes.append({
            "name": name, "parent": parent, "path": npath,
            "type": attr(a, "type"),
            "instance": ext.get(inst.group(1)) if inst else None,
            "props": props,
        })
    editable = set(EDITABLE_RE.findall(text))
    return nodes, editable, text


def res_to_file(res):
    return os.path.join(ROOT, res[len("res://"):]) if res and res.startswith("res://") else None


def nested_instances(scene_res, rel_path, prefix, depth=0):
    """Cac instance long nhau trong scene_res nam tren duong rel_path (tra ve duong dan tinh tu goc file dang xet)."""
    out = []
    f = res_to_file(scene_res)
    if depth > 8 or not f or not f.endswith(".tscn") or not os.path.exists(f):
        return out
    nodes, _, _ = parse(f)
    parts = rel_path.split("/")
    for i in range(1, len(parts) + 1):
        sub = "/".join(parts[:i])
        for n in nodes:
            if n["path"] == sub and n["instance"]:
                full = prefix + "/" + sub
                out.append(full)
                out += nested_instances(n["instance"], "/".join(parts[i:]), full, depth + 1) if i < len(parts) else []
    return out


def required_editables(path):
    """Tra ve (thieu, danh_sach_ghi_de) cho mot file .tscn."""
    nodes, editable, _ = parse(path)
    instances = {n["path"]: n["instance"] for n in nodes if n["instance"]}
    need = []
    overrides = []
    for n in nodes:
        if n["parent"] is None or n["type"] or n["instance"]:
            continue
        parts = [] if n["parent"] == "." else n["parent"].split("/")
        owner = None
        for i in range(len(parts), 0, -1):
            cand = "/".join(parts[:i])
            if cand in instances:
                owner = cand
                break
        if owner is None:
            continue
        overrides.append({"node": n["path"], "props": n["props"]})
        chain = [owner]
        rest = n["path"][len(owner) + 1:]
        parent_rest = "/".join(rest.split("/")[:-1])
        if parent_rest:
            chain += nested_instances(instances[owner], parent_rest, owner)
        for c in chain:
            if c not in editable and c not in need:
                need.append(c)
    return need, overrides


def scenes():
    for d, dirs, files in os.walk(ROOT):
        rel = os.path.relpath(d, ROOT).replace("\\", "/")
        if rel.split("/")[0] in SKIP_DIRS:
            dirs[:] = []
            continue
        for fn in files:
            if fn.endswith(".tscn"):
                yield os.path.join(d, fn)


def main():
    fix = "--fix" in sys.argv
    json_out = sys.argv[sys.argv.index("--json") + 1] if "--json" in sys.argv else None
    total = 0
    report = []
    for f in sorted(scenes()):
        need, overrides = required_editables(f)
        res = "res://" + os.path.relpath(f, ROOT).replace("\\", "/")
        if overrides:
            report.append({"scene": res, "overrides": overrides})
        if not need:
            continue
        total += len(need)
        print("%s: thieu %s" % (res, ", ".join(need)))
        if fix:
            with open(f, encoding="utf-8") as fh:
                text = fh.read().rstrip("\n")
            text += "\n" + ("" if EDITABLE_RE.search(text) else "\n")
            text += "\n".join('[editable path="%s"]' % p for p in need) + "\n"
            with open(f, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(text)
    if json_out:
        with open(json_out, "w", encoding="utf-8") as fh:
            json.dump(report, fh, ensure_ascii=False, indent=1)
    print("TONG thieu: %d%s" % (total, " (da sua)" if fix else ""))


if __name__ == "__main__":
    main()
