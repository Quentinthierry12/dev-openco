# Installation en une commande

Sur chaque machine OpenComputers (carte Internet requise), depuis OpenOS :

```
wget -f https://raw.githubusercontent.com/Quentinthierry12/dev-openco/claude/opencomputer-security-site-jw7rga/install/install.lua /tmp/secsite.lua && /tmp/secsite.lua
```

L'assistant demande :
1. l'**URL de base** (par défaut le dépôt/branche ci-dessus) et le **dossier** (`/home/secsite`) ;
2. le **rôle** de la machine : `server` / `terminal` / `agent` / `display` / `tablet` ;
3. le **secret réseau** (généré ou saisi) — **le même sur toutes les machines** de l'intranet ;
4. (serveur) le **mot de passe admin initial** (remplace le `admin` par défaut).

Il télécharge alors uniquement les fichiers du rôle (voir `install/manifest.lua`), écrit la config
(`secsite.cfg`), et affiche la ligne d'autostart à ajouter à `/home/.shrc`.

## Variante pastebin
Téléverser `install/install.lua` sur pastebin puis :
```
pastebin run <CODE>
```

## Après installation
- **server** : `SECSITE_ROOT=/home/secsite /home/secsite/server/main.lua`
- **terminal** : copier les `*.app` dans les Applications MineOS, puis
  `/home/secsite/mineos/login-fork/install.lua`
- **agent** : `SECSITE_ROOT=/home/secsite /home/secsite/agent/main.lua`
- **display** : `/home/secsite/display/wall.lua center` (ou `left`/`right`/`info`)
- **tablet** : `/home/secsite/remote/tablet.lua`

## Dépannage
- « carte Internet requise » : ajoutez une Internet Card à la machine.
- Un échec de téléchargement d'un fichier est signalé ligne par ligne : relancez l'assistant.
- Réseau privé : si les machines ne se voient pas, vérifiez que le **secret est identique** partout.
