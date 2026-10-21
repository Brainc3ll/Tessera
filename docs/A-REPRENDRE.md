# À reprendre (état au 21 octobre 2026)

## Où on en est
- **1.0.0-rc8 publiée le 21/10** (GitHub, CurseForge, Wago ; test28 à test36 validées en jeu ; descriptions recollées). Le détail de chaque version est dans `CHANGELOG.md`.
- La bêta de WoW Forever ferme le **jeudi 23/10 à 19 h (heure belge ; 10 h PDT)**. Ensuite, plus de test en jeu jusqu'à la sortie de Forever.
- Branches : `main` (la rc8) et `refonte-rangees` (bêta du placement par rangées, rangée le 21/10 : l'ancien moteur suffit depuis que le recentrage est retiré ; à rouvrir seulement si les joueurs en ont besoin). `multi-versions` et `rc8-places` sont à supprimer sur GitHub par Braincell1980.

- **1.0.0 en préparation** : entrée « 1.0.0 » ouverte avec son intro, version 1.0.0 dans le .toc. Correction : quitter le mode démo ne déplace plus un bloc de la deuxième rangée (un bloc masqué garde la largeur qu'il avait affiché, `cfg.slotW` ; la démo efface ses valeurs d'exemple ; `/tessera preview` ne change plus `slotW`). Styles FlareUI et FlareUI carré à 50 % de fond (comme FlareUI 2.4.1, vérifié). Cadres d'EllesmereUI 9.6.1 ajoutés à `ns.KNOWN_UI_FRAMES` (noms lus dans son code, pas testés en jeu : Braincell1980 n'a pas le temps).

## Calendrier jusqu'à la 1.0.0
- **22/10 - 3/11 : hors jeu** : images dans les galeries de CurseForge et Wago, post Reddit, messages Discord ; corrections seulement.
- **4/11 : publication de la 1.0.0** (après « on publie ») : nouvelle entrée « 1.0.0 » en haut du changelog avec l'intro « Première version stable » (dans l'historique git de `Changelog.lua`, juste avant le commit « Release 1.0.0-rc8 »), version dans le .toc. Garder de la marge pour une 1.0.1 rapide.

## Le placement depuis la rc8 (décidé le 21/10)
Le joueur décide au pixel près ; Tessera ne recentre plus rien.
- Un bloc activé mais masqué garde sa place (`ns:HasPlace`, largeur `cfg.slotW`).
- Barres toutes prêtes : la barre est placée une fois (`FreezeAnchoredGroups`, après le premier chargement) ; ses rangées sont accrochées sous le bord gauche de la barre (`anchor.fixed`, `anchor.offset = 0`) et prennent sa largeur (`fill`, deux passes pour une rangée sous une rangée) ; bord à bord quand elles sont alignées aux deux bouts (8 px de marge). La première barre ne contient que des blocs toujours affichés.
- Un groupe déplacé s'aligne par ses bords extérieurs seulement. On peut fusionner des blocs sur une rangée figée.
- Devant / derrière s'applique à une barre avec ses rangées (`GetVisualRoot`), blocs masqués compris.
- FlareUI est traité comme les autres interfaces : seul le nom de son style apparaît dans les textes du jeu. Ses cadres (barre d'XP pour l'aimantation, cadres pour les chevauchements) sont dans `ns.KNOWN_UI_FRAMES` (Core.lua), où ajouter d'autres interfaces après un test en jeu.
- « Problèmes connus » (descriptions) : un bloc masqué ne fait plus resserrer ses voisins ; option à l'étude.

## Feuille de route
1. 1.0.0 le 4/11 : la rc8 plus les corrections éventuelles.
2. 1.1 (fin novembre) : déplacer un bloc au pixel (flèches du clavier et à l'écran), l'agrandir ou le rétrécir ; option « laisser les voisins se resserrer » à l'étude ; cadres d'autres interfaces ; nettoyage du code, recherche dans les options, mode DataBroker plus simple, styles pour d'autres interfaces.
3. 1.2 « Comme chez Blizzard » : styles HD (galerie `/tes debug hd` dans les zips de test), fenêtre d'options avec les pièces des Réglages du jeu, bouton « ? », étiquette « Nouveau ».
4. 1.3 « Accessibilité » : taille du texte, contraste élevé, moins d'animations, formes en plus des couleurs, lecture vocale et alertes, assistant du premier lancement.
5. 2.0 « Manette » : Tessera prend la manette seulement quand ses fenêtres sont ouvertes, navigation à la croix, menu en cercle, vibration et barre lumineuse.
Maquettes des options (deux volets, mosaïque, accessibilité, manette) : artefact « Tessera – idées d'interface des options » (20/10).

## Version Forever + Retail (pas une priorité, décidé le 21/10)
- Retail 12.1.5 (interface 120105) et le PTR 12.1.7 ont la même API (Midnight) que Forever.
- Les modules propres à Forever ne s'enregistrent que si leurs fonctions existent ; les fonctions propres à Forever passent par `_G["Nom"]`.
- Zips de test Retail : TOC `## Interface: 16001, 120105, 120107`.
- Repartir de `main`, pas de l'ancienne branche `multi-versions`.

## Textes sur CurseForge
- Le workflow de publication envoie l'anglais et le français à CurseForge (`missing-phrase-handling: DoNothing` : une clé supprimée y reste). Pour un gros ménage : import anglais à la main avec suppression des phrases absentes, puis import français (fait le 16/10).
- Descriptions : à recoller à la main sur CurseForge et Wago quand elles changent.

## Documentation de l'API de WoW Forever (trouvée le 18/10)
- Documentation générée par Blizzard, recopiée par Ketho : dépôt `Ketho/wow-ui-source-forever`, dossier `Interface/AddOns/Blizzard_APIDocumentationGenerated` (`C_SkillInfo`, `LegacyConsts`, `C_GameRules`...), avec le code de l'interface de Blizzard.
- warcraft.wiki.gg : « Patch 1.60.1/API changes » et la catégorie « Exclusive API/forever ». `GetInspectHonorData` donne l'honneur et le seuil du niveau suivant (rangs JcJ en 1.1).
- À faire après la 1.0.0 : relire les blocs WoW Forever (Compréhension, Camping, Honneur) avec cette documentation.

## Visibilité
- CurseForge et Wago (projet ANz7wj64). Pistes : Reddit (r/WoWUI avec le paragraphe « AI Disclaimer », subreddit Forever), Discords Forever (publicité autorisée par Malkkav), WoWInterface, pic de promotion vers le 4/11.
- Images (`docs/media`, dans le README) : bannière animée, trois GIF des styles, image anglais / français (sa moitié française vient d'une version plus ancienne : une capture récente du mode démo en français permettrait de la refaire). À envoyer dans les galeries de CurseForge et Wago.

## Outils de la session (hors dépôt)
- `TesseraDev.lua` (commandes de test : `/tes test`, rapport de debug, galerie `/tes debug hd`...) et `make_test_zip.sh` : `/home/claude/tessera-dev/`, ajoutés seulement aux zips de test (prochain : test37).
- Générateur des textes : `/home/claude/tessera-tools/gen`, `TESSERA_EXCLUDE="ROWS_,MENU_ROW_ALIGN,ROW_ALIGN_" python3 build.py` pour `main` (les textes de la branche des rangées restent dehors). Le fichier français utilise des espaces normales.
- Simulateur avec vraies positions : `MOCK_GEOMETRY = true` dans un script qui charge `tools/mock_run.lua` (voir le test des dispositions toutes prêtes).

Les idées pour plus tard sont dans `docs/IDEES-FUTUR.md`. Les plans et listes de tests terminés sont dans `docs/archive/`.
