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

## Icônes nettes sur les grands écrans (4K) (11 octobre 2026)

Constat de Braincell1980 : en dehors des bordures, ce sont surtout les **icônes** des blocs qui pixelisent sur un grand écran (les icônes du jeu sont souvent en 64 × 64 et deviennent floues une fois agrandies). À travailler dans une version future.

Pistes, par ordre d'intérêt :

- **Prise en charge de Masque** : le joueur habille les icônes de ses blocs avec le skin Masque de son choix (beaucoup existent, dont des skins HD), assorti à ses barres d'action. Tessera n'a aucune image à fournir.
- **Icônes HD du jeu** : le client de Forever est moderne et contient peut-être des versions haute définition de certaines icônes et images (atlas) ; les utiliser quand elles existent. À vérifier en jeu avec une version debug.
- **Ne pas agrandir au-delà du net** : option « icône nette » qui limite la taille de l'icône à ce qui reste propre, et calage sur la grille de pixels de l'écran.
- **Jeu d'icônes HD propre à Tessera** (dessins originaux, 256 px), pour les blocs de Tessera seulement : échantillon fait le 11 octobre 2026 (`Tessera-apercu-HD.png`, icônes or, sacs, horloge, latence, Compréhension, camping, héritage et cadre « Mosaïque »). Les lanceurs et les blocs DataBroker gardent l'icône de leur addon.
- Format des images à vérifier sur Forever (TGA sûr, PNG à tester).

## Idées tirées des autres addons de barres (13 octobre 2026)

Comparaison avec Titan Panel, Arcana (ex-ChocolateBar), Bazooka, XIV_Databar Continued,
TitanData Texts, ForeverPlus et les textes de données d'ElvUI. Liste du plus simple au plus
compliqué ; Braincell1980 choisit la version de chaque idée.

1. Taille des infobulles réglable (option globale).
2. Infobulle seulement en tenant Alt (option globale).
3. (Pas de combats de mascottes sur Forever pour le moment : mis de côté, voir plus bas.)
4. Coût de réparation et état de chaque pièce dans l'infobulle de durabilité.
5. Fondu des barres en entrant ou en sortant de combat (au lieu de les masquer d'un coup).
6. Or filtré : tous les personnages / ce jeu de règles / ce jeu de règles et cette faction / ce personnage.
7. Régénération de vie et de mana (nouveau bloc).
8. Statistiques du personnage (critique, hâte, toucher, puissance d'attaque et des sorts, armure, esquive) (nouveau bloc).
9. Méthode de butin du groupe (maître du butin, seuil, /roll) (nouveau bloc).
10. Zones dans un groupe : gauche / centre / droite, le centre restant centré quand les largeurs changent ; réglage par groupe et option globale. (L'alignement du texte dans chaque bloc existe déjà, onglet Blocs > Texte.)
11. Mélangeur de volume : une glissière par canal dans l'infobulle du bloc volume.
12. Micro-menu : un bloc qui ouvre tous les panneaux du jeu.
13. Bloc de voyage : pierre de foyer + téléportations de classe, clic droit pour choisir.
14. Recharges de métiers sur tous les personnages (Étoffe lunaire, transmutations...).
15. Options chargées seulement à l'ouverture (moins de mémoire en jeu) : gros chantier, avec le nettoyage du code.

### À garder pour plus tard (pas sur Forever, pour une version multi-versions)
- Grande Chambre forte, clés mythiques +, téléportations mythiques +.
- Changement de spécialisation de butin.
- Masquer les barres pendant les combats de mascottes (pas sur Forever pour le moment).
- Outils de raid (appel, compte à rebours, marqueurs) : à revoir selon la demande.
