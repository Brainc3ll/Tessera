# À reprendre (état au 15 octobre 2026)

## Calendrier jusqu'à la 1.0.0 (validé le 13/10)
La bêta de WoW Forever ferme le **22 octobre** : après, plus aucun test en jeu avant la sortie.
Tout ce qui part le 4 novembre doit avoir été testé en jeu avant le 22.
- **15/10 : rc5** publiée (tests de la test17 réussis, mode DataBroker testé dans les deux sens ; seule l'instance n'a pas été testée).
- **16-19/10 :** tests larges (instance, raid, combat, groupe ; Blizzard seul, FlareUI, Bazooka).
- **19-20/10 : version candidate 1.0.0** ; **20-21/10 :** dernier test de cette version exacte (c'est elle qui part le 4/11, sans retouche).
- **Avant le 22, en jeu :** captures en client anglais (pour les images et le GIF des styles du mode démo).
- **22/10 - 3/11 : hors jeu seulement** : pages CurseForge / Wago (texte « sortie », sans « bêta »), résumé 1.0.0 du changelog, post Reddit, messages Discord.
- **4/11 :** publication de la 1.0.0 et promotion ; garder de la marge pour une 1.0.1 rapide si la sortie change des identifiants.
- Pas avant la 1.0.0 (en 1.1) : nettoyage du code, styles pour tous, zones, bloc voyage, recharges de métiers, or filtré, fondu des barres, version multi-versions.

## Versions
- **1.0.0-rc4** : publiée le 13/10 (GitHub, CurseForge, Wago).
- **1.0.0-rc5** : publiée le 15/10 (GitHub, CurseForge, Wago). Décision de Braincell1980 : s'il n'y a pas de nouvelle version de test avant le 22/10, la rc5 devient la 1.0.0 finale (même code, version renommée 1.0.0 et publiée le 4/11).
- **1.0.0** (en préparation, pas publiée) : correction du 15/10 : la barre du haut suit la barre d'XP de FlareUI même quand FlareUI ou sa barre d'XP est activé après coup. Zip de test 1.0.0-test1. Puis 1.0.0-test2 (15/10, demande de Braincell1980 : refléter la future 1.0.0, pensée pour les nouveaux joueurs) : « Styles mélangés » dans le mode démo, changelog 1.0.0 écrit pour ceux qui découvrent Tessera, plus de « bêta » dans l'aide, le README et les descriptions, 19 styles partout. Liste de tests : `docs/TESTS-1.0.0.md`. Testée le 15/10 : points 0 à 3 OK (nouveau joueur, Styles mélangés, barre d'XP de FlareUI) ; reste l'instance (point 4). Puis 1.0.0-test3 (15/10 au soir) : nouveau bloc Date (formats, locale ou serveur, clic : calendrier), date à côté de l'horloge dans les quatre dispositions façon barre des tâches et dans le mode démo, « Autour des gryphons » en deux rectangles nets. Puis 1.0.0-test4 : changelog trié par catégorie ; correction : une deuxième rangée reposée tout contre sa barre se fondait dans la barre (vu en vidéo par Braincell1980 pendant la visite rapide). La 1.0.0 sera la test4, une fois testée (points 3 bis, 3 ter et instance).
- **1.1.0-alpha1** (autres versions du jeu) : ancienne branche `multi-versions`, abandonnée au profit de l'approche ci-dessous.

## Build de WoW Forever du 16/10
Nouveau build (en-tête de la minicarte et cadres d'unité revus, nouveau tutoriel) : FlareUI cassé sans erreur Lua, correction en cours chez Malkkav. Tessera sans FlareUI, testé le 16/10 : bouton de la minicarte, déplacement, Héritage, Compréhension, « faire de la place » dans le mode Édition OK. Reste à voir : liste des lanceurs, nouveau personnage (tutoriel + bienvenue de Tessera), clic sur le bloc Guilde.

## Textes inutilisés sur CurseForge
Fait le 15/10 : les 12 textes que l'addon n'utilise plus ont été supprimés de la page Localization
de CurseForge (TAB_VERSION n'y était pas : retiré avant le premier envoi des textes).

## En attente de Braincell1980
- (Facultatif) une capture du mode démo en français avec la version actuelle (style Grimoire, « 12/19 ») pour refaire `docs/media/english-french.jpg`, dont la moitié française vient d'une version plus ancienne.
- Test en instance (profil donjon, masquer en instance, clics en combat).

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
- `TesseraDev.lua` (commandes de test et de développement) et `make_test_zip.sh` : `/home/claude/tessera-dev/`, ajoutés seulement aux zips de test.
- Générateur des textes (`help_struct.py`, `help_texts.py`...) : `/home/claude/tessera-tools/gen`, `python3 build.py`.

Les idées pour plus tard sont dans `docs/IDEES-FUTUR.md`. Les plans terminés (mode Édition, onglet Apparence) sont gardés comme archive dans `docs/archive/`.
