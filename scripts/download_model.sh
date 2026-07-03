#!/usr/bin/env bash
# download_model.sh — Téléchargement de modèles GGUF depuis HuggingFace
# Usage : bash download_model.sh [gemma2-2b | llama3.2-3b | llama3.2-1b | phi3-mini]

set -e
MODEL_DIR="$(dirname "$0")/../models"
mkdir -p "$MODEL_DIR"

MODEL=${1:-gemma2-2b}

case "$MODEL" in
  gemma2-2b)
    URL="https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf"
    FILE="gemma-2-2b-it-q4_k_m.gguf"
    SIZE="~1.6 Go"
    ;;
  llama3.2-3b)
    URL="https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
    FILE="llama-3.2-3b-instruct-q4_k_m.gguf"
    SIZE="~2.0 Go"
    ;;
  llama3.2-1b)
    URL="https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
    FILE="llama-3.2-1b-instruct-q4_k_m.gguf"
    SIZE="~0.8 Go"
    ;;
  phi3-mini)
    URL="https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf"
    FILE="phi-3-mini-4k-instruct-q4_k_m.gguf"
    SIZE="~2.2 Go"
    ;;
  *)
    echo "❌ Modèle inconnu : $MODEL"
    echo "   Modèles disponibles : gemma2-2b, llama3.2-3b, llama3.2-1b, phi3-mini"
    exit 1
    ;;
esac

echo "📥 Téléchargement : $FILE ($SIZE)"
echo "   Source : $URL"
echo "   Destination : $MODEL_DIR/$FILE"
echo ""

if command -v wget &>/dev/null; then
    wget -c -O "$MODEL_DIR/$FILE" "$URL" --show-progress
elif command -v curl &>/dev/null; then
    curl -L -C - -o "$MODEL_DIR/$FILE" "$URL" --progress-bar
else
    echo "❌ wget ou curl requis"
    exit 1
fi

echo ""
echo "✅ Modèle téléchargé : $MODEL_DIR/$FILE"
echo "   Taille : $(du -sh "$MODEL_DIR/$FILE" | cut -f1)"
echo ""
echo "Utilisation :"
echo "  python prototype-cli/chatbot.py --model models/$FILE"
echo "  python prototype-cli/benchmark.py --model models/$FILE"
