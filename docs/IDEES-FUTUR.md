# Idées pour le futur

Idées notées pour plus tard : elles seront reprises ou pas. Rien ici n'est validé ni prévu à une date.
Les projets déjà validés ont leur propre plan (`PLAN-edit-mode.md`, `PLAN-options-apparence.md`).

## Cadres décoratifs autour d'un groupe (11 octobre 2026)

Idée de Braincell1980 : permettre au joueur d'entourer un groupe de blocs d'un cadre plus graphique qu'une simple bordure.

Pistes possibles :

- **Cadres ornés** : coins sculptés, motifs (pierre, bois, métal doré, style parchemin, style « tablette de mosaïque »), dessinés par-dessus la bordure du groupe. Les coins restent de taille fixe et les côtés se répètent, pour s'adapter à n'importe quelle taille de groupe.
- **Éléments décoratifs** accrochés au cadre : petite gargouille ou gryphon sur un coin, blason, cristal, chaîne qui pend… placés sur un coin ou au milieu d'un côté, au choix.
- **Titre de groupe** : un bandeau ou une plaque avec un nom (« Économie », « Social »…) posé sur le bord du cadre.
- **Fond de groupe** : texture derrière tout le groupe (parchemin, pierre, cuir), au lieu de la couleur unie de chaque bloc.
- **Assorti aux styles** : cadres prévus pour aller avec FlareUI, ElvUI, Blizzard… et un cadre « mosaïque » propre à Tessera.

Points à étudier le moment venu :

- **Images** : les cadres doivent être des textures libres de droits, ou créées pour Tessera (pas d'images reprises d'autres jeux ou addons). LibSharedMedia pourrait servir pour les textures fournies par d'autres addons.
- **Comportement** : le cadre suit le groupe (déplacement, blocs masqués qui le font rétrécir), ne bloque pas les clics, et reste sous le plan d'affichage des blocs.
- **Groupes collés aux bords** : pas de cadre du côté de l'écran, comme pour la bordure.
- **Réglages** : choix du cadre, de sa couleur, de sa taille, des éléments décoratifs, par groupe (dans l'onglet Apparence prévu par `PLAN-options-apparence.md`).
- **Performance** : rester léger (quelques textures par groupe, pas d'animation coûteuse).
