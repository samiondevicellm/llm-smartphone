# Installation llama.cpp — Infinix Hot 60i 5G

Mémoire de Master — Informatique / Intelligence Artificielle
LLMs Embarqués sur Smartphone

**Appareil** : Infinix Hot 60i 5G (modèle X6730)
**SoC** : MediaTek Dimensity 6400 (6 nm), octa-core (2×2.5 GHz A76 + 6×2.0 GHz A55), GPU Mali-G57 MC2
**RAM** : 8 Go physique + 5 Go virtuelle (swap sur flash — non pertinente pour le chargement du modèle)
**Stockage** : 128 Go eMMC
**Batterie** : 6000 mAh
**OS** : Android 15, XOS 15.1

---

## Étape 1 — Installer UserLAnd

UserLAnd est une application Android qui simule un environnement Linux complet (Ubuntu) sans nécessiter le root du téléphone. Elle utilise **proot** — un émulateur léger qui permet de faire tourner des programmes Linux à l'intérieur d'Android.

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

```bash
sudo apt install -y git cmake build-essential libssl-dev python3 python3-pip wget
```

| Paquet | Rôle |
|---|---|
| `git` | Cloner le code source de llama.cpp depuis GitHub |
| `cmake` | Générer les fichiers de configuration de compilation |
| `build-essential` | Compilateur C++ (g++) et outils de base |
| `libssl-dev` | Bibliothèque de chiffrement requise par certaines dépendances |
| `python3` + `python3-pip` | Faire tourner le prototype chatbot Python et le script de mesure RAM |
| `wget` | Télécharger le modèle GGUF depuis HuggingFace |

---

## Étape 3 — Compiler llama.cpp

```bash
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
cd llama.cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON
```

- `-DGGML_NATIVE=ON` active les optimisations ARM NEON spécifiques au Dimensity 6400.
- Le GPU Mali-G57 n'est pas exploitable par llama.cpp (cf. limitation déjà documentée pour Exynos/MediaTek) → inférence CPU uniquement.

```bash
cmake --build build -j2
```

- Avec 8 Go de RAM physique, `-j2` devrait passer sans crash (contrairement à l'A12/A26 limités à `-j1`). En cas de crash mémoire pendant la compilation, repasser à `-j1`.

**Durée estimée** : 15 à 30 minutes.

---

## Étape 4 — Télécharger le modèle

```bash
wget -c "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf" \
     -O ~/Llama-3.2-1B-Instruct-Q4_K_M.gguf
```

Même modèle (771 Mo) que sur les autres appareils — indispensable pour que les comparaisons restent valides.

---

## Étape 5 — Lancer le benchmark complet

```bash
bash ~/benchmark_complet.sh ~/Llama-3.2-1B-Instruct-Q4_K_M.gguf "Infinix_Hot60i_5G"
```

Si le script n'est pas encore présent sur l'appareil, le recréer avec `scripts/recreate_command.txt` (copier-coller le contenu dans le terminal UserLAnd).

Le script mesure automatiquement : prefill/decode (5 runs), delta RAM, throttling thermique (run1 vs run2), consommation batterie avant/après. Pour la batterie, comme sous UserLAnd les chemins sysfs sont généralement inaccessibles, le script demandera de saisir manuellement le % batterie affiché par Android avant et après le test.

---

## Étape 6 — Récupérer les résultats

Les fichiers générés :
- `~/benchmark_results/Infinix_Hot60i_5G_<timestamp>.json`
- `~/benchmark_results/resultats_tous_appareils.csv` (ligne ajoutée automatiquement)

Copier ces fichiers vers le PC (via la clé USB-C, ou `scp`/partage réseau) pour les intégrer au tableau comparatif de `04_analyse_performances.md`.

---

## Point méthodologique à noter dans le rapport

Les 8 Go + 5 Go affichés par Infinix incluent de la RAM virtuelle (swap sur flash eMMC) — seuls les 8 Go physiques comptent pour le chargement du modèle. Si `RAM_delta_Mo` dans les résultats dépasse largement les 8 Go disponibles, le swap virtuel peut s'activer et fausser fortement les temps de decode (latence d'écriture flash >> RAM) : à surveiller via `free -m` pendant le test.
