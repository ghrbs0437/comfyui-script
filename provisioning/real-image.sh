#!/bin/bash
# Custom provisioning for the PiD / Krea2 ComfyUI workflow.
#
# Models AND custom nodes are placed inside the *real* ComfyUI install
# (auto-detected), using ComfyUI's native model folder names, so they are
# recognized without depending on extra_model_paths.yaml.
#
# If auto-detection picks the wrong install, force it by exporting COMFY_DIR
# before provisioning, e.g.:  export COMFY_DIR=/workspace/ComfyUI

# ---- Target ComfyUI install (confirmed running instance) --------------------
# Pinned to the live install at /workspace/ComfyUI (persistent Vast volume).
# Override at runtime with:  export COMFY_DIR=/some/other/ComfyUI
COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
# ----------------------------------------------------------------------------

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
)

LORA_MODELS=(
    "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/loras/krea2_turbo_lora_rank_64_bf16.safetensors"
    "https://huggingface.co/Kutches/Kr3a/resolve/main/krea2filterbypass.safetensors"
    # Optional / disabled in the workflow:
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
    if [[ -n "$COMFY_DIR" && -f "$COMFY_DIR/main.py" ]]; then
        printf "Using COMFY_DIR override: %s\n" "$COMFY_DIR"
    else
        # Prefer a currently-running ComfyUI process if one exists.
        local pid cmd path
        pid="$(pgrep -f 'main\.py' 2>/dev/null | head -n1)"
        if [[ -n "$pid" ]]; then
            cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
            path="$(printf '%s\n' "$cmd" | grep -oE '[^ ]*/main\.py' | head -n1)"
            [[ -n "$path" && -f "$path" ]] && COMFY_DIR="$(dirname "$path")"
        fi
        # Fall back to a candidate list (persistent /workspace first).
        if [[ -z "$COMFY_DIR" ]]; then
            local candidates=(
                "/workspace/ComfyUI"
                "/opt/workspace-internal/ComfyUI"
                "${WORKSPACE}/ComfyUI"
                "/opt/ComfyUI"
                "$HOME/ComfyUI"
            )
            for d in "${candidates[@]}"; do
                [[ -n "$d" && -f "$d/main.py" ]] && COMFY_DIR="$d" && break
            done
        fi
        # Last resort: filesystem search.
        if [[ -z "$COMFY_DIR" ]]; then
            local found
            found="$(find / -maxdepth 6 -name main.py -path '*ComfyUI*' 2>/dev/null | head -n1)"
            [[ -n "$found" ]] && COMFY_DIR="$(dirname "$found")"
        fi
    fi

    if [[ -z "$COMFY_DIR" || ! -f "$COMFY_DIR/main.py" ]]; then
        printf "ERROR: could not locate a ComfyUI installation.\n" >&2
        return 1
    fi
    MODELS_DIR="${COMFY_DIR}/models"
    NODES_DIR="${COMFY_DIR}/custom_nodes"
    printf "ComfyUI dir : %s\n" "$COMFY_DIR"
    printf "models dir  : %s\n" "$MODELS_DIR"
    printf "nodes dir   : %s\n" "$NODES_DIR"
}

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header

    resolve_comfyui_dir || { provisioning_print_end; return; }

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

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
            "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
        else
            micromamba run -n comfyui pip install --no-cache-dir "$@"
        fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip_install ${PIP_PACKAGES[@]}
    fi
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
                if [[ -e $requirements ]]; then
                   pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#          Provisioning container            #\n#         This will take some time           #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Web UI will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"
    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" -H "Content-Type: application/json")
    if [ "$response" -eq 200 ]; then return 0; else return 1; fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"
    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" -H "Content-Type: application/json")
    if [ "$response" -eq 200 ]; then return 0; else return 1; fi
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
}

provisioning_start
