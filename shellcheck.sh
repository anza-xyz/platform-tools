#!/usr/bin/env bash
#
# Reference: https://github.com/koalaman/shellcheck/wiki/Directive
set -e

cd "$(dirname "$0")"

set -x
docker pull koalaman/shellcheck
find . -name "*.sh" \
       -not -regex ".*/llvm/.*" \
    -print0 \
  | xargs -0 \
      docker run --workdir /llvm-builder --volume "$PWD:/llvm-builder" --rm koalaman/shellcheck --color=always --external-sources --shell=bash

exit 0
