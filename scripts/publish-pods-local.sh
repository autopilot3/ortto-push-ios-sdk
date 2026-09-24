#!/usr/bin/env bash
# Publish all Ortto pods for a tag from a local machine, in dependency order.
# Stopgap while GitHub Actions is disabled on this repo (deploy.yml is the CI
# equivalent). Needs CocoaPods installed and a trunk session for a pod owner
# (pod trunk register). Usage:
#   scripts/publish-pods-local.sh v1.10.0
set -euo pipefail

tag="${1:?usage: publish-pods-local.sh <tag, e.g. v1.10.0>}"
cd "$(dirname "$0")/.."

echo "--- trunk session"
pod trunk me

echo "--- checking out ${tag}"
git fetch --tags --quiet
previous_ref="$(git rev-parse --abbrev-ref HEAD)"
git -c advice.detachedHead=false checkout --quiet "$tag"
trap 'git checkout --quiet "$previous_ref"' EXIT

# Dependency order: Core -> PushMessaging -> FCM/APNS -> InAppNotifications.
# Each push retries a few times because trunk's CDN can take minutes to see
# the previous pod, which fails the next pod's lint.
for spec in OrttoSDKCore OrttoPushMessaging OrttoPushMessagingFCM OrttoPushMessagingAPNS OrttoInAppNotifications; do
  for attempt in 1 2 3 4 5; do
    echo "--- pushing ${spec} (attempt ${attempt})"
    if pod trunk push "${spec}.podspec" --allow-warnings --synchronous; then
      break
    fi
    if [ "$attempt" -eq 5 ]; then
      echo "${spec} failed after 5 attempts" >&2
      exit 1
    fi
    echo "waiting 90s for trunk CDN before retrying ${spec}"
    sleep 90
  done
done

echo "--- published versions on trunk:"
curl -s https://trunk.cocoapods.org/api/v1/pods/OrttoSDKCore |
  python3 -c 'import json,sys; print([v["name"] for v in json.load(sys.stdin)["versions"][-3:]])'
