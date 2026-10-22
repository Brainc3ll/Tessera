# Publier une version de Tessera (guide)

Ce dossier `docs/` n'est pas inclus dans l'addon (voir `.pkgmeta`) : il sert au projet et à la publication.

## Ce qui est automatique

Un seul bouton publie partout : le workflow **Package and release** (onglet Actions du dépôt GitHub → « Run workflow », ou `gh workflow run release.yml` ; si GraphQL est bloqué : `gh api -X POST repos/Brainc3ll/Tessera/actions/workflows/release.yml/dispatches -f ref=main`). Pousser un tag `v…` lance aussi le workflow. Dans l'ordre, il :

1. **vérifie la documentation** (`tools/check_docs.lua`, voir plus bas) : si elle n'est pas à jour, rien n'est publié ;
2. lit la version dans `Tessera.toc` et crée le tag `v<version>` ;
3. envoie l'anglais et le français à l'outil de traduction de CurseForge (`docs/localization/`) ;
4. fabrique le zip `Tessera-v<version>-forever.zip`, avec les traductions de la communauté ;
5. crée la release GitHub (titre `v<version>`) et envoie le zip sur **CurseForge** et sur **Wago**, avec la partie de cette version de `CHANGELOG.md` comme notes de version.

Le type de version vient du nom : « alpha » → Alpha, « beta » → Beta (Wago : alpha / beta), tout le reste → Release (Wago : stable).

Secrets nécessaires (Settings → Secrets and variables → Actions) : `CF_API_KEY` (CurseForge) et `WAGO_API_TOKEN` (Wago). Identifiants des projets dans `Tessera.toc` : `X-Curse-Project-ID` et `X-Wago-ID`.

## Avant de lancer la publication (fait par Claude, vérifié par la machine)

1. Nouvelle entrée en haut de `Changelog.lua` (anglais et français) **avec la date**, puis `lua5.1 tools/changelog_md.lua > CHANGELOG.md`. Relire toute l'entrée : elle ne doit pas se contredire (un changement fait plus tard dans la même version réécrit la ligne concernée, au lieu d'annoncer la « correction » de quelque chose que les joueurs n'ont jamais eu). Trier les changements par catégorie (`sections` : intro, nouveautés, améliorations, corrections). Le changelog reste dans `Changelog.lua` (anglais et français), jamais dans les textes envoyés à l'outil de traduction de CurseForge.
2. La même version dans `Tessera.toc` (`## Version:`).
3. Textes : `python3 tools/gen/build.py` (sur `main` : avec `TESSERA_EXCLUDE="ROWS_,MENU_ROW_ALIGN,ROW_ALIGN_"`), puis `lua5.1 tools/export_locales.lua . enUS docs/localization/enUS.lua` (et pareil pour `frFR`).
4. Documentation à jour (voir la liste ci-dessous).
5. Tests : `luacheck .`, `lua5.1 tools/mock_run.lua . enUS` (et `frFR`, `frFR broker` ; avec un passage en donjon et en combat), `lua5.1 tools/fuzz_blocks.lua .` (les blocs WoW Forever résistent à un jeu qui change), puis `lua5.1 tools/check_docs.lua . release`. L'audit de l'API WoW (`tools/api_audit.py`, l'outil de Ketho utilisé par les modérateurs de Reddit) tourne à chaque push.
6. Pousser sur `main`, lancer le workflow.

## La documentation à tenir à jour à chaque changement

À chaque nouvelle fonction, nouveau bloc, nouvelle option ou commande, **dans le même commit** :

| Fichier | Quoi |
|---|---|
| Aide en jeu (onglet Aide, anglais et français) | le sujet concerné ; un nouvel onglet ou une nouvelle section a son paragraphe |
| Infobulles des options | une infobulle claire pour chaque nouvelle option |
| `Changelog.lua` / `CHANGELOG.md` | une ligne par nouveauté ou correction visible, rangée dans sa catégorie |
| `README.md` | points forts, liste des blocs, commandes, tableau des fichiers, partie développeurs |
| `docs/curseforge-description.md` et `docs/wago-description.md` | la page des joueurs, anglais et français (à recoller à la main sur CurseForge et Wago quand elle change) |
| `docs/summary.md` | titre, résumé, texte « About » de GitHub, si le cœur de l'addon change |
| `docs/A-REPRENDRE.md` | où en est le projet, ce qui reste à faire |
| `docs/IDEES-FUTUR.md` | idées faites (marquées) ou nouvelles |

### Ce que la machine vérifie (`tools/check_docs.lua`)

À chaque push (workflow **Checks**) et avant chaque publication :
- la version est la même dans `Tessera.toc`, `Changelog.lua` et `CHANGELOG.md` ; avant une publication, la dernière entrée a une date ;
- `CHANGELOG.md` correspond exactement à `Changelog.lua` ;
- `docs/localization` correspond aux fichiers de textes de l'addon ;
- chaque commande publique est dans le README, l'aide (anglais et français), la liste des commandes de la discussion et les deux descriptions ; une nouvelle commande doit y être ajoutée (ou déclarée cachée) ;
- chaque bloc est nommé dans le README et dans les parties anglaise et française des deux descriptions ;
- chaque fichier Lua de l'addon a sa ligne dans le tableau des fichiers du README ;
- chaque onglet des options est décrit dans l'aide ;
- aucun texte ne dépasse 600 caractères, et chaque ligne de l'aide a sa traduction française.

### Des textes faciles à traduire

Sur CurseForge, changer un texte oblige les traducteurs à refaire tout ce texte. Les longs textes sont donc découpés : l'aide a une clé par ligne ou par paragraphe. Ajouter une ligne = une **nouvelle** clé ; corriger une ligne = la même clé ; on ne renumérote jamais. Ainsi, un mot changé ou une ligne ajoutée ne demande de retraduire que cette ligne.

Ce qu'elle ne peut pas vérifier (la clarté des textes, le détail de l'aide) reste à relire : par Claude à chaque changement, par Braincell1980 avant la publication.

## À la main, quand ça change

- **Description des pages** : CurseForge et Wago ne lisent pas le dépôt ; recoller `docs/curseforge-description.md` sur CurseForge et `docs/wago-description.md` sur Wago (onglet General ; l'import automatique de la description depuis GitHub est désactivé sur Wago).
- **« About » du dépôt GitHub** : roue dentée sur la page du dépôt, texte et topics dans `docs/summary.md`.
- **Captures d'écran** : `/tessera preview` (valeurs d'exemple) ou le mode démo (`/tessera demo`) ; éviter les pseudos d'autres joueurs, les notifications du bureau et les boutons d'autres addons.

## Traductions (automatique)

- L'anglais et le français viennent toujours du dépôt : une modification faite sur CurseForge dans ces deux langues n'arrive jamais dans l'addon.
- Les autres langues sont traduites par la communauté sur CurseForge et ajoutées au zip à chaque publication.
- Les textes qui n'existent plus restent sur CurseForge (aucun travail de traducteur n'est supprimé).
- Si CurseForge refuse l'envoi des textes, la publication continue sans les traductions de la communauté.

## Faire le ménage des textes sur CurseForge

Quand l'addon n'utilise plus certains textes : page Localization de CurseForge, **Import**, langue **English**, coller tout `docs/localization/enUS.lua`, option des phrases absentes réglée pour les **supprimer** ; puis **Import** en **French** avec `docs/localization/frFR.lua` et l'option « ne rien faire ». Fait ainsi le 16/10/2026 (43 textes retirés d'un coup).
