# PFE — LLMs Embarqués sur Smartphone

> Mémoire de Master Informatique — Intelligence Artificielle  
> Solutions Google (Gemini Nano, ML Kit GenAI) et alternatives open source (llama.cpp, MLC-LLM, Gemma)

---

## Structure du dépôt

```
pfe-llm-smartphone/
├── docs/
│   ├── 01_etat_art.md               # État de l'art complet (voir aussi le PDF)
│   ├── 02_tutoriel_llamacpp.md      # Tutoriel llama.cpp Android/Termux + PC
│   ├── 03_tutoriel_mlkit.md         # Tutoriel ML Kit GenAI (Android Studio)
│   ├── 04_analyse_performances.md   # Analyse des performances mesurées
│   └── 05_retour_critique.md        # Retour critique et recommandations
├── prototype-cli/
│   ├── chatbot.py                   # Chatbot CLI interactif (llama-cpp-python)
│   ├── benchmark.py                 # Script de mesure latence/mémoire
│   ├── utils.py                     # Fonctions utilitaires
│   └── requirements.txt             # Dépendances Python
├── prototype-android/               # Squelette app Android (ML Kit GenAI)
│   └── app/src/main/
│       ├── java/com/pfe/llmchat/    # Code Kotlin
│       └── res/layout/              # Layouts XML
├── benchmarks/
│   ├── run_benchmark.sh             # Script benchmark complet
│   └── results/                     # Résultats JSON des benchmarks
└── scripts/
    ├── setup_termux.sh              # Installation automatique Android/Termux
    └── download_model.sh            # Téléchargement modèles GGUF
```

---

## Démarrage rapide — Prototype CLI

### Prérequis
- Python 3.9+
- 4 Go de RAM disponibles minimum
- Un modèle GGUF (voir `scripts/download_model.sh`)

### Installation

```bash
cd prototype-cli
pip install -r requirements.txt

# Télécharger un modèle (exemple : Gemma 2 2B Q4)
bash ../scripts/download_model.sh gemma2-2b

# Lancer le chatbot
python chatbot.py --model ../models/gemma-2-2b-it-q4_k_m.gguf

# Mode benchmark
python benchmark.py --model ../models/gemma-2-2b-it-q4_k_m.gguf
```

### Démo rapide (mode mock — sans modèle)

```bash
python chatbot.py --mock
```

---

## Démarrage rapide — Android (Termux)

```bash
# Copier et exécuter le script d'installation
bash scripts/setup_termux.sh
```

Voir `docs/02_tutoriel_llamacpp.md` pour le tutoriel complet pas-à-pas.

---

## Solutions couvertes

| Solution | Type | Framework | Appareil requis |
|---|---|---|---|
| llama.cpp + Gemma 2 2B | Open source | llama.cpp | Tout Android ARM64 |
| ML Kit GenAI + Gemini Nano | Propriétaire | AICore | Pixel 9/10, Galaxy S25/S26 |

---

## Livrables du PFE

- `etat_art_llm_smartphone_v2.pdf` — État de l'art complet (LaTeX)
- `timeline_llm_smartphone.pdf` — Chronologie illustrée imprimable
- `rapport_final_pfe.pdf` — Rapport complet (généré depuis ce dépôt)
- Ce dépôt Git — code + tutoriels reproductibles

---

## Références principales

- [llama.cpp](https://github.com/ggml-org/llama.cpp) — Gerganov, 2023
- [MLC-LLM](https://github.com/mlc-ai/mlc-llm) — MLC AI Contributors, 2023
- [ML Kit GenAI](https://developers.google.com/ml-kit/genai) — Google, 2025
- [Gemma](https://arxiv.org/abs/2403.08295) — Google DeepMind, 2024
- [Xu et al. COTS Benchmark](https://arxiv.org/abs/2410.03613) — 2024
