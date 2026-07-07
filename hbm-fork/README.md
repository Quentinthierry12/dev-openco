# hbm-fork — Intégration OpenComputers dans HBM's Nuclear Tech (1.12.2)

Volet **Java/Forge** du projet : exposer le **radar HBM** (puis silo/réacteur) comme **composant
OpenComputers**, afin d'obtenir une vraie API (`getContacts()`, `getThreatLevel()`) au lieu du seul
signal redstone. Le volet Lua fonctionne sans ce jar (repli redstone), et bascule automatiquement
sur le composant `hbm_radar` dès qu'il est présent (voir `server/adapters/radar_source.lua`).

> ⚠️ Ce dossier contient un **squelette documenté** (pas buildé ici : pas de toolchain Forge dans
> l'environnement de dev). Il montre exactement le code à intégrer dans le fork.

## Base

Forker **[Warfactory-Official/Hbm-s-Nuclear-Tech-CE](https://github.com/Warfactory-Official/Hbm-s-Nuclear-Tech-CE)**
(le port 1.12.2 maintenu ; le dépôt principal HbmMods est en 1.7.10).

## Licence — IMPORTANT

HBM NTM est sous **LGPL v3**. Usage privé (ton serveur) = aucune contrainte. Si tu **redistribues**
le jar modifié, tu dois **publier tes sources** sous licence compatible (LGPL/GPL) et conserver les
mentions de copyright.

## Approche : `SimpleComponent` (soft-dependency)

La voie la plus simple avec l'API OC est `li.cil.oc.api.network.SimpleComponent` : le TileEntity
expose automatiquement ses méthodes `@Callback` comme un composant nommé (`getComponentName()`).
On garde OC en **dépendance optionnelle** via `@Optional.Interface` / `@Optional.Method`, pour que
HBM tourne **sans** OpenComputers installé.

## Étapes d'intégration

1. Ajouter la dépendance OC (artefact **deobf**) au `build.gradle` — voir le fichier fourni.
2. Faire hériter le TileEntity radar de HBM de `SimpleComponent` (ou déléguer). Le fichier
   `src-oc/com/secsite/hbmoc/TileEntityRadarOC.java` montre le patron ; il faut le **greffer sur la
   classe radar réelle de HBM CE** (nom à repérer dans les sources, ex. `TileEntityRadarLarge`).
3. Remplir `getContacts()` depuis la **liste de blips déjà suivie** par le radar HBM (positions,
   distance, vitesse). C'est le seul point qui dépend des internes de HBM.
4. `./gradlew build` → jar custom. Le déposer sur le serveur à la place du HBM d'origine.
5. En jeu : `component.hbm_radar.getContacts()` doit renvoyer les missiles entrants. Le volet Lua
   s'y branche tout seul.

## Fichiers

- `build.gradle` — dépendances (Forge 1.12.2 + OC deobf), soft-dep.
- `src-oc/com/secsite/hbmoc/TileEntityRadarOC.java` — patron du composant radar OC.
