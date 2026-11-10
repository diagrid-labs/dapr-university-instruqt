#!/usr/bin/env bash
# Validate a lab that consumes the registry module `diagrid/dapr-sandbox`.
# `instruqt lab validate` cannot resolve registry sources or local modules outside the lab root,
# so this validates a temporary copy of the lab with the module block rewritten to a local copy.
# Usage: validate-lab.sh <lab-dir> <module-dir>
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <lab-dir> <module-dir>" >&2
  exit 2
fi
lab_dir=$1
module_dir=$2
[[ -d $lab_dir ]] || { echo "validate-lab: lab dir not found: $lab_dir" >&2; exit 2; }
[[ -d $module_dir ]] || { echo "validate-lab: module dir not found: $module_dir" >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp -R "$lab_dir/." "$tmp/"
mkdir -p "$tmp/modules/dapr-sandbox"
cp -R "$module_dir/." "$tmp/modules/dapr-sandbox/"

# Rewrite `source = "diagrid/dapr-sandbox"` and drop the `version` line in the module "sandbox" block.
rewritten=0
while IFS= read -r f; do
  if grep -q 'source[[:space:]]*=[[:space:]]*"diagrid/dapr-sandbox"' "$f"; then
    python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
def fix(m):
    block = m.group(0)
    block = re.sub(r'source\s*=\s*"diagrid/dapr-sandbox"', 'source = "./modules/dapr-sandbox"', block)
    block = re.sub(r'\n[ \t]*version\s*=\s*"[^"]*"[ \t]*(?=\n)', '', block)
    return block
new = re.sub(r'module\s+"[^"]+"\s*\{.*?\n\}', lambda m: fix(m) if 'diagrid/dapr-sandbox' in m.group(0) else m.group(0), s, flags=re.S)
open(p, 'w').write(new)
PY
    rewritten=1
  fi
done < <(find "$tmp" -path "$tmp/modules" -prune -o -name '*.hcl' -print)

if [[ $rewritten -eq 0 ]]; then
  echo "validate-lab: no module block with source = \"diagrid/dapr-sandbox\" found in $lab_dir" >&2
  exit 1
fi

instruqt lab validate "$tmp"
