#!/usr/bin/env bash
# Deploys öv AI to production (ov-ai-5ae61): Cloud Functions, Firestore and
# Storage rules, and the Flutter web app on Firebase Hosting.
# Run from a clean checkout of main after `npx firebase-tools login`.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=ov-ai-5ae61
FLUTTER_VERSION=3.41.7
FIREBASE=(npx -y firebase-tools@latest)

branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$branch" != main ]]; then
  echo "Deploy from main (current branch: $branch)." >&2
  exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Commit or stash local changes before deploying." >&2
  exit 1
fi
if ! flutter --no-version-check --version | grep -q "Flutter $FLUTTER_VERSION"; then
  echo "Flutter $FLUTTER_VERSION is required (see 'flutter --version')." >&2
  exit 1
fi

echo "== Functions: install, build, unit tests"
npm ci
npm test

echo "== App: analyze, test, build web"
(
  cd app
  flutter --no-version-check pub get
  flutter --no-version-check analyze
  flutter --no-version-check test
  flutter --no-version-check build web --release --no-wasm-dry-run
)

echo "== Deploy to $PROJECT"
"${FIREBASE[@]}" deploy --project "$PROJECT" \
  --only functions,firestore:rules,storage,hosting

echo "Done: https://$PROJECT.web.app  ·  https://$PROJECT.web.app/privacy.html"
