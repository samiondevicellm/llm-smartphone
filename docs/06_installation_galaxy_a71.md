# Installation llama.cpp — Samsung Galaxy A71

Mémoire de Master — Informatique / Intelligence Artificielle
LLMs Embarqués sur Smartphone

---

## Étape 1 — Installer UserLAnd

UserLAnd est une application Android qui simule un environnement Linux complet (Ubuntu) sans nécessiter le root du téléphone. Elle utilise une technique appelée **proot** — un émulateur léger qui permet de faire tourner des programmes Linux à l'intérieur d'Android.

**Pourquoi c'est nécessaire** : llama.cpp est un programme Linux/Unix, il ne tourne pas nativement sur Android sans cet environnement intermédiaire.

**Procédure** :

1. Ouvrir le Play Store
2. Rechercher « UserLAnd »
3. Installer l'application
4. Lancer l'app → choisir **Ubuntu** comme distribution → **Terminal** comme type de session
5. Créer un nom d'utilisateur et un mot de passe (valables uniquement pour cette session locale)
6. Attendre 5 à 10 minutes au premier lancement (téléchargement du système Ubuntu, ~200 Mo)

---

## Étape 2 — Mettre à jour le système et installer les dépendances

```bash
sudo apt update && sudo apt upgrade -y
```

- `apt update` : actualise la liste des paquets disponibles (sans rien installer)
- `apt upgrade -y` : met à jour les paquets déjà installés vers leur dernière version ; `-y` confirme automatiquement

```bash
sudo apt install -y git cmake build-essential libssl-dev python3 python3-pip wget
```

Rôle de chaque paquet :

| Paquet | Rôle |
|---|---|
| `git` | Télécharger (cloner) le code source de llama.cpp depuis GitHub |
| `cmake` | Générer les fichiers de configuration nécessaires à la compilation |
| `build-essential` | Compilateur C++ (g++) et outils de compilation de base |
| `libssl-dev` | Bibliothèque de chiffrement requise par certaines dépendances de llama.cpp |
| `python3` + `python3-pip` | Faire tourner le prototype chatbot Python |
| `wget` | Télécharger le modèle GGUF depuis HuggingFace |

---

## Étape 3 — Compiler llama.cpp

```bash
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
```

Télécharge le code source de llama.cpp. `--depth 1` ne récupère que la dernière version (pas tout l'historique Git) — plus rapide et plus léger.

```bash
cd llama.cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON
```

- `cmake -B build` : génère les fichiers de compilation dans un dossier `build/`
- `-DCMAKE_BUILD_TYPE=Release` : compile en mode optimisé (rapide à l'exécution, contrairement au mode Debug)
- `-DGGML_NATIVE=ON` : active les optimisations spécifiques au processeur du téléphone (ici, les instructions ARM NEON du Snapdragon 730)

```bash
cmake --build build -j1
```

Lance la compilation effective.

- `-j1` : un seul fichier compilé à la fois, pour éviter le crash RAM observé sur l'A12/A26
- Avec 6–8 Go de RAM sur l'A71, `-j2` peut être tenté pour gagner du temps ; en cas de crash, revenir à `-j1`

**Durée estimée** : 20 à 40 minutes selon la RAM disponible.

---

## Étape 4 — Télécharger le modèle

```bash
wget -c "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf" \
     -O ~/Llama-3.2-1B-Instruct-Q4_K_M.gguf
```

- `wget -c` : télécharge le fichier ; `-c` permet de reprendre le téléchargement s'il est interrompu (utile sur WiFi instable)
- `-O ~/...` : précise le nom et l'emplacement du fichier téléchargé (ici, directement dans le dossier home `~/`)

Le fichier fait 771 Mo. Il s'agit du même modèle quantifié LLaMA 3.2 1B utilisé sur la VM Kali, le Galaxy A26 et le Galaxy A12 — conserver le même modèle est essentiel pour que les comparaisons entre appareils restent valides.

---

Une fois ces quatre étapes terminées, le benchmark `llama-bench` peut être lancé selon le même protocole que sur les autres appareils (5 runs, 512 tokens prompt, 128 tokens générés).
