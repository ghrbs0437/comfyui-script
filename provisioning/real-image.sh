#!/bin/bash
# Custom provisioning for the PiD / Krea2 ComfyUI workflow.
#
# Key robustness features:
#  - Targets the REAL ComfyUI install (COMFY_DIR), not the ai-dock storage layout.
#  - Installs every custom-node requirements.txt into the SAME python that the
#    live ComfyUI uses (COMFY_PY), so nodes like RES4LYF import correctly
#    regardless of ComfyUI core version.
#  - Registers the ComfyUI root on that python's path (.pth) to avoid
#    "No module named 'comfy'" import failures.
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
    "https://github.com/ClownsharkBatwing/RES4LYF"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/spacepxl/ComfyUI-VAE-Utils"
)

DIFFUSION_MODELS=(
    "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/diffusion_models/krea2_raw_bf16.safetensors"
    "https://huggingface.co/Comfy-Org/PixelDiT/resolve/main/diffusion_models/pid_qwenimage_1024_to_4096_4step_bf16.safetensors"
)

TEXT_ENCODER_MODELS=(
    "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/text_encoders/qwen3vl_4b_bf16.safetensors"
    "https://huggingface.co/Comfy-Org/PixelDiT/resolve/main/text_encoders/gemma_2_2b_it_elm_bf16.safetensors"
)

LORA_MODELS=(
    "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/loras/krea2_turbo_lora_rank_64_bf16.safetensors"
    "https://huggingface.co/Kutches/Kr3a/resolve/main/krea2filterbypass.safetensors"
    #"https://huggingface.co/diobrando0/krea2_loras_public/resolve/main/snofs_krea_v1.safetensors"
    # my_first_lora_v1.safetensors = your own trained LoRA placeholder (no public URL).
)

VAE_MODELS=(
    "https://huggingface.co/spacepxl/Wan2.1-VAE-upscale2x/resolve/main/Wan2.1_VAE_upscale2x_imageonly_real_v1.safetensors"
)

CHECKPOINT_MODELS=()
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

# Find the python interpreter the live ComfyUI actually uses.
function resolve_comfyui_python() {
    COMFY_PY=""
    # 1) explicit override
    if [[ -n "$COMFY_PYTHON" && -x "$COMFY_PYTHON" ]]; then
        COMFY_PY="$COMFY_PYTHON"
    fi
    # 2) python of a currently-running ComfyUI process (ground truth)
    if [[ -z "$COMFY_PY" ]]; then
        local pid exe
        pid="$(pgrep -f 'main\.py' 2>/dev/null | head -n1)"
        if [[ -n "$pid" ]]; then
            exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null)"
            [[ -x "$exe" ]] && COMFY_PY="$exe"
        fi
    fi
    # 3) a venv bundled with the install
    if [[ -z "$COMFY_PY" ]]; then
        for p in "$COMFY_DIR/venv/bin/python" "$COMFY_DIR/.venv/bin/python" \
                 "$COMFY_DIR/../venv/bin/python" "/workspace/venv/bin/python"; do
            [[ -x "$p" ]] && COMFY_PY="$p" && break
        done
    fi
    # 4) ai-dock venv pip -> derive python
    if [[ -z "$COMFY_PY" && -n "$COMFYUI_VENV_PIP" ]]; then
        local d; d="$(dirname "$COMFYUI_VENV_PIP")"
        [[ -x "$d/python" ]] && COMFY_PY="$d/python"
    fi
    # 5) fallback: whatever python is on PATH
    [[ -z "$COMFY_PY" ]] && COMFY_PY="$(command -v python3 || command -v python)"

    [[ -n "$COMFY_PY" ]] || { printf "ERROR: no python interpreter found.\n" >&2; return 1; }
    printf "ComfyUI py  : %s\n" "$COMFY_PY"
    # Confidence check: this env should already have torch if it's the comfy env.
    if "$COMFY_PY" -c "import torch" >/dev/null 2>&1; then
        printf "  -> torch import OK (looks like the ComfyUI environment)\n"
    else
        printf "  -> WARNING: 'import torch' failed in this python. It may be the wrong env.\n"
        printf "     If nodes still fail to import, set COMFY_PYTHON to the correct interpreter\n"
        printf "     (check: ps -eo args | grep '[m]ain.py').\n"
    fi
}

# Ensure the ComfyUI root is importable from COMFY_PY (fixes "No module named 'comfy'").
function register_comfy_on_path() {
    local sp
    sp="$("$COMFY_PY" -c 'import site,sys; ps=site.getsitepackages() if hasattr(site,"getsitepackages") else []; print(ps[0] if ps else sys.path[-1])' 2>/dev/null)"
    if [[ -n "$sp" && -d "$sp" ]]; then
        echo "$COMFY_DIR" > "$sp/zz_comfyui_root.pth"
        printf "Registered ComfyUI root on path via %s/zz_comfyui_root.pth\n" "$sp"
    fi
}

# pip that always targets the live ComfyUI python.
function pip_install() {
    "$COMFY_PY" -m pip install --no-cache-dir "$@"
}

function provisioning_start() {
    # ai-dock env is optional; ignore if this isn't an ai-dock image.
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
        # Always (re)install requirements into the live ComfyUI python.
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
