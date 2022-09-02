#!/usr/bin/env bash
# Copyright 2021 Sony Group Corporation. All rights reserved.
# Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# ---------------------------------- NOTE ---------------------------------- #
#
# Please keep the logic in this file consistent with the logic in the
# `shared.bat` script in the same directory to ensure that Flutter continue
# to work across all platforms!
#
# -------------------------------------------------------------------------- #

set -e

# Needed because if it is set, cd may print the path it changed to.
unset CDPATH

FLUTTER_REPO="https://github.com/flutter/flutter.git"

if [[ -z "$BIN_DIR" ]]; then
  echo "BIN_DIR is not set."
  exit 1
fi
ROOT_DIR="$(cd "${BIN_DIR}/.." ; pwd -P)"
FLUTTER_DIR="$ROOT_DIR/flutter"
SNAPSHOT_PATH="$ROOT_DIR/bin/cache/flutter-elinux.snapshot"

FLUTTER_EXE="$FLUTTER_DIR/bin/flutter"
DART_EXE="$FLUTTER_DIR/bin/cache/dart-sdk/bin/dart"

function update_flutter() {
  if [[ -e "$FLUTTER_DIR" && ! -d "$FLUTTER_DIR/.git" ]]; then
    echo "$FLUTTER_DIR is not a git directory. Remove it and try again."
    exit 1
  fi

  # Clone flutter repo if not installed.
  if [[ ! -d "$FLUTTER_DIR" ]]; then
    git clone --depth=1 "$FLUTTER_REPO" "$FLUTTER_DIR"
  fi

  # GIT_DIR and GIT_WORK_TREE are used in the git command.
  export GIT_DIR="$FLUTTER_DIR/.git"
  export GIT_WORK_TREE="$FLUTTER_DIR"

  # Update flutter repo if needed.
  local version="$(cat "$ROOT_DIR/bin/internal/flutter.version")"
  if [[ "$version" != "$(git rev-parse HEAD)" ]]; then
    git reset --hard
    git clean -xdf
    git fetch --depth=1 "$FLUTTER_REPO" "$version"
    git checkout FETCH_HEAD

    # Invalidate the cache.
    rm -fr "$ROOT_DIR/bin/cache"
  fi

  if [[ "$version" != "$(git rev-parse HEAD)" ]]; then
    echo "Something went wrong when upgrading the Flutter SDK." \
         "Remove directory $FLUTTER_DIR and try again."
    exit 1
  fi

  unset GIT_DIR
  unset GIT_WORK_TREE

  # Invalidate the flutter cache.
  local stamp_path="$FLUTTER_DIR/bin/cache/flutter_tools.stamp"
  if [[ ! -f "$stamp_path" || "$version" != "$(cat "$stamp_path")" ]]; then
    "$FLUTTER_EXE" --version
  fi
}

function update_flutter_elinux() {
  mkdir -p "$ROOT_DIR/bin/cache"

  local revision="$(git --git-dir="$ROOT_DIR/.git" rev-parse HEAD)"
  local stamp_path="$ROOT_DIR/bin/cache/flutter-elinux.stamp"

  if [[ ! -f "$SNAPSHOT_PATH" || ! -s "$stamp_path" || "$revision" != "$(cat "$stamp_path")" 
        || "$ROOT_DIR/pubspec.yaml" -nt "$ROOT_DIR/pubspec.lock" ]]; then
    echo "Running pub upgrade..."
    (cd "$ROOT_DIR" && "$FLUTTER_EXE" pub upgrade) || {
      >&2 echo "Error: Unable to 'pub upgrade' flutter-elinux."
      exit 1
    }

    echo "Compiling flutter-elinux..."
    "$DART_EXE" --disable-dart-dev --no-enable-mirrors \
                --snapshot="$SNAPSHOT_PATH" --packages="$ROOT_DIR/.dart_tool/package_config.json" \
                "$ROOT_DIR/bin/flutter_elinux.dart"

    echo "$revision" > "$stamp_path"
  fi
}

function exec_snapshot() {
  "$DART_EXE" --disable-dart-dev --packages="$ROOT_DIR/.dart_tool/package_config.json" "$SNAPSHOT_PATH" "$@"
}
