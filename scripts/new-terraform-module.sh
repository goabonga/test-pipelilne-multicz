#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Scaffold a new Terraform module from infrastructure/modules/_template and
# register it everywhere it needs registering, so adding a module is one
# command instead of a copy plus two hand edits of multicz.toml that are
# easy to half-do.
#
# It does four things:
#   1. copies _template/ to modules/<name>/, substitutes the name, and
#      generates README.md with terraform-docs
#   2. adds a [components.infra-modules-<name>] block to multicz.toml —
#      its version lives in README.md, not a VERSION file
#   3. adds that component to every configs-<env>'s depends_on, so the
#      upstream-notes plugin surfaces the module's commits in each
#      environment's deploy changelog
#   4. publishes its version: a key in zensical.toml, the component in
#      docs' depends_on, and a row in docs/versions.md
#   5. runs `multicz validate --strict`
#
# Steps 3 and 4 are the reason this is a script and not a paragraph in a
# README: they touch four files, and half-doing them fails silently — the
# module releases fine, it just quietly stops appearing anywhere.
#
# Usage: scripts/new-terraform-module.sh <name>        (or: make infra-new-module NAME=<name>)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${REPO_ROOT}/infrastructure/modules/_template"
MULTICZ="${REPO_ROOT}/multicz.toml"

log() { printf '\033[1;34m[new-terraform-module]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[new-terraform-module]\033[0m %s\n' "$*" >&2; exit 1; }

NAME="${1:-}"
[ -n "${NAME}" ] || die "usage: scripts/new-terraform-module.sh <name>"

# Module names end up in a tag (infra-modules-<name>-v1.2.3), a directory
# and a TOML key — keep them boring.
[[ "${NAME}" =~ ^[a-z][a-z0-9-]*$ ]] || \
  die "invalid name '${NAME}': lowercase letters, digits and dashes only, starting with a letter"

DEST="${REPO_ROOT}/infrastructure/modules/${NAME}"
[ ! -e "${DEST}" ] || die "${DEST#"${REPO_ROOT}/"} already exists"
[ -d "${TEMPLATE}" ] || die "template not found at ${TEMPLATE#"${REPO_ROOT}/"}"
COMPONENT="infra-modules-${NAME}"
# zensical.toml keys use underscores (chart_api, chart_migrations, ...).
ZKEY="infra_modules_${NAME//-/_}"
grep -q "^\[components\.${COMPONENT}\]" "${MULTICZ}" && \
  die "multicz.toml already declares [components.${COMPONENT}]"

log "copying _template -> infrastructure/modules/${NAME}"
cp -R "${TEMPLATE}" "${DEST}"

# The template's own docstrings point at _template; make them point at the
# real module so the copy doesn't read like a template forever.
log "substituting the module name"
python3 - "$DEST" "$NAME" <<'PY'
import pathlib, sys

dest, name = pathlib.Path(sys.argv[1]), sys.argv[2]
placeholder_main = """# Placeholder. Copy this directory with `make infra-new-module NAME=<name>`
# (or scripts/new-terraform-module.sh) and replace this with the real
# resources. See ../README.md.
#
# Declaring no resources is what lets the reference unit
# services/example/ plan cleanly before a provider is wired.
"""
main = dest / "main.tf"
main.write_text(
    main.read_text().replace(
        placeholder_main,
        f"# TODO: declare the resources for `{name}` here.\n",
    )
)
for path in dest.rglob("*"):
    if path.is_file() and path.suffix in {".md", ".hcl", ".yml"}:
        path.write_text(path.read_text().replace("infra-modules-<name>", f"infra-modules-{name}"))

# README.md carries the version (there is no VERSION file), so the copy
# needs its title and its template-only preamble rewritten. Everything
# above BEGIN_TF_DOCS is hand-written and survives regeneration.
readme = dest / "README.md"
text = readme.read_text()
text = text.replace("# _template\n", f"# {name}\n", 1)
text = text.replace(
    """Copy this directory with `make infra-new-module NAME=<name>` — that also
registers the module with multicz and wires it into each environment's
`depends_on`. Describe here what the real module creates and how a unit is
expected to consume it.""",
    f"TODO: describe what `{name}` creates and how a unit is expected to consume it.",
)
text = text.replace("../../modules/<name>", f"../../modules/{name}")
readme.write_text(text)
PY

log "generating README.md with terraform-docs"
if command -v terraform-docs >/dev/null 2>&1; then
  terraform-docs -c "infrastructure/modules/${NAME}/.terraform-docs.yml" \
    "infrastructure/modules/${NAME}"
else
  log "terraform-docs not on PATH — README.md keeps an empty docs block (run 'make infra-docs' once installed)"
fi

# --- 2. register the component -----------------------------------------
# Appended rather than inserted at a computed offset: multicz reads the
# whole table, order is cosmetic, and appending can't corrupt a block.
log "registering [components.${COMPONENT}] in multicz.toml"
cat >> "${MULTICZ}" <<EOF

[components.${COMPONENT}]
paths      = ["infrastructure/modules/${NAME}/**"]
# The version lives in README.md — there is no VERSION file. post_bump
# regenerates the terraform-docs block right after the rewrite, so a
# released module always ships docs matching the code that was tagged;
# \`mode: inject\` only touches what sits between the BEGIN/END markers, so
# the **Version:** line survives.
bump_files = [
    { file = "infrastructure/modules/${NAME}/README.md", key = 'regex:^\*\*Version:\*\* (.+)$' },
    { file = "zensical.toml", key = "project.extra.versions.${ZKEY}" },
]
changelog  = "infrastructure/modules/${NAME}/CHANGELOG.md"
post_bump  = ["terraform-docs -c infrastructure/modules/${NAME}/.terraform-docs.yml infrastructure/modules/${NAME}"]
EOF

# --- 3. wire it into every environment's depends_on ---------------------
log "adding ${COMPONENT} to each configs-<env> depends_on"
python3 - "$MULTICZ" "$COMPONENT" <<'PY'
import pathlib, re, sys

path, component = pathlib.Path(sys.argv[1]), sys.argv[2]
text = path.read_text()
touched = []

# Match `depends_on = [...]` inside each [components.configs-<env>] block.
for match in re.finditer(r"^\[components\.(configs-[a-z0-9-]+)\]$", text, re.M):
    env, start = match.group(1), match.end()
    end = text.find("\n[", start)
    block = text[start : end if end != -1 else len(text)]
    dep = re.search(r"depends_on\s*=\s*\[(.*?)\]", block, re.S)
    if not dep or f'"{component}"' in dep.group(1):
        continue
    updated = dep.group(0).replace("]", f', "{component}"]', 1) if dep.group(1).strip() \
        else f'depends_on = ["{component}"]'
    text = text[:start] + block.replace(dep.group(0), updated, 1) + text[start + len(block):]
    touched.append(env)

path.write_text(text)
print("  " + (", ".join(touched) if touched else "(no configs-* component found)"))
PY

# --- 4. publish the version in the docs ---------------------------------
log "publishing ${ZKEY} in zensical.toml, docs depends_on and docs/versions.md"
python3 - "$REPO_ROOT" "$COMPONENT" "$ZKEY" "$NAME" <<'ZPY'
import pathlib, re, sys

root, component, zkey, name = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]

# multicz writes into an existing key; it does not create the table entry.
zen = root / "zensical.toml"
text = zen.read_text()
if f"\n{zkey} " not in text and f"\n{zkey}=" not in text:
    text = text.replace(
        'infra_modules_example = "0.0.0"',
        f'infra_modules_example = "0.0.0"\n{zkey} = "0.0.0"',
        1,
    )
    zen.write_text(text)

# docs cascades on everything that writes into zensical.toml, otherwise the
# page keeps shipping the previous number.
mz = root / "multicz.toml"
text = mz.read_text()
marker = '"infra", "infra-modules-example", "configs-staging", "configs-production",'
# Scope the "already there?" check to the docs block itself. Splitting on
# the header and taking the tail is not enough: the configs-<env> blocks
# sit further down the file and step 3 has just written this component into
# THEIR depends_on, so a looser check finds it and skips silently.
start = text.index("[components.docs]")
end = text.find("\n[", start + 1)
docs_block = text[start : end if end != -1 else len(text)]
if f'"{component}"' not in docs_block:
    text = text[:start] + docs_block.replace(marker, marker + f'\n    "{component}",', 1) + text[start + len(docs_block):]
    mz.write_text(text)

# one row in the modules table, inserted in sorted position.
#
# This used to anchor on the literal `example` row, so reformatting that
# row silently stopped every future module from being listed — the module
# released, and the only page that answers "what version is X" never
# mentioned it. Anchoring on the section instead survives edits to the
# table's contents.
vers = root / "docs" / "versions.md"
text = vers.read_text()
row = f"| `{name}` | {{{{ config.extra.versions.{zkey} }}}} |"
if row not in text:
    start = text.index("### Terraform modules")
    end = text.index("###", start + 3)
    seg = text[start:end]
    lines = seg.splitlines(keepends=True)
    body = [i for i, l in enumerate(lines) if l.startswith("| `")]
    if not body:
        raise SystemExit("docs/versions.md: no module rows found under '### Terraform modules'")
    rows = sorted([lines[i] for i in body] + [row + "\n"])
    seg = "".join(lines[:body[0]]) + "".join(rows) + "".join(lines[body[-1] + 1:])
    vers.write_text(text[:start] + seg + text[end:])
ZPY

# --- 4b. VERSION --------------------------------------------------------
# VERSION lists every component. It was added to the module bump_files by
# hand once, which is exactly the kind of registration that falls behind:
# twenty-four modules were scaffolded and none of them landed here, so the
# file claimed 23 components while multicz.toml knew 47.
VERSION_FILE="${REPO_ROOT}/VERSION"
if grep -q "^${COMPONENT}=" "$VERSION_FILE" 2>/dev/null; then
  log "${COMPONENT} already in VERSION"
else
  python3 - "$VERSION_FILE" "$COMPONENT" <<'VPY'
import pathlib, sys
p, comp = pathlib.Path(sys.argv[1]), sys.argv[2]
t = p.read_text()
marker = "\n# \u2500\u2500 deployed state "
i = t.index(marker)
head, tail = t[:i], t[i:]
# keep the module list sorted so a diff shows one added line
lines = [l for l in head.splitlines() if l.startswith("infra-modules-")]
lines.append(f"{comp}=0.0.0")
rest = [l for l in head.splitlines() if not l.startswith("infra-modules-")]
out, done = [], False
for l in rest:
    out.append(l)
    if l.startswith("# which appends here") and not done:
        out.extend(sorted(lines)); done = True
p.write_text("\n".join(out) + tail)
VPY
  log "added ${COMPONENT} to VERSION"
fi

# --- 5. CI jobs ---------------------------------------------------------
# Generated, not printed. This used to be an item in the "Next:" list,
# which meant four blocks pasted by hand into a 4000-line workflow for
# every module — and forgetting them registered the module everywhere
# except the one place that checks it. A module that releases but is never
# tested is worse than one that does not exist.
CI="${REPO_ROOT}/.github/workflows/ci.yml"
TMPL="${REPO_ROOT}/scripts/templates/ci-module-jobs.yml.tmpl"
if grep -q "^  infra-modules-${NAME}-fmt:" "$CI" 2>/dev/null; then
  log "CI jobs for ${NAME} already present, leaving them alone"
elif [ ! -f "$TMPL" ]; then
  die "missing ${TMPL}"
else
  RENDERED=$(mktemp)
  sed "s/@NAME@/${NAME}/g" "$TMPL" > "$RENDERED"
  # Inserted before release-bump, where the other infra-modules-* jobs
  # live. awk rather than sed: the block is multi-line and contains the
  # slashes and quotes that make a sed insert unreadable.
  awk -v f="$RENDERED" '
    /^  release-bump:$/ && !done {
      while ((getline line < f) > 0) print line
      print ""
      done = 1
    }
    { print }
  ' "$CI" > "${CI}.new" && mv "${CI}.new" "$CI"
  rm -f "$RENDERED"
  log "added 4 CI jobs for ${NAME}"
fi


# --- 6. validate --------------------------------------------------------
if command -v multicz >/dev/null 2>&1; then
  multicz validate --strict
elif command -v uvx >/dev/null 2>&1; then
  uvx multicz validate --strict
else
  log "multicz not on PATH — skipping validate (run 'make release-validate')"
fi

cat <<EOF

  Created infrastructure/modules/${NAME}/ and registered ${COMPONENT}.

  Next:
    1. declare the resources in infrastructure/modules/${NAME}/main.tf
    2. write real assertions in infrastructure/modules/${NAME}/tests/
    3. add a release-infra-modules-${NAME} job modelled on
       release-infra-modules-example, and wire it into release-bump's
       outputs (the four check jobs were generated for you)

    4. consume it from a unit:

         # infrastructure/services/<unit>/terragrunt.hcl
         terraform {
           source = "../../modules/${NAME}"
         }

         exclude {
           if      = !local.config.services.<unit>.enabled
           actions = ["all"]
         }

    5. add that unit's block to configs/staging/config.yaml and
       configs/production/config.yaml
EOF
