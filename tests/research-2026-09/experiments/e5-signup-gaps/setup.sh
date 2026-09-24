cp -R "/Users/schlenks/Developer/personal/superpowers-bd/tests/research-2026-09/experiments/e5-signup-gaps/feature/." . && git add -A && git commit -q -m "feat: validate signup payloads (su-2)"
sha=$(git rev-parse --short HEAD)
python3 - "$sha" <<'PY'
import json, os, sys
rep = open("/Users/schlenks/Developer/personal/superpowers-bd/tests/research-2026-09/experiments/e5-signup-gaps/impl-report.md").read().replace("{sha}", sys.argv[1])
path = os.environ["BD_STUB_DIR"] + "/comments-su-2.json"
json.dump([{"id": 1, "text": rep}], open(path, "w"))
PY
