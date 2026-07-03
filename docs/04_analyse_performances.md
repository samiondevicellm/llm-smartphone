# Analyse des Performances — LLMs Embarqués sur Smartphone

## 1. Méthodologie de mesure

Toutes les mesures suivent le protocole défini par Xu et al. [19] et le profileur lm-Meter [21] :

- **Prefill** : traitement du prompt entrant (compute-bound — limité par la puissance CPU/NPU)
- **Decode** : génération token par token (memory-bound — limité par la bande passante RAM)
- **Throttling** : dégradation des performances mesurée après 5 minutes d'inférence continue
- **RAM delta** : mémoire supplémentaire consommée après chargement du modèle

### Outil de mesure

```bash
# Lancer le benchmark complet
python benchmark.py --model models/gemma-2-2b-it-q4_k_m.gguf --runs 5

# Résultats sauvegardés dans benchmarks/results/
```

---

## 2. Résultats sur appareils réels (llama.cpp, Gemma 2 2B Q4_K_M)

| SoC | Appareil | Prefill | Decode | RAM delta | Throttling 5 min |
|---|---|---|---|---|---|
| Snapdragon 8 Gen 3 | Xiaomi 14 Pro | 28–35 tok/s | 12–16 tok/s | +2,4 Go | −12 % |
| Dimensity 9300 | Vivo X100 | 22–28 tok/s | 10–14 tok/s | +2,4 Go | −14 % |
| Apple A17 Pro | iPhone 15 Pro | 40–52 tok/s | 18–24 tok/s | +2,2 Go | −8 % |
| Kirin 9000E | Huawei P60 | 14–18 tok/s | 8–11 tok/s | +2,5 Go | −22 % |
| Exynos 1380 | Galaxy A54 | 10–14 tok/s | 5–8 tok/s | +2,4 Go | −25 % |

> Source : Xu et al. [19], Fassold [20], mesures protocole lm-Meter [21].

---

## 2bis. Résultats mesurés en conditions réelles (protocole interne, UserLAnd, llama.cpp, Llama 3.2 1B Q4_K_M)

> ⚠️ Modèle différent de la section 2 (Llama 3.2 1B vs Gemma 2 2B) — comparaison à titre indicatif uniquement, pas de comparaison directe valide entre les deux tableaux.

| SoC | Appareil | Environnement | RAM totale | Prefill | Decode | Throttling | Delta RAM | Batterie |
|---|---|---|---|---|---|---|---|---|
| Dimensity 6400 (6nm) | Infinix Hot 60i 5G | UserLAnd | 7625 Mo | 54,78 ± 3,15 tok/s | 11,86 ± 0,35 tok/s | −21,8 % (pas de throttling) | −178 Mo* | −1 % / 3 min |
| Dimensity 6400 (6nm) | Infinix Hot 60i 5G | Termux natif | 7625 Mo | 54,75 ± 7,20 tok/s | 12,67 ± 0,75 tok/s | −0,7 % (artefact schedutil, pas de throttling)♦ | −236 Mo* | −1 % / 5 min |
| Exynos 1280 (5nm) | Galaxy A26 | UserLAnd | 5427 Mo | 65,21 ± 6,50 tok/s | 6,86 ± 0,07 tok/s | aucun (protocole naïf 5 runs)†† | N/A | N/A |
| Exynos 1280 (5nm) | Galaxy A26 | Termux natif | 5427 Mo | **92,13 ± 30,42 tok/s**† | 10,83 ± 2,54 tok/s | **−100,2 % (artefact governor)‡** | −569 Mo* | −1 % / 15 min |
| Snapdragon 730 (8nm) | Galaxy A71 | UserLAnd | 7519 Mo | 36,05 ± 0,07 tok/s | 11,66 ± 0,03 tok/s | +0,3 % (pas de throttling) | −411 Mo* | −1 % / 5 min |
| Snapdragon 730 (8nm) | Galaxy A71 | Termux natif | 7519 Mo | 46,66 ± 0,24 tok/s | 11,40 ± 0,29 tok/s | −4,4 % (artefact schedutil, pas de throttling)§§ | −184 Mo* | −1 % / 5 min |
| Snapdragon 778G (6nm) | Galaxy A73 | UserLAnd | 7333 Mo | 58,07 ± 14,09 tok/s | **13,19 ± 0,13 tok/s** | **0,0 % (aucun throttling)** | −893 Mo* | −2 % / 5 min |
| Snapdragon 778G (6nm) | Galaxy A73 | Termux natif | 7333 Mo | **79,69 ± 1,07 tok/s** | **13,36 ± 0,80 tok/s** | **−104,8 % (artefact governor)**¤ | −469 Mo* | <1 % / 5 min† |
| Exynos 1330 (5nm) | Galaxy A16 | Termux natif | 5452 Mo | **57,99 ± 7,77 tok/s**† | 14,00 ± 0,42 tok/s¶ | **−19,1 % (throttling thermique réel)**∥ | −634 Mo* | N/A (sysfs inaccessible) |
| Snapdragon 8 Elite (3nm) | Galaxy S26 | Termux natif | 10240 Mo | **235,65 ± 11,26 tok/s** | **46,68 ± 14,40 tok/s**◊ | **−17,3 % (throttling thermique réel)**◆ | N/A | −2 % / 12 min |

\* Delta RAM négatif — artefact probable : faible RAM libre avant test, le noyau réclame du cache mémoire sous pression pendant l'inférence, ce qui fausse la mesure brute `free -m`.

†† Galaxy A26 (UserLAnd) — decode anormalement bas : 6,86 tok/s sous UserLAnd vs 10,83 tok/s sous Termux natif (−37 %). Unique dans le corpus : sur tous les autres appareils testés, le decode UserLAnd et Termux sont comparables (±5–10 %). Hypothèse : l'Exynos 1280 (Cortex-A55 efficaces) subit une dégradation de bande passante mémoire plus marquée sous la couche proot/UserLAnd que les architectures big.LITTLE avec cœurs A78 dominants (A73, A71). Throttling non remesuré avec le protocole rigoureux (warm-up + 9 runs) — valeur "aucun" issue de l'observation sur 5 runs consécutifs (session initiale 07/06/2026). RAM delta et batterie non mesurés lors de cette session.

† Prefill Galaxy A26 : valeur élevée (92 tok/s) avec écart-type très important (±30,42 = 33 % de CV). Cause identifiée : Termux natif accède directement au governor `schedutil` Android — les premiers runs bénéficient d'un boost de fréquence CPU, puis se stabilisent, créant une forte variance inter-runs. Valeur de prefill peu robuste sans warm-up préalable.

‡ Throttling Galaxy A26 : valeur −100,2 % = artefact de mesure identique à celui observé sur l'Infinix Hot 60i. La baseline (6,23 tok/s) a été capturée pendant un creux du governor CPU (schedutil Android) immédiatement après le warm-up. Sous charge soutenue (11 runs / 300s), le CPU s'est stabilisé à ~11–13 tok/s (médiane 11,94 tok/s), cohérent avec le benchmark principal (10,83 tok/s). Deux creux ponctuels (7,13 et 8,48 tok/s) liés à l'ordonnanceur Android, pas à la température. **Conclusion : aucun throttling thermique détectable sur le Galaxy A26 sur ~5 min de charge continue** — même résultat que le Dimensity 6400, mais pour une raison différente : la variance est ici dominée par le governor Android (schedutil) plutôt que par la thermique.

**Protocole de mesure du throttling (affiné)** : un premier test naïf (decode à froid vs decode immédiatement après 2 runs espacés de 2s) donnait un throttling quasi nul (0,5 %) mais n'était pas représentatif — fenêtre trop courte pour chauffer le SoC. Un deuxième test avec charge continue via chat interactif (`llama-cli`, génération de 4000 tokens, 622s) a donné une dégradation apparente de −43,7 % (= accélération), confondue par la croissance du contexte (le decode ralentit naturellement avec un contexte qui s'allonge, indépendamment de la température). Le protocole final corrige les deux biais : (1) un run de warm-up neutralise l'effet de ramp-up du gouverneur CPU avant la mesure baseline, (2) la charge est générée par une boucle `llama-bench` à contexte fixe (512 prompt / 128 génération par run, 9 runs sur 310s) pour éviter la confusion avec la croissance de contexte.

**Résultat** : même avec ce protocole rigoureux, le decode post-charge (12,12 tok/s) reste plus rapide que la baseline (9,95 tok/s). **Aucun throttling thermique détectable sur ~5 minutes de charge continue** sur le Dimensity 6400 — à l'inverse des SoCs du tableau de référence en section 2 (Exynos 1380 : −25 %, Kirin 9000E : −22 %). Hypothèse : le 6nm du Dimensity 6400 et la faible charge de calcul d'un modèle 1B Q4 (vs Gemma 2 2B testé en section 2) restent dans l'enveloppe thermique du boîtier sur cette durée. **Limite** : ce résultat ne couvre que ~5 min ; une charge plus longue (10–15 min) pourrait éventuellement révéler un throttling qui n'apparaît pas encore à ce stade — à mentionner explicitement comme piste non explorée plutôt que de conclure à une absence totale de throttling.

¶ Decode Galaxy A16 (benchmark principal) : valeur 9,26 ± 4,44 tok/s sous-estimée — artefact schedutil identique au A26. La performance decode réelle sous conditions stables est ~13,3 tok/s (mesurée via baseline du test throttling).

∥ Throttling Galaxy A16 : **premier throttling thermique réel observé dans le corpus** (protocole rigoureux : warm-up + baseline 13,30 tok/s + 9 runs contexte fixe + post-charge 10,76 tok/s). La chute apparaît au run 8 (11,22 tok/s) et se confirme en post-charge. Contrairement aux autres appareils testés (Infinix, A71 sous UserLAnd), l'Exynos 1330 du Galaxy A16 atteint ses limites thermiques après ~8 runs (~8 min de charge continue) sous Termux natif. Batterie throttling test : 24 % → 21 % (−3 % / ~12 min).

§ Throttling Galaxy A71 (UserLAnd) : protocole rigoureux (warm-up + baseline + 9 runs contexte fixe 512+128 tokens). Résultats : baseline 11,82 tok/s → médiane charge 11,65 tok/s → post-charge 11,78 tok/s. Spread total : 11,52–11,76 tok/s (0,24 tok/s). **Aucun throttling thermique détectable (+0,3 %)** — même conclusion que l'Infinix Hot 60i sous UserLAnd. La couche proot/UserLAnd isole du governor schedutil Android, donnant une variance minimale. Batterie throttling test : 44 % → 41 % (−3 % / ~12 min).

¤ Throttling Galaxy A73 (Termux natif) : artefact governor schedutil extrême. Baseline capturée à 7,87 tok/s (creux governor post warm-up), post-charge à 16,12 tok/s (CPU à pleine fréquence). Runs 1-6 : oscillations 7,91–11,52 tok/s (governor en montée), runs 7-9 : 15,47–16,08 tok/s (fréquence stabilisée). Aucun throttling thermique — la performance stable réelle est ~13–16 tok/s, cohérente avec le benchmark (13,36 tok/s). Le Snapdragon 778G présente un governor schedutil plus agressif que le Snapdragon 730 sous Termux natif. Contraste majeur avec le test UserLAnd (0,0 % de variance) : la couche proot isole totalement ce comportement. Batterie : 63 % → 59 % (−4 % / ~12 min).

§§ Throttling Galaxy A71 (Termux natif) : warm-up 11,60 tok/s → baseline 11,34 tok/s → 9 runs charge (11,39–11,84 tok/s, spread 0,45 tok/s) → post-charge 11,84 tok/s → −4,4 %. Valeur négative = artefact schedutil (baseline légèrement basse, post-charge légèrement haute). **Aucun throttling thermique sur ~12 min de charge continue** — même conclusion que sous UserLAnd. Notable : le Snapdragon 730 montre une variance beaucoup plus faible sous Termux natif (prefill ±0,24 tok/s) que les Exynos 1280/1330 (±13–30 tok/s) — le governor Qualcomm schedutil est significativement plus stable que son équivalent Samsung. Batterie throttling test : 54 % → 52 % (−2 % / ~12 min).

♦ Throttling Infinix Hot 60i 5G (Termux natif) : protocole rigoureux (warm-up 12,55 → baseline 13,01 tok/s → 9 runs contexte fixe → post-charge 13,10 tok/s). Throttling : −0,7 % (quasi nul). Deux creux ponctuels détectés : run 7 (11,12 tok/s) et run 9 (9,51 tok/s) — artefacts schedutil MediaTek Dimensity 6400, non liés à la thermique (le post-charge revient immédiatement à 13,10 tok/s). Médiane charge : 12,79 tok/s, spread 9,51–13,57 tok/s (4,06 tok/s). **Aucun throttling thermique sur ~12 min de charge continue** — même conclusion que sous UserLAnd (−21,8 %). Comportement notable : contrairement aux Snapdragon 730/778G qui montrent un governor schedutil très agressif sous Termux (creux baseline → accélération apparente post-charge), le Dimensity 6400 présente une baseline stable (13,01) et des oscillations en cours de charge plutôt qu'au démarrage. La variance (±7,20 tok/s en prefill benchmark, creux ponctuels en throttling) est une signature propre au governor MediaTek EAS sous Android. Batterie throttling test : 65 % → 63 % (−2 % / ~12 min).

◊ Decode Galaxy S26 : variance élevée (CV = 30,8 %) due au governor schedutil Snapdragon 8 Elite très agressif. Run 2 anomalie extrême (6,46 tok/s) = crash thermique bref puis récupération immédiate — signature documentée du Snapdragon 8 Elite. Médiane charge : 43,5 tok/s.

◆ Throttling Galaxy S26 : baseline 49,48 tok/s → post-charge 40,92 tok/s → −17,3 %. **Throttling thermique réel confirmé** — 2ème cas du corpus après le Galaxy A16 (−19,1 %). Le Snapdragon 8 Elite génère significativement plus de chaleur que les SoCs milieu de gamme avec le même modèle 1B Q4, car il s'exécute à des fréquences bien plus élevées (235 tok/s prefill vs 36–80 tok/s milieu de gamme). 9 runs individuels : prefill 82–237 tok/s, decode 6,46–51,38 tok/s (oscillations governor extrêmes). Batterie : 37 % → 35 % (−2 % / ~12 min).

> Source : mesures propres via `benchmark_complet.sh` — Infinix : UserLAnd/proot (Ubuntu), 30 juin 2026 ; Termux natif, 1er juillet 2026 — Galaxy A26 : Termux natif (Android), 1er juillet 2026 — Galaxy A71 : UserLAnd/proot + Termux natif (Android), 1er juillet 2026 — Galaxy A16 : Termux natif (Android), 1er juillet 2026 — Galaxy A73 : UserLAnd/proot + Termux natif (Android), 1er juillet 2026 — Galaxy S26 : Termux natif (Android), 3 juillet 2026.

---

## 3. Comparaison llama.cpp vs MLC-LLM (Snapdragon 8 Gen 3)

| Métrique | llama.cpp | MLC-LLM | Gain MLC |
|---|---|---|---|
| Prefill (tok/s) | 28–35 | 34–44 | +23 % |
| Decode (tok/s) | 12–16 | 15–20 | +25 % |
| Latence 1er token | 0,8–1,2s | 0,6–0,9s | −25 % |
| RAM utilisée | 2,4 Go | 2,3 Go | −4 % |
| GPU Mali activé | ❌ Non | ✅ Oui (Vulkan) | — |

> **Conclusion** : MLC-LLM est 20–25 % plus rapide grâce à l'optimisation compilateur TVM et au support GPU Mali via Vulkan.

---

## 4. Impact de la quantification sur la qualité

| Format | Taille (Gemma 2 2B) | MMLU | GSM8K | Decode (Snap. 8 Gen 3) |
|---|---|---|---|---|
| FP16 (référence) | 4,8 Go | 52,4 % | 46,2 % | 6–8 tok/s |
| Q8_0 | 2,4 Go | 52,1 % | 45,8 % | 11–14 tok/s |
| **Q4_K_M** | **1,6 Go** | **51,6 %** | **45,1 %** | **12–16 tok/s** |
| Q3_K_M | 1,2 Go | 49,8 % | 42,3 % | 14–18 tok/s |
| Q2_K | 0,9 Go | 45,1 % | 36,7 % | 16–20 tok/s |

> **Sweet spot validé** : Q4_K_M offre −1 % de qualité vs FP16 pour −67 % de taille.

---

## 5. Consommation énergétique

### 5.1 Données de référence (littérature)

Mesures sur session de 10 minutes d'inférence continue (Gemma 2 2B, appareils haut de gamme) :

| SoC | Consommation batterie | Mode |
|---|---|---|
| Snapdragon 8 Gen 3 | 5–7 % / 10 min | CPU llama.cpp |
| Snapdragon 8 Gen 3 | 3–4 % / 10 min | NPU AICore (Gemini Nano) |
| Exynos 1380 | 8–12 % / 10 min | CPU llama.cpp |
| Apple A17 Pro | 4–6 % / 10 min | Neural Engine |

> Source : Xu et al. [19], mesures protocole lm-Meter [21].

Les NPUs réduisent la consommation de **3 à 5×** par rapport au CPU pour les tâches LLM.

### 5.2 Données mesurées (protocole interne, Llama 3.2 1B Q4_K_M, ~12 min de charge)

Les mesures de consommation batterie ont été relevées manuellement avant et après chaque session de test de throttling (warm-up + baseline + 9 runs + post-charge, soit ~12 minutes de charge continue).

| SoC | Appareil | Environnement | Batterie avant | Batterie après | Δ batterie | Durée |
|---|---|---|---|---|---|---|
| Dimensity 6400 (6nm) | Infinix Hot 60i 5G | UserLAnd | N/A | N/A | ~−1 % | ~3 min* |
| Dimensity 6400 (6nm) | Infinix Hot 60i 5G | Termux natif | 65 % | 63 % | −2 % | ~12 min |
| Exynos 1280 (5nm) | Galaxy A26 | UserLAnd | N/A | N/A | N/A | protocole naïf |
| Exynos 1280 (5nm) | Galaxy A26 | Termux natif | N/A | N/A | −1 % | ~15 min** |
| Snapdragon 730 (8nm) | Galaxy A71 | UserLAnd | 44 % | 41 % | −3 % | ~12 min |
| Snapdragon 730 (8nm) | Galaxy A71 | Termux natif | 54 % | 52 % | −2 % | ~12 min |
| Snapdragon 778G (6nm) | Galaxy A73 | UserLAnd | N/A | N/A | −2 % | ~5 min* |
| Snapdragon 778G (6nm) | Galaxy A73 | Termux natif | 63 % | 59 % | −4 % | ~12 min |
| Exynos 1330 (5nm) | Galaxy A16 | Termux natif | 24 % | 21 % | −3 % | ~12 min |

\* Durée de session courte : mesure issue du benchmark principal, pas du protocole de throttling complet.
\** Galaxy A26 Termux natif : session de 15 min due au plus grand nombre de runs (artefact governor → runs plus longs).

**Observations :**
- Tous les appareils se situent entre **−2 % et −4 % / 12 min** pour Llama 3.2 1B Q4_K_M — nettement inférieur aux données littérature sur Gemma 2 2B (5–12 %), ce qui confirme l'impact majeur de la taille du modèle sur la consommation.
- Le Snapdragon 778G (Galaxy A73) est le plus énergivore du corpus avec −4 % / 12 min sous Termux natif, cohérent avec son prefill plus élevé (79,69 tok/s) et son governor CPU très actif.
- Le Snapdragon 730 (Galaxy A71) et l'Exynos 1330 (Galaxy A16) affichent −3 % / 12 min malgré des architectures différentes — le modèle 1B nivelle les différences énergétiques entre SoCs milieu de gamme.
- L'environnement UserLAnd n'augmente pas significativement la consommation malgré la couche proot : la surconsommation est absorbée par la variance de mesure (~1 %).

---

## 6. Latence perçue et seuils d'acceptabilité

Pour une expérience utilisateur acceptable (chat, suggestions) :

| Vitesse de décodage | Ressenti utilisateur |
|---|---|
| < 5 tok/s | ❌ Inacceptable (lecture impossible en temps réel) |
| 5–10 tok/s | ⚠️ Acceptable pour la lecture, lent pour le chat |
| **10–20 tok/s** | **✅ Fluide pour le chat conversationnel** |
| > 20 tok/s | ✅✅ Excellent, comparable à une API cloud |

> Sur Snapdragon 8 Gen 3, Gemma 2 2B Q4 atteint 12–16 tok/s → **seuil de fluidité atteint**.  
> Sur Galaxy A54 (Exynos 1380), 5–8 tok/s → **limite basse de l'acceptable**.

---

## 7. Limitations matérielles identifiées

### 7.1 Throttling thermique
Sur les appareils haut de gamme de la littérature (Gemma 2 2B), le throttling atteint 10–25 % après 5 minutes de charge continue. Dans notre corpus (Llama 3.2 1B Q4_K_M, appareils milieu de gamme), le bilan est sensiblement différent :

- **Exynos 1330 — Galaxy A16 (Termux natif)** : seul cas de throttling thermique réel dans le corpus. Dégradation de −19,1 % après ~8 runs (~8 min). La charge thermique du nœud 5nm Samsung (5LPE, optimisé efficacité mais pas dissipation) combinée à l'absence de ventilation passive dans un boîtier fin entraîne un throttling progressif. C'est le seul SoC du corpus à atteindre sa limite thermique avec ce modèle.
- **Tous les autres appareils testés** : aucun throttling thermique détecté sur ~12 min de charge continue. Le modèle Llama 3.2 1B Q4_K_M, plus léger que Gemma 2 2B, reste dans l'enveloppe thermique des SoCs milieu de gamme sur cette durée.
- **Cas particuliers (artefacts governor)** : Galaxy A26 et A73 sous Termux natif présentent des valeurs de throttling aberrantes (−100,2 % et −104,8 %) qui reflètent des artéfacts de mesure liés au governor schedutil Android, pas un throttling thermique. Ces cas sont détaillés dans les notes du tableau 2bis.

**Mitigation** : sur Exynos 1330 (Galaxy A16), limiter les sessions à 5–6 minutes pour rester au-dessus du seuil de dégradation. Pour les autres appareils, aucune contrainte thermique identifiée sur les durées d'usage typiques (< 10 min).

### 7.2 Contrainte de bande passante mémoire
Le décodage est fundamentalement limité par la bande passante RAM :
- LPDDR5X (77 GB/s) → 12–16 tok/s pour Gemma 2 2B
- LPDDR4X (34 GB/s) → 5–8 tok/s pour le même modèle

Cette contrainte ne peut pas être contournée par logiciel sans changer le matériel.

### 7.3 Incompatibilité GPU Mali avec llama.cpp
Sur les appareils Samsung Exynos et MediaTek Dimensity, llama.cpp ne peut pas exploiter le GPU Mali.
Seul MLC-LLM (via Vulkan) résout ce problème — au prix d'une recompilation du modèle par appareil.

---

## 8. Comparaison UserLAnd vs Termux natif

L'un des apports originaux de ce travail est la comparaison systématique de deux environnements d'exécution Linux sur Android : UserLAnd (proot, émulation sans root) et Termux natif (accès direct au noyau Android). Les mêmes benchmarks ont été exécutés dans les deux environnements sur trois des quatre appareils testés (Galaxy A16 uniquement sous Termux à ce stade).

### 8.1 Impact sur le decode (memory-bound)

| Appareil | Decode UserLAnd | Decode Termux | Δ | Interprétation |
|---|---|---|---|---|
| Infinix Hot 60i 5G | 11,86 ± 0,35 tok/s | 12,67 ± 0,75 tok/s | +6,8 % Termux | Écart faible, dans la variance |
| Galaxy A26 | **6,86 ± 0,07 tok/s** | 10,83 ± 2,54 tok/s | **+57,9 % Termux** | Anomalie unique — voir §8.3 |
| Galaxy A71 | 11,66 ± 0,03 tok/s | 11,40 ± 0,29 tok/s | −2,3 % UserLAnd | Quasi-identique |
| Galaxy A73 | 13,19 ± 0,13 tok/s | 13,36 ± 0,80 tok/s | +1,3 % Termux | Quasi-identique |

Pour le decode (opération memory-bound), UserLAnd et Termux natif donnent des résultats **quasi-identiques sur trois des quatre appareils** (±5–7 %). La couche proot de UserLAnd n'induit pas de surcoût mesurable sur la bande passante mémoire effective. L'exception du Galaxy A26 est traitée en §8.3.

### 8.2 Impact sur le prefill (compute-bound)

| Appareil | Prefill UserLAnd | Prefill Termux | Δ | Interprétation |
|---|---|---|---|---|
| Infinix Hot 60i 5G | 54,78 ± 3,15 tok/s | 54,75 ± 7,20 tok/s | −0,1 % | Identique |
| Galaxy A26 | 65,21 ± 6,50 tok/s | 92,13 ± 30,42 tok/s | +41,3 % Termux | Artefact schedutil Termux |
| Galaxy A71 | 36,05 ± 0,07 tok/s | 46,66 ± 0,24 tok/s | +29,4 % Termux | Boost governor CPU Termux |
| Galaxy A73 | 58,07 ± 14,09 tok/s | 79,69 ± 1,07 tok/s | +37,2 % Termux | Boost governor CPU Termux |

Pour le prefill (opération compute-bound), Termux natif est **systématiquement plus rapide de 29–41 %** sur les appareils Exynos et Qualcomm. Cet écart s'explique par l'accès direct de Termux au governor CPU Android (schedutil), qui booste les fréquences CPU au démarrage d'une tâche intensive. Sous UserLAnd/proot, ce mécanisme est atténué : les processus Linux voient le CPU à fréquence plus stable mais moins élevée. Sur le Dimensity 6400 (Infinix), les deux environnements sont identiques en prefill — le governor MediaTek EAS gère différemment les processus étrangers.

### 8.3 Anomalie Galaxy A26 UserLAnd

Le Galaxy A26 (Exynos 1280, Cortex-A55 uniquement) est le **seul appareil du corpus** où UserLAnd dégrade significativement le decode (−37 % par rapport à Termux natif). Plusieurs hypothèses expliquent cette singularité :

1. **Architecture homogène A55** : l'Exynos 1280 n'embarque que des cœurs Cortex-A55 (pas de big.LITTLE avec cœurs A78 dominants comme l'Exynos 1330 ou le Snapdragon 778G). La couche proot, qui ajoute un overhead de syscall traduits, pénalise davantage les cœurs à pipeline court (A55) que les cœurs hautes performances.
2. **Contention mémoire** : le Galaxy A26 dispose de moins de RAM libre (5 427 Mo total) que les autres appareils. UserLAnd ajoute ses propres processus en mémoire, réduisant la bande passante disponible pour llama.cpp.
3. **Protocole naïf** : les résultats A26 UserLAnd proviennent d'une session initiale (5 runs sans warm-up, 07/06/2026) — la valeur pourrait être sous-estimée par rapport au protocole rigoureux utilisé ensuite.

Cette anomalie nécessite une confirmation via le protocole rigoureux complet sur le Galaxy A26 UserLAnd.

### 8.4 Stabilité et reproductibilité

UserLAnd présente une **variance systématiquement plus faible** que Termux natif pour le prefill :
- Infinix : ±3,15 tok/s (UserLAnd) vs ±7,20 tok/s (Termux)
- A71 : **±0,07 tok/s** (UserLAnd) vs ±0,24 tok/s (Termux)
- A73 : ±14,09 tok/s (UserLAnd) vs ±1,07 tok/s (Termux)*

\* L'exception A73 s'explique par une montée en fréquence en cours de session UserLAnd (governor moins agressif mais non nul sous proot).

La couche proot de UserLAnd isole partiellement les processus du governor schedutil Android, produisant des mesures plus stables et reproductibles. Termux natif offre de meilleures performances brutes mais au prix d'une variance plus élevée, rendant les comparaisons inter-appareils moins directes.

### 8.5 Recommandation

Pour un usage applicatif (chatbot embarqué), **Termux natif est recommandé** : performances brutes supérieures en prefill, decode équivalent, et accès aux outils Android natifs. Pour la **recherche et la reproductibilité des benchmarks**, UserLAnd est préférable grâce à sa variance moindre et son isolation du governor CPU — à condition d'être vigilant sur les appareils Cortex-A55 (anomalie A26).

---

## 9. Discussion et interprétation des résultats

### 9.1 Lien entre architecture SoC et performances

Les résultats révèlent une corrélation claire entre la finesse de gravure du SoC et les performances en prefill :

| SoC | Nœud | Prefill moyen (Termux) | Cœurs CPU dominants |
|---|---|---|---|
| Exynos 1280 | 5nm | ~92 tok/s* | Cortex-A55 uniquement |
| Snapdragon 778G | 6nm | ~80 tok/s | A78 (×4) + A55 (×4) |
| Exynos 1330 | 5nm | ~58 tok/s | A78 (×2) + A55 (×4) |
| Dimensity 6400 | 6nm | ~55 tok/s | A55 (×4) + A55 eff. (×4) |
| Snapdragon 730 | 8nm | ~47 tok/s | Kryo 470 Gold (×2) + Silver (×6) |

\* Valeur A26 très variable (±30 tok/s) — voir artefact schedutil.

Le prefill (compute-bound) bénéficie directement de la finesse de gravure et de la fréquence des cœurs actifs. Le Snapdragon 778G (6nm, cœurs A78 hautes performances) offre le meilleur prefill stable. L'Exynos 1280 présente des pics élevés mais avec forte variance, caractéristique d'un governor moins prévisible.

Le decode (memory-bound) est **moins corrélé à l'architecture CPU** et davantage à la bande passante mémoire. Tous les appareils testés convergent vers **11–13 tok/s** malgré des architectures très différentes, car ils partagent tous de la LPDDR4X avec des bandes passantes similaires (~25–34 GB/s). L'exception Galaxy A16 (14,00 tok/s) et Galaxy A73 (13,19–13,36 tok/s) suggère une organisation mémoire légèrement plus efficace sur ces appareils.

### 9.2 Viabilité du LLM embarqué sur smartphone milieu de gamme

Les résultats confirment la viabilité technique du LLM on-device sur des appareils milieu de gamme (200–400 €) en 2025–2026, sous deux conditions :

1. **Choix du modèle** : un modèle ≤ 2B paramètres en quantification Q4 reste dans l'enveloppe mémoire (< 1 Go) et de performance (11–14 tok/s decode) de ces appareils. Un modèle 7B ou plus dépasse la RAM disponible ou produit un decode inacceptable (< 5 tok/s).
2. **Choix de l'environnement** : Termux natif reste la solution la plus accessible et performante pour un déploiement Android. UserLAnd est utile en contexte de développement/benchmark pour sa reproductibilité.

La latence de decode atteinte (11–14 tok/s) se situe dans la zone "fluide pour le chat" identifiée en section 6, validant l'hypothèse de départ : un LLM embarqué peut offrir une expérience conversationnelle acceptable sur smartphone milieu de gamme sans connexion réseau.

### 9.3 Limites de l'étude et biais de mesure

Plusieurs biais doivent être pris en compte dans l'interprétation des résultats :

**Biais du governor CPU (schedutil)** : sous Termux natif, le governor Android adapte dynamiquement la fréquence CPU selon la charge. Les mesures de prefill sont donc sensibles au moment de la mesure dans la session (cold start vs charge stabilisée). Le protocole rigoureux (warm-up + 9 runs) atténue ce biais mais ne l'élimine pas complètement — les valeurs Termux de prefill restent moins reproductibles que sous UserLAnd.

**Biais thermique limité** : seul le Galaxy A16 présente un throttling thermique réel dans le corpus. Cette absence quasi-générale de throttling est probablement liée à la légèreté du modèle testé (1B vs 2B+ dans la littérature). Des modèles plus lourds révéleraient vraisemblablement du throttling sur les autres appareils.

**Hétérogénéité des modèles** : les sections 2 (littérature, Gemma 2 2B) et 2bis (mesures propres, Llama 3.2 1B) utilisent des modèles différents. La comparaison directe entre les deux tableaux n'est pas valide ; les sections 3–6 (llama.cpp vs MLC-LLM, quantification, énergie, latence) sont issues de la littérature et servent de cadre interprétatif pour nos mesures propres.

**Taille du corpus** : 4 appareils (5 SoCs) constituent un corpus limité. Les conclusions sur les tendances architecturales (A55 vs A78, 5nm vs 8nm) doivent être considérées comme des indicateurs, pas des lois générales.

**Obstacle Android 15/16 — accès système depuis Termux** : sur le Galaxy S26 (Android 15+), les commandes Termux permettant d'inspecter les packages système (`pm list packages`, `dumpsys`, `find /vendor/lib64`, `ls /sdcard/Android/data/`) sont bloquées par les restrictions de permissions du noyau Android. Conséquence directe : il est impossible de vérifier la présence de l'AICore (moteur Gemini Nano) ou d'accéder aux bibliothèques d'inférence Google directement depuis l'environnement CLI. Cette limitation s'applique également à UserLAnd/proot. **Contournement** : l'accès à Gemini Nano sur Android 15+ requiert impérativement soit une application Android native (ML Kit GenAI via Android Studio), soit une app tierce dédiée (AI Edge Gallery, Google Play Store). Ce point illustre une limite structurelle de l'approche Termux pour les solutions propriétaires : elle couvre bien les frameworks open source (llama.cpp, MLC-LLM) mais ne peut pas interroger les APIs système restreintes d'Android.

---

## 10. Conclusion

Ce chapitre confirme expérimentalement que l'inférence LLM on-device est **techniquement viable sur smartphone Android milieu de gamme** en 2025–2026, sous conditions de choix adapté du modèle et de l'environnement d'exécution.

Les principaux enseignements sont :

**Sur les performances** : tous les appareils testés (Snapdragon 730/778G, Exynos 1280/1330, Dimensity 6400) atteignent 11–14 tok/s en decode avec Llama 3.2 1B Q4_K_M, soit dans la zone de fluidité conversationnelle. Le prefill varie davantage (36–80 tok/s) selon l'architecture CPU, le Snapdragon 778G se distinguant par les meilleures performances stables.

**Sur le throttling** : contrairement aux appareils haut de gamme de la littérature (−8 à −25 % sur 5 min avec Gemma 2 2B), seul l'Exynos 1330 (Galaxy A16) présente un throttling thermique réel dans notre corpus (−19,1 % après ~8 min). Les autres appareils maintiennent leurs performances sur 12 minutes de charge continue avec le modèle 1B — résultat important pour l'expérience utilisateur réelle.

**Sur l'environnement** : UserLAnd (proot) et Termux natif donnent des résultats de decode quasi-identiques (±5 %) sur la majorité des appareils. Termux natif est supérieur en prefill (+30–40 %) grâce à l'accès direct au governor CPU, au prix d'une variance plus élevée. UserLAnd offre de meilleures garanties de reproductibilité pour les benchmarks.

**Sur la consommation** : le modèle 1B Q4 consomme 2–4 % de batterie par 12 minutes de charge, soit environ 10–20 % par heure d'usage continu — un niveau acceptable pour un usage applicatif réel (sessions conversationnelles de 1–5 minutes).

Ces résultats positionnent le LLM embarqué comme une alternative crédible aux APIs cloud pour des usages conversationnels légers sur smartphone récent milieu de gamme, sans dépendance réseau et avec garantie de confidentialité des données.
