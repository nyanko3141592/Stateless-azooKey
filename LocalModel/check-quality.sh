#!/bin/sh
# Reports are development regressions; holdout is measured separately without training.
set -eu
unset LOCAL_MULTI_CASES
cd "$(dirname "$0")/.."
report_dir="${1:-$PWD/LocalModel/release-quality}"
mkdir -p "$report_dir"
report_dir="$(cd "$report_dir" && pwd)"
LOCAL_MULTI_REPORT="$report_dir/final.json" \
LOCAL_QUALITY_REPORT="$report_dir/regression-final.json" \
swift test --package-path Core --filter 'localAccuracy|localMulti|localQuality|localModel|localLive|mixed|liveMixed|language|jev'
LOCAL_MULTI_CASES=LocalModel/release-holdout.json \
LOCAL_MULTI_REPORT="$report_dir/holdout.json" \
swift test --package-path Core --filter localMultiSwitchFreshEvaluation

LOCAL_ACCURACY_CASES=LocalModel/accuracy-v2/fresh-evaluation.json \
LOCAL_ACCURACY_REPORT="$report_dir/accuracy-v2-fresh.json" \
swift test --package-path Core --filter localAccuracyComparison
