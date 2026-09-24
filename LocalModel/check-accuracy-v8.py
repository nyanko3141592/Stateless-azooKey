"""Reproduce frozen-v7 comparisons and enforce v8 development release floors."""
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
out = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "LocalModel/accuracy-v8/recheck"
out.mkdir(parents=True, exist_ok=True)
fixtures = {
    "prior80": "accuracy-v2/fresh-evaluation.json",
    "multi": "multiswitch-evaluation.json",
    "prior24": "release-holdout.json",
    "prior48": "accuracy-v3/fresh-evaluation.json",
    "priorfinal24": "accuracy-v3/final-unseen.json",
    "development48": "accuracy-v4/development.json",
    "final40": "accuracy-v4/final-evaluation.json",
    "fresh48": "accuracy-v5/fresh-evaluation.json",
    "developmentV6": "accuracy-v6/fresh-evaluation.json",
    "finalV6": "accuracy-v6/final-evaluation.json",
    "finalV7": "accuracy-v7/final-evaluation-corrected.json",
    "finalV8": "accuracy-v8/final-evaluation.json",
}
summary = {}
for name, fixture in fixtures.items():
    report = out / (name + ".json")
    env = {k: v for k, v in os.environ.items() if not k.startswith("LOCAL_ACCURACY_")}
    env.update(LOCAL_ACCURACY_BASELINE="45e8da8", LOCAL_ACCURACY_CASES="LocalModel/" + fixture,
               LOCAL_ACCURACY_REPORT=str(report))
    with (out / (name + ".log")).open("w") as log:
        subprocess.run(["swift", "test", "--package-path", str(root / "Core"), "--skip-build",
                        "--filter", "localAccuracyComparison"], env=env, stdout=log,
                       stderr=subprocess.STDOUT, check=True)
    rows = json.loads(report.read_text())
    stats = {}
    for version in ["45e8da8", "current"]:
        r = [x for x in rows if x["version"] == version]
        stats[version] = dict(exact=sum(x["exact"] for x in r), count=len(r),
                             damage=sum(x["damagedEnglishFrames"] for x in r),
                             reversals=sum(x["labelReversalFrames"] for x in r))
    before = {x["id"]: x for x in rows if x["version"] == "45e8da8"}
    assert not any(before[x["id"]]["exact"] and not x["exact"] for x in rows if x["version"] == "current"), name
    summary[name] = stats
    print(name, stats, flush=True)
(out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
assert summary["prior80"]["current"]["exact"] >= 80
assert summary["prior80"]["current"]["damage"] <= 50
assert summary["final40"]["current"]["exact"] >= 40
assert summary["development48"]["current"]["exact"] >= 48
assert summary["fresh48"]["current"]["exact"] >= 45
assert summary["fresh48"]["current"]["damage"] <= 59
for name, stats in summary.items():
    assert stats["current"]["damage"] <= stats["45e8da8"]["damage"], name
assert summary["finalV6"]["current"]["exact"] >= 37
assert summary["finalV6"]["current"]["damage"] <= 117
assert summary["finalV7"]["current"]["exact"] >= 39
assert summary["finalV7"]["current"]["damage"] <= 115
assert summary["finalV8"]["current"]["exact"] >= 27
assert summary["finalV8"]["current"]["damage"] <= 302
print("V8 goals passed. All sets are now development regressions; not new held-out evidence.")
