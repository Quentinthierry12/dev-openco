# hbm-oc-addon — Addon OpenComputers pour HBM CE

Mod Forge 1.12.2 **séparé** qui expose les blocs de **HBM's Nuclear Tech (Community Edition)** comme
**composants OpenComputers**, **sans modifier HBM**. C'est la voie retenue (plutôt que forker HBM) :
survit aux mises à jour de HBM et aucune obligation LGPL de republier HBM (œuvre séparée liée par
l'API OC).

## Principe
- On enregistre **un** driver de bloc OC (`DriverHbm`) via `li.cil.oc.api.Driver.add(...)`.
- En jeu, le joueur place un **bloc Adapter OpenComputers** contre un bloc HBM ; le driver le
  reconnaît (package `com.hbm.*`) et crée l'Environment adapté.
- `HbmMapping` choisit l'Environment selon le **nom de la classe** de la TileEntity (matching par
  sous-chaîne, ajustable), avec un **générique** en repli.
- Les Environments lisent/écrivent la TileEntity par **réflexion** (`util/Reflect`) → pas d'import dur.

## Composants exposés
| Composant OC   | Bloc HBM          | Méthodes |
|----------------|-------------------|----------|
| `hbm_door`     | portes/sas/trappes | `open()`, `close()`, `isOpen()`, `lock(b)` |
| `hbm_silo`     | silo / pas de tir  | `arm()`, `launch(x,z)`, `getState()` |
| `hbm_reactor`  | réacteurs          | `getTemp()`, `getFuel()`, `getPower()`, `scram()` |
| `hbm_radar`    | radar              | `getContacts()`, `getThreatLevel()` |
| `hbm_machine`  | tout le reste      | `getEnergy()`, `getType()`, `setActive(b)`, `isActive()` |

## Build
1. Renseigner l'artefact **deobf de HBM CE** dans `build.gradle` (dépôt + coordonnées).
2. `./gradlew build` → jar dans `build/libs/`. Le déposer dans `mods/` du serveur (à côté d'OC + HBM).

## À confirmer dans les sources de HBM CE
Les **noms de classes/méthodes/champs** exacts (portes : `open/close/isOpen` ; silo : cible/`launch` ;
réacteur : `heat/fuel/power` ; radar : liste de blips). Ajuster `HbmMapping` (sous-chaînes) et les
`Reflect.field(...)`/`Reflect.invoke(...)` dans les classes `env/*`. Rien d'autre à recompiler côté
mapping grâce au matching par nom.

## Côté intranet Lua
- Portes : `shared/doors.lua` → `driver = { kind="hbm_oc", address="<adresse hbm_door>" }`
  (voir l'exemple `bunker_oc`). `server/adapters/door_driver.lua` gère `kind="hbm_oc"`.
- Radar : `server/adapters/radar_source.lua` utilise `component.hbm_radar` s'il est présent.

## Licence
HBM est LGPL v3 ; cet addon ne modifie pas HBM et s'y lie via l'API OC → il peut avoir sa propre
licence, sans obligation de republier les sources de HBM.
