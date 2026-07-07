# Matériel & câblage (en jeu)

## Serveur
- 1 ordinateur OpenComputers (rack conseillé) : CPU, RAM, **disque dur**, **carte réseau**.
- Peut être headless (pas d'écran). Lance `server/main.lua`.

## Terminaux (MineOS)
- Ordinateur **Tier 3** : GPU T3 + écran T3, RAM ×2 conseillée (MineOS est gourmand).
- **Carte réseau** (reliée au réseau privé).
- **Lecteur de carte OpenSecurity** (`os_magreader` ou `os_rfidreader`) adjacent.
- (Admin) **graveur de cartes** (`os_cardwriter`) pour émettre les badges.

## Réseau
- Relier serveur + terminaux + agents par **câble réseau** (Network Cable). Sans fil possible mais
  le HMAC + liste blanche restent indispensables en multijoueur.
- Port utilisé : **2412** (`shared/protocol.lua`).

## Radar HBM
- **Sans le fork Java** : sortie **redstone** du radar HBM → un bloc/câble redstone lu par la
  **Redstone Card** du serveur. Configurer la face dans `server/adapters/radar_source.lua`
  (`CONFIG.side`, `CONFIG.channel` pour un canal *bundled* Project Red).
- **Avec le fork Java** (`hbm-fork/`) : le radar devient le composant `hbm_radar`, aucune redstone
  nécessaire ; `radar_source.lua` le détecte automatiquement.

## Portes
- **Redstone** (HBM/blast/silo) : relier la **Redstone Card** du serveur aux contrôleurs. Utiliser
  un câble **bundled Project Red** pour piloter plusieurs portes/canaux depuis une face
  (`channel`, ou `channelInner`/`channelOuter` pour un sas). Voir `shared/doors.lua`.
- **OpenSecurity** (`os_secdoor`) : renseigner l'`address` du composant dans `shared/doors.lua`.

## Alarme / chat
- **os_alarm** (sirène) à portée réseau du serveur.
- **Computronics chatbox** (`chat_box`) pour diffuser alertes et annonces dans le chat du serveur.

## Agents (gestion à distance) & tablette
- **Agent** : lancer `agent/main.lua` au boot de chaque machine gérée (terminaux inclus). Définir
  éventuellement `SECSITE_NODE_KIND` (terminal/server/…).
- **Tablette** : ordinateur portable OC avec **carte réseau sans fil** ; lancer `remote/tablet.lua`.

## Bonus
- **OpenGlasses 2** : `bonus/glasses.lua` affiche le DEFCON en HUD.
- **Projecteur d'hologramme** (Tier 2) : `bonus/hologram.lua` (positions de missiles si fork HBM).

## Câblage type d'un sas (airlock)
Un canal bundled par battant (ex. `channelInner=2`, `channelOuter=3` sur la face `north`). Le moteur
`server/services/doors.lua` garantit l'interlock (un seul battant ouvert à la fois).
