#!/bin/sh
# Reports are development regressions; holdout is measured separately without training.
set -eu
unset LOCAL_MULTI_CASES LOCAL_ACCURACY_BASELINE LOCAL_ACCURACY_CASES LOCAL_ACCURACY_REPORT
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

python3 LocalModel/check-accuracy-v4.py "$report_dir/v4"
