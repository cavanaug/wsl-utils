declare -g -x WIN_WINDIR=${WIN_WINDIR:-/mnt/c/Windows}
if [[ ! -d $WIN_WINDIR ]]; then
    echo "ERROR: WIN_WINDIR is not configured and unable to find WINDOWS" >&2
    exit 1
fi

if [[ ! ":$PATH:" == *":${WSLUTIL_DIR}/bin:"* ]]; then
    export PATH="${WSLUTIL_DIR}/bin:${PATH}"
fi
export WSL_INTEROP=${WSL_INTEROP:-/run/WSL/1_interop}
if test ! -S ${WSL_INTEROP}; then
    echo "ERROR: WSL_INTEROP is not configured properly" >&2
    exit 1
fi

# TODO: Create wsl vars here based on XDG variables if set, else use the defaults.  These vars should then be used in the rest of the script and unset at the end to avoid environment pollution.
mkdir -p "${HOME}/.cache/wslutil"
mkdir -p "${HOME}/.local/state/wslutil"

# WSL2-specific environment variables and functions
declare WIN_ENV_FILE="${HOME}/.cache/wslutil/env"
declare WIN_COMSPEC="/mnt/c/Windows/System32/cmd.exe"

if [[ ! -f "${WIN_COMSPEC}" ]]; then
    WIN_ERROR="ERROR: Windows system32 cmd.exe not found at ${WIN_COMSPEC}"
    echo "${WIN_ERROR}" >&2
    exit 1
fi

#
# Setup the WIN_* global environment variables for WINDOWS for use in any cli usage
#
# WIN_ENV is a dictionary of all environment variables from cmd.exe that can be used in bash
# - Source ${WIN_ENV}.sh to gain access to these variables
# - Any directories in these variables will be converted to WSL format
build_win_env_sh() {
    local lockfile="${WIN_ENV_FILE}.lock"
    local temp_sh="${WIN_ENV_FILE}.sh.$$"
    local temp_win="${WIN_ENV_FILE}.win.$$"
    
    # Try to acquire exclusive lock (non-blocking)
    # Returns immediately if another process holds the lock
    exec 200>"${lockfile}"
    if ! flock -n 200; then
        # Another process is building - skip
        exec 200>&-
        return 1
    fi
    
    # We have the lock - build the cache
    ${WIN_COMSPEC} /c "set" 2>/dev/null | win-utf8 | \
        sed -e 's#=\([A-Za-z]\):#=/mnt/\L\1#' \
            -e 's#;\([A-Za-z]\):#;/mnt/\L\1#g' \
            -e 's#\\#/#g' | sort > "${temp_win}"
    
    declare line=""
    while IFS= read -r line; do
        declare key="${line%%=*}"
        declare value="${line#*=}"
        if [[ "$key" =~ [\(\)\#\.] ]]; then
            key="${key//\(/_}"
            key="${key//\)/_}"
            key="${key//\./_}"
            key="${key%_}"
        fi
        echo WIN_ENV[\'${key}\']=\""${value}\"" >> "${temp_sh}"
    done < "${temp_win}"
    
    # Atomic rename (only successful if build completed)
    if [[ -f "${temp_sh}" ]] && [[ -f "${temp_win}" ]]; then
        mv -f "${temp_win}" "${WIN_ENV_FILE}.win"
        mv -f "${temp_sh}" "${WIN_ENV_FILE}.sh"
    fi
    
    # Clean up temp files if they still exist
    rm -f "${temp_sh}" "${temp_win}"
    
    # Release lock (fd 200 closes automatically, but explicit is clearer)
    exec 200>&-
}

# Wait for any in-progress build to complete
wait_for_build_complete() {
    local lockfile="${WIN_ENV_FILE}.lock"
    
    # Try to acquire lock with 5 second timeout
    # If we get it, build is done; release immediately
    exec 201>"${lockfile}"
    if flock -w 5 201; then
        exec 201>&-
        return 0
    else
        exec 201>&-
        return 1
    fi
}

declare -g -A -x WIN_ENV

# Initial cache check and build
if [[ ! -f "${WIN_ENV_FILE}.sh" ]]; then
    # No cache exists - build it synchronously (foreground)
    build_win_env_sh
else
    # Cache exists - check if it's stale (>1 hour old)
    if [[ -n $(find "${WIN_ENV_FILE}.sh" -mmin +60 2>/dev/null) ]]; then
        # Stale cache - trigger background rebuild
        # Use subshell to avoid polluting current environment
        (build_win_env_sh) &>/dev/null &
    fi
fi

# Wait for any in-progress build to complete
wait_for_build_complete

# Source the cache (guaranteed to exist and be complete now)
if [[ -f "${WIN_ENV_FILE}.sh" ]]; then
    source "${WIN_ENV_FILE}.sh"
fi

declare -g -x WIN_APPDATA="${WIN_ENV[APPDATA]}"
declare -g -x WIN_LOCALAPPDATA="${WIN_ENV[LOCALAPPDATA]}"
declare -g -x WIN_COMPUTERNAME="${WIN_ENV[COMPUTERNAME]}"
declare -g -x WIN_USERNAME="${WIN_ENV[USERNAME]}"
declare -g -x WIN_USERDOMAIN="${WIN_ENV[USERDOMAIN]}"
declare -g -x WIN_USERPROFILE="${WIN_ENV[USERPROFILE]}"
declare -g -x WIN_PROGRAMFILES="${WIN_ENV[ProgramFiles]}"
declare -g -x WIN_PROGRAMFILES_X86="${WIN_ENV['ProgramFiles_x86']}"
declare -g -x WIN_HOMEPATH="${WIN_ENV[HOMEDRIVE]}${WIN_ENV[HOMEPATH]}"

#
# Setup the graphical environment for WSL2 GUI apps
# - wslg is required for things like clipboard support
# - Attempt to correct scaling for high DPI displays
#
#  WARNING: This technically shouldnt be needed anymore with modern WSL/WSLg
#
# if [[ "${WSL2_GUI_APPS_ENABLED}" ]]; then
#     # Ensure WSL2 GUI apps are enabled and set the DISPLAY variable for GUI applications
#     if [[ -z "${DISPLAY}" ]]; then
#         export DISPLAY=":0"
#     fi
#
#     # This sets up the environment for wslg & Wayland so that things like wl-clipboard work properly
#     if [ ! -L "${XDG_RUNTIME_DIR}/wayland-0" ] && [ "$(readlink -f ${XDG_RUNTIME_DIR}/wayland-0)" != "/mnt/wslg/runtime-dir/wayland-0" ]; then
#         ln -s /mnt/wslg/runtime-dir/wayland-0 $XDG_RUNTIME_DIR
#         ln -s /mnt/wslg/runtime-dir/wayland-0.lock $XDG_RUNTIME_DIR
#     fi
#
#     # Ensure the Wayland socket is available for GUI applications
#     if [[ -S "${XDG_RUNTIME_DIR}/wayland-0" ]]; then
#         export WAYLAND_DISPLAY="wayland-0"
#     fi
#
#     # Fix the scaling for high DPI displays in WSL2 GUI apps
#     if command -v wayland-info > /dev/null; then
#         if [[ "$(wayland-info | grep refresh | cut -f2 -d' ')" -ge 3840 ]]; then
#             export GDK_SCALE=${GDK_SCALE:-1.5}
#             export GDK_DPI_SCALE=${GDK_DPI_SCALE:-1.5}
#             export QT_SCALE_FACTOR=${QT_SCALE_FACTOR:-1.5}
#         fi
#     fi
# else
#     # Fallback to X11 if GUI apps are not enabled
#     export DISPLAY=":0"
# fi
