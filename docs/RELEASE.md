# Publier Tessera 1.0.0-rc1 (guide pour Braincell1980)

Ce dossier `docs/` n'est pas inclus dans l'addon (voir `.pkgmeta`) : il sert seulement à la publication.

Deux fichiers zip :
- **Tessera-1.0.0-rc1.zip** : l'addon tel que les joueurs l'installent (à envoyer sur CurseForge et à joindre à la release GitHub).
- **Tessera-1.0.0-rc1-source.zip** : tout le projet (outils, modèles GitHub, ce dossier docs) : c'est ce qui va dans le dépôt GitHub.

## 0. Avant de publier

Installe **Tessera-1.0.0-rc1.zip** dans `Interface/AddOns/` et vérifie en jeu :
- la barre de base sous FlareUI, le déverrouillage, la fusion, le verrouillage ;
- un export puis un import de profil (onglet Profils) ;
- les blocs métiers et compétences d'armes ;
- avec Bazooka : la fenêtre « mode DataBroker » au premier lancement, ses deux boutons, l'onglet Aide du mode broker ;
- sans Bazooka : rien de changé.

## 1. GitHub

### Créer le dépôt
1. Va sur github.com/new (compte Brainc3ll).
2. Nom : `Tessera`. Public. Ne coche **rien** (pas de README, pas de licence : ils sont déjà dans le projet).
3. Dans « About » (roue dentée à droite de la page du dépôt) : colle la description de `docs/summary.md` et les topics.

### Envoyer les fichiers
1. Dézippe **Tessera-1.0.0-rc1-source.zip**.
2. Sur la page du dépôt vide : « uploading an existing file ».
3. Glisse **le contenu** du dossier `Tessera` (pas le dossier lui-même). Attention, `.github`, `.pkgmeta` et `.luacheckrc` sont des fichiers cachés : dans Fichiers (GNOME), Ctrl + H pour les voir.
4. Message : `Tessera 1.0.0-rc1`, puis « Commit changes ».

### Créer la release
1. Onglet « Releases » → « Draft a new release ».
2. « Choose a tag » : tape `v1.0.0-rc1` → « Create new tag ».
3. Titre : `Tessera 1.0.0-rc1`.
4. Description : colle la partie 1.0.0-rc1 de `CHANGELOG.md`.
5. Joins **Tessera-1.0.0-rc1.zip** (zone « Attach binaries »).
6. Laisse **« Set as a pre-release » décoché** et « Set as the latest release » coché, pour rester cohérent avec CurseForge.
7. « Publish release ».

## 2. CurseForge

### Créer le projet
1. Sur le site des auteurs CurseForge : créer un projet, jeu World of Warcraft, type Addon.
2. Nom : `Tessera`.
3. Résumé : la ligne « CurseForge summary » de `docs/summary.md`.
4. Description : le contenu de `docs/curseforge-description.md` (anglais puis français). Si l'éditeur propose le format Markdown, choisis-le, les titres et tableaux s'afficheront bien.
5. Catégories : choisis celles qui correspondent dans leur liste (par exemple ce qui touche aux données, au DataBroker, à la minicarte ou à l'interface).
6. Licence : MIT. Liens : l'adresse du dépôt GitHub (source et signalement de bugs).
7. Logo : il faut une image plus grande que l'icône de l'addon (64 × 64 px) ; je peux t'en préparer une si tu veux.

Un nouveau projet passe en général par une validation de CurseForge avant d'être visible.

### Envoyer le fichier
1. Onglet des fichiers → envoyer un fichier : **Tessera-1.0.0-rc1.zip**.
2. Nom affiché : `Tessera 1.0.0-rc1`.
3. Type de version : **Release** (pas Beta ni Alpha). Ainsi les joueurs qui ne montrent que les versions stables voient l'addon. Le « rc1 » dans le nom ne change rien pour CurseForge.
4. Version du jeu : la même que celle choisie pour FlareUI sur WoW Forever (regarde la page de FlareUI si tu hésites).
5. Changelog : la partie 1.0.0-rc1 de `CHANGELOG.md`.

### Captures d'écran
Avec `/tessera preview` (valeurs d'exemple), quelques idées :
- la barre de base sous FlareUI, avec sa deuxième rangée ;
- le mode placement (blocs bleus, guides d'alignement) ;
- la fenêtre d'options ;
- les blocs de Tessera dans Bazooka ;
- un bloc en style Transparent.
La règle IA de CurseForge ne vise que les images générées par IA : de vraies captures n'ont besoin d'aucune mention. Le disclaimer IA est déjà dans la description.

## 3. Traductions avec l'outil de CurseForge (automatique)

À chaque publication, le workflow envoie lui-même l'anglais (langue de base) et le français à l'outil de traduction de CurseForge, depuis `docs/localization/enUS.lua` et `frFR.lua`. Rien à importer à la main.

- Les traducteurs de la communauté travaillent sur le site CurseForge ; leurs traductions (allemand, espagnol, russe...) sont ajoutées au zip à chaque publication.
- L'anglais et le français de l'addon viennent toujours du dépôt (`Locales/enUS.lua`, `Locales/frFR.lua`) : une modification faite sur CurseForge dans ces deux langues n'arrive jamais dans l'addon.
- Les textes qui n'existent plus dans l'addon restent sur CurseForge (aucun travail de traducteur n'est supprimé).
- Si CurseForge refuse l'envoi, la publication continue quand même, sans les traductions de la communauté.
- Avant chaque publication, `docs/localization` est régénéré : `lua5.1 tools/export_locales.lua . enUS docs/localization/enUS.lua` (et pareil pour `frFR`).

## 4. Publication automatique

Le fichier `.github/workflows/release.yml` utilise le packager BigWigs.

**Méthode simple** : mettre à jour la version dans `Tessera.toc`, `Changelog.lua` et `CHANGELOG.md`, pousser sur `main`, puis lancer le workflow « Package and release » (onglet Actions > Run workflow, ou `gh workflow run release.yml`). Il lit la version dans `Tessera.toc`, crée le tag `v<version>`, envoie les textes à CurseForge, fabrique le zip, crée la release GitHub et envoie le zip sur CurseForge avec `CHANGELOG.md` comme notes de version.

Pousser soi-même un tag (par exemple `v1.0.1`) lance aussi la publication.

Le type est déduit du tag : « alpha » donne une Alpha, « beta » une Beta, tout le reste une Release. Le secret `CF_API_KEY` (clé d'API CurseForge) doit exister dans Settings > Secrets and variables > Actions. Le résultat se suit dans l'onglet Actions du dépôt.

La description de la page CurseForge (`docs/curseforge-description.md`) et le résumé (`docs/summary.md`) ne sont pas envoyés par le workflow : ils se collent à la main sur CurseForge quand ils changent.
