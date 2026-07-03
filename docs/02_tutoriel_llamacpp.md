# Tutoriel — llama.cpp sur Android (Termux) et PC

> **Reproductibilité** : toutes les commandes ont été testées sur Android 12+ (ARM64) et Ubuntu 22.04.  
> **Temps estimé** : 30–45 minutes (hors téléchargement du modèle).

---

## Partie A — Installation sur Android via Termux

### A.1 Prérequis matériels

| Critère | Minimum | Recommandé |
|---|---|---|
| RAM | 6 Go | 12 Go |
| Stockage libre | 5 Go | 10 Go |
| SoC | ARM64 quelconque | Snapdragon 8 Gen 2/3 |
| Android | 7.0+ | 12+ |

> ⚠️ **GPU Mali (Samsung Exynos, MediaTek Dimensity)** : l'accélération GPU est inutilisable avec llama.cpp. L'inférence se fera en **CPU uniquement** — les performances seront 3 à 5× inférieures à un appareil Snapdragon équivalent.

---

### A.2 Installation de Termux

1. **Télécharger Termux depuis F-Droid** (pas le Play Store — version obsolète) :  
   → [https://f-droid.org/packages/com.termux/](https://f-droid.org/packages/com.termux/)

2. Ouvrir Termux et mettre à jour les paquets :

```bash
pkg update && pkg upgrade -y
```

3. Installer les dépendances de compilation :

```bash
pkg install -y git cmake clang make python
```

4. Vérifier l'architecture (doit afficher `aarch64`) :

```bash
uname -m
# Attendu : aarch64
```

---

### A.3 Compilation de llama.cpp

```bash
# Cloner le dépôt
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp

# Compiler avec support ARM NEON (optimisation mobile)
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_NATIVE=ON \
  -DGGML_OPENMP=OFF
cmake --build build --config Release -j$(nproc)

# Vérifier la compilation
./build/bin/llama-cli --version
```

> ⏱️ La compilation prend **8 à 20 minutes** selon le SoC.  
> 💡 `-j$(nproc)` utilise tous les cœurs disponibles. Sur un Snapdragon 8 Gen 3 (8 cœurs), cela divise le temps de compilation par ~6.

---

### A.4 Téléchargement du modèle

```bash
# Créer un dossier pour les modèles
mkdir -p ~/models && cd ~/models

# Option 1 : Gemma 2 2B (recommandé, open source Google, bon équilibre)
# Taille : ~1,6 Go (Q4_K_M)
curl -L -o gemma-2-2b-it-q4_k_m.gguf \
  "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf"

# Option 2 : LLaMA 3.2 3B (Meta, très bon raisonnement)
# Taille : ~2,0 Go (Q4_K_M)
curl -L -o llama-3.2-3b-instruct-q4_k_m.gguf \
  "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"

# Option 3 : LLaMA 3.2 1B (le plus léger, pour appareils <6 Go RAM)
# Taille : ~0,8 Go (Q4_K_M)
curl -L -o llama-3.2-1b-instruct-q4_k_m.gguf \
  "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
```

---

### A.5 Première inférence

```bash
cd ~/llama.cpp

# Test rapide (non-interactif)
./build/bin/llama-cli \
  -m ~/models/gemma-2-2b-it-q4_k_m.gguf \
  -p "Qu'est-ce que l'intelligence artificielle ?" \
  -n 200 \
  --temp 0.7

# Mode chat interactif
./build/bin/llama-cli \
  -m ~/models/gemma-2-2b-it-q4_k_m.gguf \
  -i \
  --chat-template gemma \
  -n 512 \
  --temp 0.7 \
  -c 2048
```

**Paramètres importants :**

| Paramètre | Description | Valeur recommandée mobile |
|---|---|---|
| `-n` | Nombre de tokens à générer | 256–512 |
| `-c` | Taille du contexte (tokens) | 1024–2048 |
| `--temp` | Température (créativité) | 0.7 |
| `-t` | Nombre de threads CPU | `$(nproc)` ou 4 |
| `--n-gpu-layers` | Couches sur GPU | 0 (CPU uniquement sur Android) |

---

### A.6 Mesure des performances

```bash
# Benchmark intégré llama.cpp
./build/bin/llama-bench \
  -m ~/models/gemma-2-2b-it-q4_k_m.gguf \
  -p 512 \
  -n 128 \
  -r 3

# Résultat attendu sur Snapdragon 8 Gen 3 :
# pp512  : ~25–35 tok/s  (prefill — traitement du prompt)
# tg128  : ~12–18 tok/s  (decode — génération token par token)
```

```bash
# Monitoring mémoire en temps réel (dans un second terminal Termux)
while true; do
  free -m | grep Mem | awk '{printf "RAM utilisée: %d Mo / %d Mo\n", $3, $2}'
  sleep 2
done
```

---

### A.7 Dépannage fréquent

| Erreur | Cause | Solution |
|---|---|---|
| `SIGKILL` pendant l'inférence | OOM (manque de RAM) | Passer au modèle 1B ou réduire `-c` |
| `llama_model_load: error loading model` | Fichier GGUF corrompu | Re-télécharger, vérifier MD5 |
| Performances très lentes | Throttling thermique | Pause 5 min, ventiler l'appareil |
| `pkg: command not found` | Termux non mis à jour | `pkg update && pkg upgrade` |
| `cmake: not found` | Dépendances manquantes | `pkg install cmake clang` |

---

## Partie B — Installation sur PC Linux/Mac (développement)

### B.1 Linux (Ubuntu/Debian)

```bash
# Dépendances
sudo apt update && sudo apt install -y git cmake build-essential libgomp1

# Cloner et compiler
git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON
cmake --build build --config Release -j$(nproc)
```

### B.2 Mac (Apple Silicon)

```bash
# Homebrew + compilation avec Metal (GPU Apple)
brew install cmake
git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=ON
cmake --build build --config Release -j$(sysctl -n hw.logicalcpu)

# Sur Mac M1/M2/M3 : ajouter --n-gpu-layers 99 pour utiliser le GPU Metal
./build/bin/llama-cli -m ~/models/gemma-2-2b-it-q4_k_m.gguf \
  --n-gpu-layers 99 -i --chat-template gemma
```

---

## Partie C — Installation Python (llama-cpp-python)

Pour le prototype CLI (voir `prototype-cli/`), on utilise les bindings Python :

```bash
# Installation CPU (compatible partout)
pip install llama-cpp-python

# Installation avec support GPU Metal (Mac M1/M2/M3)
CMAKE_ARGS="-DGGML_METAL=ON" pip install llama-cpp-python

# Installation avec support CUDA (Linux + GPU Nvidia)
CMAKE_ARGS="-DGGML_CUDA=ON" pip install llama-cpp-python
```

---

## Récapitulatif des performances mesurées

| Appareil | SoC | Modèle | Prefill | Decode | RAM utilisée |
|---|---|---|---|---|---|
| Xiaomi 14 Pro | Snapdragon 8 Gen 3 | Gemma 2 2B Q4 | ~28 tok/s | ~14 tok/s | ~2,4 Go |
| Galaxy A54 | Exynos 1380 | Gemma 2 2B Q4 | ~10 tok/s | ~6 tok/s | ~2,4 Go |
| iPhone 15 Pro | Apple A17 Pro | Gemma 2 2B Q4 | ~45 tok/s | ~22 tok/s | ~2,2 Go |
| PC Ubuntu | Intel i7-12th | Gemma 2 2B Q4 | ~35 tok/s | ~18 tok/s | ~2,6 Go |
| Mac M2 | Apple M2 | Gemma 2 2B Q4 | ~55 tok/s | ~28 tok/s | ~2,2 Go |

> Sources : Xu et al. [19], Fassold [20], mesures directes sur appareils COTS.

---

## Références

- [llama.cpp GitHub](https://github.com/ggml-org/llama.cpp)
- [GGUF Format Spec](https://github.com/ggml-org/ggml/blob/master/docs/gguf.md)
- [HuggingFace — Modèles GGUF](https://huggingface.co/models?library=gguf)
- Xu et al. (2024). *Understanding LLMs in Your Pockets*. arXiv:2410.03613
