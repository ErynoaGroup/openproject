#!/usr/bin/env bash
# Fails if any workflow has an active automatic trigger or a runner that is not a free GitHub-hosted label.
# Allowed automatic triggers (exhaustive):
#   erynoa-build.yml:          push with tags only (ragfit-plan-v*), no branches/paths
#   erynoa-upstream-sync.yml:  schedule
# Manual triggers (workflow_dispatch, workflow_call) are always allowed.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
python3 - <<'PY'
import glob, os, re, sys
try:
    import yaml
except ImportError:
    sys.exit("trigger-check: python3 PyYAML missing (pip install pyyaml)")

MANUAL = {"workflow_dispatch", "workflow_call"}
ALLOWED = {
    "erynoa-upstream-sync.yml": {"schedule"},
    "erynoa-build.yml": {"push"},
}
# Free GitHub-hosted runner labels (standard, not "larger runners")
HOSTED = re.compile(r"^(ubuntu-(latest|slim|2[0-9]\.04(-arm)?)|windows-(latest|20[0-9]{2})|macos-(latest|1[0-9]))$")

errors = []
for path in sorted(glob.glob(".github/workflows/*.y*ml")):
    name = os.path.basename(path)
    doc = yaml.safe_load(open(path)) or {}
    on = doc.get(True, doc.get("on"))
    if isinstance(on, str):
        on = {on: None}
    elif isinstance(on, list):
        on = {k: None for k in on}
    on = on or {}
    for trig, cfg in on.items():
        if trig in MANUAL:
            continue
        if trig not in ALLOWED.get(name, set()):
            errors.append(f"{name}: active automatic trigger '{trig}'")
        elif name == "erynoa-build.yml":
            cfg = cfg or {}
            if set(cfg) - {"tags"} or cfg.get("tags") != ["ragfit-plan-v*"]:
                errors.append(f"{name}: push trigger must be tags ['ragfit-plan-v*'] only, got {cfg}")
    for job_id, job in (doc.get("jobs") or {}).items():
        ro = job.get("runs-on") if isinstance(job, dict) else None
        if ro is None:
            continue  # reusable workflow call
        labels = ro if isinstance(ro, list) else ([ro] if isinstance(ro, str) else ["<object>"])
        for lab in labels:
            if isinstance(lab, str) and "${{" in lab:
                continue  # matrix expression, values checked below
            if not (isinstance(lab, str) and HOSTED.match(lab)):
                errors.append(f"{name}: job '{job_id}' runner '{lab}' is not a free GitHub-hosted label")
        # matrix runner values
        for v in ((job.get("strategy") or {}).get("matrix") or {}).get("include", []) or []:
            if isinstance(v, dict) and "runner" in v and not HOSTED.match(str(v["runner"])):
                errors.append(f"{name}: job '{job_id}' matrix runner '{v['runner']}' is not GitHub-hosted")

if errors:
    print("trigger-check: FAILED")
    for e in errors:
        print("  " + e)
    sys.exit(1)
print("trigger-check: clean")
PY
