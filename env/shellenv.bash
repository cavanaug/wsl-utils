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
    ${WIN_COMSPEC} /c "set" 2> /dev/null | win-utf8 | sed -e 's#=\([A-Za-z]\):#=/mnt/\L\1#' -e 's#;\([A-Za-z]\):#;/mnt/\L\1#g' -e 's#\\#/#g' | sort > ${WIN_ENV_FILE}.win
    declare line=""
    rm -f ${WIN_ENV_FILE}.sh
    while IFS= read -r line; do
        #echo "line=\"$line\""
        declare key="${line%%=*}"
        declare value="${line#*=}"
        #echo "key=${key} value=${value}"
        if [[ "$key" =~ [\(\)\#\.] ]]; then
            #echo "SPECIAL HANDLING FOR WIN_ENV[$key]=${win_env[$key]}"
            key="${key//\(/_}"
            key="${key//\)/_}"
            key="${key//\./_}"
            key="${key%_}"
            #echo "NEW key=${key} value=${value}"
        fi
        #WIN_ENV[${key}]="${value}"
        echo WIN_ENV[\'${key}\']=\""${value}\"" >> ${WIN_ENV_FILE}.sh
        #WIN_ENV[${key}]="$(printf "%s" "${value}")" || :
        #echo "WIN_ENV[$key]=${WIN_ENV[${key}]}"
    done < "${WIN_ENV_FILE}.win"
}
declare -g -A -x WIN_ENV

if [[ ! -f ${WIN_ENV_FILE}.sh ]]; then
    build_win_env_sh
fi
source ${WIN_ENV_FILE}.sh
nohup build_win_env_sh &> /dev/null &

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
if [[ "${WSL2_GUI_APPS_ENABLED}" ]]; then
    # Ensure WSL2 GUI apps are enabled and set the DISPLAY variable for GUI applications
    if [[ -z "${DISPLAY}" ]]; then
        export DISPLAY=":0"
    fi

    # This sets up the environment for wslg & Wayland so that things like wl-clipboard work properly
    if [ ! -L "${XDG_RUNTIME_DIR}/wayland-0" ] && [ "$(readlink -f ${XDG_RUNTIME_DIR}/wayland-0)" != "/mnt/wslg/runtime-dir/wayland-0" ]; then
        ln -s /mnt/wslg/runtime-dir/wayland-0 $XDG_RUNTIME_DIR
        ln -s /mnt/wslg/runtime-dir/wayland-0.lock $XDG_RUNTIME_DIR
    fi

    # Ensure the Wayland socket is available for GUI applications
    if [[ -S "${XDG_RUNTIME_DIR}/wayland-0" ]]; then
        export WAYLAND_DISPLAY="wayland-0"
    fi

    # Fix the scaling for high DPI displays in WSL2 GUI apps
    if command -v wayland-info > /dev/null; then
        if [[ "$(wayland-info | grep refresh | cut -f2 -d' ')" -ge 3840 ]]; then
            export GDK_SCALE=${GDK_SCALE:-1.5}
            export GDK_DPI_SCALE=${GDK_DPI_SCALE:-1.5}
            export QT_SCALE_FACTOR=${QT_SCALE_FACTOR:-1.5}
        fi
    fi
else
    # Fallback to X11 if GUI apps are not enabled
    export DISPLAY=":0"
fi
