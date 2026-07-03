#!/bin/bash
# =============================================================================
# throttling_rigoureux.sh — Test de throttling thermique rigoureux
#
# Protocole (validé sur Infinix + Galaxy A26) :
#   1. Run warm-up  → neutralise l'effet de ramp-up du governor CPU
#   2. Baseline     → capture decode tps à chaud (CPU stabilisé)
#   3. Charge 5 min → boucle llama-bench à contexte FIXE (évite le biais KV cache)
#   4. Post-load    → capture decode tps après charge soutenue
#   5. Throttling   → (baseline − post-load) / baseline × 100
#
# Usage : bash throttling_rigoureux.sh <modele.gguf> [nom_appareil]
# =============================================================================

MODEL_PATH="${1:-$HOME/models/Llama-3.2-1B-Instruct-Q4_K_M.gguf}"
DEVICE_NAME="${2:-$(hostname)}"
LLAMA_BENCH="$HOME/llama.cpp/build/bin/llama-bench"
THREADS=$(nproc)
RESULTS_DIR="$HOME/benchmark_results"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Test Throttling Rigoureux — $DEVICE_NAME           ${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

if [ ! -f "$MODEL_PATH" ]; then
    echo -e "${RED}❌ Modèle introuvable : $MODEL_PATH${NC}"; exit 1
fi
if [ ! -f "$LLAMA_BENCH" ]; then
    echo -e "${RED}❌ llama-bench introuvable : $LLAMA_BENCH${NC}"; exit 1
fi

mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG="$RESULTS_DIR/throttling_${DEVICE_NAME}_${TIMESTAMP}.log"

parse_tps() {
    echo "$1" | grep "tg128" | grep -oP '[0-9]+\.[0-9]+(?=\s*±)' | head -1
}

# --------------------------------------------------------------------------- #
# ÉTAPE 1 : Warm-up (1 run — neutralise schedutil ramp-up)
# --------------------------------------------------------------------------- #
echo -e "${YELLOW}[1/4] Warm-up (1 run — stabilisation CPU)...${NC}"
WARMUP_OUT=$("$LLAMA_BENCH" -m "$MODEL_PATH" -p 512 -n 128 -r 1 -t "$THREADS" 2>/dev/null)
WARMUP_TPS=$(parse_tps "$WARMUP_OUT")
echo -e "   Warm-up decode : ${WARMUP_TPS} tok/s (non utilisé dans calcul)"
echo ""

# --------------------------------------------------------------------------- #
# ÉTAPE 2 : Baseline (1 run immédiatement après warm-up, CPU à régime)
# --------------------------------------------------------------------------- #
echo -e "${YELLOW}[2/4] Baseline (CPU stabilisé post warm-up)...${NC}"
BASELINE_OUT=$("$LLAMA_BENCH" -m "$MODEL_PATH" -p 512 -n 128 -r 1 -t "$THREADS" 2>/dev/null)
BASELINE_TPS=$(parse_tps "$BASELINE_OUT")
echo -e "   ✅ Baseline decode : ${GREEN}${BASELINE_TPS} tok/s${NC}"
echo "$BASELINE_TPS" >> "$LOG"
echo ""

# --------------------------------------------------------------------------- #
# ÉTAPE 3 : Charge soutenue ~5 min (9 runs × contexte fixe 512+128)
# --------------------------------------------------------------------------- #
echo -e "${YELLOW}[3/4] Charge soutenue ~5 min (9 runs × contexte fixe)...${NC}"
echo -e "   (contexte fixe = évite biais KV cache / croissance de contexte)"
echo ""

DECODE_VALUES=()
START=$(date +%s)

for i in $(seq 1 9); do
    RUN_OUT=$("$LLAMA_BENCH" -m "$MODEL_PATH" -p 512 -n 128 -r 1 -t "$THREADS" 2>/dev/null)
    TPS=$(parse_tps "$RUN_OUT")
    ELAPSED=$(( $(date +%s) - START ))
    echo -e "   Run $i/9  →  ${TPS} tok/s  (${ELAPSED}s écoulées)"
    echo "$TPS" >> "$LOG"
    DECODE_VALUES+=("$TPS")
done

TOTAL_TIME=$(( $(date +%s) - START ))
echo ""
echo -e "   Durée charge soutenue : ${TOTAL_TIME}s"
echo ""

# --------------------------------------------------------------------------- #
# ÉTAPE 4 : Mesure post-charge
# --------------------------------------------------------------------------- #
echo -e "${YELLOW}[4/4] Mesure post-charge...${NC}"
POST_OUT=$("$LLAMA_BENCH" -m "$MODEL_PATH" -p 512 -n 128 -r 1 -t "$THREADS" 2>/dev/null)
POST_TPS=$(parse_tps "$POST_OUT")
echo -e "   ✅ Post-charge decode : ${GREEN}${POST_TPS} tok/s${NC}"
echo "$POST_TPS" >> "$LOG"
echo ""

# --------------------------------------------------------------------------- #
# CALCUL THROTTLING + STATISTIQUES
# --------------------------------------------------------------------------- #
python3 - "$BASELINE_TPS" "$POST_TPS" "${DECODE_VALUES[@]}" <<'PYEOF'
import sys, statistics

baseline = float(sys.argv[1])
postload = float(sys.argv[2])
values   = [float(v) for v in sys.argv[3:] if v]

all_vals = values + [postload]
throttling = (baseline - postload) / baseline * 100
median_val = statistics.median(values)
min_val    = min(values)
max_val    = max(values)

print("─" * 56)
print(f"  Baseline   (post warm-up) : {baseline:.2f} tok/s")
print(f"  Médiane    (charge 9 runs): {median_val:.2f} tok/s")
print(f"  Min/Max    (charge 9 runs): {min_val:.2f} / {max_val:.2f} tok/s")
print(f"  Post-charge               : {postload:.2f} tok/s")
print("─" * 56)
if throttling > 0:
    print(f"  ⚠️  THROTTLING : −{throttling:.1f}%  (dégradation réelle)")
elif throttling > -5:
    print(f"  ✅ Pas de throttling : {throttling:+.1f}%  (stable)")
else:
    print(f"  ✅ Pas de throttling : {throttling:+.1f}%  (accélération post-ramp)")
print("─" * 56)

if abs(min_val - max_val) > 2:
    print(f"  ⚠️  Variance élevée ({max_val-min_val:.1f} tok/s) — probable artefact governor")
    print(f"      Interprétation : pas de throttling thermique, variance = schedutil")
PYEOF

# Sauvegarde JSON
RESULT_JSON="$RESULTS_DIR/throttling_${DEVICE_NAME}_${TIMESTAMP}.json"
python3 - "$DEVICE_NAME" "$TIMESTAMP" "$THREADS" "$BASELINE_TPS" "$POST_TPS" "$TOTAL_TIME" "${DECODE_VALUES[@]}" <<'PYEOF'
import sys, json, statistics

device, ts, threads = sys.argv[1], sys.argv[2], int(sys.argv[3])
baseline  = float(sys.argv[4])
postload  = float(sys.argv[5])
total_sec = int(sys.argv[6])
values    = [float(v) for v in sys.argv[7:] if v]

throttling = (baseline - postload) / baseline * 100

data = {
    "appareil": device,
    "timestamp": ts,
    "protocole": "warm-up + 9 runs contexte fixe (512+128 tokens)",
    "duree_charge_s": total_sec,
    "threads": threads,
    "baseline_tps": baseline,
    "charge_valeurs": values,
    "charge_mediane": round(statistics.median(values), 2),
    "charge_min": round(min(values), 2),
    "charge_max": round(max(values), 2),
    "postload_tps": postload,
    "throttling_pct": round(throttling, 1),
    "conclusion": "throttling_thermique" if throttling > 10 else "pas_de_throttling"
}

import os
outdir = os.path.expanduser("~/benchmark_results")
os.makedirs(outdir, exist_ok=True)
fname = f"{outdir}/throttling_{device}_{ts}.json"
with open(fname, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print(f"\n  JSON : {fname}")
PYEOF

echo ""
echo -e "${GREEN}✅ Test throttling terminé.${NC}"
echo -e "   Log brut  : $LOG"
echo ""
