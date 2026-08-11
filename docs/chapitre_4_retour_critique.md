# Chapitre 4 — Retour Critique : LLMs Embarqués sur Smartphone

> **Mémoire PFE** — Intelligence Artificielle, Master Informatique  
> Rédigé en juillet 2026

---

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

### 1.5 Barrière de la reproductibilité : le cas Gemini Nano

À notre connaissance, **aucune étude académique publiée à ce jour ne fournit de benchmarks empiriques indépendants de Gemini Nano**. Cette absence n'est pas un oubli des chercheurs : elle reflète une limite structurelle.

Gemini Nano est un modèle entièrement propriétaire dont les poids ne sont pas distribués. L'accès passe obligatoirement par l'API ML Kit GenAI ou AICore, qui n'était pas publiquement disponible avant mi-2025. Par ailleurs, l'API n'expose pas les métriques brutes nécessaires à un benchmark rigoureux (prefill/decode en tokens/s, bande passante mémoire, utilisation NPU). Xu et al. [19], qui constituent la référence la plus complète sur les LLMs mobiles, ont délibérément exclu Gemini Nano de leur corpus pour cette raison et se limitent à llama.cpp et MLC-LLM — deux frameworks entièrement open source et reproductibles.

Notre PFE s'est heurté aux mêmes obstacles. La tentative de déploiement via ML Kit GenAI a révélé que le SDK n'est pas référencé sur Maven Central public, et les modèles "via AICore" se sont avérés désactivés sur le Galaxy S26 Ultra testé (bouton non fonctionnel dans AI Edge Gallery). Le benchmark Google on-device a finalement été réalisé via LiteRT (AI Edge Gallery), qui constitue la solution Google on-device la plus proche accessible sans compte développeur ni matériel certifié.

**Ce constat illustre une tension fondamentale dans le domaine :** les solutions propriétaires les plus performantes (Gemini Nano, Apple Intelligence) sont précisément celles qui échappent à l'évaluation scientifique indépendante. La recherche reproductible sur les LLMs embarqués reste donc, en 2025-2026, quasi-exclusivement fondée sur les frameworks open source.

### 1.6 Commercialisation et barrières d'accès à l'IA embarquée

Au-delà des contraintes techniques, nos observations terrain révèlent une série de **barrières d'ordre commercial** qui structurent profondément l'accessibilité à l'inférence LLM on-device et méritent d'être examinées d'un point de vue critique.

#### 1.6.1 La stratification artificielle des capacités IA selon le segment de prix

Les constructeurs de smartphones segmentent délibérément l'accès aux fonctionnalités IA en fonction du positionnement tarifaire de leurs appareils, indépendamment des capacités matérielles réelles. Le Galaxy A16 5G (Exynos 1330) intègre un NPU dédié dont les spécifications sont insuffisamment documentées publiquement, et Samsung n'expose aucune API tierce permettant son exploitation directe. De même, le Galaxy S26 Ultra testé dans ce PFE dispose d'un Snapdragon 8 Elite dont le NPU (Hexagon) offre une puissance largement supérieure aux besoins de Gemma 2 2B — mais l'accès à AICore y est désactivé via AI Edge Gallery. Nos benchmarks démontrent pourtant que les deux appareils peuvent exécuter l'inférence LLM de manière fonctionnelle via llama.cpp sur CPU, contournant ainsi la couche de contrôle commerciale imposée par les fabricants. Cette observation soulève une question fondamentale : les restrictions d'accès aux fonctions IA sur les appareils entrée et milieu de gamme relèvent-elles de contraintes techniques objectives, ou d'une stratégie de différenciation commerciale par la fonctionnalité ?

#### 1.6.2 L'obsolescence déclarée versus la capacité matérielle effective

Notre corpus d'appareils met en évidence un décalage significatif entre l'obsolescence logicielle déclarée par les constructeurs et la capacité matérielle effective des appareils. Le Galaxy A71 (Snapdragon 730, lancé en 2019) a cessé de recevoir des mises à jour système Samsung en 2023 et est exclu de tout accès à « Galaxy AI ». Pourtant, nos mesures établissent qu'il exécute Gemma 2 2B Q4_K_M à une vitesse d'inférence permettant une interaction conversationnelle réelle. Ce résultat empirique illustre que l'obsolescence IA proclamée par les constructeurs est en partie commercialement construite : elle accélère le cycle de renouvellement des appareils en associant les fonctionnalités IA aux modèles récents, là où la capacité matérielle permettrait une continuité de service pour l'utilisateur. En ce sens, la distinction entre « appareil IA » et « appareil non-IA » reflète davantage une décision stratégique de l'écosystème qu'une limite technique absolue.

#### 1.6.3 Le label « AI phone » à l'épreuve des mesures empiriques

La GSMA projette 750 millions d'« AI phones » en circulation d'ici 2028 [14]. Or, l'examen de ce label révèle une définition hétérogène : il désigne aussi bien des appareils intégrant un traitement on-device réel que des terminaux dont les fonctions « IA » sont intégralement déléguées au cloud. Nos résultats fournissent un étalon de mesure concret : un Galaxy A16 5G commercialisé à environ 200 euros produit une inférence LLM locale à ~1,5 tokens/s via llama.cpp, sans connexion réseau, avec une empreinte mémoire de 2,2 Go. En comparaison, le Galaxy S26 Ultra, dont le prix dépasse 900 euros et qui est officiellement positionné comme un « AI flagship », affiche un temps de génération de 6,0 secondes pour une réponse via LiteRT — quatre fois plus lent que llama.cpp sur le même appareil pour la tâche équivalente, selon nos mesures (chapitre 2, section analyse des performances). Ces données empiriques invitent à nuancer le discours marketing autour de l'IA embarquée et à distinguer la puissance matérielle brute de l'efficacité d'inférence réelle sur les frameworks disponibles.

#### 1.6.4 La fragmentation des écosystèmes comme obstacle à l'universalité

Apple Intelligence (Apple, 2025), Gemini Nano / AICore (Google), et Galaxy AI (Samsung) constituent trois écosystèmes d'IA embarquée intentionnellement fermés et mutuellement incompatibles. Cette fragmentation n'est pas accidentelle : elle répond à une logique de rétention des utilisateurs dans l'écosystème propriétaire de chaque constructeur. Pour la recherche académique, cette situation est problématique à double titre. D'une part, elle rend impossible toute évaluation comparative rigoureuse entre solutions propriétaires, comme le démontre l'impossibilité d'obtenir des métriques brutes sur Gemini Nano (section 1.5). D'autre part, elle concentre les capacités IA les plus avancées sur des appareils et des marchés inaccessibles à la majorité des utilisateurs mondiaux. Nos benchmarks sur appareils entrée et milieu de gamme — absents de la littérature académique existante, comme le montre la comparaison avec Xu et al. [19] — constituent une réponse directe à cette lacune : ils démontrent la faisabilité d'une IA embarquée reproductible, indépendante des écosystèmes propriétaires, sur le type d'appareils que possèdent effectivement la majorité des utilisateurs dans les marchés émergents.

#### 1.6.5 Vers une IA embarquée accessible : le rôle des frameworks open source

Face à ces barrières commerciales, les frameworks open source — llama.cpp, MLC-LLM, GGUF — jouent un rôle de **correctif structurel**. En s'appuyant uniquement sur le CPU ARM64 disponible sur tout appareil Android depuis 2018, llama.cpp contourne l'ensemble des verrous commerciaux décrits ci-dessus. Cette approche, qui constitue le cœur méthodologique de ce PFE, n'est pas neutre : elle repositionne l'utilisateur comme acteur autonome de son environnement IA, indépendamment des décisions commerciales du constructeur ou de l'opérateur. Elle s'inscrit dans une tradition plus large de souveraineté technologique et de droit à la réparabilité numérique, dont l'extension au domaine de l'IA embarquée constitue, à notre sens, un enjeu de politique publique émergent que la recherche académique a un rôle à jouer pour documenter et légitimer.

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

4. **Évaluer PowerInfer-2 en production** [26] : la sparsité des activations est une piste prometteuse pour faire tourner des modèles 7B+ sur mobile. Xue et al. (2024) démontrent 29,2× d'accélération via décomposition en clusters de neurones (neuron cluster decomposition), permettant théoriquement l'exécution d'un modèle 47B sur smartphone. Ces résultats spectaculaires ne sont pas encore reproduits de manière indépendante, mais la direction algorithmique est prometteuse pour dépasser les limites actuelles de la bande passante mémoire.

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
- [22] Li et al. (2024). *PalmBench: A Comprehensive Benchmark of Compressed Large Language Models on Mobile Platforms*. arXiv:2410.05315.
- [23] Murthy et al. (2024). *MobileAIBench: Benchmarking LLMs and LMMs for On-Device Use Cases*. NeurIPS 2024. arXiv:2406.10290.
- [24] Song et al. (2025). *A Systematic Evaluation of On-Device LLMs: Quantization, Performance, and Resources*. arXiv:2505.15030.
- [25] Tummalapalli et al. (2026). *LLM Inference at the Edge: Mobile, NPU, and GPU Performance Efficiency Trade-offs Under Sustained Load*. arXiv:2603.23640.
- [26] Xue et al. (2024). *PowerInfer-2: Fast Large Language Model Inference on a Smartphone*. arXiv:2406.06282.
- [27] Yadav, M. & Bhargavi, P. (2024). *Optimizing LLMs Using Quantization For Mobile Execution*. ICT4SD 2025, Springer LNNS. arXiv:2512.06490.
