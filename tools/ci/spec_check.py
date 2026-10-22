#!/usr/bin/env python3
"""Spec check (docs/systems/README.md): a branch that changes gameplay code or tuning data also
changes the spec that owns it, and every file under the checked roots has an owner.

    python3 tools/ci/spec_check.py                 # this branch against origin/main
    python3 tools/ci/spec_check.py --base main     # against another base
    python3 tools/ci/spec_check.py --files a b     # check a given list of changed files
    python3 tools/ci/spec_check.py --coverage      # only list files no spec owns

The owners are in docs/systems/map.json. The changed files are the branch's commits since its
merge base with the base, plus uncommitted and untracked files. A pure refactor opts out with a
line `Spec-Skip: <why>` in a commit message on the branch, or SPEC_SKIP=<why> in the
environment. Exits 1 on a missing spec change or an unowned file.
"""
import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAP = "docs/systems/map.json"
SKIP_RE = re.compile(r"^Spec-Skip:\s*(.+)$", re.M)


def git(*args):
    r = subprocess.run(["git", *args], cwd=HERE, capture_output=True, text=True)
    return r.returncode, r.stdout


def glob_re(pat):
    out = ""
    i = 0
    while i < len(pat):
        if pat.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pat.startswith("**", i):
            out += ".*"
            i += 2
        elif pat[i] == "*":
            out += "[^/]*"
            i += 1
        elif pat[i] == "?":
            out += "[^/]"
            i += 1
        else:
            out += re.escape(pat[i])
            i += 1
    return re.compile("^" + out + "$")


class Owners:
    def __init__(self, m):
        self.roots = m["roots"]
        self.specs = {}
        for name, s in m["specs"].items():
            self.specs[name] = {"docs": s["docs"], "paths": [glob_re(p) for p in s["paths"]], "raw": s["paths"]}
        self.exempt = [glob_re(p) for p in m["exempt"]["patterns"]]
        self.exempt_raw = m["exempt"]["patterns"]

    def checked(self, f):
        return any(f.startswith(r) for r in self.roots)

    def owners(self, f):
        return [n for n, s in self.specs.items() if any(r.match(f) for r in s["paths"])]

    def is_exempt(self, f):
        return any(r.match(f) for r in self.exempt)


def tracked_files():
    _, out = git("ls-files")
    return [f for f in out.splitlines() if f]


def changed_files(base):
    code, mb = git("merge-base", base, "HEAD")
    if code != 0:
        print(f"spec_check: can't find a merge base with {base} (fetch it, or pass --base)", file=sys.stderr)
        sys.exit(2)
    mb = mb.strip()
    print(f"spec_check: changes since {base} ({mb[:9]}); fetch {base} first if it is stale")
    files = set()
    for args in (["diff", "--name-only", mb, "HEAD"], ["diff", "--name-only", "HEAD"],
                 ["ls-files", "--others", "--exclude-standard"]):
        _, out = git(*args)
        files.update(f for f in out.splitlines() if f)
    _, log = git("log", "--format=%B%x00", f"{mb}..HEAD")
    return sorted(files), log


def default_base():
    for b in ("origin/main", "main"):
        if git("rev-parse", "--verify", "--quiet", b)[0] == 0:
            return b
    return "origin/main"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default=None)
    ap.add_argument("--files", nargs="*")
    ap.add_argument("--coverage", action="store_true")
    a = ap.parse_args()
    own = Owners(json.load(open(os.path.join(HERE, MAP), encoding="utf-8")))
    bad = 0

    # The map itself: every doc exists, every pattern still matches something.
    tracked = tracked_files()
    for name, s in own.specs.items():
        for d in s["docs"]:
            if not os.path.exists(os.path.join(HERE, d)):
                print(f"FAIL  map: spec '{name}' lists {d}, which doesn't exist")
                bad += 1
        for raw, r in zip(s["raw"], s["paths"]):
            if not any(r.match(f) for f in tracked):
                print(f"warn  map: spec '{name}' path {raw} matches no file")

    # Coverage: every file under the roots has an owner or is exempt.
    unowned = [f for f in tracked if own.checked(f) and not own.owners(f) and not own.is_exempt(f)]
    for f in unowned:
        print(f"FAIL  unowned: {f} (add it to a spec's paths, or to exempt, in {MAP})")
    bad += len(unowned)
    if a.coverage:
        print(f"{len(unowned)} unowned file(s)")
        return 1 if bad else 0

    if a.files is not None:
        files, log = sorted(set(a.files)), ""
    else:
        files, log = changed_files(a.base or default_base())
    skip = os.environ.get("SPEC_SKIP", "").strip()
    m = SKIP_RE.search(log)
    if not skip and m:
        skip = m.group(1).strip()

    changed = set(files)
    need = {}  # owners tuple -> files
    for f in files:
        if not own.checked(f):
            continue
        o = own.owners(f)
        if o:
            need.setdefault(tuple(o), []).append(f)
    missing = []
    for o, fs in need.items():
        docs = [d for n in o for d in own.specs[n]["docs"]]
        if not any(d in changed for d in docs):
            missing.append((o, fs))
    for o, fs in missing:
        specs = ", ".join(f"docs/systems/{n}.md" for n in o)
        print(f"{'skip' if skip else 'FAIL'}  spec not updated: {specs} (or a page it lists) for")
        for f in fs:
            print(f"        {f}")
    if skip and missing:
        print(f"Spec-Skip: {skip}")
    elif missing:
        bad += len(missing)
        print("Update the spec in this branch, or mark a pure refactor with a commit line 'Spec-Skip: <why>'.")
    n = sum(len(fs) for fs in need.values())
    print(f"spec_check: {len(files)} changed file(s), {n} owned by a spec, {len(missing)} spec(s) missing an update, "
          f"{len(unowned)} unowned file(s)" + (" (skipped)" if skip and missing else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
