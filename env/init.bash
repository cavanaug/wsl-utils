declare -x WIN_WINDIR=${WIN_WINDIR:-/mnt/c/Windows}
if [[ ! -d $WIN_WINDIR ]]; then
    echo "ERROR: WIN_WINDIR is not configured and unable to find WINDOWS"
    exit 1
fi

if [[ ! ":$PATH:" == *":${WSLUTIL_DIR}/bin:"* ]]; then
    export PATH="${WSLUTIL_DIR}/bin:${PATH}"
fi

mkdir -p "${HOME}/.cache/wslutil"
mkdir -p "${HOME}/.local/state/wslutil"

# Mount this WSL distro's root directory under /mnt/wsl
if ! mountpoint -q "/mnt/wsl/${WSL_DISTRO_NAME}"; then
    mkdir -p "/mnt/wsl/${WSL_DISTRO_NAME}"
    # HACK:  Clever way to avoid the need to use sudo to run a command
    wsl.exe -d "${WSL_DISTRO_NAME}" -u root mount --bind / "/mnt/wsl/${WSL_DISTRO_NAME}/"
fi

# WSL2-specific environment variables and functions
declare WIN_ENV_FILE="${HOME}/.cache/wslutil/env"
declare WIN_COMSPEC="/mnt/c/Windows/System32/cmd.exe"

if [[ ! -f "${WIN_COMSPEC}" ]]; then
    WIN_ERROR="ERROR: Windows system32 cmd.exe not found at ${WIN_COMSPEC}"
    echo "${WIN_ERROR}"
    exit 1
fi

# Set some global environment variables for WINDOWS for use in any cli usage
declare -g -A -x WIN_ENV
${WIN_COMSPEC} /c "set" 2> /dev/null | tr -d '\r' | sed -e 's/[\d128-\d255]//g' -e 's#=\([A-Za-z]\):#=/mnt/\L\1#' -e 's#;\([A-Za-z]\):#;/mnt/\L\1#g' -e 's#\\#/#g' | sort > $WIN_ENV_FILE
declare line=""
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
    WIN_ENV[${key}]="${value}"
    #WIN_ENV[${key}]="$(printf "%s" "${value}")" || :
    #echo "WIN_ENV[$key]=${WIN_ENV[${key}]}"
done < "${WIN_ENV_FILE}"

declare -g -x WIN_APPDATA="${WIN_ENV[APPDATA]}"
declare -g -x WIN_COMPUTERNAME="${WIN_ENV[COMPUTERNAME]}"
declare -g -x WIN_USERNAME="${WIN_ENV[USERNAME]}"
declare -g -x WIN_USERDOMAIN="${WIN_ENV[USERDOMAIN]}"
declare -g -x WIN_USERPROFILE="${WIN_ENV[USERPROFILE]}"
declare -g -x WIN_HOMEPATH="${WIN_ENV[HOMEDRIVE]}${WIN_ENV[HOMEPATH]}"

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
            export GDK_SCALE=${GDK_SCALE:-1}
            export GDK_DPI_SCALE=${GDK_DPI_SCALE:-1}
            export QT_SCALE_FACTOR=${QT_SCALE_FACTOR:-1}
        fi
    fi
else
    # Fallback to X11 if GUI apps are not enabled
    export DISPLAY=":0"
fi
