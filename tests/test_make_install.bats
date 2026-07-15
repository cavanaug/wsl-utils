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
    [ -x "$PREFIX/bin/wslutil-setup" ]
    [ -x "$PREFIX/bin/wslutil-setup-linux" ]
    [ -x "$PREFIX/bin/win-env" ]
    [ -f "$PREFIX/share/wslutil/config/wslutil.yml" ]
    [ -f "$PREFIX/share/wslutil/env/shellenv.bash" ]
    [ -f "$PREFIX/share/wslutil/lib/wslutil-paths.sh" ]
    [ -f "$PREFIX/share/wslutil/lib/wslutil-setup-common.sh" ]
    [ -f "$PREFIX/share/wslutil/VERSION" ]
    [ -L "$PREFIX/bin/wslview" ] || [ -f "$PREFIX/bin/wslview" ]
}

@test "wslutil doctor tolerates unset WIN_* environment variables" {
    run env -u WIN_USERPROFILE -u WIN_WINDIR "$BATS_TEST_DIRNAME/../bin/wslutil-doctor"
    [ "$status" -eq 0 ]
    [[ "$output" =~ win-env\ USERPROFILE ]]
    [[ "$output" != *unbound\ variable* ]]
}

@test "wslutil doctor reports VERSION for prefix install" {
    PREFIX="$TEST_TEMP_DIR/pfx"
    make -C "$BATS_TEST_DIRNAME/.." install PREFIX="$PREFIX"
    run env PATH="$PREFIX/bin:$PATH" "$PREFIX/bin/wslutil-doctor"
    [ "$status" -eq 0 ]
    [[ "$output" =~ Installed\ version: ]]
    [[ ! "$output" =~ not\ a\ git\ repository ]]
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
