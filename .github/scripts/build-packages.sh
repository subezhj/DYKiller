#!/usr/bin/env bash

set -euo pipefail

rm -rf packages
mkdir -p packages

make package-rootful FINALPACKAGE=1
make package-rootless FINALPACKAGE=1
make package-roothide FINALPACKAGE=1

version=$(awk -F': *' '$1 == "Version" { print $2; exit }' control)
if [[ -f "packages/DYKiller.dylib" ]]; then
    mv "packages/DYKiller.dylib" "packages/DYKiller_${version}.dylib"
fi
