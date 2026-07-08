# Architecture

## Vue d'ensemble

```
   [Terminal MineOS]  [Terminal MineOS]  [Tablette]   [Agent machine]
          \                 |               |              /
           \________________|_______________|_____________/
                        réseau privé OC (port 2412)
                     messages signés HMAC + liste blanche
                                   |
                            [ Serveur (OpenOS) ]
                     accounts · auth · logs · (radar · doors · nodes)
```

## Protocole

- Transport : `component.modem` (câble filaire ou sans fil), port `2412`.
- Format « fil » : `netsec.encode(table)` = `serialize` → enveloppe `{b=corps, m=HMAC}` → `serialize`.
  Le corps contient `timestamp | nonce | payload` ; le HMAC couvre le tout.
- Corrélation requête/réponse par `id` (généré client, renvoyé par le serveur).
- Requête : `{ v, t, id, ... }` où `t` ∈ `protocol.REQ`. Réponse : `{ ok, data|error, id }`.

## Sécurité

1. **Authenticité/intégrité** : HMAC-SHA256 avec secret partagé. Un message forgé ou altéré est
   rejeté (`bad_mac`).
2. **Anti-rejeu** : horodatage + fenêtre (`netsec.window`, 30 s) + nonce.
3. **Cloisonnement** : liste blanche d'adresses (`netsec.whitelist`).
4. **Autorisation** : chaque requête sensible exige un token de session valide **et** la permission
   correspondante (`roles.can`), vérifié **côté serveur** dans `server/router.lua`.
5. **Secrets au repos** : cartes et mots de passe hachés (SHA-256 salé) — jamais en clair.

## Modules purs vs modules matériels

- **Purs (testés hors-jeu)** : `shared/*`, `server/services/*`, `server/router.lua`.
- **Matériels (dépendent d'OC, vérifiés en jeu)** : `server/main.lua`, `mineos/lib/net.lua`,
  `mineos/lib/card.lua`. Toute incertitude d'API mod y est isolée derrière un adaptateur.

## Rôles

| Rôle   | Résumé des droits |
|--------|-------------------|
| admin  | tout (`*`), y compris `door:silo`, gestion comptes, flotte |
| agent  | dashboard, logs, alarmes, lockdown, `door:*` (sauf silo) |
| invite | dashboard, `door:lobby` |

Définis dans `shared/roles.lua` (dont `RESTRICTED` pour les permissions à rôle explicite).
