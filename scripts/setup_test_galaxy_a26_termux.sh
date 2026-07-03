#!/usr/bin/env bash
# =============================================================================
# setup_test_galaxy_a26_termux.sh — Installation + benchmark complet en un seul fichier
# Appareil : Samsung Galaxy A26 — Environnement : Termux (natif, sans proot)
# Usage    : copier-coller ce fichier entier dans le terminal Termux, ou
#            bash setup_test_galaxy_a26_termux.sh
# =============================================================================

set -e

DEVICE_NAME="Galaxy_A26_Termux"
MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
MODEL_PATH="$HOME/Llama-3.2-1B-Instruct-Q4_K_M.gguf"

echo "=== PFE — Installation + Benchmark llama.cpp sur ${DEVICE_NAME} ==="
echo ""

# --------------------------------------------------------------------------- #
# 1. Mise à jour Termux + dépendances
# --------------------------------------------------------------------------- #
echo "[1/6] Mise à jour des paquets Termux..."
pkg update -y && pkg upgrade -y

echo "[2/6] Installation des dépendances de compilation..."
pkg install -y git cmake clang make python wget

ARCH=$(uname -m)
echo "Architecture détectée : $ARCH (attendu : aarch64)"
echo ""

# --------------------------------------------------------------------------- #
# 2. Clonage + compilation de llama.cpp
# --------------------------------------------------------------------------- #
echo "[3/6] Clonage de llama.cpp..."
cd "$HOME"
if [ -d "llama.cpp" ]; then
    cd llama.cpp && git pull
else
    git clone --depth 1 https://github.com/ggml-org/llama.cpp
    cd llama.cpp
fi

echo "[4/6] Compilation (RAM limitée sur l'A26 -> -j1 pour éviter un crash)..."
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=ON \
    -DGGML_OPENMP=OFF
cmake --build build --config Release -j1

echo "Compilation terminée."
./build/bin/llama-cli --version
echo ""

# --------------------------------------------------------------------------- #
# 3. Téléchargement du modèle (identique aux autres appareils testés)
# --------------------------------------------------------------------------- #
echo "[5/6] Téléchargement du modèle Llama 3.2 1B Q4_K_M (771 Mo)..."
wget -c -O "$MODEL_PATH" "$MODEL_URL"
echo ""

# --------------------------------------------------------------------------- #
# 4. Création du script de benchmark (version corrigée — parsing fiable)
# --------------------------------------------------------------------------- #
echo "[6/6] Création de benchmark_complet.sh..."

cat > "$HOME/benchmark_complet.sh" << 'BENCHSCRIPT_EOF'
#!/bin/bash
set -e

MODEL_PATH="${1:-$HOME/Llama-3.2-1B-Instruct-Q4_K_M.gguf}"
DEVICE_NAME="${2:-$(hostname)}"
RESULTS_DIR="$HOME/benchmark_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_JSON="$RESULTS_DIR/${DEVICE_NAME}_${TIMESTAMP}.json"
OUTPUT_CSV="$RESULTS_DIR/resultats_tous_appareils.csv"
THREADS=$(nproc)
LLAMA_BENCH="$HOME/llama.cpp/build/bin/llama-bench"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}=== PFE Benchmark LLM Embarque : ${DEVICE_NAME} ===${NC}"
echo ""
echo -e "${YELLOW}[1/5] Verifications...${NC}"

if [ ! -f "$MODEL_PATH" ]; then echo -e "${RED}Modele introuvable${NC}"; exit 1; fi
if [ ! -f "$LLAMA_BENCH" ]; then echo -e "${RED}llama-bench introuvable${NC}"; exit 1; fi

mkdir -p "$RESULTS_DIR"
ARCH=$(uname -m)
OS=$(uname -o 2>/dev/null || uname -s)
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
FREE_RAM_MB=$(free -m | awk '/^Mem:/{print $4}')
MODEL_SIZE_MB=$(du -m "$MODEL_PATH" | cut -f1)

echo -e "   Architecture : ${GREEN}$ARCH${NC}"
echo -e "   RAM totale   : ${GREEN}${TOTAL_RAM_MB} Mo${NC}"
echo -e "   RAM libre    : ${GREEN}${FREE_RAM_MB} Mo${NC}"
echo -e "   Modele       : ${GREEN}$(basename $MODEL_PATH) (${MODEL_SIZE_MB} Mo)${NC}"
echo -e "   Threads      : ${GREEN}$THREADS${NC}"
echo ""

echo -e "${YELLOW}[2/5] Mesure batterie AVANT...${NC}"
BATTERY_FILE="/sys/class/power_supply/battery/capacity"
BATTERY_FILE2="/sys/class/power_supply/Battery/capacity"
if [ -f "$BATTERY_FILE" ]; then BATTERY_BEFORE=$(cat "$BATTERY_FILE")
elif [ -f "$BATTERY_FILE2" ]; then BATTERY_BEFORE=$(cat "$BATTERY_FILE2")
else
    echo "   (Sous Termux natif, vérifie : termux-battery-status si l'app termux-api est installée)"
    read -p "   Entrez le % batterie actuel : " BATTERY_BEFORE
    BATTERY_BEFORE="${BATTERY_BEFORE:-manuel_requis}"
fi
START_TIME=$(date +%s)
echo ""

RAM_BEFORE_MB=$(free -m | awk '/^Mem:/{print $3}')

echo -e "${YELLOW}[3/5] Benchmark latence (5 runs)...${NC}"
BENCH_OUTPUT=$("$LLAMA_BENCH" -m "$MODEL_PATH" -p 512 -n 128 -r 5 -t "$THREADS" 2>/dev/null)
echo "$BENCH_OUTPUT"
echo ""

PREFILL_TPS=$(echo "$BENCH_OUTPUT" | grep "pp512" | grep -oP '[0-9]+\.[0-9]+(?=\s*±)')
DECODE_TPS=$(echo  "$BENCH_OUTPUT" | grep "tg128" | grep -oP '[0-9]+\.[0-9]+(?=\s*±)')
PREFILL_STD=$(echo "$BENCH_OUTPUT" | grep "pp512" | grep -oP '±\s*\K[0-9.]+')
DECODE_STD=$(echo  "$BENCH_OUTPUT" | grep "tg128" | grep -oP '±\s*\K[0-9.]+')

echo -e "   Prefill : ${GREEN}${PREFILL_TPS} ± ${PREFILL_STD} tok/s${NC}"
echo -e "   Decode  : ${GREEN}${DECODE_TPS} ± ${DECODE_STD} tok/s${NC}"
echo ""

echo -e "${YELLOW}[4/5] Mesure memoire...${NC}"
RAM_AFTER_MB=$(free -m | awk '/^Mem:/{print $3}')
RAM_DELTA_MB=$((RAM_AFTER_MB - RAM_BEFORE_MB))
RAM_FREE_AFTER_MB=$(free -m | awk '/^Mem:/{print $4}')
echo -e "   Delta RAM : ${GREEN}${RAM_DELTA_MB} Mo${NC}"
echo ""

echo -e "${YELLOW}[4b] Analyse throttling thermique (test rapide — voir throttling_5min.sh pour version rigoureuse)...${NC}"
RUN1=$("$LLAMA_BENCH" -m "$MODEL_PATH" -p 512 -n 128 -r 1 -t "$THREADS" 2>/dev/null | grep "tg128" | grep -oP '[0-9]+\.[0-9]+(?=\s*±)')
sleep 2
RUN2=$("$LLAMA_BENCH" -m "$MODEL_PATH" -p 512 -n 128 -r 1 -t "$THREADS" 2>/dev/null | grep "tg128" | grep -oP '[0-9]+\.[0-9]+(?=\s*±)')
THROTTLING=$(python3 -c "
r1, r2 = $RUN1, $RUN2
print(f'{(r1 - r2) / r1 * 100:.1f}')
" 2>/dev/null || echo "N/A")
echo -e "   Decode run 1 : ${RUN1} tok/s"
echo -e "   Decode run 2 : ${RUN2} tok/s"
echo -e "   Degradation  : ${GREEN}${THROTTLING}%${NC}"
echo ""

echo -e "${YELLOW}[5/5] Mesure batterie APRES...${NC}"
END_TIME=$(date +%s)
DURATION_MIN=$(( (END_TIME - START_TIME) / 60 ))
if [ -f "$BATTERY_FILE" ]; then BATTERY_AFTER=$(cat "$BATTERY_FILE")
elif [ -f "$BATTERY_FILE2" ]; then BATTERY_AFTER=$(cat "$BATTERY_FILE2")
else
    read -p "   Entrez le % batterie actuel : " BATTERY_AFTER
    BATTERY_AFTER="${BATTERY_AFTER:-manuel_requis}"
fi
BATTERY_CONSUMED="N/A"
if [[ "$BATTERY_BEFORE" =~ ^[0-9]+$ ]] && [[ "$BATTERY_AFTER" =~ ^[0-9]+$ ]]; then
    BATTERY_CONSUMED=$((BATTERY_BEFORE - BATTERY_AFTER))
fi
echo ""

cat > "$OUTPUT_JSON" <<JSONEOF
{
  "appareil": "$DEVICE_NAME",
  "timestamp": "$TIMESTAMP",
  "systeme": {"architecture": "$ARCH", "threads": $THREADS, "ram_totale_mb": $TOTAL_RAM_MB},
  "modele": {"fichier": "$(basename $MODEL_PATH)", "taille_mb": $MODEL_SIZE_MB},
  "latence": {"prefill_tps": $PREFILL_TPS, "prefill_std": "${PREFILL_STD:-0}", "decode_tps": $DECODE_TPS, "decode_std": "${DECODE_STD:-0}"},
  "memoire": {"ram_avant_mb": $RAM_BEFORE_MB, "ram_apres_mb": $RAM_AFTER_MB, "delta_mb": $RAM_DELTA_MB},
  "throttling": {"decode_run1_tps": "${RUN1}", "decode_run2_tps": "${RUN2}", "degradation_pct": "${THROTTLING}"},
  "energie": {"batterie_avant_pct": "${BATTERY_BEFORE}", "batterie_apres_pct": "${BATTERY_AFTER}", "consommation_pct": "${BATTERY_CONSUMED}", "duree_benchmark_min": $DURATION_MIN}
}
JSONEOF

if [ ! -f "$OUTPUT_CSV" ]; then
    echo "Appareil,Architecture,RAM_totale_Mo,Prefill_tps,Prefill_std,Decode_tps,Decode_std,RAM_delta_Mo,Throttling_pct,Batterie_avant_pct,Batterie_apres_pct,Conso_batterie_pct,Duree_min,Date" > "$OUTPUT_CSV"
fi
echo "$DEVICE_NAME,$ARCH,$TOTAL_RAM_MB,$PREFILL_TPS,${PREFILL_STD:-0},$DECODE_TPS,${DECODE_STD:-0},$RAM_DELTA_MB,${THROTTLING},${BATTERY_BEFORE},${BATTERY_AFTER},${BATTERY_CONSUMED},$DURATION_MIN,$(date '+%Y-%m-%d')" >> "$OUTPUT_CSV"

echo -e "${GREEN}=== RECAP $DEVICE_NAME ===${NC}"
echo -e "  Prefill : ${PREFILL_TPS} ± ${PREFILL_STD} tok/s"
echo -e "  Decode  : ${DECODE_TPS} ± ${DECODE_STD} tok/s"
echo -e "  Delta RAM : ${RAM_DELTA_MB} Mo"
echo -e "  Throttling : ${THROTTLING}%"
echo -e "  Batterie : ${BATTERY_BEFORE}% -> ${BATTERY_AFTER}%"
echo ""
echo "JSON : $OUTPUT_JSON"
echo "CSV  : $OUTPUT_CSV"
BENCHSCRIPT_EOF

chmod +x "$HOME/benchmark_complet.sh"
echo "benchmark_complet.sh créé."
echo ""

# --------------------------------------------------------------------------- #
# 5. Lancement immédiat du benchmark
# --------------------------------------------------------------------------- #
echo "=== Lancement du benchmark sur ${DEVICE_NAME} ==="
bash "$HOME/benchmark_complet.sh" "$MODEL_PATH" "$DEVICE_NAME"
