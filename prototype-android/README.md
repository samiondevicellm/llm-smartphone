# Prototype Android — Chatbot Gemini Nano (ML Kit GenAI)

Application Android minimaliste pour tester Gemini Nano via l'API ML Kit GenAI.  
Mesure la latence et le débit de tokens pour l'analyse de performances du PFE.

## Prérequis

- **Android Studio** Hedgehog 2023.1.1 ou plus récent
- **Appareil physique** (émulateur non supporté pour AICore) :
  - Samsung Galaxy S25 / S25+ / S25 Ultra / **S26**
  - Google Pixel 9 / 9 Pro / 9 Pro XL / 10
- Android 14 (API 34) minimum sur l'appareil
- Connexion internet au premier lancement (téléchargement du modèle ~1 Go)

## Compilation et déploiement

```bash
# 1. Ouvrir le projet dans Android Studio
#    File → Open → sélectionner ce dossier (prototype-android/)

# 2. Synchroniser Gradle
#    (Android Studio le propose automatiquement)

# 3. Connecter le S26 en USB (activer le mode développeur)
#    Paramètres → À propos → Numéro de build (tap 7 fois)
#    Paramètres → Options développeur → Débogage USB → Activer

# 4. Lancer l'application
#    Run → Run 'app' (Shift+F10)
```

## Structure du projet

```
prototype-android/
├── app/
│   ├── build.gradle.kts          # Dépendances ML Kit GenAI
│   └── src/main/
│       ├── AndroidManifest.xml   # Permissions + meta-data AICore
│       ├── java/com/pfe/llmchat/
│       │   ├── LlmViewModel.kt   # Logique inférence + métriques
│       │   ├── MainActivity.kt   # UI principale
│       │   └── ChatAdapter.kt    # Adaptateur RecyclerView
│       └── res/layout/
│           └── activity_main.xml # Layout principal
├── settings.gradle.kts
└── build.gradle.kts
```

## Métriques collectées

L'application affiche en temps réel pour chaque réponse :
- **Latence totale** (ms) — du premier token au dernier
- **Débit** (tokens/s) — approximation basée sur le streaming
- **Nombre de tokens générés**

Ces métriques alimentent la section "Volet 2 — Gemini Nano" du chapitre d'analyse des performances.

## Notes importantes

- Le modèle Gemini Nano est géré par AICore (système Android) — il est partagé entre toutes les applications et mis en cache automatiquement.
- La fenêtre de contexte est limitée à ~2 048 tokens par l'API AICore.
- L'application ne fonctionne **pas** sur émulateur.
- En cas d'erreur "Gemini Nano non disponible" sur S26 : vérifier que **Google Play Services** est à jour (version 24.20+) et que **Android AI Core** est installé (Settings → Apps → AI Core).
