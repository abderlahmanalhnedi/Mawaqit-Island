#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build/tests
swiftc -swift-version 5 Sources/MawaqitCore.swift Sources/NotchGeometry.swift Tests/main.swift -o build/tests/MawaqitCoreTests
build/tests/MawaqitCoreTests
