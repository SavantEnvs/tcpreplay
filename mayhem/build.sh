#!/usr/bin/env bash
#
# mayhem/build.sh — build tcpreplay's fuzz targets AND its upstream functional test suite.
#
# Mayhem targets (historical names preserved for the first two):
#   tcpcapinfo    — the upstream pcap-info CLI, a natural file-input parser, built sanitized so
#                   Mayhem fuzzes the real pcap-parsing code path (@@ file input).
#   dualmac2hex   — an in-process libFuzzer harness over common/mac.c:dualmac2hex(), linked against
#                   the sanitized libcommon.a.
#   fuzz_pcap     — upstream's own OSS-Fuzz harness (test/fuzz/fuzz_pcap.c): libpcap read path +
#                   the shared header parsers (§6.2 item 12 — OSS-Fuzz harness parity).
#   fuzz_fragroute — upstream's OSS-Fuzz harness over the fragroute rules parser + module chain
#                   (test/fuzz/fuzz_fragroute.c); needs libdumbnet (installed as root, below).
#   fuzz_services — upstream's OSS-Fuzz harness over the tcpprep --services parser
#                   (test/fuzz/fuzz_services.c).
#
# The fuzzed code (libcommon + tcpcapinfo + fragroute) is built with $SANITIZER_FLAGS +
# $DEBUG_FLAGS. The test suite (tcpprep/tcprewrite/tcpreplay) is built SEPARATELY with the
# project's normal flags so mayhem/test.sh only RUNS it and won't false-fail on benign UB. autogen
# (the AutoOpts generator), libpcap, libdumbnet, asciidoctor (upstream issue 895 — src/*.1 man
# pages + src/*_opts.c/h are generated, not committed) and the system libopts are provided by the
# image (installed as root in mayhem/Dockerfile).
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

INSTALL_PREFIX=/mayhem/install
COMMON_A="$SRC/src/common/libcommon.a"
HARNESS="$SRC/mayhem/fuzz_dualmac2hex.cpp"

# 1) SANITIZED build — instrument the fuzzed code (libcommon.a + the tcpcapinfo CLI). Build only the
#    artifacts the fuzz targets need (skip the man-page/all targets, which need groff-style tooling).
./autogen.sh
./configure CC="$CC" CFLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS" \
    --disable-local-libopts --prefix="$INSTALL_PREFIX"
make -C src/common -j"$MAYHEM_JOBS"
# The AutoOpts *_opts.{c,h} are generated at build time; a parallel `make` can start compiling the
# tool before its generated header is fully written ("unterminated /* comment"). Build the tools
# serially so the generation ordering holds. `tcpcapinfo_opts.h`'s only Makefile.am dependency edge
# is the literal (unexpanded) `tcpcapinfo_OBJECTS: tcpcapinfo_opts.h` line, which is a no-op — the
# variable name, not $(tcpcapinfo_OBJECTS) — so on a from-clean checkout (no .deps/ yet) `make
# tcpcapinfo` alone never generates the header before compiling tcpcapinfo_opts.c, which #includes
# it ("tcpcapinfo_opts.h file not found"). Generate it explicitly first.
make -C src tcpcapinfo_opts.h
make -C src tcpcapinfo
install -D -m0755 "$SRC/src/tcpcapinfo" "$INSTALL_PREFIX/bin/tcpcapinfo"
# libfragroute.a, sanitized — fuzz_fragroute exercises fragroute.c and the module chain directly.
# configure auto-detects libdumbnet (installed as root below) and generates this Makefile
# unconditionally; only the top-level SUBDIRS recursion is gated on COMPILE_FRAGROUTE.
make -C src/fragroute -j"$MAYHEM_JOBS"

# 2) dualmac2hex harness — fuzzer binary + standalone (run-once, no libFuzzer runtime) reproducer.
#    The C++ harness keeps LLVMFuzzerTestOneInput at C linkage; compile the standalone main as C.
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    "$HARNESS" "$COMMON_A" -lpcap -o /mayhem/fuzz_dualmac2hex
$CC  $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS \
    "$HARNESS" /tmp/standalone_main.o "$COMMON_A" -lpcap -o /mayhem/fuzz_dualmac2hex-standalone

# 2b) Upstream's own OSS-Fuzz harnesses (test/fuzz/*.c) — plain C, each paired with
#     fuzz_globals.c (the "debug" global libcommon.a references only in a --enable-debug build;
#     harmless to always link). Built by hand (not via autotools --enable-fuzzer) so they honor
#     the same $SANITIZER_FLAGS/$LIB_FUZZING_ENGINE override contract as dualmac2hex above,
#     instead of the hardcoded -fsanitize=fuzzer,address in test/fuzz/Makefile.am.
FUZZ_INC="-I$SRC -I$SRC/src -I$SRC/test/fuzz"
FRAGROUTE_A="$SRC/src/fragroute/libfragroute.a"
LDNETLIB="$(dumbnet-config --libs 2>/dev/null || true)"

build_fuzz_target () {
    # $1 = target name (test/fuzz/<name>.c); $2... = extra link libs (order matters for .a's)
    #
    # -fsanitize=fuzzer-no-link at the -c step adds SanitizerCoverage instrumentation to the
    # harness object without pulling in libFuzzer's own main() (that only comes from the full
    # $LIB_FUZZING_ENGINE at the link step below) — same convention as every other split
    # compile+link target in this fleet (rtpproxy, tinyxml2, dislocker, muparser, gdcm, pike).
    # Without this, the compiled .o carries no __sancov_* sections and Mayhem sees edges=0.
    local name="$1"; shift
    $CC $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link $FUZZ_INC -DHAVE_CONFIG_H \
        -c "$SRC/test/fuzz/${name}.c" -o "/tmp/${name}.o"
    $CC $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link $FUZZ_INC -DHAVE_CONFIG_H \
        -c "$SRC/test/fuzz/fuzz_globals.c" -o "/tmp/${name}_globals.o"
    $CXX $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
        "/tmp/${name}.o" "/tmp/${name}_globals.o" "$@" -o "/mayhem/${name}"
    $CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main2.o
    $CXX $SANITIZER_FLAGS $DEBUG_FLAGS \
        "/tmp/${name}.o" "/tmp/${name}_globals.o" /tmp/standalone_main2.o "$@" \
        -o "/mayhem/${name}-standalone"
}

build_fuzz_target fuzz_pcap "$COMMON_A" -lpcap
build_fuzz_target fuzz_services "$COMMON_A"
build_fuzz_target fuzz_fragroute "$FRAGROUTE_A" "$COMMON_A" -lpcap $LDNETLIB

# 3) NORMAL build of the tools the upstream test suite drives (independent, unsanitized). Left in
#    $SRC/src for mayhem/test.sh. distclean drops the sanitized config; regenerate + reconfigure.
make distclean
./autogen.sh
env -u CFLAGS -u LDFLAGS ./configure --disable-local-libopts CFLAGS="$COVERAGE_FLAGS" LDFLAGS="$COVERAGE_FLAGS"
make -C src/common -j"$MAYHEM_JOBS"
make -C src/tcpedit -j"$MAYHEM_JOBS"
# tcprewrite links against libfragroute.a (--fragroute support); fragroute is enabled (libdumbnet
# is installed) but not part of the tcpedit/common builds above.
make -C src/fragroute -j"$MAYHEM_JOBS"
# Same missing-header-on-first-build issue as tcpcapinfo above (the Makefile.am dependency edge
# for each tool's generated *_opts.h is an unexpanded literal, a no-op) — generate them explicitly
# before requesting the binaries.
make -C src tcpprep_opts.h tcprewrite_opts.h tcpreplay_opts.h
make -C src tcpprep tcprewrite tcpreplay
