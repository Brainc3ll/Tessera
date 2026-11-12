# À reprendre (état au 12 novembre 2026)

Ce fichier donne l'état actuel. Le détail daté de la 1.0 à la 1.3.1 est dans `docs/archive/HISTORIQUE-1.0-1.3.md` (à ouvrir seulement en cas de besoin). Plan du dossier : `docs/README.md`.

## Où on en est
- **Version en jeu : 1.3.1**, publiée le 12/11 (tag `v1.3.1`). Le run du 11/11 au soir a échoué à cause d'une panne de GitHub Actions ; relancé le 12/11 à 5 h 30, réussi.
- **Dans la 1.3.1** : styles renommés (Bronze, Bronze ancien, Bronze carré, Émeraude, Elfique), nouveau style Bronze et or (fenêtre de FlareUI 6.0), entrée « Automatique » en tête de la liste des styles, bouton « Blocs vides » dans les bandeaux de placement, merci à Malkkav réécrit et bouton « FlareUI » dans À propos.
- **Versions précédentes** : 1.3.0 le 11/11 (fenêtre d'options, Placer au pixel, onglet Accessibilité, nouveautés) ; 1.2.1 le 10/11 (correctifs) ; 1.2.0 le 7/11 (style de groupe, Compétences, Amis).
- **Branches** : `main` = version en jeu (correctifs seulement, tags `vX.Y.Z`) ; `next` = versions suivantes (1.4, 2.0…), jamais renommée ; synchronisées le 12/11. Chaque correctif sur `main` est reporté dans `next`. Un bug urgent : repartir du dernier tag.
- **Prochain zip de test : test118** (zips construits avec le dépôt privé `Tessera-dev`, voir « Outils »).
- **Façon de travailler** : une conversation par version (handoff dès la publication) ; avant de coder, demander si c'est un correctif (`main`) ou une nouveauté (`next`), conseiller modèle et effort, poser les questions, attendre le « go » ; chaque commit et chaque note indique la version du modèle. Détail : `CLAUDE.md`, `docs/REPRISE-CLAUDE.md`.

## Ouvert
- **Bug des flèches** (placement au pixel) : avec les flèches seules, le bloc GSF a sauté de 10 à 40 px par appui (vidéo du 11/11, test105). Jamais reproduit ; Braincell1980 pense à une mauvaise manipulation.
- **« Tous les blocs » pour un bloc seul ou un groupe** : le bouton garde le même décalage avec l'onglet Apparence que la page « Tous les blocs » (corrigée en 1.3.1). À revoir si Braincell1980 le veut.
- **Style choisi à la main dont l'interface disparaît** : il reste en imitation et ne passe pas en Blizzard Forever. Le changer modifie l'allure sans demander et touche aux profils (`tessera-gate2`).
- **À valider en jeu** : les notes d'origine marquent « à valider en jeu » pour l'entrée « Automatique » (test117), le bouton « Blocs vides » (test115) et la page « Tous les blocs » grisée (test116) ; la validation n'y est pas notée. À voir aussi : largeur des 5 boutons de liens d'À propos.
- **Flèche du bloc Corps** : attendre une capture en jeu pour voir la marge de la texture, avant de proposer.
- **Reportés après la 1.3** (choix de Braincell1980, 11/11) : échelle pixel perfect (lot 5b, voir `IDEES-FUTUR.md`) et sélecteur de langue.

## Pistes suivantes (aucun choix fait)
- **Manette 2.0** : voir `docs/IDEES-FUTUR.md`, « Manette native ».
- **Polices d'accessibilité** (1.4) : voir la feuille de route ci-dessous et `docs/IDEES-FUTUR.md`.
- **Vol et bateaux** : à sonder. Idées vérifiées avec forever-lint le 7/11, à choisir par Braincell1980 : file d'attente, calendrier, chrono de combat, recharges de métier, mal de résurrection.

## Le placement depuis la rc8 (décidé le 21/10)
Le joueur décide au pixel près ; Tessera ne recentre plus rien.
- Un bloc activé mais masqué garde sa place (`ns:HasPlace`, largeur `cfg.slotW`).
- Barres toutes prêtes : la barre est placée une fois (`FreezeAnchoredGroups`, après le premier chargement) ; ses rangées sont accrochées sous le bord gauche de la barre (`anchor.fixed`, `anchor.offset = 0`) et prennent sa largeur (`fill`, deux passes pour une rangée sous une rangée) ; bord à bord quand elles sont alignées aux deux bouts (8 px de marge). La première barre ne contient que des blocs toujours affichés.
- Un groupe déplacé s'aligne par ses bords extérieurs seulement. On peut fusionner des blocs sur une rangée figée.
- Devant / derrière s'applique à une barre avec ses rangées (`GetVisualRoot`), blocs masqués compris.
- FlareUI est traité comme les autres interfaces : seul le nom de son style apparaît dans les textes du jeu. Ses cadres (barre d'XP pour l'aimantation, cadres pour les chevauchements) sont dans `ns.KNOWN_UI_FRAMES` (Core.lua), où ajouter d'autres interfaces après un test en jeu.
- « Problèmes connus » (descriptions) : un bloc masqué ne fait plus resserrer ses voisins ; option à l'étude.

## Feuille de route
Décidé le 24/10, revu le 6/11 : 1.1.x = corrections et nettoyage du code ; 1.2 = nouveaux blocs ; 1.3 = fin de la refonte des options. Le détail (bon / bof / non) est dans IDEES-FUTUR, « Bilan du 24 octobre ».
1. à 5. **Faits** : 1.0.0 (4/11), 1.0.1 à 1.0.4 (5/11), 1.1.x (6 et 7/11), 1.2 (7/11), 1.3 (11/11). Détail dans `docs/archive/HISTORIQUE-1.0-1.3.md`.
   **Règle (24/10) : dès la 1.3, chaque chantier prépare l'accessibilité (1.4) et la manette (2.0), pour ne rien refaire ensuite.** Pour la 1.3, ça veut dire :
   - la nouvelle fenêtre d'options se met en page toute seule (pas de colonnes de largeur fixe) : un texte plus gros pousse les réglages au lieu de déborder ;
   - chaque pièce (case, curseur, liste, couleur, bouton « ? ») passe par l'usine à widgets, avec dès le départ un ordre de navigation, un état « sélectionné » bien visible (pas seulement une couleur) et une action « valider » / « retour » : la manette n'aura qu'à s'y brancher ;
   - chaque style HD a une variante lisible en contraste élevé, et le texte reste lisible quand sa taille augmente ;
   - toute nouvelle animation respecte un réglage « moins d'animations » (même s'il n'est montré qu'en 1.4) ;
   - l'étiquette « Nouveau » est un mot ou une forme, pas seulement une couleur ;
   - chaque maquette est vérifiée avec trois questions : « avec un texte deux fois plus gros ? », « sans souris, à la croix ? », « en contraste élevé ? ».
6. **1.4 « Accessibilité »** (à reprendre depuis `next` ; ne pas refaire ce que les Réglages de Blizzard font déjà : les suivre et les indiquer, voir IDEES-FUTUR) : polices pour l'accessibilité (OpenDyslexic, Atkinson Hyperlegible, Luciole, Lexend, Andika, Inclusive Sans, partagées avec les autres addons ; voir IDEES-FUTUR), taille du texte, contraste élevé partout, moins d'animations, formes en plus des couleurs, lecture vocale et alertes, assistant du premier lancement.
7. **2.0 « Manette »** (même branche) : Tessera prend la manette seulement quand ses fenêtres sont ouvertes, navigation à la croix, menu en cercle, vibration et barre lumineuse ; bloc « Batterie de la manette » à sonder (`C_GamePad.GetPowerLevel`). Bâtir sur la manette native de Forever (navigation et menus en cercle de Blizzard), voir IDEES-FUTUR, « Manette native ».
8. **Après la 2.0** : disposition « Portable » (Steam Deck, ROG Ally ; texte et blocs plus gros).
Maquettes des options (deux volets, mosaïque, accessibilité, manette) : artefact « Tessera – idées d'interface des options » (20/10).
Maquette selon la règle de la 1.3 (24/10) : artefact « Tessera – options accessibles (maquette 1.3) » : fenêtre normale, texte ×2, contraste élevé, menu en cercle à la manette.

## Version Forever + Retail (pas une priorité, décidé le 21/10)
- Retail 12.1.5 (interface 120105) et le PTR 12.1.7 ont la même API (Midnight) que Forever.
- Les modules propres à Forever ne s'enregistrent que si leurs fonctions existent ; les fonctions propres à Forever passent par `_G["Nom"]`.
- Zips de test Retail : TOC `## Interface: 16001, 120105, 120107`.
- Repartir de `main` (l'ancienne branche `multi-versions` est supprimée).

## Textes sur CurseForge
- Depuis la 1.1.0, plus rien n'est envoyé à l'outil de traduction de CurseForge : toutes les langues sont dans `Locales/` (voir `docs/TRANSLATING.md`, `docs/RELEASE.md`).
- Descriptions : à recoller à la main sur CurseForge et Wago quand elles changent.

## Documentation de l'API de WoW Forever (trouvée le 18/10)
- Documentation générée par Blizzard, recopiée par Ketho : dépôt `Ketho/wow-ui-source-forever`, dossier `Interface/AddOns/Blizzard_APIDocumentationGenerated` (`C_SkillInfo`, `LegacyConsts`, `C_GameRules`...), avec le code de l'interface de Blizzard.
- warcraft.wiki.gg : « Patch 1.60.1/API changes » et la catégorie « Exclusive API/forever ». `GetInspectHonorData` donne l'honneur et le seuil du niveau suivant (rangs JcJ en 1.1).
- À faire après la 1.0.0 : relire les blocs WoW Forever (Compréhension, Camping, Honneur) avec cette documentation.

## Visibilité
- CurseForge et Wago (projet ANz7wj64). Pistes : Reddit (r/WoWUI avec le paragraphe « AI Disclaimer », subreddit Forever), Discords Forever (publicité autorisée par Malkkav), WoWInterface, pic de promotion vers le 4/11. Annuaires Forever (28/10) : Tessera est déjà listé sur **reveredwow.tools** (classements par likes, prix « Community Choice » : nominations ouvertes) et **vranx.com**. À chaque version : vérifier que leurs fiches pointent vers la dernière version et ont la bonne description.
- Transparence sur l'IA : `ACR.md` à la racine (AI Code Rating E4d, spec 0.1, décidé le 25/10) et un badge en haut du README. À remettre à jour (`updated:`) si la façon de travailler change (par exemple si un programmeur relit le code : la dernière lettre monte). Aussi `AI-DECLARATION.md` (spec 0.1.2, niveau global auto à cause de la relecture), sans badge. Décision : on s'arrête à ces deux formats ; Braincell1980 surveille si une norme se démarque ou est adoptée.
- Images (`docs/media`, dans le README) : bannière animée, trois GIF des styles, image anglais / français (sa moitié française vient d'une version plus ancienne : une capture récente du mode démo en français permettrait de la refaire). À envoyer dans les galeries de CurseForge et Wago.

## Outils de la session (hors dépôt)
- `TesseraDev.lua` (commandes de test : `/tes test`, rapport de debug, galerie `/tes debug hd`...) et `make_test_zip.sh` : dépôt privé `Brainc3ll/Tessera-dev` (cloné dans `/home/claude/tessera-dev/`), ajoutés seulement aux zips de test (prochain numéro : voir « Où on en est »).
- Générateur des textes : dans le dépôt, `tools/gen` (anglais et français) ; `TESSERA_EXCLUDE="ROWS_,MENU_ROW_ALIGN,ROW_ALIGN_" python3 tools/gen/build.py` pour `main` (les textes de la branche des rangées restent dehors). Le fichier français utilise des espaces normales.
- Simulateur avec vraies positions : `MOCK_GEOMETRY = true` dans un script qui charge `tools/mock_run.lua` (voir le test des dispositions toutes prêtes).

Reprise rapide pour Claude : `docs/REPRISE-CLAUDE.md`. Les idées pour plus tard sont dans `docs/IDEES-FUTUR.md`. Les plans et listes de tests terminés sont dans `docs/archive/`.
