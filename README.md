# dev-openco — Intranet de sécurité OpenComputers

Système de sécurité pour serveur Minecraft **1.12.2** multijoueur, bâti sur **OpenComputers**,
**OpenSecurity** et **HBM's Nuclear Tech**. Les terminaux tournent sous **MineOS** ; un serveur
central headless détient comptes, rôles, journaux et l'état de sécurité. Le tout communique sur un
**réseau privé signé (HMAC)**.

> Voir le plan complet et les décisions dans le fichier de plan de la session.

## Fonctionnalités (état actuel — Lot 1)

- **Réseau privé** : chaque message est signé HMAC-SHA256 (SHA-256/HMAC en Lua pur, sans Data Card)
  + nonce anti-rejeu + liste blanche d'adresses. Un ordinateur sans le secret est ignoré.
- **Comptes & rôles** : Admin / Agent / Invité, permissions vérifiées côté serveur. Carte et mot de
  passe **hachés et salés** (jamais en clair).
- **Double authentification** : carte OpenSecurity **ou** identifiant + mot de passe.
- **Serveur** : daemon OpenOS, routeur de requêtes, journal d'audit, persistance fichier.
- **Client MineOS** : lib réseau RPC, adaptateur lecteur de carte, squelette du fork de login,
  application `SecurityConsole`.

À venir : radar/DEFCON, portes typées (bunker/sas/shelter/silo), badges, gestion de flotte à
distance (tablette), collaboration. Voir le plan de livraison.

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
lua5.3 tools/test/run.lua          # 51 assertions : HMAC, netsec, rôles, comptes, auth, routeur
find . -name '*.lua' -exec luac5.3 -p {} \;   # vérification de syntaxe
```

Voir [docs/installation.md](docs/installation.md) pour le déploiement en jeu.
