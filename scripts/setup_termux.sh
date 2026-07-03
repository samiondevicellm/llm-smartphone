#!/usr/bin/env bash
# setup_termux.sh — Installation complète de llama.cpp sur Android via Termux
# À exécuter dans Termux sur l'appareil Android

set -e

echo "╔══════════════════════════════════════════════════════╗"
echo "║   Installation llama.cpp — Android (Termux)         ║"
echo "║   PFE Master IA — LLMs Embarqués sur Smartphone     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Vérification architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "⚠️  Architecture : $ARCH (attendu : aarch64)"
    echo "   Ce script est optimisé pour Android ARM64."
fi

# 1. Mise à jour des paquets
echo "📦 [1/5] Mise à jour des paquets Termux..."
pkg update -y && pkg upgrade -y

# 2. Installation des dépendances
echo "🔧 [2/5] Installation des dépendances..."
pkg install -y git cmake clang make python curl wget

# 3. Clonage de llama.cpp
echo "📥 [3/5] Clonage de llama.cpp..."
cd ~
if [ -d "llama.cpp" ]; then
    echo "   llama.cpp déjà présent, mise à jour..."
    cd llama.cpp && git pull
else
    git clone https://github.com/ggml-org/llama.cpp
    cd llama.cpp
fi

# 4. Compilation
echo "🔨 [4/5] Compilation (peut prendre 10-20 minutes)..."
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=ON \
    -DGGML_OPENMP=OFF
cmake --build build --config Release -j$(nproc)

echo "✅ Compilation terminée !"
./build/bin/llama-cli --version

# 5. Téléchargement du modèle
echo ""
echo "📥 [5/5] Téléchargement du modèle Gemma 2 2B (Q4_K_M, ~1.6 Go)..."
mkdir -p ~/models
wget -c -O ~/models/gemma-2-2b-it-q4_k_m.gguf \
    "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf" \
    --show-progress

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   ✅ Installation terminée !                         ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Commandes de test :"
echo "  cd ~/llama.cpp"
echo "  ./build/bin/llama-cli \\"
echo "    -m ~/models/gemma-2-2b-it-q4_k_m.gguf \\"
echo "    -p 'Qu'est-ce que l'IA embarquée ?' -n 200"
echo ""
echo "  # Mode chat interactif :"
echo "  ./build/bin/llama-cli \\"
echo "    -m ~/models/gemma-2-2b-it-q4_k_m.gguf \\"
echo "    -i --chat-template gemma -c 2048"
echo ""
echo "  # Benchmark :"
echo "  ./build/bin/llama-bench \\"
echo "    -m ~/models/gemma-2-2b-it-q4_k_m.gguf \\"
echo "    -p 512 -n 128 -r 3"
