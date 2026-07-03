#!/usr/bin/env bash
# =============================================================================
# setup_test_galaxy_a16_termux.sh — Préparation Termux SANS benchmark
# Appareil : Samsung Galaxy A16 — Termux natif
# Usage    : coller dans Termux, puis : bash ~/setup_a16.sh
# =============================================================================

set -e

echo "=== [1/4] Mise à jour Termux ==="
pkg update -y && pkg upgrade -y
pkg install -y git cmake clang make python wget

echo ""
echo "=== [2/4] Correction spawn.h (manquant dans Termux sysroot) ==="
python3 - <<'PYEOF'
import os
p = os.environ.get('PREFIX', '/data/data/com.termux/files/usr')
content = """#pragma once
#include <sys/types.h>
#include <sched.h>
#include <signal.h>

#define POSIX_SPAWN_RESETIDS      1
#define POSIX_SPAWN_SETPGROUP     2
#define POSIX_SPAWN_SETSIGDEF     4
#define POSIX_SPAWN_SETSIGMASK    8
#define POSIX_SPAWN_SETSCHEDPARAM 16
#define POSIX_SPAWN_SETSCHEDULER  32

struct __posix_spawnattr;
typedef struct __posix_spawnattr* posix_spawnattr_t;
struct __posix_spawn_file_actions;
typedef struct __posix_spawn_file_actions* posix_spawn_file_actions_t;

#ifdef __cplusplus
extern "C" {
#endif
int posix_spawn(pid_t*, const char*, const posix_spawn_file_actions_t*, const posix_spawnattr_t*, char* const[], char* const[]);
int posix_spawnp(pid_t*, const char*, const posix_spawn_file_actions_t*, const posix_spawnattr_t*, char* const[], char* const[]);
int posix_spawnattr_init(posix_spawnattr_t*);
int posix_spawnattr_destroy(posix_spawnattr_t*);
int posix_spawnattr_setflags(posix_spawnattr_t*, short);
int posix_spawnattr_getflags(const posix_spawnattr_t*, short*);
int posix_spawnattr_setpgroup(posix_spawnattr_t*, pid_t);
int posix_spawnattr_getpgroup(const posix_spawnattr_t*, pid_t*);
int posix_spawnattr_setsigmask(posix_spawnattr_t*, const sigset_t*);
int posix_spawnattr_getsigmask(const posix_spawnattr_t*, sigset_t*);
int posix_spawnattr_setsigdefault(posix_spawnattr_t*, const sigset_t*);
int posix_spawnattr_getsigdefault(const posix_spawnattr_t*, sigset_t*);
int posix_spawn_file_actions_init(posix_spawn_file_actions_t*);
int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t*);
int posix_spawn_file_actions_addopen(posix_spawn_file_actions_t*, int, const char*, int, mode_t);
int posix_spawn_file_actions_addclose(posix_spawn_file_actions_t*, int);
int posix_spawn_file_actions_adddup2(posix_spawn_file_actions_t*, int, int);
#ifdef __cplusplus
}
#endif
"""
out = p + '/include/spawn.h'
with open(out, 'w') as f:
    f.write(content)
print(f"spawn.h cree : {out}")
PYEOF

echo ""
echo "=== [3/4] Compilation llama.cpp (-j1, RAM limitee) ==="
cd "$HOME"
if [ -d "llama.cpp" ]; then
    echo "llama.cpp deja present, git pull..."
    cd llama.cpp && git pull
else
    git clone --depth 1 https://github.com/ggml-org/llama.cpp
    cd llama.cpp
fi

cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=ON \
    -DGGML_OPENMP=OFF

cmake --build build --config Release -j1

echo "Verification binaires :"
ls -lh build/bin/llama-bench build/bin/llama-cli
echo ""

echo "=== [4/4] Telechargement modele Llama-3.2-1B Q4_K_M (771 Mo) ==="
mkdir -p "$HOME/models"
wget -c \
    -O "$HOME/models/Llama-3.2-1B-Instruct-Q4_K_M.gguf" \
    "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"

echo ""
echo "=========================================================="
echo "  SETUP TERMINE !"
echo "  llama-bench : $HOME/llama.cpp/build/bin/llama-bench"
echo "  Modele      : $HOME/models/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
echo ""
echo "  Prochain appel (benchmark) :"
echo "  bash ~/benchmark_complet.sh \\"
echo "    ~/models/Llama-3.2-1B-Instruct-Q4_K_M.gguf Galaxy_A16"
echo "=========================================================="
