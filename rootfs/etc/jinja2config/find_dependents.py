#!/usr/bin/env python3
"""Find every *.yaml.jinja file that (transitively) imports a changed template.

Given a changed .jinja file, this parses all .jinja templates under the config
directory with Jinja2's AST, uses jinja2.meta.find_referenced_templates to
extract each file's forward dependencies (from/import/include/extends), inverts
that into a reverse-dependency graph, and prints the *.yaml.jinja files that
need recompiling (one absolute path per line).

The changed file itself is never printed: when it is a *.yaml.jinja the shell
compiles it directly, so listing it here would double-compile.
"""
import os
import sys

from jinja2 import Environment, meta

# Reuse the exact delimiter params j2 compiles with, so parsing matches.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from j2_customizations import j2_environment_params
    ENV_PARAMS = j2_environment_params()
except Exception as exc:
    # Falling back to default delimiters here would silently break dependency
    # detection on any config using custom delimiters, so make the failure
    # loud instead of swallowing it.
    sys.stderr.write(
        "find_dependents.py: could not load j2_customizations, falling back to "
        "default delimiters (dependency detection may be wrong): %s\n" % exc
    )
    ENV_PARAMS = {}


def iter_jinja_files(config_dir):
    for root, _dirs, names in os.walk(config_dir):
        for name in names:
            if name.endswith(".jinja"):
                yield os.path.normpath(os.path.join(root, name))


def referenced_templates(env, path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            source = fh.read()
        ast = env.parse(source)
    except Exception:
        # A file that fails to parse can't contribute reliable deps.
        return set()
    # find_referenced_templates yields None for dynamic includes; drop those.
    return {ref for ref in meta.find_referenced_templates(ast) if ref}


def resolve(ref, importer, config_dir, files_set, basename_index):
    """Map a referenced template string to the real file(s) it points at."""
    candidates = []
    if ref.startswith("/"):
        candidates.append(os.path.normpath(ref))
    candidates.append(os.path.normpath(os.path.join(config_dir, ref)))
    candidates.append(os.path.normpath(os.path.join(os.path.dirname(importer), ref)))

    resolved = {c for c in candidates if c in files_set}
    if resolved:
        return resolved
    # Couldn't resolve to a concrete path (relative to an unknown searchpath):
    # fall back to matching by basename.
    return set(basename_index.get(os.path.basename(ref), []))


def find_dependents(env, changed, config_dir):
    """Return the sorted *.yaml.jinja files that (transitively) import `changed`.

    The changed file itself is excluded from the result.
    """
    changed = os.path.normpath(changed)
    config_dir = os.path.normpath(config_dir)

    files = list(iter_jinja_files(config_dir))
    files_set = set(files)
    basename_index = {}
    for f in files:
        basename_index.setdefault(os.path.basename(f), []).append(f)

    # On a delete/rename the changed file is already gone from disk, so the walk
    # above won't have found it and importers could never resolve back to it.
    # Inject it into the lookup tables so its dependents are still discovered.
    if changed not in files_set:
        files_set.add(changed)
        basename_index.setdefault(os.path.basename(changed), []).append(changed)

    # reverse[target] = set of files that import target
    reverse = {}
    for f in files:
        for ref in referenced_templates(env, f):
            for target in resolve(ref, f, config_dir, files_set, basename_index):
                reverse.setdefault(target, set()).add(f)

    # Transitive closure of importers, starting from the changed file.
    seen = set()
    stack = [changed]
    while stack:
        cur = stack.pop()
        for importer in reverse.get(cur, ()):
            if importer not in seen:
                seen.add(importer)
                stack.append(importer)

    return [
        f for f in sorted(seen)
        if f != changed and f.endswith(".yaml.jinja")
    ]


def main():
    if len(sys.argv) != 3:
        sys.stderr.write("usage: find_dependents.py <changed_file> <config_dir>\n")
        return 2

    env = Environment(**ENV_PARAMS)
    for f in find_dependents(env, sys.argv[1], sys.argv[2]):
        print(f)
    return 0


if __name__ == "__main__":
    sys.exit(main())
