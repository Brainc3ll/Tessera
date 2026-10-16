# À reprendre (état au 16 octobre 2026)

## Calendrier jusqu'à la 1.0.0 (validé le 13/10)
La bêta de WoW Forever ferme le **22 octobre** : après, plus aucun test en jeu avant la sortie.
Tout ce qui part le 4 novembre doit avoir été testé en jeu avant le 22.
- **15/10 :** rc5 publiée (GitHub, CurseForge, Wago).
- **15-16/10 :** zips de test 1.0.0-test1 à test12, tous validés en jeu par Braincell1980.
- **Avant le 22, en jeu :** le test en instance (seul test restant).
- **22/10 - 3/11 : hors jeu seulement** : date dans le changelog, descriptions à recoller sur CurseForge et Wago, images dans leurs galeries, post Reddit, messages Discord.
- **4/11 :** publication de la 1.0.0 (après « on publie ») et promotion ; garder de la marge pour une 1.0.1 rapide si la sortie change des identifiants.
- Après la 1.0.0 : bulle d'aide et boutons qui « respirent » (vers une 1.0.5), puis 1.1 (nettoyage du code, mode DataBroker plus simple, styles pour tous, zones, bloc voyage, recharges de métiers, or filtré, fondu des barres, version multi-versions).

## Versions
- **1.0.0-rc4** : publiée le 13/10. **1.0.0-rc5** : publiée le 15/10.
- **1.0.0** (pas publiée) : ce sera exactement la **test12** (testée), une fois l'instance testée. Depuis la rc5 :
  - correction : la barre du haut suit la barre d'XP de FlareUI même activée après coup ;
  - mode démo : « Styles mélangés » ;
  - nouveau bloc Date ; « Oublier un personnage » dans le bloc Or ;
  - « Autour des gryphons » en deux rectangles nets ; « Chemin de ronde » remplace les 4 dispositions façon système ;
  - Tessera ne déplace plus les cadres de Blizzard : blocs devant ou derrière (bouton du bandeau et bouton qui respire sous la fenêtre du mode Édition ; question seulement après avoir utilisé le bouton ; onglet Apparence ; question aussi en appliquant une disposition qui recouvre des cadres). Ne plus mentionner l'ancien système aux joueurs (demande de Braincell1980) ; un joueur encore sur une ancienne copie se voit proposer de revenir à sa disposition ;
  - `/tessera preview forever` retirée (le mode démo la remplace) ;
  - corrections : deuxième rangée reposée contre sa barre, style gardé en appliquant une disposition, plus de « n/d » après un écran de chargement ;
  - textes : plus de « bêta », 19 styles partout, changelog trié par catégorie et écrit pour les nouveaux joueurs.
- **1.1.0-alpha1** (autres versions du jeu) : ancienne branche `multi-versions`, abandonnée au profit de l'approche plus bas.

## Build de WoW Forever du 16/10
Nouveau build (en-tête de la minicarte et cadres d'unité revus, nouveau tutoriel) : FlareUI cassé quelques heures puis corrigé par Malkkav. Tessera testé avec et sans FlareUI : tout OK.

## Textes sur CurseForge
- 15/10 : 12 textes inutilisés supprimés à la main.
- 16/10 : import anglais par Braincell1980 avec suppression des phrases absentes (les 43 textes retirés depuis la rc5), puis import français. Méthode à garder pour les prochains ménages.

## En attente de Braincell1980
- (Facultatif) une capture du mode démo en français avec la version actuelle (style Grimoire, « 12/19 ») pour refaire `docs/media/english-french.jpg`, dont la moitié française vient d'une version plus ancienne.
- Test en instance (profil donjon, masquer en instance, clics en combat) : le seul test restant de la 1.0.0.

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
