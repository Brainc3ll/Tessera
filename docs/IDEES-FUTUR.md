# Idées pour le futur

Idées notées pour plus tard : elles seront reprises ou pas. Rien ici n'est validé ni prévu à une date.
Les idées faites sont marquées [Fait] avec leur version.

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
- **Réglages** : choix du cadre, de sa couleur, de sa taille, des éléments décoratifs, par groupe (dans l'onglet Apparence).
- **Performance** : rester léger (quelques textures par groupe, pas d'animation coûteuse).

## Icônes nettes sur les grands écrans (4K) (11 octobre 2026)

Constat de Braincell1980 : en dehors des bordures, ce sont surtout les **icônes** des blocs qui pixelisent sur un grand écran (les icônes du jeu sont souvent en 64 × 64 et deviennent floues une fois agrandies). À travailler dans une version future.

Pistes, par ordre d'intérêt :

- **Prise en charge de Masque** : le joueur habille les icônes de ses blocs avec le skin Masque de son choix (beaucoup existent, dont des skins HD), assorti à ses barres d'action. Tessera n'a aucune image à fournir.
- **Icônes HD du jeu** : le client de Forever est moderne et contient peut-être des versions haute définition de certaines icônes et images (atlas) ; les utiliser quand elles existent. À vérifier en jeu avec une version debug.
- **Ne pas agrandir au-delà du net** : option « icône nette » qui limite la taille de l'icône à ce qui reste propre, et calage sur la grille de pixels de l'écran.
- **Jeu d'icônes HD propre à Tessera** (dessins originaux, 256 px), pour les blocs de Tessera seulement : échantillon fait le 11 octobre 2026 (`Tessera-apercu-HD.png`, icônes or, sacs, horloge, latence, Compréhension, camping, héritage et cadre « Mosaïque »). Les lanceurs et les blocs DataBroker gardent l'icône de leur addon.
- Format des images à vérifier sur Forever (TGA sûr, PNG à tester).

## Look « HD » (15 octobre 2026, à l'étude)

Souhait de Braincell1980 : un Tessera beaucoup plus HD, même sur Forever (il fait « 2006 » aujourd'hui). Pistes :
1. Lignes nettes au pixel près : bordures de 1 pixel réel calées sur les pixels de l'écran, à toutes les échelles.
2. Images faites pour Tessera, dessinées en grand (256-512 px) : bordures, coins, léger dégradé, ombre douce, lueur au survol.
3. Une police moderne libre de droits (licence OFL) livrée avec Tessera.
4. Icônes : Masque, taille plafonnée à ce qui reste net (voir « Icônes nettes » plus haut).
5. Petites animations : fondu, valeur qui glisse, survol qui s'allume.
Méthode proposée : d'abord un nouveau style « HD » (points 1 à 3) à côté des autres, puis étendre ses images aux autres styles s'il plaît. Plutôt en 1.1. Avant de coder : une maquette (même barre, style actuel et style HD côte à côte).

## Idées tirées des autres addons de barres (13 octobre 2026)

Comparaison avec Titan Panel, Arcana (ex-ChocolateBar), Bazooka, XIV_Databar Continued,
TitanData Texts, ForeverPlus et les textes de données d'ElvUI. Liste du plus simple au plus
compliqué ; Braincell1980 choisit la version de chaque idée.

1. [Fait, rc4] Taille des infobulles réglable (option globale).
2. [Fait, rc4] Infobulle seulement en tenant Alt (option globale).
3. (Pas de combats de mascottes sur Forever pour le moment : mis de côté, voir plus bas.)
4. [Fait, rc4] Coût de réparation et état de chaque pièce dans l'infobulle de durabilité.
5. Fondu des barres en entrant ou en sortant de combat (au lieu de les masquer d'un coup).
6. Or filtré : tous les personnages / ce jeu de règles / ce jeu de règles et cette faction / ce personnage.
7. [Fait, rc4 : mana seulement, le jeu ne donne pas la régénération de vie] Régénération de vie et de mana (nouveau bloc).
8. [Fait, rc4] Statistiques du personnage (critique, hâte, toucher, puissance d'attaque et des sorts, armure, esquive) (nouveau bloc).
9. [Fait, rc4] Méthode de butin du groupe (maître du butin, seuil, /roll) (nouveau bloc).
10. Zones dans un groupe : gauche / centre / droite, le centre restant centré quand les largeurs changent ; réglage par groupe et option globale. (L'alignement du texte dans chaque bloc existe déjà, onglet Blocs > Texte.) Validé, plutôt pour la v1.1. Intérêt surtout pour les barres pleine largeur (dispositions barre des tâches). Exigence de Braincell1980 : à expliquer très très clairement (infobulles, aide, visite rapide, exemple visuel gauche / centre / droite, changelog).
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

## Styles (14-15 octobre 2026)

- [Fait, rc5] Quatre styles fantasy (Pierre runique, Grimoire, Parchemin, Arcanes) et cinq styles faits des cadres du jeu (Sceau royal, Forgefer, Lame runique, Braise, Sylvestre).
- [Fait, rc5] Styles des interfaces (FlareUI, ElvUI, EllesmereUI) choisissables sans l'addon, en imitation.
- En réserve : « Forge naine » (fer sombre, texte orange braise).
- Styles pour d'autres interfaces (TukUI, GW2 UI, NDui, KkthnxUI, SpartanUI…), en 1.1.
- Style « écran de sélection » (15/10, intéresse Braincell1980 ; pour une prochaine version majeure, gros travail) : le look des écrans avant d'entrer en jeu (choix et création de personnage) : fond brun très sombre, liseré or fin aux coins ouvragés, titres or en Friz Quadrata, valeurs claires. À vérifier d'abord avec une sonde de la version debug (pendant la bêta si possible) : les images de ces écrans sont-elles accessibles à un addon une fois en jeu sur Forever ? Si oui, vraies bordures et vrais coins ; sinon, imitation avec les cadres du jeu (comme Sceau royal).
- Option « icônes en médaillon » (même jour) : icônes rondes cerclées d'or, comme les icônes de faction, race et classe de ces écrans ; pour ce style ou pour tous.
- Formes de blocs (15/10, pour une v2 ou une v3 : évolution technique importante) : 1. coins arrondis et barres « pilule » (les blocs se collent encore) ; 2. lanceurs ronds, icône seule (rejoint les médaillons) ; 3. hexagones en nid d'abeille pour les lanceurs (une vraie mosaïque) ; 4. bannière ou ruban pour les titres de groupe (espaces avec texte). Formes libres (blason, bouclier) écartées : le texte s'y place mal et elles ne s'assemblent pas. À vérifier : découpe d'images (masques) sur Forever ; images dessinées exprès ; zone de clic toujours rectangulaire. Va avec le style « écran de sélection » et les médaillons (une version « look »).

## Affichage des valeurs (14 octobre 2026)

- [Fait, rc5] Or (icônes ou lettres, or et argent, arrondi, séparateur), sacs, XP, durabilité, FPS, latence, secondes, coordonnées, amis, guilde, réputation : sous-onglet Texte, « Valeur affichée ».

## Mode démo (14 octobre 2026)

- [Fait, rc5] Tous les blocs par catégorie, valeurs d'exemple, sélecteur de styles, interface du jeu masquable.
- [Fait, 1.0.0] « Styles mélangés » : après les styles, chaque colonne dans son propre style (4 étapes).
- Pistes : bouton « capture » qui masque aussi le bandeau ; choisir les catégories affichées ; style par groupe pour les joueurs (menu Alt + clic droit, à côté de « Apparence du groupe »), après la 1.0.0.

## Remplacement de blocs (14 octobre 2026)

Fait pour la rc5 : croix et flèches sur le bloc survolé en mode placement, liste en deux parties (masqués / affichés), remplacer un espace par un bloc, sujet d'aide dédié.

Pistes pour après la 1.0.0 :
- remplacer en glissant : poser un bloc sur un autre en tenant Alt prend sa place (sans passer par la liste) ;
- dans la liste, l'aperçu de la valeur de chaque bloc (comme sur les blocs d'exemple), pour choisir sans essayer ;
- « blocs suggérés » en haut de la liste selon la classe et le niveau (munitions pour un chasseur, composants pour un mage...).
