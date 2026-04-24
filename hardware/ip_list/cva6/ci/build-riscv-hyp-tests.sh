#!/bin/bash
set -e
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION="19760b7a7d72227376d91b1afb0f13915c233efb"

cd $ROOT/tmp

if [ -z ${NUM_JOBS} ]; then
    NUM_JOBS=1
fi

[ -d $ROOT/tmp/riscv-hyp-tests ] || git clone https://github.com/niwis/riscv-hyp-tests.git
cd riscv-hyp-tests
git checkout pulp
git submodule update --init --recursive
make PLAT=cva6 LOG_LEVEL=LOG_DETAIL
