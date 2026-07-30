#!/bin/sh
# Xcode Cloud clones the repository, which has no .xcodeproj: the project is
# generated from project.yml. Build it here, before Xcode looks for a scheme.
set -e

brew install xcodegen
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
