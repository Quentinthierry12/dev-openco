# Installation & déploiement

## 1. Prérequis (serveur Minecraft 1.12.2)

Mods : **OpenComputers**, **OpenSecurity**, **HBM's Nuclear Tech** (port CE conseillé),
**Computronics**, **Project Red** (câble redstone *bundled*), **OpenGlasses 2** (optionnel).

Matériel OpenComputers :
- **Serveur** : 1 ordinateur (rack ou tour) avec disque dur, **carte réseau** (câble filaire
  conseillé). Peut être « headless » sous OpenOS.
- **Terminaux** : ordinateurs **Tier 3** (GPU + écran T3, RAM confortable — MineOS est gourmand),
  **carte réseau**, un **lecteur de carte OpenSecurity** (`os_magreader` ou `os_rfidreader`).
- Réseau : reliez toutes les machines par **câble réseau** (ou cartes sans fil sur un canal dédié).

## 2. Déployer le code

Placez l'arborescence du dépôt sous un même dossier sur chaque machine, par défaut
`/home/secsite`. Vous pouvez surcharger via la variable d'environnement `SECSITE_ROOT`.

Chaque machine n'a besoin que de ce qui la concerne, mais copier tout `shared/` est requis partout :

| Machine   | Dossiers à copier                              |
|-----------|------------------------------------------------|
| Serveur   | `shared/`, `server/`                           |
| Terminal  | `shared/`, `mineos/`                            |
| Tablette  | `shared/`, `mineos/lib/`, `remote/` (lot 4)     |
| Agent     | `shared/`, `agent/` (lot 4)                     |

## 3. Réseau privé (secret partagé)

Sur **chaque** machine admise, créez le fichier secret **identique** :

```
mkdir -p /home/secsite/server/data           # (serveur)
echo "un-secret-long-et-aleatoire" > /home/secsite/server/data/secret
```

Pour les terminaux/tablettes, déployez le même secret là où `netsec` le lit (voir `netsec.setSecret`
dans votre script de démarrage, ou adaptez le chemin). Sans secret identique, la machine ne peut ni
émettre ni comprendre un message : c'est ce qui cloisonne l'intranet.

Optionnel : `server/data/whitelist` — une adresse de composant par ligne — restreint encore les
expéditeurs acceptés.

## 4. Lancer le serveur

```
SECSITE_ROOT=/home/secsite lua server/main.lua
```

Au premier lancement, un compte **admin / mot de passe `admin`** est créé — **changez-le**. Le
serveur écoute sur le port modem `2412` (voir `shared/protocol.lua`).

## 5. Terminaux MineOS

1. Installez MineOS (`pastebin run PDE3eVsL`, depuis une disquette OpenOS + carte Internet).
2. Copiez `shared/` et `mineos/` sous `SECSITE_ROOT`.
3. Installez l'app : copiez `mineos/apps/SecurityConsole.app` dans les applications MineOS.
4. Fork du login : lancez `mineos/login-fork/install.lua` puis suivez ses indications (le point
   d'injection exact du login MineOS est à confirmer en jeu — `patch.tryCardLogin()` est
   utilisable immédiatement pour un test manuel du swipe).

## 6. Vérification en jeu

- `SecurityConsole` doit afficher « Serveur : EN LIGNE » (le ping signé aboutit).
- Un swipe de carte inconnue est refusé et journalisé ; une carte enregistrée ouvre une session.
- Un login/mot de passe valide fonctionne aussi.

## API confirmées (via wiki/sources)

- **Lecteur carte** : magreader → event `magData` (cardData/cardUniqueId) ; rfidreader → `scan()`
  puis event `rfidData` (data). Câblé dans `mineos/lib/card.lua`.
- **Card writer** : `write(data, displayName, [locked], [color])` → `mineos/lib/writer.lua`.
- **Alarme** : `os_alarm.activate()/deactivate()/setAlarm()/setRange()` → `server/adapters/alarm.lua`.
- **Porte OpenSecurity** : Door Controller `open(pw)/close(pw)/isOpen()` → `door_driver.lua`
  (kind `os_secdoor`, `password` optionnel dans la config).
- **Chatbox Computronics** : `chat_box.say(msg[, distance])` → `server/adapters/alarm.lua`.
- **MineOS GUI** : signatures `GUI.button/input/text/panel/comboBox/textBox/layout/container/
  filledWindow` vérifiées.

## Restent à confirmer en jeu / dans les sources

- **Fork du login MineOS** — point d'injection **identifié** : `Libraries/System.lua`,
  fonction `system.authorize()`. Le mot de passe y est vérifié par
  `require("SHA-256").hash(input.text) == userSettings.securityPassword`, puis `updateUser(userName)`
  (local) ouvre le bureau. Insérer `patch.cardListener(function(userName) … updateUser(userName) end)`
  après la création de `container`/`updateUser` (snippet exact affiché par
  `mineos/login-fork/install.lua`). Convention : le **nom du profil MineOS = nom du compte** SecSite.
- **Canal/face redstone** du radar HBM et des portes → `radar_source.lua`, `shared/doors.lua`.
- **Classes/champs HBM CE** pour l'addon Java → `hbm-oc-addon/` (mapping + Reflect).
