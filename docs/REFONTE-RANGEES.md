# Refonte du placement : les rangées (branche `refonte-rangees`)

Décidé le 20/10/2026 avec Braincell1980 : simplifier le système de fusion tout en gardant la
liberté, avec quelques contraintes, viser « zéro bug », et dire au joueur ce qui est possible
ou pas. Prototype sur cette branche, zips « beta » ; la 1.0.0 continue sur `main` sans être touchée.

## Règle (Braincell1980, 20/10)
Aucune option de la 1.0.0 ne disparaît : un joueur de la 1.0.0 doit retrouver tout ce qu'il avait
(« ce n'est pas l'addon que j'ai téléchargé » ne doit jamais arriver). Changements de comportement
à surveiller dans la beta : Maj + glisser sort un seul bloc (avant : le bloc et ceux accrochés à
lui) ; (la rangée courte à l'écart a été retirée en beta5).

## Pourquoi
Aujourd'hui chaque bloc s'accroche à un seul voisin (chaîne `cfg.dock`), et une deuxième rangée
« pend » sous une autre (`cfg.anchor.below`). Tessera ne connaît pas les rangées. D'où :
- un bloc posé au-dessus prend la largeur du bloc du dessous mais ne s'accroche pas à ses
  voisins du haut (redimensionnement à la main) ;
- poser un bloc entre deux autres défait et refait la chaîne : chevauchements ;
- un bloc masqué quand vide laisse un trou que Tessera doit « sauter » (`GetEffectiveDock`) ;
- les bordures des formes en L / T se recollent morceau par morceau (`ApplySeams`) : traits,
  morceaux de l'ancien style ;
- ancrages bloc à bloc : risque de boucle (« Cannot anchor to a region dependent on it »).

## Le modèle
- **Un groupe = une pile de rangées. Une rangée = une liste de blocs, de gauche à droite.**
  Une barre : 1 rangée. Une colonne : des rangées d'un bloc. Double barre, autour des gryphons :
  2 rangées.
- **Chaque rangée a son alignement** : gauche, centre ou droite (dans la largeur du groupe).
  Une rangée plus courte que les autres donne les formes en L, en T, les colonnes à côté d'une barre.
- **Hauteur** : tous les blocs d'une rangée ont la hauteur du plus haut.
- **Largeur** : chaque bloc à sa taille, ou (option du groupe) toutes les rangées à la même
  largeur, les blocs se partagent la place.
- **Positions absolues** : chaque bloc est placé par rapport au coin de son groupe (un cadre
  invisible), jamais par rapport à un autre bloc. Plus de chaîne, plus de boucle possible.
- **Bloc vide masqué** : il sort de sa rangée au moment du calcul, la rangée se resserre ; une
  rangée vide disparaît. Rien à « sauter ».
- **La deuxième rangée de la barre par défaut** devient la rangée 2 du groupe.

## Les contraintes (dites au joueur pendant le placement)
1. **Fusionné, formes en L et en T** : une rangée prend la largeur du groupe si ses blocs au plus
   doublent leur largeur ; sinon (une rangée de 1 ou 2 blocs) elle garde sa taille et son alignement
   (menu rapide), collée aux autres : L (gauche ou droite), T (centre). Les bordures partagées en
   partie sont recollées par `UpdateSeams` (positions exactes). Une colonne (un bloc par rangée) a
   toujours une seule largeur. (Essai beta1-beta4 : rangée courte 2 px à l'écart ; refusé par
   Braincell1980 le 20/10, les blocs semblaient détachés.)
2. **Une seule bordure par groupe fusionné** : celle du bloc de tête. Le texte, les icônes et les
   couleurs restent propres à chaque bloc.
3. **24 rangées au plus par groupe, 24 blocs au plus par rangée** (la disposition « colonne »
   a plus de 6 rangées : la limite de 6 a été relevée).
4. **Une barre collée au bord et étirée sur toute la largeur reste sur une rangée** (déjà le cas).

Pendant un glisser, le cadre sous le bandeau dit où le bloc va aller et pourquoi un endroit est
refusé : « Rangée 2 de la barre du haut, entre Or et Sacs », « Groupe fusionné : la rangée prend
la largeur du groupe », « 6 rangées au plus », etc. Un trait doré montre l'endroit d'insertion.

## Les gestes
- Glisser un bloc contre le **côté gauche ou droit** d'un bloc : il entre dans sa rangée, à cet
  endroit (les suivants se décalent).
- Contre le **haut ou le bas** d'un bloc : une nouvelle rangée au-dessus ou en dessous.
- Glisser le **groupe** : comme aujourd'hui (le bloc de tête, ou n'importe quel bloc sans Maj).
- **Maj + glisser** : sortir un bloc de son groupe.
- Menu rapide d'une rangée : alignement (gauche / centre / droite).
- Le reste ne change pas : remplacer (flèches), croix, espaces, bords de l'écran, Ctrl + Z,
  groupe figé, échelle du groupe.

## Données
- `db.groups[id] = { rows = { { keys = {...}, align = "LEFT" | "CENTER" | "RIGHT" }, ... },
  point = {...} ou anchor = {...}, look, fill, scale, frozen, edges, stretch }`.
- `cfg.group = id` sur chaque bloc ; `cfg.dock` et `cfg.anchor.below` disparaissent.
- Undo : copie de `db.groups` et des positions.

## Conversion des dispositions des joueurs
À la première connexion avec la nouvelle version, pour chaque profil :
1. parcours de chaque chaîne depuis sa tête : droite = même rangée, colonne + 1 ; gauche =
   colonne - 1 ; dessous = rangée + 1 ; dessus = rangée - 1 ;
2. les rangées triées par position, les blocs de chaque rangée par colonne ;
3. une deuxième rangée qui pendait sous un groupe devient la rangée suivante de ce groupe,
   centrée ;
4. alignement de chaque rangée déduit de sa première colonne (gauche / centre / droite) ;
5. ce qui ne rentre pas (plus de 6 rangées...) devient un groupe à part, au même endroit ;
6. un message dit que la disposition a été convertie, avec Ctrl + Z pour revenir à la
   conversion près, et une sauvegarde de l'ancienne disposition (comme le mode démo).

## Étapes (zips beta)
1. **Simulateur de positions** pour les tests hors du jeu : calcule où chaque bloc se trouve
   vraiment, et vérifie des centaines de dispositions (aucun chevauchement, aucun trou, tout
   dans son groupe).
2. **Moteur de rangées** (`Rows.lua`) : données, calcul des positions, rendu (bordure de groupe
   en fusionné, cadres de blocs en tuiles), blocs masqués.
3. **Conversion** des profils + dispositions toutes prêtes réécrites en rangées.
4. **Placement** : glisser, trait d'insertion, messages du cadre sous le bandeau, menu de rangée.
   → **beta1** à tester.
5. Bords de l'écran, barres étirées, deuxième rangée, mode démo, DataBroker, export / import.
   → **beta2**.
6. Aide, infobulles, changelog, descriptions ; nettoyage de l'ancien code de `Merge.lua`.

## État (20/10/2026, beta1)
- Fait : `Rows.lua` (lecture / écriture des rangées sur `cfg.dock` canonique + `cfg.rowAlign` sur la
  tête, conversion de toute ancienne disposition, rangées pendantes intégrées), moteur de
  disposition par rangées dans `Merge.lua` (`LayoutGroup` : hauteurs par rangée, grilles,
  justification ou alignement, blocs ancrés à la tête), dépôt par rangées (`JoinRows`), trait
  d'insertion et texte pendant le glisser, alignement de rangée dans le menu rapide, espaces
  insérés par rangées, sortie d'un bloc (Maj) sans emporter ses voisins.
- Le stockage reste lisible par la 1.0.0 (docks valides) ; à la première conversion d'un profil,
  une copie « <nom> (1.0) » est gardée.
- `tools/geometry_check.lua` : 404 dispositions (toutes prêtes × aspects × blocs masqués,
  déplacements au hasard, vieux arbres au hasard), 0 problème.
- Reste : aide, infobulles, changelog, descriptions ; nettoyage du code mort de `Merge.lua`
  (`GetEffectiveDock`, `Reroot`, `GetVisualRoot`, chemins `HangTarget`).
