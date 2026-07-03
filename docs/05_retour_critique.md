# Retour Critique — LLMs Embarqués sur Smartphone

## 1. Limites actuelles des modèles on-device

### 1.1 Raisonnement et logique formelle

Les modèles embarqués (<4B paramètres) présentent des limitations structurelles sur le raisonnement :

| Tâche | Gemma 2 2B | Phi-3 Mini (3,8B) | Gemini Nano-2 | GPT-4o (référence cloud) |
|---|---|---|---|---|
| GSM8K (arithmétique) | 46 % | 82,5 % | ~72 % | 92 % |
| ARC-Challenge (logique) | 51 % | 61 % | ~65 % | 96 % |
| MMLU (connaissances) | 52 % | 68,8 % | 79,6 % | 88 % |
| Raisonnement multi-étapes | Faible | Moyen | Moyen | Excellent |

**Conclusion** : les modèles on-device sont viables pour les tâches simples (Q/R factuelles, résumé, classification) mais insuffisants pour les tâches nécessitant un raisonnement enchaîné complexe (déduction logique, mathématiques avancées, planification longue).

### 1.2 Fenêtre de contexte limitée

La contrainte RAM impose des contextes courts :

| Modèle | Contexte max théorique | Contexte pratique sur mobile |
|---|---|---|
| Gemma 2 2B Q4 | 8 192 tokens | 2 048 tokens (3–4 Go RAM) |
| LLaMA 3.2 3B Q4 | 128 000 tokens | 2 048–4 096 tokens |
| Gemini Nano-2 | Non publié | ~2 048 tokens (AICore) |

Au-delà de 2 048 tokens de contexte, la consommation RAM devient critique sur les appareils avec 6–8 Go disponibles, provoquant des `SIGKILL` (OOM killer Android).

**Impact pratique** : impossibilité d'analyser des documents longs (articles académiques, contrats), de maintenir des conversations très longues, ou de faire de la RAG (Retrieval-Augmented Generation) avec de grands chunks.

### 1.3 Stabilité et hallucinations

Les modèles compressés (INT4) présentent une légère augmentation des hallucinations par rapport à leurs versions FP16 :
- Environ 3–5 % de dégradation sur les benchmarks de fidélité factuelle
- Particulièrement visible sur les noms propres et les données chiffrées
- Le throttling thermique aggrave ces comportements en fin de session longue

### 1.4 Support multilingue dégradé

Le français et les autres langues non-anglaises sont systématiquement moins bien supportés :
- Phi-3 Mini : −15 à 20 % de qualité en français vs anglais
- LLaMA 3.2 3B : biais anglophone marqué malgré 8 langues déclarées
- Seul Gemini Nano (via Gemini) offre un support multilingue robuste

---

## 2. Pertinence pour des systèmes complexes (agents, MCP)

### 2.1 LLMs embarqués comme agents autonomes

L'utilisation de modèles on-device dans des architectures agentiques (type ReAct, Tool-use, MCP) est **théoriquement possible mais pratiquement limitée** :

**Ce qui fonctionne :**
- Agents simples avec 2–3 outils fixes (calculatrice, horloge, calendrier)
- Classification et routage de tâches vers le bon outil
- Extraction d'entités et structuration de données
- Agents "single-step" sans chaîne de pensée longue

**Ce qui ne fonctionne pas bien :**
- ReAct (Reasoning + Acting) avec chaînes >3 étapes : le modèle perd le fil
- Tool-calling fiable : les modèles <4B génèrent des appels malformés fréquemment
- Planning long horizon : dégradation rapide avec la profondeur de la chaîne
- Self-correction : les petits modèles ont du mal à détecter leurs propres erreurs

### 2.2 Intégration avec le protocole MCP (Model Context Protocol)

Le MCP (Anthropic, 2024) définit un protocole standardisé pour connecter des LLMs à des outils externes. Son intégration avec des modèles embarqués présente des défis spécifiques :

```
Architecture MCP on-device envisageable :

[Application Android]
       ↓
[MCP Client local]
       ↓
[LLM embarqué — Gemma 2 2B / Gemini Nano]
       ↓
[MCP Server local] → [Outils : calendrier, notes, contacts, GPS]
```

**Problèmes identifiés :**
1. **Format JSON strict** : les modèles <4B génèrent du JSON malformé dans ~15–30 % des cas (dépend du prompt engineering)
2. **Latence cumulée** : chaque appel d'outil ajoute 1–3 secondes de délai. Une chaîne de 5 outils représente 15–20s de latence totale
3. **Gestion du contexte** : l'historique des appels d'outils consomme rapidement la fenêtre de contexte limitée

**Solution pragmatique** : utiliser le modèle embarqué uniquement pour le **routage et la classification**, et déléguer l'exécution complexe à un MCP server structuré avec des templates rigides :

```python
# Exemple : routage local + exécution structurée
def route_request(user_input: str, llm) -> str:
    # Le LLM embarqué classe l'intention (tâche simple)
    intent = classify_intent(user_input, llm)  # "calendrier", "notes", "question"
    
    if intent == "calendrier":
        return calendar_tool.handle(user_input)  # Logique déterministe
    elif intent == "question":
        return llm.generate(user_input)          # LLM pour les questions libres
```

### 2.3 Cas d'usage réalistes avec les LLMs embarqués

| Cas d'usage | Faisabilité | Modèle recommandé | Notes |
|---|---|---|---|
| Chatbot FAQ local | ✅ Excellent | Gemma 2 2B / Gemini Nano | Cas d'usage principal |
| Résumé d'emails/articles | ✅ Très bon | Gemini Nano + ML Kit | ML Kit GenAI natif |
| Clavier intelligent | ✅ Bon | MobileLLM 1B | Faible latence requise |
| Classification de sentiment | ✅ Excellent | Gemma 2 2B | Très fiable |
| Extraction d'entités (NER) | ✅ Bon | Phi-3 Mini | Meilleur en anglais |
| Agent de planification | ⚠️ Limité | Phi-3 Mini uniquement | Max 3 étapes |
| Analyse de documents longs | ❌ Inadapté | Aucun | Contexte trop court |
| Raisonnement complexe | ❌ Inadapté | Aucun | Qualité insuffisante |
| Code generation complexe | ⚠️ Partiel | Phi-3 Mini | Simple seulement |

---

## 3. Recommandations pour une architecture réaliste

### 3.1 Principe directeur : "Local by default, Cloud by exception"

L'architecture la plus pragmatique n'est ni entièrement locale ni entièrement cloud, mais **hybride avec un routeur intelligent** :

```
┌─────────────────────────────────────────────────────────┐
│                  APPLICATION MOBILE                      │
│                                                         │
│  ┌──────────┐    ┌─────────────────────────────────┐   │
│  │  Routeur │───▶│    Traitement LOCAL              │   │
│  │  local   │    │  • Gemma 2 2B / Gemini Nano     │   │
│  │ (règles  │    │  • Résumé, FAQ, classification   │   │
│  │  + LLM)  │    │  • Réponse en <2s               │   │
│  └──────────┘    └─────────────────────────────────┘   │
│       │                                                 │
│       │ (si tâche complexe OU hors contexte)           │
│       ▼                                                 │
│  ┌─────────────────────────────────────────────────┐   │
│  │        Traitement CLOUD (si connecté)           │   │
│  │  • Gemini Flash / GPT-4o                       │   │
│  │  • Raisonnement, documents longs               │   │
│  │  • Réponse en <1s (latence réseau)             │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Critères de routage suggérés :**

```python
def should_use_cloud(request: str, context_length: int) -> bool:
    # Basculer vers le cloud si :
    return any([
        context_length > 1500,          # Contexte trop long pour le local
        contains_complex_reasoning(request),  # Maths, logique formelle
        requires_recent_knowledge(request),   # Infos récentes (post-entraînement)
        user_prefers_speed and is_online(),   # Préférence vitesse + connecté
    ])
```

### 3.2 Choix du framework selon le contexte

| Contexte | Framework recommandé | Justification |
|---|---|---|
| App grand public, flagship récent | ML Kit GenAI | Performance NPU, API simple |
| App R&D, tous appareils | llama.cpp | Flexibilité maximale |
| Appareils Samsung/MediaTek | MLC-LLM | Seul à exploiter GPU Mali |
| Prototypage rapide | llama-cpp-python | Éco. Python, itération rapide |
| Production multiplateforme | MLC-LLM | Performance + couverture matérielle |

### 3.3 Recommandations pour les futurs travaux

1. **Explorer la quantification adaptative** : ajuster la précision par couche selon la sensibilité (certaines couches tolèrent INT2 sans perte notable)

2. **Implémenter le KV Cache partiel** : Apple montre qu'un KV Cache Sharing bien conçu réduit la mémoire de 37,5 % — applicable aux frameworks open source

3. **Systèmes multi-modèles** : un petit modèle (1B) pour le routage + un modèle moyen (3B) pour l'exécution — meilleure utilisation des ressources que d'un seul grand modèle

4. **Évaluer PowerInfer-2 en production** : la sparsité des activations est une piste prometteuse pour faire tourner des modèles 7B+ sur mobile

5. **Standard OS LLM** : contribuer ou adopter les standards émergents (type LLM as System Service) pour éviter la duplication des modèles entre applications

---

## 4. Conclusion critique

Les LLMs embarqués sur smartphone ont atteint en 2024–2025 un niveau de maturité suffisant pour des applications grand public **bien circonscrites** : résumé, FAQ, suggestion de texte, classification. La combinaison Gemma 2 2B Q4 + llama.cpp offre une solution open source reproductible, fonctionnelle sur tout appareil ARM64 Android.

Cependant, plusieurs barrières persistent :
- **Qualitatif** : le gap avec les modèles cloud reste significatif sur le raisonnement
- **Matériel** : la fragmentation Android (GPU Mali non supporté par llama.cpp) complique le déploiement universel
- **Architectural** : l'absence de standard OS pour le service LLM force chaque application à dupliquer le modèle en mémoire

L'architecture hybride — modèle local pour les tâches courantes, cloud pour les cas complexes — représente le compromis le plus réaliste pour les 2–3 prochaines années, jusqu'à ce que les modèles embarqués franchissent le seuil qualitatif des 7–10B paramètres quantifiés en 2 bits.

---

## Références

- Xu et al. (2024). *Understanding LLMs in Your Pockets*. arXiv:2410.03613
- Fassold (2024). *Porting LLMs to Mobile Devices*. CVPR Workshops
- Apple ML Research (2024). *Apple Intelligence Foundation Language Models*. arXiv:2507.13575
- Yin et al. (2024). *LLM as a System Service on Mobile Devices*
- Ye et al. (2025). *Prima.cpp*. arXiv:2504.08791
