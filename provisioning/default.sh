#!/bin/bash
# Minimal provisioning (vast.ai ComfyUI image compatible).
# real-image.sh와 같은 방식: 실제 ComfyUI 설치를 자동 탐지해 그 안에 설치한다.
#
# Overrides (export before running if auto-detect picks wrong):
#   export COMFY_DIR=/workspace/ComfyUI
#   export COMFY_PYTHON=/workspace/ComfyUI/venv/bin/python

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
COMFY_PYTHON="${COMFY_PYTHON:-}"

APT_PACKAGES=(
)

PIP_PACKAGES=(
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/cubiq/ComfyUI_essentials"
)

CHECKPOINT_MODELS=()
DIFFUSION_MODELS=()
TEXT_ENCODER_MODELS=()
LORA_MODELS=()
VAE_MODELS=()
CONTROLNET_MODELS=()
CLIP_VISION_MODELS=()
IPADAPTER_MODELS=()
UPSCALE_MODELS=()

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function resolve_comfyui_dir() {
    if [[ ! -f "$COMFY_DIR/main.py" ]]; then
        local pid path cmd
        pid="$(pgrep -f 'main\.py' 2>/dev/null | head -n1)"
        if [[ -n "$pid" ]]; then
            cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
            path="$(printf '%s\n' "$cmd" | grep -oE '[^ ]*/main\.py' | head -n1)"
            [[ -n "$path" && -f "$path" ]] && COMFY_DIR="$(dirname "$path")"
        fi
    fi
    if [[ ! -f "$COMFY_DIR/main.py" ]]; then
        for d in "/workspace/ComfyUI" "/opt/workspace-internal/ComfyUI" "${WORKSPACE}/ComfyUI" "/opt/ComfyUI" "$HOME/ComfyUI"; do
            [[ -n "$d" && -f "$d/main.py" ]] && COMFY_DIR="$d" && break
        done
    fi
    if [[ ! -f "$COMFY_DIR/main.py" ]]; then
        local found
        found="$(find / -maxdepth 6 -name main.py -path '*ComfyUI*' 2>/dev/null | head -n1)"
        [[ -n "$found" ]] && COMFY_DIR="$(dirname "$found")"
    fi
    [[ -f "$COMFY_DIR/main.py" ]] || { printf "ERROR: ComfyUI not found.\n" >&2; return 1; }
    MODELS_DIR="${COMFY_DIR}/models"
    NODES_DIR="${COMFY_DIR}/custom_nodes"
    printf "ComfyUI dir : %s\n" "$COMFY_DIR"
}

function resolve_comfyui_python() {
    COMFY_PY=""
    if [[ -n "$COMFY_PYTHON" && -x "$COMFY_PYTHON" ]]; then
        COMFY_PY="$COMFY_PYTHON"
    fi
    if [[ -z "$COMFY_PY" ]]; then
        local pid exe
        pid="$(pgrep -f 'main\.py' 2>/dev/null | head -n1)"
        if [[ -n "$pid" ]]; then
            exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null)"
            [[ -x "$exe" ]] && COMFY_PY="$exe"
        fi
    fi
    if [[ -z "$COMFY_PY" ]]; then
        for p in "$COMFY_DIR/venv/bin/python" "$COMFY_DIR/.venv/bin/python" \
                 "$COMFY_DIR/../venv/bin/python" "/workspace/venv/bin/python"; do
            [[ -x "$p" ]] && COMFY_PY="$p" && break
        done
    fi
    if [[ -z "$COMFY_PY" && -n "$COMFYUI_VENV_PIP" ]]; then
        local d; d="$(dirname "$COMFYUI_VENV_PIP")"
        [[ -x "$d/python" ]] && COMFY_PY="$d/python"
    fi
    [[ -z "$COMFY_PY" ]] && COMFY_PY="$(command -v python3 || command -v python)"

    [[ -n "$COMFY_PY" ]] || { printf "ERROR: no python interpreter found.\n" >&2; return 1; }
    printf "ComfyUI py  : %s\n" "$COMFY_PY"
    if "$COMFY_PY" -c "import torch" >/dev/null 2>&1; then
        printf "  -> torch import OK (looks like the ComfyUI environment)\n"
    else
        printf "  -> WARNING: 'import torch' failed in this python. It may be the wrong env.\n"
    fi
}

function register_comfy_on_path() {
    local sp
    sp="$("$COMFY_PY" -c 'import site,sys; ps=site.getsitepackages() if hasattr(site,"getsitepackages") else []; print(ps[0] if ps else sys.path[-1])' 2>/dev/null)"
    if [[ -n "$sp" && -d "$sp" ]]; then
        echo "$COMFY_DIR" > "$sp/zz_comfyui_root.pth"
        printf "Registered ComfyUI root on path via %s/zz_comfyui_root.pth\n" "$sp"
    fi
}

function pip_install() {
    "$COMFY_PY" -m pip install --no-cache-dir "$@"
}

function provisioning_start() {
    [[ -f /opt/ai-dock/etc/environment.sh ]] && source /opt/ai-dock/etc/environment.sh
    [[ -f /opt/ai-dock/bin/venv-set.sh ]] && source /opt/ai-dock/bin/venv-set.sh comfyui 2>/dev/null

    provisioning_print_header
    resolve_comfyui_dir   || { provisioning_print_end; return; }
    resolve_comfyui_python || { provisioning_print_end; return; }
    register_comfy_on_path

    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages

    provisioning_get_models "${MODELS_DIR}/checkpoints"      "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models "${MODELS_DIR}/diffusion_models" "${DIFFUSION_MODELS[@]}"
    provisioning_get_models "${MODELS_DIR}/text_encoders"    "${TEXT_ENCODER_MODELS[@]}"
    provisioning_get_models "${MODELS_DIR}/loras"            "${LORA_MODELS[@]}"
    provisioning_get_models "${MODELS_DIR}/vae"              "${VAE_MODELS[@]}"
    provisioning_get_models "${MODELS_DIR}/controlnet"       "${CONTROLNET_MODELS[@]}"
    provisioning_get_models "${MODELS_DIR}/clip_vision"      "${CLIP_VISION_MODELS[@]}"
    provisioning_get_models "${MODELS_DIR}/ipadapter"        "${IPADAPTER_MODELS[@]}"
    provisioning_get_models "${MODELS_DIR}/upscale_models"   "${UPSCALE_MODELS[@]}"

    provisioning_print_end
}

function provisioning_get_apt_packages() {
    [[ -n $APT_PACKAGES ]] && sudo $APT_INSTALL ${APT_PACKAGES[@]}
}

function provisioning_get_pip_packages() {
    [[ -n $PIP_PACKAGES ]] && pip_install ${PIP_PACKAGES[@]}
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${NODES_DIR}/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
        fi
        if [[ -e $requirements ]]; then
            printf "Installing requirements for %s into %s\n" "${dir}" "${COMFY_PY}"
            pip_install -r "${requirements}" || printf "WARN: requirements install failed for %s\n" "${dir}"
        fi
    done
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"; mkdir -p "$dir"; shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n#############################################\n#          Provisioning container           #\n#############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete. Restart ComfyUI if it was already running.\n\n"
}

function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
    unset auth_token
}

provisioning_start
