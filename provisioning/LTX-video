#!/bin/bash
# Wan 2.2 SVI Pro + LTX-2.3 하이브리드 비디오 파이프라인 프로비저닝 (v3)
# vast.ai ComfyUI 이미지 호환 — real-image.sh와 같은 방식으로 실제 설치를 자동 탐지한다.
#
# v3 변경점:
#   - ai-dock storage 레이아웃 제거. 노드/모델 전부 자동 탐지된 $COMFY_DIR 안에 설치
#     (v2는 노드·text_encoders가 /opt/ComfyUI로 가서 vast.ai에서 인식 안 됨)
#   - 카테고리 폴더명을 실제 ComfyUI 이름으로: unet→diffusion_models, lora→loras, esrgan→upscale_models
#   - 워크플로우는 wan22svi-ltx23-remote.workflow.json (경로 구분자 / 변환본)을 쓸 것
#
# 필요 환경변수:
#   CIVITAI_TOKEN — 필수 (Dasiwa·LoRA 다수가 NSFW 게이트)
#   HF_TOKEN      — 선택 (HF 파일은 전부 공개)
#
# 디스크: 모델 합계 약 105 GB → 120 GB 이상 할당 권장
#
# Overrides:
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
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/evanspearman/ComfyMath"
    "https://github.com/M1kep/ComfyLiterals"
    "https://github.com/Lightricks/ComfyUI-LTXVideo"
    "https://github.com/TenStrip/10S-Comfy-nodes"
    "https://github.com/IAMCCS/IAMCCS-nodes"
    "https://github.com/shootthesound/comfyUI-LongLook"
    "https://github.com/AlekPet/ComfyUI_Custom_Nodes_AlekPet"
    "https://github.com/TinyTerra/ComfyUI_tinyterraNodes"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
)
# 전 저장소 존재 확인함 (2026-07-21, GitHub API 200)

# "카테고리/하위폴더|URL" — 워크플로우 로더 값과 정확히 같은 트리로 받는다.
# 전부 ${MODELS_DIR}(= $COMFY_DIR/models) 기준.
MODEL_ITEMS=(
    # --- diffusion_models ---
    "diffusion_models/Wan2.2/Dasiwa|https://civitai.com/api/download/models/2761725"
    "diffusion_models/Wan2.2/Dasiwa|https://civitai.com/api/download/models/2761870"
    "diffusion_models/Wan2.2|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"
    "diffusion_models/LTX2.3/Kijai|https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/diffusion_models/ltx-2-3-22b-dev_transformer_only_fp8_input_scaled.safetensors"
    # --- loras ---
    "loras/Wan2.2/SVI2|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors"
    "loras/Wan2.2/SVI2|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_LOW_lora_rank_128_fp16.safetensors"
    "loras/Wan2.2/LightningX2V/rCM|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/rCM/Wan22-I2V-A14B-HIGH-rCM6_0_lora_rank_64_bf16.safetensors"
    "loras/LTX2.3|https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-22b-distilled-lora-384-1.1.safetensors"
    "loras/LTX2.3|https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/loras/LTX-2.3-OmniNFT-RL-Lora_bf16.safetensors"
    # 활성(강도 1) 필수 LoRA — Civitai 2349271, 받은 뒤 rename (아래)
    "loras/Wan2.2/Breasts|https://civitai.com/api/download/models/2642369"
    "loras/Wan2.2/Breasts|https://civitai.com/api/download/models/2642368"
    # 강도 0이지만 검증 통과에 필요 — Civitai 2048082 (파일명 정확 일치)
    "loras/Wan2.2|https://civitai.com/api/download/models/2317956"
    "loras/Wan2.2|https://civitai.com/api/download/models/2318025"
    # 우회(bypass) 노드용 (선택) — Civitai 2529707
    "loras/LTX2.3/Beasts|https://civitai.com/api/download/models/2843106"
    # --- vae ---
    "vae/Wan2_1|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
    "vae/LTX2/2.3|https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_video_vae_bf16.safetensors"
    "vae/LTX2/2.3|https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_audio_vae_bf16.safetensors"
    "vae/LTX2|https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/taeltx2_3.safetensors"
    # --- text_encoders ---
    "text_encoders/Wan2_1|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
    "text_encoders/LTX2|https://huggingface.co/GitMylo/LTX-2-comfy_gemma_fp8_e4m3fn/resolve/main/gemma_3_12B_it_fp8_e4m3fn.safetensors"
    "text_encoders/LTX2/2.3|https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/text_encoders/ltx-2.3_text_projection_bf16.safetensors"
    # --- upscale_models ---
    "upscale_models|https://huggingface.co/utnah/esrgan/resolve/main/2x_NMKD-UpgifLiteV2_210k.pth"
    # --- frame_interpolation (comfy-core RIFE) ---
    "frame_interpolation|https://huggingface.co/Comfy-Org/frame_interpolation/resolve/main/frame_interpolation/rife_v4.26.safetensors"
)

# Civitai가 주는 파일명 → 워크플로우가 참조하는 이름으로 변경 ("폴더|원본|변경")
RENAME_ITEMS=(
    "loras/Wan2.2/Breasts|20260129-48585079_high_noise.safetensors|Big-breasted shakes_high_noise.safetensors"
    "loras/Wan2.2/Breasts|20260129-48585079_low_noise.safetensors|Big-breasted shakes_low_noise.safetensors"
)

# 미해결 (없어도 실행 가능 — 해당 노드가 우회/빈 슬롯 처리됨):
#  - LTX2.3/Sulphur/sulphur_experimental_lora_v1.safetensors (출처 미상, bypass+강도0)
#  - "wan2.2 NSFW Motion Enhancer_HIGH.safetensors" (버전 특정 불가 — 변환본 워크플로우에서 슬롯 'no')

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

    for item in "${MODEL_ITEMS[@]}"; do
        dir="${MODELS_DIR}/${item%%|*}"
        url="${item#*|}"
        mkdir -p "$dir"
        printf "Downloading: %s -> %s\n" "$url" "$dir"
        provisioning_download "$url" "$dir"
    done

    for item in "${RENAME_ITEMS[@]}"; do
        IFS='|' read -r rel src dst <<< "$item"
        if [[ -f "${MODELS_DIR}/${rel}/${src}" && ! -f "${MODELS_DIR}/${rel}/${dst}" ]]; then
            mv "${MODELS_DIR}/${rel}/${src}" "${MODELS_DIR}/${rel}/${dst}"
            printf "Renamed: %s -> %s\n" "$src" "$dst"
        fi
    done

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
