#!/usr/bin/env bash
# Unit test of accel/accel_socket.sv (tests/tb_accel_socket.sv) on a built work dir: XSIM_WORK=<dir>, whose core count
# sets the user-field layout. Extra arguments go to xsim (e.g. -sv_seed 7). SOCKET_SV=<file> tests
# another version of the socket (e.g. the one of an older commit, from git show).
# The tb's accel_slots stands in for the real one, so the tb and the socket are compiled into a library of their own
# (tb_sock) and the work library keeps the real ones for the SoC. The tb and the socket read the SoC's packages under
# the name soc (inside a compile into tb_sock, "work" names tb_sock); the SoC's units still find theirs as work, the
# same library, so a package such as axi_pkg is elaborated twice (fine for packed types). No --ignore_assertions:
# axi_lite_from_mem's request-stability SVA run.
set -e
source "$(dirname "$0")/../env.sh"
sock=$(realpath "${SOCKET_SV:-$HW/accel/accel_socket.sv}")
WORK=$(realpath "$WORK")
cd "$WORK"
# alsaqr-mcp's runner takes this lock around its tb compile, which rewrites the packages read here
exec 9>"$WORK/elab.lock"; flock 9
# no unit of an earlier run may stand in for $sock
rm -rf xsim.dir/tb_sock xsim.dir/accel_socket_unit
soc="soc=$WORK/xsim.dir/work"
xvlog -sv -work tb_sock -L "$soc" "$XSIM_DIR/tests/tb_accel_socket.sv" "$sock" \
  > xvlog_accel_socket_unit.log 2>&1 || { grep -E "ERROR" xvlog_accel_socket_unit.log | head -5; exit 1; }
grep -q "analyzing module accel_socket$" xvlog_accel_socket_unit.log || { echo "no module accel_socket in $sock"; exit 1; }
# one thread: the design is tiny, and xelab's default runs a burst of parallel jobs
xelab tb_sock.tb_accel_socket -L tb_sock -L "$soc" -s accel_socket_unit --timescale 1ns/1ps --mt off \
  > xelab_accel_socket_unit.log 2>&1 || { grep -E "ERROR" xelab_accel_socket_unit.log | head -5; exit 1; }
# the tb's own watchdog counts clock edges, so a run whose simulation time stops (xsim's combinational rings, see
# ../README.md, section 2) needs this wall-clock bound
rc=0
timeout 600 xsim accel_socket_unit -R -log accel_socket_unit.log "$@" > accel_socket_unit_stdout.log 2>&1 || rc=$?
grep -vE "^(INFO|Time resolution|source |# |run -all|exit|[$]finish called| *[*][*]|$)" accel_socket_unit_stdout.log || true
[ $rc = 124 ] && { echo "ACCEL SOCKET UNIT FAIL: xsim still running after 600 s (simulation time stopped?)"; exit 1; }
# xsim may exit zero after $fatal or with $error messages, so require the explicit success marker and no errors.
! grep -qE "^(Error|Fatal|ERROR|FATAL)" accel_socket_unit_stdout.log && grep -q 'ACCEL SOCKET UNIT PASS' accel_socket_unit_stdout.log
