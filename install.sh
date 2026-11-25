#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/4t145/rust-cookbook-for-agents.git"
DEFAULT_CLONE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rust-cookbook-for-agents"
BIN_DIR="${HOME}/.local/bin"
DEFAULT_LANG="en"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zh|--zh-CN)
      DEFAULT_LANG="zh"
      shift
      ;;
    --en)
      DEFAULT_LANG="en"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./install.sh [--en | --zh]

Installs the `rust-ai` CLI helper into ~/.local/bin/rust-ai.
  --en    Default `rust-ai` to English AGENTS.md (default)
  --zh    Default `rust-ai` to Chinese AGENTS.zh-CN.md
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_PATH" && -f "$(dirname "$SCRIPT_PATH")/AGENTS.md" ]]; then
  REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
else
  REPO_DIR="$DEFAULT_CLONE_DIR"
  if [[ -d "$REPO_DIR/.git" ]]; then
    echo "Updating existing checkout at $REPO_DIR..."
    git -C "$REPO_DIR" pull --ff-only
  else
    echo "Cloning $REPO_URL to $REPO_DIR..."
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$REPO_URL" "$REPO_DIR"
  fi
fi

mkdir -p "$BIN_DIR"

cat > "${BIN_DIR}/rust-ai" <<EOF
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR}"
LANG_CHOICE="${DEFAULT_LANG}"
ACTION="link"

while [[ \$# -gt 0 ]]; do
  case "\$1" in
    link|copy|unlink|update)
      ACTION="\$1"
      shift
      ;;
    --link)
      ACTION="link"
      shift
      ;;
    --copy)
      ACTION="copy"
      shift
      ;;
    --unlink)
      ACTION="unlink"
      shift
      ;;
    --update)
      ACTION="update"
      shift
      ;;
    --zh|--zh-CN)
      LANG_CHOICE="zh"
      shift
      ;;
    --en)
      LANG_CHOICE="en"
      shift
      ;;
    -h|--help)
      cat <<'HELP'
Usage: rust-ai [link | copy | unlink | update] [--en | --zh]

Commands:
  link     Symlink AGENTS.md into current project and add to .git/info/exclude (default)
  copy     Copy standalone AGENTS.md into current directory (for committing to Git)
  unlink   Remove symlinked AGENTS.md (or .agents/rules/rust-cookbook.md)
  update   Pull latest guidelines from GitHub (updates all symlinked projects)

Options:
  --en     Use English AGENTS.md
  --zh     Use Chinese AGENTS.zh-CN.md
HELP
      exit 0
      ;;
    *)
      echo "Unknown argument: \$1 (run 'rust-ai --help' for usage)" >&2
      exit 1
      ;;
  esac
done

if [[ "\$LANG_CHOICE" == "zh" ]]; then
  SOURCE_FILE="\${REPO_DIR}/AGENTS.zh-CN.md"
else
  SOURCE_FILE="\${REPO_DIR}/AGENTS.md"
fi

add_git_exclude() {
  local pattern="\$1"
  if [[ -d ".git/info" ]]; then
    touch .git/info/exclude
    if ! grep -qxF "\$pattern" .git/info/exclude; then
      echo "\$pattern" >> .git/info/exclude
    fi
  fi
}

case "\$ACTION" in
  link)
    if [[ -f "AGENTS.md" && ! -L "AGENTS.md" ]]; then
      mkdir -p .agents/rules
      ln -sf "\$SOURCE_FILE" .agents/rules/rust-cookbook.md
      add_git_exclude "/.agents/rules/rust-cookbook.md"
      echo "Existing AGENTS.md detected; linked (\${LANG_CHOICE}) to .agents/rules/rust-cookbook.md"
    else
      ln -sf "\$SOURCE_FILE" ./AGENTS.md
      add_git_exclude "/AGENTS.md"
      echo "Linked (\${LANG_CHOICE}) -> ./AGENTS.md (added to .git/info/exclude)"
    fi
    ;;
  copy)
    cp "\$SOURCE_FILE" ./AGENTS.md
    echo "Copied (\${LANG_CHOICE}) -> ./AGENTS.md"
    ;;
  unlink)
    removed=0
    if [[ -L "AGENTS.md" ]]; then
      rm -f AGENTS.md
      echo "Removed symlink ./AGENTS.md"
      removed=1
    fi
    if [[ -L ".agents/rules/rust-cookbook.md" ]]; then
      rm -f .agents/rules/rust-cookbook.md
      echo "Removed symlink .agents/rules/rust-cookbook.md"
      removed=1
    fi
    if [[ "\$removed" -eq 0 ]]; then
      echo "No rust-ai symlink found in current directory."
    fi
    ;;
  update)
    git -C "\$REPO_DIR" pull --ff-only
    echo "Updated rust-cookbook-for-agents in \$REPO_DIR"
    ;;
esac
EOF

chmod +x "${BIN_DIR}/rust-ai"
echo "Installed rust-ai to ${BIN_DIR}/rust-ai (source: ${REPO_DIR}, default lang: ${DEFAULT_LANG})"

case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *)
    echo "Note: add ${BIN_DIR} to your PATH to invoke 'rust-ai' directly."
    ;;
esac
