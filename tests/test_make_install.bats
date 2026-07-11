#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

@test "make install PREFIX places bin and share/wslutil" {
    PREFIX="$TEST_TEMP_DIR/pfx"
    run make -C "$BATS_TEST_DIRNAME/.." install PREFIX="$PREFIX"
    [ "$status" -eq 0 ]
    [ -x "$PREFIX/bin/wslutil" ]
    [ -f "$PREFIX/share/wslutil/config/wslutil.yml" ]
    [ -f "$PREFIX/share/wslutil/env/shellenv.bash" ]
    [ -f "$PREFIX/share/wslutil/lib/wslutil-paths.sh" ]
    [ -f "$PREFIX/share/wslutil/VERSION" ]
    [ -L "$PREFIX/bin/wslview" ] || [ -f "$PREFIX/bin/wslview" ]
}

@test "make uninstall leaves shimdir alone under PREFIX share" {
    PREFIX="$TEST_TEMP_DIR/pfx"
    make -C "$BATS_TEST_DIRNAME/.." install PREFIX="$PREFIX"
    mkdir -p "$PREFIX/share/wslutil/bin"
    ln -sf /bin/true "$PREFIX/share/wslutil/bin/dummy.exe"
    run make -C "$BATS_TEST_DIRNAME/.." uninstall PREFIX="$PREFIX"
    [ "$status" -eq 0 ]
    [ ! -e "$PREFIX/bin/wslutil" ]
    [ ! -d "$PREFIX/share/wslutil/config" ]
    [ ! -d "$PREFIX/share/wslutil/env" ]
    [ -L "$PREFIX/share/wslutil/bin/dummy.exe" ]
}
