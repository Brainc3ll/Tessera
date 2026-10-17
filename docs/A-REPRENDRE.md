# À reprendre (état au 17 octobre 2026, après-midi)

## Calendrier jusqu'à la 1.0.0 (validé le 13/10)
La bêta de WoW Forever ferme le **22 octobre** : après, plus aucun test en jeu avant la sortie.
Tout ce qui part le 4 novembre doit avoir été testé en jeu avant le 22.
- **15/10 :** rc5 publiée (GitHub, CurseForge, Wago).
- **15-17/10 :** zips de test 1.0.0-test1 à test16, tous validés en jeu par Braincell1980.
- **17/10 :** rc6 publiée (GitHub, CurseForge, Wago), la dernière version candidate.
- **Avant le 22, en jeu :** le test en instance (seul test restant) ; retours éventuels des joueurs de la rc6.
- **22/10 - 3/11 : hors jeu seulement** : entrée 1.0.0 du changelog, images dans les galeries de CurseForge et Wago, post Reddit, messages Discord.
- **4/11 :** publication de la 1.0.0 (après « on publie ») et promotion ; garder de la marge pour une 1.0.1 rapide si la sortie change des identifiants.
- Après la 1.0.0 : bulle d'aide et boutons qui « respirent » (vers une 1.0.5), puis 1.1 (nettoyage du code, recherche dans les options, mode DataBroker plus simple, styles pour tous, zones, bloc voyage, recharges de métiers, or filtré, fondu des barres, version multi-versions).

## Versions
- **1.0.0-rc4** : publiée le 13/10. **1.0.0-rc5** : publiée le 15/10.
- **1.0.0-rc6** : publiée le 17/10 (dispatch du workflow par l'API REST de GitHub : `gh api -X POST repos/Brainc3ll/Tessera/actions/workflows/release.yml/dispatches -f ref=main`). Depuis la rc5 :
  - nouveau bloc Date ; « Oublier un personnage » dans le bloc Or ; mode démo : « Styles mélangés » ;
  - Tessera ne déplace plus les cadres de Blizzard : blocs devant ou derrière (bouton du bandeau et bouton qui respire sous la fenêtre du mode Édition ; question seulement après avoir utilisé le bouton ; onglet Apparence ; question aussi en appliquant une disposition qui recouvre des cadres). Ne plus mentionner l'ancien système aux joueurs (demande de Braincell1980) ; un joueur encore sur une ancienne copie se voit proposer de revenir à sa disposition ;
  - « Chemin de ronde » remplace les 4 dispositions façon système ; « Autour des gryphons » en deux rectangles nets ;
  - onglet Apparence : raccourcis « Cadre / Texte de tous les blocs » ;
  - style FlareUI aux looks de FlareUI 2.1.1 : lignes bronze entre les blocs collés, barre de progression à la texture « FlareUI Forever » (avec FlareUI installé) ;
  - couleurs des seuils au choix (onglet Général) : automatiques, vives, adoucies, pour daltoniens (l'ancienne case est convertie). Les textes ne citent FlareUI que comme nom de style (demande de Braincell1980) ;
  - noms de WoW Forever « Prénom Nom » : la clé d'un personnage est nom complet + jeu de règles (or, historique, profil) ; les données des anciennes clés sont déplacées ;
  - corrections : barre du haut sous la barre d'XP de FlareUI activée après coup, deuxième rangée reposée contre sa barre, style gardé en appliquant une disposition, plus de « n/d » après un écran de chargement ;
  - `/tessera preview forever` retirée (le mode démo la remplace) ; textes sans « bêta », 19 styles partout, changelog trié par catégorie.
- **1.0.0** (4 novembre) : la rc6 plus les corrections éventuelles. Au moment de la publier : nouvelle entrée « 1.0.0 » en haut du changelog avec l'intro « Première version stable » (dans l'historique git de `Changelog.lua`, avant le commit « Prepare 1.0.0-rc6 »), version dans le .toc.
- **1.1.0-alpha1** (autres versions du jeu) : ancienne branche `multi-versions`, abandonnée au profit de l'approche plus bas.

## 1.0.0-rc6-hotfix (préparée le 17/10, zip test17, pas publiée)
Bugs vus dans les vidéos de Braincell1980 (17/10, rc6), corrigés :
- un bloc resté seul dans la deuxième rangée (Cuisine) ne s'étire plus sur toute la barre : la rangée ne prend la largeur de la barre que si ses blocs doublent au plus leur largeur (`Fill`, `atMostDouble`, Merge.lua) ;
- un groupe de plusieurs rangées collé à la barre (BugSack + Mémoire des addons) ne recouvre plus la deuxième rangée : elle descend sous le bloc le plus bas du groupe (`hangDrop`, `CenterAnchoredGroups`) ;
- 56 Mo pour Tessera : chaque changement de texte (FPS, latence, coordonnées toutes les 0,25 s, heure) relançait toute la mise en page (≈ 50 Ko de déchets à chaque fois). Maintenant seulement si la taille du texte change. À vérifier en jeu avec le bloc Mémoire des addons.

## Textes sur CurseForge
- 16/10 : import anglais par Braincell1980 avec suppression des phrases absentes (43 textes retirés), puis import français. Méthode à garder pour les gros ménages.
- 17/10 : `TIP_COLORBLIND` supprimé à la main ; la rc6 a envoyé les nouveaux textes (couleurs des seuils, `HELP_LOOK_11`) et 5 textes corrigés à la relecture (`HELP_PLACE_12`, `TUTORIAL_5`, `SECTION_EDGES`, `HELP_GENERAL_3`, `HELP_BLOCKS_4` en français).

## En attente de Braincell1980
- Recoller `docs/curseforge-description.md` sur CurseForge et `docs/wago-description.md` sur Wago (ligne Accessibilité changée) ; annoncer la rc6 sur Discord.
- Test en instance (profil donjon, masquer en instance, clics en combat) : le seul test restant de la 1.0.0.
- (Facultatif) une capture du mode démo en français avec la version actuelle pour refaire `docs/media/english-french.jpg`, dont la moitié française vient d'une version plus ancienne.

## Build de WoW Forever du 16/10
Nouveau build (en-tête de la minicarte et cadres d'unité revus, nouveau tutoriel) : FlareUI cassé quelques heures puis corrigé par Malkkav (FlareUI 2.1.1, étudié le 17/10 : rien de cassé pour Tessera). Tessera testé avec et sans FlareUI : tout OK.

## Visibilité
- Tessera est sur CurseForge et Wago (projet ANz7wj64, description = `docs/wago-description.md`).
- Pistes : Reddit (r/WoWUI avec le paragraphe « AI Disclaimer », subreddit Forever), Discords Forever (publicité autorisée par Malkkav), WoWInterface (catégorie la plus proche en précisant « WoW Forever »), pic de promotion vers le 4 novembre.
- Images faites le 15/10 (`docs/media`, affichées dans le README) : bannière animée (Blizzard moderne puis FlareUI), trois GIF des styles du mode démo (moins de 2 Mo chacun), image anglais / français. Pour CurseForge et Wago : à envoyer dans leur galerie d'images.

## Version multi-versions (après la 1.0.0, en 1.1) : approche validée le 14/10
- Repartir de `main` (propre, audit Ketho à 0), pas de l'ancienne branche `multi-versions`.
- Tous les secours pour Classic Era / BC / MoP dans un seul fichier de compatibilité (`Compat.lua`) : fonction moderne si elle existe, sinon l'ancienne, avec un commentaire par version du jeu ; le reste du code n'appelle que ces fonctions.
- Tester chaque client (faux client `TESSERA_FLAVOR` + tests en jeu) avant toute publication.
- Si un jour elle est publiée : retirer le suffixe « -forever » du nom du zip.

## Outils de la session (hors dépôt)
- `TesseraDev.lua` (commandes de test et de développement) et `make_test_zip.sh` : `/home/claude/tessera-dev/`, ajoutés seulement aux zips de test. Chaque nouveau zip de test prend un nouveau numéro (prochain : test17).
- Générateur des textes (`help_struct.py`, `help_texts.py`...) : `/home/claude/tessera-tools/gen`, `python3 build.py`. Le fichier français utilise des espaces normales (pas d'espaces insécables).

Les idées pour plus tard sont dans `docs/IDEES-FUTUR.md`. Les plans terminés (mode Édition, onglet Apparence) sont gardés comme archive dans `docs/archive/`.
