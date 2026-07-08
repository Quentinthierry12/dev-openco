# dev-openco — Intranet de sécurité OpenComputers

Système de sécurité pour serveur Minecraft **1.12.2** multijoueur, bâti sur **OpenComputers**,
**OpenSecurity** et **HBM's Nuclear Tech**. Les terminaux tournent sous **MineOS** ; un serveur
central headless détient comptes, rôles, journaux et l'état de sécurité. Le tout communique sur un
**réseau privé signé (HMAC)**.

> Voir le plan complet et les décisions dans le fichier de plan de la session.

## Fonctionnalités

- **Réseau privé** : chaque message est signé HMAC-SHA256 (SHA-256/HMAC en Lua pur, sans Data Card)
  + nonce anti-rejeu + liste blanche d'adresses. Un ordinateur sans le secret est ignoré.
- **Comptes & rôles** : Admin / Agent / Invité, permissions vérifiées côté serveur. Carte et mot de
  passe **hachés et salés** (jamais en clair). **Double auth** : carte OpenSecurity **ou** mot de passe.
- **Radar / DEFCON** : échelle 5→1, escalade automatique → sirène + LOCKDOWN + diffusion réseau +
  journal. Source = composant OC du fork HBM, sinon **repli redstone**.
- **Portes typées** : `simple`, `bunker`, `shelter`, `airlock` (sas **interverrouillé**), `silo`
  (réservé Admin). Config déclarative ; driver redstone HBM **ou** composant OpenSecurity.
- **Badges** : émission/révocation via `os_cardwriter`.
- **Flotte à distance** : agent par machine + console **tablette** / `Fleet.app` pour
  reboot/shutdown/lock/status (réservé Admin, journalisé).
- **Collaboration** : bulletin d'annonces (diffusion + chatbox Computronics) + messagerie interne.
- **Salle de contrôle** : mur d'écrans (`display/wall.lua`) — écran central bascule en alerte, écrans
  latéraux = dashboard (DEFCON, alarme, lockdown + compte à rebours, ETA/risque d'impact, sas/portes).
- **Protocoles / overrides** : séquences par code, mode **drill** (simulation) ou réel ; override
  « couper tous les postes » (page « INACCESSIBLE ») épargnant les écrans du mur.
- **Installateur une-commande** (`install/`) : `wget … && install.lua` — assistant rôle + secret +
  mot de passe admin + autostart.
- **Supervision réacteur / énergie** (`Reactor.app`) : température/combustible/puissance, seuils
  warn/crit, **alarme + SCRAM auto** au critique.
- **Contre-mesures anti-missile** (`Defense.app`) : modes off/manual/auto ; en auto le serveur
  **engage automatiquement** (CIWS/intercepteur) sur escalade DEFCON ; tir manuel possible.
- **Bonus** : HUD DEFCON OpenGlasses, hologramme des menaces.
- **Addon OC HBM** (`hbm-oc-addon/`) : mod Forge séparé exposant les blocs HBM CE (portes/silo/
  réacteur/radar + générique) comme composants OpenComputers, sans modifier HBM.

Tous les lots du plan sont implémentés. Logique métier **couverte par 148 tests**.

## Structure

```
shared/   libs communes (protocol, netsec/HMAC, roles, doors, util, sha2)
server/   daemon + services (accounts, auth, logs) + routeur
mineos/   client MineOS : lib/ (net, card), login-fork/, apps/
agent/    (lot 4) daemon de gestion à distance par machine
remote/   (lot 4) console tablette
hbm-fork/ (volet Java) intégration OpenComputers dans un fork de HBM CE
tools/    mock/ + test/  (harnais de test hors-jeu)
docs/     installation, architecture, matériel
```

## Tests

Aucun besoin de Minecraft pour la logique. Avec Lua 5.3 :

```sh
lua5.3 tools/test/run.lua          # 100 assertions : HMAC, netsec, rôles, comptes, auth, portes,
                                   # radar/DEFCON, flotte, collaboration, routeur, transport signé
find . -name '*.lua' -exec luac5.3 -p {} \;   # vérification de syntaxe
```

Voir [docs/installation.md](docs/installation.md) pour le déploiement en jeu.
