#!/bin/bash
# =============================================================================
# benchmark_complet.sh — PFE LLMs Embarqués sur Smartphone
# Mesure : Latence (prefill/decode) + Mémoire (RAM) + Énergie (batterie)
# Usage  : bash benchmark_complet.sh <chemin_modele.gguf> [nom_appareil]
# Exemple: bash benchmark_complet.sh ~/models/Llama-3.2-1B-Instruct-Q4_K_M.gguf "Galaxy_A12"
# =============================================================================

set -e

# --------------------------------------------------------------------------- #
# 0. PARAMÈTRES
# --------------------------------------------------------------------------- #
MODEL_PATH="${1:-$HOME/models/Llama-3.2-1B-Instruct-Q4_K_M.gguf}"
DEVICE_NAME="${2:-$(hostname)}"
RESULTS_DIR="$HOME/benchmark_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_JSON="$RESULTS_DIR/${DEVICE_NAME}_${TIMESTAMP}.json"
OUTPUT_CSV="$RESULTS_DIR/resultats_tous_appareils.csv"
THREADS=$(nproc)
LLAMA_BENCH="$HOME/llama.cpp/build/bin/llama-bench"
LLAMA_CLI="$HOME/llama.cpp/build/bin/llama-cli"

# Couleurs
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   PFE — Benchmark LLM Embarqué                      ║${NC}"
echo -e "${BLUE}║   Appareil : ${DEVICE_NAME}                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# --------------------------------------------------------------------------- #
# 1. VÉRIFICATIONS PRÉLIMINAIRES
# --------------------------------------------------------------------------- #
echo -e "${YELLOW}[1/5] Vérifications...${NC}"

if [ ! -f "$MODEL_PATH" ]; then
    echo -e "${RED}❌ Modèle introuvable : $MODEL_PATH${NC}"
    echo "   Téléchargez le modèle avec : bash download_model.sh"
    exit 1
fi

if [ ! -f "$LLAMA_BENCH" ]; then
    echo -e "${RED}❌ llama-bench introuvable. Compilez d'abord llama.cpp :${NC}"
    echo "   cd ~/llama.cpp && cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON"
    echo "   cmake --build build -j1"
    exit 1
fi

mkdir -p "$RESULTS_DIR"

# Infos système
ARCH=$(uname -m)
OS=$(uname -o 2>/dev/null || uname -s)
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
FREE_RAM_MB=$(free -m  | awk '/^Mem:/{print $4}')
MODEL_SIZE_MB=$(du -m "$MODEL_PATH" | cut -f1)

echo -e "   Architecture : ${GREEN}$ARCH${NC}"
echo -e "   OS           : ${GREEN}$OS${NC}"
echo -e "   RAM totale   : ${GREEN}${TOTAL_RAM_MB} Mo${NC}"
echo -e "   RAM libre    : ${GREEN}${FREE_RAM_MB} Mo${NC}"
echo -e "   Modèle       : ${GREEN}$(basename $MODEL_PATH) (${MODEL_SIZE_MB} Mo)${NC}"
echo -e "   Threads      : ${GREEN}$THREADS${NC}"
echo ""

# --------------------------------------------------------------------------- #
# 2. MESURE ÉNERGIE — AVANT (% batterie)
# --------------------------------------------------------------------------- #
echo -e "${YELLOW}[2/5] Mesure batterie AVANT benchmark...${NC}"

BATTERY_BEFORE="N/A"
BATTERY_FILE="/sys/class/power_supply/battery/capacity"
BATTERY_FILE2="/sys/class/power_supply/Battery/capacity"

if [ -f "$BATTERY_FILE" ]; then
    BATTERY_BEFORE=$(cat "$BATTERY_FILE")
    echo -e "   🔋 Batterie avant : ${GREEN}${BATTERY_BEFORE}%${NC}"
elif [ -f "$BATTERY_FILE2" ]; then
    BATTERY_BEFORE=$(cat "$BATTERY_FILE2")
    echo -e "   🔋 Batterie avant : ${GREEN}${BATTERY_BEFORE}%${NC}"
else
    echo -e "   ⚠️  Batterie non accessible via sysfs (UserLAnd normal)"
    echo -e "   ${YELLOW}→ Notez manuellement le % batterie affiché sur Android : _____%${NC}"
    read -p "   Entrez le % batterie actuel (ou Entrée pour ignorer) : " BATTERY_BEFORE
    BATTERY_BEFORE="${BATTERY_BEFORE:-manuel_requis}"
fi

START_TIME=$(date +%s)
echo ""

# --------------------------------------------------------------------------- #
# 3. MESURE RAM — AVANT
# --------------------------------------------------------------------------- #
RAM_BEFORE_MB=$(free -m | awk '/^Mem:/{print $3}')

# --------------------------------------------------------------------------- #
# 4. BENCHMARK LATENCE — llama-bench (5 runs)
# --------------------------------------------------------------------------- #
echo -e "${YELLOW}[3/5] Benchmark latence (5 runs, ~5-10 min)...${NC}"
echo -e "   Prefill : 512 tokens d'entrée"
echo -e "   Decode  : 128 tokens générés"
echo ""

BENCH_OUTPUT=$("$LLAMA_BENCH" \
    -m "$MODEL_PATH" \
    -p 512 \
    -n 128 \
    -r 5 \
    -t "$THREADS" \
    2>/dev/null)

echo "$BENCH_OUTPUT"
echo ""

# Parser les résultats (extraction par lookahead — robuste face au "|" final du tableau markdown)
PREFILL_TPS=$(echo "$BENCH_OUTPUT" | grep "pp512" | grep -oP '[0-9]+\.[0-9]+(?=\s*±)')
DECODE_TPS=$(echo  "$BENCH_OUTPUT" | grep "tg128" | grep -oP '[0-9]+\.[0-9]+(?=\s*±)')
PREFILL_STD=$(echo "$BENCH_OUTPUT" | grep "pp512" | grep -oP '±\s*\K[0-9.]+')
DECODE_STD=$(echo  "$BENCH_OUTPUT" | grep "tg128" | grep -oP '±\s*\K[0-9.]+')

echo -e "   ✅ Prefill : ${GREEN}${PREFILL_TPS} ± ${PREFILL_STD} tok/s${NC}"
echo -e "   ✅ Decode  : ${GREEN}${DECODE_TPS} ± ${DECODE_STD} tok/s${NC}"
echo ""

# --------------------------------------------------------------------------- #
# 5. MESURE MÉMOIRE — pendant et après
# --------------------------------------------------------------------------- #
echo -e "${YELLOW}[4/5] Mesure mémoire...${NC}"

RAM_AFTER_MB=$(free -m | awk '/^Mem:/{print $3}')
RAM_DELTA_MB=$((RAM_AFTER_MB - RAM_BEFORE_MB))
RAM_FREE_AFTER_MB=$(free -m | awk '/^Mem:/{print $4}')

echo -e "   RAM avant benchmark : ${RAM_BEFORE_MB} Mo utilisés"
echo -e "   RAM après benchmark : ${RAM_AFTER_MB} Mo utilisés"
echo -e "   Delta RAM           : ${GREEN}+${RAM_DELTA_MB} Mo${NC}"
echo -e "   RAM libre restante  : ${GREEN}${RAM_FREE_AFTER_MB} Mo${NC}"
echo ""

# Test avec chargement modèle Python (mesure précise RAM modèle)
echo -e "   Mesure précise RAM modèle via Python..."
RAM_MODEL_MB=$(python3 - <<EOF 2>/dev/null || echo "N/A"
import os, time, psutil
try:
    from llama_cpp import Llama
    p = psutil.Process(os.getpid())
    before = p.memory_info().rss / (1024*1024)
    llm = Llama(model_path="$MODEL_PATH", n_ctx=512, n_threads=$THREADS,
                n_gpu_layers=0, verbose=False, use_mmap=True)
    after = p.memory_info().rss / (1024*1024)
    print(f"{after-before:.0f}")
except:
    print("N/A")
EOF
)

echo -e "   RAM modèle (Python) : ${GREEN}+${RAM_MODEL_MB} Mo${NC}"
echo ""

# --------------------------------------------------------------------------- #
# 6. THROTTLING — comparaison run 1 vs run 5
# --------------------------------------------------------------------------- #
echo -e "${YELLOW}[4b] Analyse throttling thermique...${NC}"

# Relancer 2 runs espacés pour détecter la dégradation
RUN1=$("$LLAMA_BENCH" -m "$MODEL_PATH" -p 512 -n 128 -r 1 -t "$THREADS" 2>/dev/null | grep "tg128" | grep -oP '[0-9]+\.[0-9]+(?=\s*±)')
sleep 2
RUN2=$("$LLAMA_BENCH" -m "$MODEL_PATH" -p 512 -n 128 -r 1 -t "$THREADS" 2>/dev/null | grep "tg128" | grep -oP '[0-9]+\.[0-9]+(?=\s*±)')

THROTTLING=$(python3 -c "
r1, r2 = $RUN1, $RUN2
delta = (r1 - r2) / r1 * 100
print(f'{delta:.1f}')
" 2>/dev/null || echo "N/A")

echo -e "   Decode run 1 : ${RUN1} tok/s"
echo -e "   Decode run 2 : ${RUN2} tok/s"
echo -e "   Dégradation  : ${GREEN}-${THROTTLING}%${NC}"
echo ""

# --------------------------------------------------------------------------- #
# 7. MESURE ÉNERGIE — APRÈS
# --------------------------------------------------------------------------- #
echo -e "${YELLOW}[5/5] Mesure batterie APRÈS benchmark...${NC}"

END_TIME=$(date +%s)
DURATION_MIN=$(( (END_TIME - START_TIME) / 60 ))

BATTERY_AFTER="N/A"
if [ -f "$BATTERY_FILE" ]; then
    BATTERY_AFTER=$(cat "$BATTERY_FILE")
    echo -e "   🔋 Batterie après : ${GREEN}${BATTERY_AFTER}%${NC}"
elif [ -f "$BATTERY_FILE2" ]; then
    BATTERY_AFTER=$(cat "$BATTERY_FILE2")
    echo -e "   🔋 Batterie après : ${GREEN}${BATTERY_AFTER}%${NC}"
else
    echo -e "   ${YELLOW}→ Notez le % batterie affiché sur Android maintenant : _____%${NC}"
    read -p "   Entrez le % batterie actuel (ou Entrée pour ignorer) : " BATTERY_AFTER
    BATTERY_AFTER="${BATTERY_AFTER:-manuel_requis}"
fi

# Calcul consommation
BATTERY_CONSUMED="N/A"
if [[ "$BATTERY_BEFORE" =~ ^[0-9]+$ ]] && [[ "$BATTERY_AFTER" =~ ^[0-9]+$ ]]; then
    BATTERY_CONSUMED=$((BATTERY_BEFORE - BATTERY_AFTER))
    echo -e "   ⚡ Consommation    : ${GREEN}${BATTERY_CONSUMED}% en ${DURATION_MIN} min${NC}"
fi

echo ""

# --------------------------------------------------------------------------- #
# 8. SAUVEGARDE JSON
# --------------------------------------------------------------------------- #
cat > "$OUTPUT_JSON" <<JSON
{
  "appareil": "$DEVICE_NAME",
  "timestamp": "$TIMESTAMP",
  "date": "$(date '+%Y-%m-%d %H:%M')",
  "systeme": {
    "architecture": "$ARCH",
    "os": "$OS",
    "threads": $THREADS,
    "ram_totale_mb": $TOTAL_RAM_MB,
    "ram_libre_avant_mb": $FREE_RAM_MB
  },
  "modele": {
    "fichier": "$(basename $MODEL_PATH)",
    "taille_mb": $MODEL_SIZE_MB
  },
  "latence": {
    "prefill_tps": $PREFILL_TPS,
    "prefill_std": "${PREFILL_STD:-0}",
    "decode_tps": $DECODE_TPS,
    "decode_std": "${DECODE_STD:-0}",
    "nb_runs": 5,
    "prompt_tokens": 512,
    "generate_tokens": 128
  },
  "memoire": {
    "ram_avant_mb": $RAM_BEFORE_MB,
    "ram_apres_mb": $RAM_AFTER_MB,
    "delta_mb": $RAM_DELTA_MB,
    "ram_modele_python_mb": "${RAM_MODEL_MB}"
  },
  "throttling": {
    "decode_run1_tps": "${RUN1}",
    "decode_run2_tps": "${RUN2}",
    "degradation_pct": "${THROTTLING}"
  },
  "energie": {
    "batterie_avant_pct": "${BATTERY_BEFORE}",
    "batterie_apres_pct": "${BATTERY_AFTER}",
    "consommation_pct": "${BATTERY_CONSUMED}",
    "duree_benchmark_min": $DURATION_MIN
  }
}
JSON

echo -e "${GREEN}✅ Résultats sauvegardés : $OUTPUT_JSON${NC}"

# --------------------------------------------------------------------------- #
# 9. MISE À JOUR CSV COMPARATIF
# --------------------------------------------------------------------------- #
if [ ! -f "$OUTPUT_CSV" ]; then
    echo "Appareil,Architecture,RAM_totale_Mo,Prefill_tps,Prefill_std,Decode_tps,Decode_std,RAM_delta_Mo,Throttling_pct,Batterie_avant_pct,Batterie_apres_pct,Conso_batterie_pct,Duree_min,Date" > "$OUTPUT_CSV"
fi

echo "$DEVICE_NAME,$ARCH,$TOTAL_RAM_MB,$PREFILL_TPS,${PREFILL_STD:-0},$DECODE_TPS,${DECODE_STD:-0},$RAM_DELTA_MB,${THROTTLING},${BATTERY_BEFORE},${BATTERY_AFTER},${BATTERY_CONSUMED},$DURATION_MIN,$(date '+%Y-%m-%d')" >> "$OUTPUT_CSV"

echo -e "${GREEN}✅ CSV mis à jour : $OUTPUT_CSV${NC}"

# --------------------------------------------------------------------------- #
# 10. RÉCAPITULATIF FINAL
# --------------------------------------------------------------------------- #
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   RÉCAPITULATIF — $DEVICE_NAME${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}  LATENCE                                              ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}    Prefill : ${GREEN}${PREFILL_TPS} ± ${PREFILL_STD} tok/s${NC}                       ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}    Decode  : ${GREEN}${DECODE_TPS} ± ${DECODE_STD} tok/s${NC}                       ${BLUE}║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}  MÉMOIRE                                              ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}    Delta RAM : ${GREEN}+${RAM_DELTA_MB} Mo${NC}                              ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}    RAM libre : ${GREEN}${RAM_FREE_AFTER_MB} Mo${NC}                              ${BLUE}║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}  ÉNERGIE                                              ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}    Batterie : ${GREEN}${BATTERY_BEFORE}% → ${BATTERY_AFTER}% (−${BATTERY_CONSUMED}% en ${DURATION_MIN} min)${NC}     ${BLUE}║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}  THROTTLING                                           ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}    Dégradation : ${GREEN}-${THROTTLING}%${NC}                              ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Fichiers générés :"
echo -e "  JSON : $OUTPUT_JSON"
echo -e "  CSV  : $OUTPUT_CSV"
echo ""
