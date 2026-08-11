# PFE — LLMs Embarqués sur Smartphone

> Mémoire de Master Informatique — Intelligence Artificielle  
> Solutions Google (Gemini Nano, ML Kit GenAI) et alternatives open source (llama.cpp, MLC-LLM, Gemma)

---

## Structure du dépôt

```
pfe-llm-smartphone/
├── docs/
│   ├── 01_etat_art.md                       # État de l'art complet (voir aussi le PDF)
│   ├── 02_tutoriel_llamacpp.md              # Tutoriel llama.cpp Android/Termux + PC
│   ├── 03_tutoriel_mlkit.md                 # Tutoriel ML Kit GenAI (Android Studio)
│   ├── 04_analyse_performances.md           # Analyse des performances mesurées
│   ├── 05_retour_critique.md                # Retour critique et recommandations
│   ├── 06_installation_galaxy_a71.md        # Setup spécifique Galaxy A71
│   ├── 07_installation_infinix_hot60i.md    # Setup spécifique Infinix Hot 60i
│   └── chapitre_1_etat_art.md … chapitre_4_retour_critique.md   # Chapitres du mémoire (md + html)
├── prototype-cli/
│   ├── chatbot.py                   # Chatbot CLI interactif (llama-cpp-python)
│   ├── benchmark.py                 # Script de mesure latence/mémoire
│   ├── utils.py                     # Fonctions utilitaires
│   └── requirements.txt             # Dépendances Python
├── prototype-android/                # App Android (ML Kit GenAI / Gemini Nano)
│   └── app/src/main/
│       ├── java/com/pfe/llmchat/    # Code Kotlin (MainActivity, LlmViewModel, ChatAdapter)
│       └── res/layout/              # Layouts XML
├── scripts/
│   ├── setup_test_termux.sh         # Installation llama.cpp sur Termux (paramétrable par appareil)
│   ├── download_model.sh            # Téléchargement d'un modèle GGUF seul
│   ├── benchmark_complet.sh         # Benchmark complet (latence, RAM, batterie, throttling)
│   └── throttling_rigoureux.sh      # Protocole thermique rigoureux (warm-up + charge 5 min)
└── .github/workflows/
    └── build-apk.yml                # CI : build automatique de l'APK sur push
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
# Installation seule
bash scripts/setup_test_termux.sh <nom_appareil>

# Installation + benchmark automatique
bash scripts/setup_test_termux.sh <nom_appareil> --with-benchmark
```

Voir `docs/02_tutoriel_llamacpp.md` pour le tutoriel complet pas-à-pas, et `scripts/throttling_rigoureux.sh` pour le protocole de mesure thermique détaillé.

---

## Solutions couvertes

| Solution | Type | Framework | Appareil requis |
|---|---|---|---|
| llama.cpp + Gemma 2 2B | Open source | llama.cpp | Tout Android ARM64 |
| ML Kit GenAI + Gemini Nano | Propriétaire | AICore | Pixel 9/10, Galaxy S25/S26 |

---

## Livrables du PFE

- [`etat_art_llm_smartphone_v2.pdf`](./etat_art_llm_smartphone_v2.pdf) — État de l'art complet (LaTeX)
- [`timeline_llm_smartphone.pdf`](./timeline_llm_smartphone.pdf) — Chronologie illustrée imprimable
- `docs/chapitre_1_etat_art.md` → `docs/chapitre_4_retour_critique.md` — Les 4 chapitres du mémoire (rapport complet, pas encore assemblé en un PDF unique)
- Ce dépôt Git — code + tutoriels reproductibles

---

## Références principales

- [llama.cpp](https://github.com/ggml-org/llama.cpp) — Gerganov, 2023
- [MLC-LLM](https://github.com/mlc-ai/mlc-llm) — MLC AI Contributors, 2023
- [ML Kit GenAI](https://developers.google.com/ml-kit/genai) — Google, 2025
- [Gemma](https://arxiv.org/abs/2403.08295) — Google DeepMind, 2024
- [Xu et al. COTS Benchmark](https://arxiv.org/abs/2410.03613) — 2024
