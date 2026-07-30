#!/bin/sh
# Xcode Cloud clones the repository, which has no .xcodeproj: the project is
# generated from project.yml. Build it here, before Xcode looks for a scheme.
set -e

brew install xcodegen
cd "$CI_PRIMARY_REPOSITORY_PATH"

# App Store Connect refuses a build number it has already seen, and the one in
# project.yml never moves. Xcode Cloud counts its own runs, so stamp that in
# before the project is generated.
if [ -n "$CI_BUILD_NUMBER" ]; then
  sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"$CI_BUILD_NUMBER\"/" project.yml
  echo "Build number set to $CI_BUILD_NUMBER"
fi

xcodegen generate
