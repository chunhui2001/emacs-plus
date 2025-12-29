#!/usr/bin/env bash
set -e

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

ok()    { echo -e "${GREEN}✔ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $1${NC}"; }
fail()  { echo -e "${RED}✘ $1${NC}"; }

echo "== Emacs build preflight check =="
echo

# --------------------------------------------------
# 基本信息
# --------------------------------------------------
ARCH=$(uname -m)
OS=$(sw_vers -productVersion)
BREW_PREFIX=$(brew --prefix 2>/dev/null || true)

echo "System:"
echo "  macOS   : $OS"
echo "  Arch    : $ARCH"
echo "  brew    : ${BREW_PREFIX:-not found}"
echo

# --------------------------------------------------
# Xcode CLT
# --------------------------------------------------
if xcode-select -p &>/dev/null; then
  ok "Xcode Command Line Tools installed"
else
  fail "Xcode Command Line Tools missing (run: xcode-select --install)"
fi

# --------------------------------------------------
# 编译器
# --------------------------------------------------
if command -v clang &>/dev/null; then
  ok "clang found: $(clang --version | head -n1)"
else
  fail "clang not found"
fi

if command -v gcc &>/dev/null; then
  GCC_PATH=$(which gcc)
  if [[ "$GCC_PATH" == *"/brew"* ]]; then
    warn "brew gcc detected ($GCC_PATH) – clang is recommended"
  fi
fi

# --------------------------------------------------
# Autotools
# --------------------------------------------------
for tool in autoconf make pkg-config; do
  if command -v $tool &>/dev/null; then
    ok "$tool installed"
  else
    fail "$tool missing (brew install $tool)"
  fi
done

# --------------------------------------------------
# Homebrew 架构
# --------------------------------------------------
if [[ -n "$BREW_PREFIX" ]]; then
  if [[ "$ARCH" == "arm64" && "$BREW_PREFIX" == "/usr/local" ]]; then
    fail "Rosetta brew detected on Apple Silicon (use /opt/homebrew)"
  elif [[ "$ARCH" == "x86_64" && "$BREW_PREFIX" == "/opt/homebrew" ]]; then
    fail "arm64 brew on Intel Mac (wrong architecture)"
  else
    ok "brew prefix matches CPU architecture"
  fi
fi

# --------------------------------------------------
# libgccjit / native-comp
# --------------------------------------------------
if brew list libgccjit &>/dev/null; then
  ok "libgccjit installed"

  JIT_LIB="$BREW_PREFIX/opt/libgccjit/lib/gcc/current"
  if [[ -d "$JIT_LIB" ]]; then
    ok "libgccjit path exists: $JIT_LIB"
  else
    warn "libgccjit path not found at expected location"
  fi
else
  fail "libgccjit missing (native-comp will NOT work)"
fi

# --------------------------------------------------
# 必要库
# --------------------------------------------------
libs=(
  gmp
  tree-sitter
  jansson
  gnutls
)

for lib in "${libs[@]}"; do
  if brew list "$lib" &>/dev/null; then
    ok "$lib installed"
  else
    warn "$lib missing (recommended: brew install $lib)"
  fi
done

# --------------------------------------------------
# GUI / image 支持
# --------------------------------------------------
img_libs=(
  imagemagick
  librsvg
  webp
)

for lib in "${img_libs[@]}"; do
  if brew list "$lib" &>/dev/null; then
    ok "$lib installed"
  else
    warn "$lib missing (icons / images may be limited)"
  fi
done

# --------------------------------------------------
# SDK
# --------------------------------------------------
if xcrun --show-sdk-path &>/dev/null; then
  ok "macOS SDK available"
else
  fail "macOS SDK not found"
fi

# --------------------------------------------------
# Emacs 源码状态（如果在 emacs 目录下）
# --------------------------------------------------
if [[ -f "configure.ac" ]]; then
  ok "Emacs source tree detected"

  if [[ -f "configure" ]]; then
    ok "configure script present"
  else
    warn "configure missing (need ./autogen.sh)"
  fi
fi

# --------------------------------------------------
# Doom / eln-cache 提醒
# --------------------------------------------------
echo
echo "Notes:"
warn "If you use Doom on Intel + Apple Silicon, isolate eln-cache by architecture"
echo

echo "== Preflight check completed =="
