wt() {
  local script_dir script output target_path launch_tool
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  script="$script_dir/wt-core.sh"

  if [[ ! -x "$script" ]]; then
    printf 'wt core script not executable: %s\n' "$script" >&2
    return 1
  fi

  if ! output="$("$script" "$@")"; then
    return $?
  fi

  eval "$output"

  if [[ -n "${TARGET_PATH:-}" ]]; then
    cd "$TARGET_PATH" || return 1
  fi

  launch_tool="${LAUNCH_TOOL:-none}"
  case "$launch_tool" in
    codex|claude)
      # Normalize proxy env before launching CLI tools. Some CLIs warn or fail
      # when lower/upper-case proxy vars disagree inside the current shell.
      if [[ -n "${ALL_PROXY:-}" ]]; then export all_proxy="$ALL_PROXY"; fi
      if [[ -n "${HTTP_PROXY:-}" ]]; then export http_proxy="$HTTP_PROXY"; fi
      if [[ -n "${HTTPS_PROXY:-}" ]]; then export https_proxy="$HTTPS_PROXY"; fi
      if [[ -z "${ALL_PROXY:-}" && -n "${all_proxy:-}" ]]; then export ALL_PROXY="$all_proxy"; fi
      if [[ -z "${HTTP_PROXY:-}" && -n "${http_proxy:-}" ]]; then export HTTP_PROXY="$http_proxy"; fi
      if [[ -z "${HTTPS_PROXY:-}" && -n "${https_proxy:-}" ]]; then export HTTPS_PROXY="$https_proxy"; fi
      export all_proxy="${ALL_PROXY:-${all_proxy:-}}"
      export http_proxy="${HTTP_PROXY:-${http_proxy:-}}"
      export https_proxy="${HTTPS_PROXY:-${https_proxy:-}}"

      if command -v "$launch_tool" >/dev/null 2>&1; then
        "$launch_tool"
      else
        printf '%s 命令不存在于 PATH 中，已停留在目标目录：%s\n' "$launch_tool" "$PWD" >&2
      fi
      ;;
    none|"")
      ;;
    *)
      printf '未知启动工具：%s\n' "$launch_tool" >&2
      return 1
      ;;
  esac
}
