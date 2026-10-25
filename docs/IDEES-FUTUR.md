# Idées pour le futur

Idées notées pour plus tard : elles seront reprises ou pas. Rien ici n'est validé ni prévu à une date.
Les idées faites sont marquées [Fait] avec leur version.

Rangé par thème le 25 octobre 2026 (avant : par date). Dans chaque partie, la date de chaque idée reste dans son titre. Ce qu'on a appris des autres addons, du code de Blizzard et des autres développeurs : `docs/etudes/SOURCES.md`.

- Règles et décisions
- Nouveaux blocs
- Placement et affichage
- Styles et allure
- Accessibilité et manette
- Traductions
- Code

## Règles et décisions

### Bilan du 24 octobre 2026 : bon, bof, non

Fait avec Braincell1980 après la review du code (22/10), les sondes de l'API de Forever, l'étude des modules (`docs/etudes/PLAN-modules.md`) et celle des bibliothèques. Décision : les versions après la 1.0 servent d'abord à corriger, nettoyer et optimiser (feuille de route dans A-REPRENDRE).

**Bon**
- Profils allégés, faits maison : à la déconnexion, retirer les réglages égaux à leur valeur par défaut ; au chargement, `PrepareProfile` les remet déjà. Environ 200 Ko par profil aujourd'hui en mémoire Lua (mesuré dans le simulateur), tous les profils chargés au lancement.
- Étapes de conversion des sauvegardes rangées dans la base (`sv.dbVersion`), jamais dans un module à part : un joueur peut sauter plusieurs versions.
- Pas de cadres de blocs en mode DataBroker (aujourd'hui créés puis cachés : 61 avec le Chemin de ronde).
- Catalogue des blocs et blocs « fantômes » : utiles même sans modules (un profil Forever ouvert ailleurs).
- Camping : filtrer `UNIT_AURA` sur le joueur.
- Mode placement plus rapide : caches de groupes, étiquettes non recalculées verrouillé, rechargement des styles regroupé au lancement.
- Changelog plus léger en jeu (54 Ko en mémoire, cinq fois le module Forever) : à partir de la 1.0.0, l'historique des rc sur GitHub.
- Petits bugs de la review (voir A-REPRENDRE, 1.1).
- Améliorations des blocs vues dans la sonde : Compréhension par numéro et sa description, honneur d'hier, durabilité dans les sacs (à sonder une fois).
- Audit de l'API avec la doc de Forever.
- Bloc « Batterie de la manette » (`C_GamePad.GetPowerLevel`), à sonder, pour la 2.0.
- Les 4 nouveaux blocs (DPS, Corps, Mode de jeu, Météo) ; la disposition « Portable » après la 2.0.

**Bof**
- Modules par catégorie : environ 2 à 3 % de mémoire en moins ; vrais atouts : listes plus courtes, code rangé. À décider (plan prêt).
- LibSerialize + LibDeflate (exports compressés, environ 1,5-2 Ko au lieu de 5-7) : seulement si les joueurs partagent beaucoup de profils sur Discord.
- LibDBIcon : petit gain, Tessera a déjà son bouton.
- `collectgarbage` au verrouillage : baisse le chiffre affiché mais nettoie la mémoire de tous les addons (petit à-coup possible) ; décision à reprendre.
- Retirer le code des anciennes versions de test (copies du mode Édition, assistant de captures) : propre, presque personne concerné.
- Version Retail : écartée le 21/10.

**Non**
- L'affichage des blocs en module séparé : gros chantier pour environ 0,1 Mo.
- AceDB : les profils faits maison donnent l'essentiel sans toucher au système de profils.
- AceConfig / AceGUI : perdrait la fenêtre d'options stylée et le travail prévu pour la manette et l'accessibilité.
- LibSharedMedia embarquée : Tessera l'utilise déjà quand un autre addon la charge.
- Bloc Batterie (de l'ordinateur) : impossible, les addons n'ont pas accès au système.
- Événements du monde, saison JcJ : coupés sur Forever, seulement si Blizzard les active.
- Compteur de dégâts complet (classement du groupe) : le DPS du joueur suffit.
- Rouvrir le moteur des rangées : seulement si des joueurs le réclament (`archive/refonte-rangees` du dépôt privé Tessera-dev).

Licences à vérifier avant d'embarquer une bibliothèque (Ace3, LibDeflate en zlib et LibSerialize en MIT semblent compatibles avec la licence MIT de Tessera, sans vérification).

### Blocs : de base ou propres à Forever, sinon DataBroker (24 octobre 2026)

Décision de Braincell1980 : ne pas coder (et déboguer) des blocs spécialisés qu'un autre addon fait mieux. Un nouveau bloc est **de base** ou **propre à Forever** ; sinon on cherche un addon avec un objet DataBroker, on le teste, et on l'ajoute à la liste des addons compatibles. Blocs gelés : Instances, Chuchotements. Liste vivante et constat (aucune barre d'infos dans les recommandations Forever, concurrent The Forever Panel) : `docs/etudes/ADDONS-FOREVER.md`. À faire : `/tes debug broker` (Tessera-dev), liste « testés et compatibles » dans le README et les descriptions ; proposer un objet DataBroker aux auteurs plutôt que lire l'intérieur de leurs addons.

### Pour faire de Tessera la référence des blocs d'infos (24 octobre 2026)

Moins de fonctions en plus, plus de confiance et moins d'effort pour l'adopter.
- **Bloc « Farm »** : suivre un objet récolté, avec objectif, rythme et temps restant, et un panneau épinglé en direct (à généraliser à tous les blocs). Étude complète : `docs/etudes/PLAN-bloc-farm.md` (1.2).
- **Importer depuis un autre addon** : « Reprendre ma barre de Titan Panel / ChocolateBar / datatexts d'ElvUI » recrée les mêmes blocs aux mêmes places. Inconnu : leur format de sauvegarde ; l'addon doit être installé pour être lu. À étudier, pas à promettre.
- **Plus de conditions d'affichage** : aujourd'hui en combat et en instance (et le profil automatique donjon / raid). En plus : en ville ou au repos, en groupe, sur une monture, au niveau maximum (masquer l'XP tout seul).
- **Galerie de dispositions** : une page (wiki GitHub ou CurseForge) où les joueurs postent leur texte d'export avec une capture. Vérifier si Wago.io accepte les textes de Tessera.
- La fiabilité (zéro erreur, peu de mémoire) est l'argument principal : c'est la 1.1. Publier ensuite des chiffres mesurés dans la description.
- À éviter : courir après le nombre de blocs.

### Inclusivité (24 octobre 2026)

Que personne ne se sente oublié, au-delà de l'accessibilité. Règle ajoutée dans CLAUDE.md pour les textes et le genre du personnage.
- Textes français : s'adresser au joueur directement, mots épicènes ; ni « (e) » ni point médian (mal lus par les lecteurs d'écran). Vérifié le 24 octobre : aucun dans `Locales/frFR.lua`.
- Genre du personnage : aujourd'hui Tessera ne lit la classe que pour sa couleur. Un futur bloc qui affiche une classe ou une race prend le nom accordé fourni par le jeu.
- Petites configurations (vieux PC, portables, consoles portables) : garder Tessera léger, voir la 1.1.
- Débutants : réglages par défaut qui marchent seuls, aide sans jargon (visite guidée, bloc « Session »).
- Habitudes régionales : heure 12 h / 24 h et formats de date déjà là ; vérifier que les réinitialisations s'affichent à l'heure locale.
- Une main, main gauche : manette (2.0), blocs placés de chaque côté de l'écran.
- Couleurs : rouge = perte et vert = gain ne valent pas partout ; les formes en plus des couleurs (1.4) règlent ça.
- À éviter : options « drapeaux » ou thèmes ajoutés pour afficher une valeur. L'inclusivité la plus solide ne se voit pas.

## Nouveaux blocs

### Nouveaux blocs grâce à la doc de l'API de WoW Forever (22 octobre 2026, validé pour la 1.1)

Source : la référence de l'API du client WoW Forever publiée par Atraeau (https://atraeau.github.io/WoW-Addons/, dépôt `Atraeau/WoW-Addons`, fichier `types/WowForeverAPI.lua`, build 70170). Elle liste ce qui existe dans le client (basé sur Midnight : housing, Gouffres, Mythique+... y sont aussi, sans rapport avec Forever) ; ce qui marche vraiment a été vérifié en jeu le 22/10 avec `/tes debug forever` et `/tes debug dps` (test43 et test44, dépôt privé).

Blocs validés par Braincell1980 pour la 1.1 :
- **DPS** (`C_DamageMeter`, actif sur Forever) : tes dégâts seulement (`GetCombatSessionSourceFromType` avec `UnitGUID("player")`). En combat les valeurs sont secrètes : le jeu laisse les afficher telles quelles (`SetText`), sans calcul ni texte collé (vu en jeu : « 475 », « 28 ») ; après le combat elles se lisent : DPS = dégâts / `GetSessionDurationSeconds` (vu : 7 DPS, 483 en 67 s). Le nom du bloc passe par l'icône ou un texte à part ; couleurs de seuil seulement hors combat. À essayer : le type `Enum.DamageMeterType.Dps` (1), peut-être affichable en direct.
  - Infobulle du bloc DPS : durée du combat en cours et plus long combat de la session (`GetSessionDurationSeconds`), comme le faisait StatBlock_TimeInFight de Funkeh (comparaison avec les plugins StatBlock, 25/10 : Tessera couvre déjà tous les autres sauf DPS et DPS de raid, ce dernier écarté).
- **Corps** (`C_DeathInfo.GetCorpseMapPosition(mapID)`) : en fantôme, distance et direction du corps (vu : 0,491 ; 0,561) ; bloc caché une fois ressuscité ; clic : repère sur la carte.
- **Mode de jeu** (`C_GameRules` : `IsHardcoreActive`, `IsSelfFoundAllowed`, `IsStandard`, `GetActiveGameMode`) : Standard vu en jeu ; à revérifier sur un royaume Hardcore.
- **Météo** (`C_Weather.GetCurrentWeather` : type Clair, Pluie, Neige, Tempête de sable, Divers ; intensité) : gadget.

Améliorations notées :
- **Compréhension** : `C_SkillInfo.GetSkillLineInfoByID(3012)` au lieu de parcourir la liste (marche même catégorie repliée) ; sa `description` pour l'infobulle.
- **Durabilité** : `C_Container.GetContainerItemDurability` pour les pièces rangées dans les sacs (pas encore testé : aucune pièce dans les sacs).
- **Honneur** : `GetPVPYesterdayStats`, `C_PvP.CanDisplayHonorableKills` (présents, tout à 0 au moment du test).
- **Audit** : ajouter `WowForeverAPI.lua` à `tools/api_audit.py` pour qu'il connaisse les fonctions propres à Forever.

Pas sur Forever pour l'instant : événements du monde (`C_EventScheduler.CanShowEvents` = false), saison JcJ (0 s). Principe retenu : un bloc peut attendre dans l'addon et n'apparaître que le jour où Blizzard active sa fonction (comme les blocs qui ne s'enregistrent que si le jeu a leurs fonctions).

### Bloc « Session » pour ceux qui jouent peu (24 octobre 2026)

Idée de Braincell1980 : WoW Forever va attirer beaucoup de joueurs de 35 ans et plus, avec peu de temps de jeu. Nom neutre (« Session » ou « Soirée de jeu »), pas « gamer dad ».
- Déjà dans Tessera, mais éparpillé : temps de la session (infobulle seulement), temps joué total, XP de repos, compteurs de réinitialisation, or et XP gagnés pendant la session.
- Le bloc : le temps de la session en grand ; l'infobulle « depuis la connexion : +XP, +or, niveaux ».
- « Où j'en étais » : une note courte écrite avant la déconnexion, montrée à la connexion suivante.
- « Je m'arrête à 23h » : heure de fin et temps restant. L'horloge de Blizzard a une alarme sur Retail : vérifier en jeu si elle existe sur Forever avant de recoder quoi que ce soit (règle : ne pas refaire ce que le jeu fait déjà).

### Blocs pour une version Retail (21 octobre 2026, pas une priorité)
- À masquer sur Retail : Points d'héritage, Compréhension, Camping, Compétences d'armes, Honneur (version Forever), Munitions, Composants de classe, Secourisme ; Points de talent à refaire (configurations). Un bloc déclare où il existe (Forever, Retail, les deux) ; ailleurs il disparaît des listes, options, « Remplacer par... » et du mode démo, et garde ses réglages.
- Idées de blocs Retail : spécialisation et spé de butin, configuration de talents, or du bataillon, bloc voyage (téléportations, jouets pierre de foyer) : testables sans Midnight. Grande Chambre forte, clé et cote M+, écus de saison, renom, gouffres, concentration de métier : dépendent de la saison, peut-être pas testables sans Midnight.
- Logement (housing) : maison, décorations, quartier. Avoir une maison demande Midnight (Braincell1980 ne l'a pas) : seulement en « expérimental » avec des testeurs, pas une priorité.

## Placement et affichage

### Placement simplifié (21 octobre 2026)
- Décidé : le joueur est libre au pixel près ; plus de recentrage automatique ; un bloc masqué garde sa place (rc8).
- 1.1 : déplacer le bloc choisi pixel par pixel (flèches du clavier, flèches à l'écran) et l'agrandir ou le rétrécir.
- À l'étude : option par bloc « quand il se masque : garder sa place / laisser les voisins se resserrer ». Prudence : le resserrement causait la plupart des bugs de placement.
- Cadres d'autres interfaces dans `ns.KNOWN_UI_FRAMES` (ElvUI, EllesmereUI, puis TukUI, GW2 UI...) : aimantation et avertissement de chevauchement, à ajouter seulement après test en jeu.
- Version Forever + Retail : même API (Midnight), modules propres à Forever chargés seulement s'ils existent ; zips de test avec `## Interface: 16001, 120105, 120107`.
- Fait : la bêta des rangées est rangée (branche `archive/refonte-rangees` du dépôt privé Tessera-dev depuis le 25/10) ; ses idées (colonnes de même largeur, alignement par rangée) restent possibles plus tard.

### Remplacement de blocs (14 octobre 2026)

Fait pour la rc5 : croix et flèches sur le bloc survolé en mode placement, liste en deux parties (masqués / affichés), remplacer un espace par un bloc, sujet d'aide dédié.

Pistes pour après la 1.0.0 :
- remplacer en glissant : poser un bloc sur un autre en tenant Alt prend sa place (sans passer par la liste) ;
- dans la liste, l'aperçu de la valeur de chaque bloc (comme sur les blocs d'exemple), pour choisir sans essayer ;
- « blocs suggérés » en haut de la liste selon la classe et le niveau (munitions pour un chasseur, composants pour un mage...).

### Cadres décoratifs autour d'un groupe (11 octobre 2026)

Idée de Braincell1980 : permettre au joueur d'entourer un groupe de blocs d'un cadre plus graphique qu'une simple bordure.

Pistes possibles :

- **Cadres ornés** : coins sculptés, motifs (pierre, bois, métal doré, style parchemin, style « tablette de mosaïque »), dessinés par-dessus la bordure du groupe. Les coins restent de taille fixe et les côtés se répètent, pour s'adapter à n'importe quelle taille de groupe.
- **Éléments décoratifs** accrochés au cadre : petite gargouille ou gryphon sur un coin, blason, cristal, chaîne qui pend… placés sur un coin ou au milieu d'un côté, au choix.
- **Titre de groupe** : un bandeau ou une plaque avec un nom (« Économie », « Social »…) posé sur le bord du cadre.
- **Fond de groupe** : texture derrière tout le groupe (parchemin, pierre, cuir), au lieu de la couleur unie de chaque bloc.
- **Assorti aux styles** : cadres prévus pour aller avec FlareUI, ElvUI, Blizzard… et un cadre « mosaïque » propre à Tessera.

Points à étudier le moment venu :

- **Images** : les cadres doivent être des textures libres de droits, ou créées pour Tessera (pas d'images reprises d'autres jeux ou addons). LibSharedMedia pourrait servir pour les textures fournies par d'autres addons.
- **Comportement** : le cadre suit le groupe (déplacement, blocs ajoutés ou retirés), ne bloque pas les clics, et reste sous le plan d'affichage des blocs.
- **Groupes collés aux bords** : pas de cadre du côté de l'écran, comme pour la bordure.
- **Réglages** : choix du cadre, de sa couleur, de sa taille, des éléments décoratifs, par groupe (dans l'onglet Apparence).
- **Performance** : rester léger (quelques textures par groupe, pas d'animation coûteuse).

### Affichage des valeurs (14 octobre 2026)

- [Fait, rc5] Or (icônes ou lettres, or et argent, arrondi, séparateur), sacs, XP, durabilité, FPS, latence, secondes, coordonnées, amis, guilde, réputation : sous-onglet Texte, « Valeur affichée ».

### Mode démo (14 octobre 2026)

- [Fait, rc5] Tous les blocs par catégorie, valeurs d'exemple, sélecteur de styles, interface du jeu masquable.
- [Fait, rc6] « Styles mélangés » : après les styles, chaque colonne dans son propre style (4 étapes).
- Pistes : bouton « capture » qui masque aussi le bandeau ; choisir les catégories affichées ; style par groupe pour les joueurs (menu Alt + clic droit, à côté de « Apparence du groupe »), après la 1.0.0.

### Disposition « Portable » : Steam Deck, ROG Ally et autres consoles portables (24 octobre 2026)

Idée de Braincell1980, à faire **après la refonte « Accessibilité » (1.3) et « Manette » (2.0)**, dont elle reprend les briques.
- Sur ces machines (1280×800, ou 720p/800p sur l'Ally), la place à l'écran n'est pas le souci : WoW met son interface à l'échelle (à 800p, elle fait à peu près la taille d'un écran 1366×768). Le souci, c'est la **taille physique** : sur 7 pouces, un texte en 12 devient minuscule.
- Une disposition toute prête : une seule barre, peu de blocs (or, sacs, durabilité, FPS, latence, heure), texte en 14-16, blocs plus hauts (faciles à viser au tactile ou au pavé), infobulles agrandies.
- Pas de bloc Batterie : les addons tournent dans un bac à sable sans accès au système, et l'API de Forever n'a aucune fonction de batterie (vérifié le 24/10). L'overlay de Steam l'affiche déjà.

## Styles et allure

### Styles (14-15 octobre 2026)

- [Fait, rc5] Quatre styles fantasy (Pierre runique, Grimoire, Parchemin, Arcanes) et cinq styles faits des cadres du jeu (Sceau royal, Forgefer, Lame runique, Braise, Sylvestre).
- [Fait, rc5] Styles des interfaces (FlareUI, ElvUI, EllesmereUI) choisissables sans l'addon, en imitation.
- En réserve : « Forge naine » (fer sombre, texte orange braise).
- Styles pour d'autres interfaces (TukUI, GW2 UI, NDui, KkthnxUI, SpartanUI…), en 1.1.
- Style « écran de sélection » (15/10, intéresse Braincell1980 ; pour une prochaine version majeure, gros travail) : le look des écrans avant d'entrer en jeu (choix et création de personnage) : fond brun très sombre, liseré or fin aux coins ouvragés, titres or en Friz Quadrata, valeurs claires. À vérifier d'abord avec une sonde de la version debug (pendant la bêta si possible) : les images de ces écrans sont-elles accessibles à un addon une fois en jeu sur Forever ? Si oui, vraies bordures et vrais coins ; sinon, imitation avec les cadres du jeu (comme Sceau royal).
- Option « icônes en médaillon » (même jour) : icônes rondes cerclées d'or, comme les icônes de faction, race et classe de ces écrans ; pour ce style ou pour tous.
- Formes de blocs (15/10, pour une v2 ou une v3 : évolution technique importante) : 1. coins arrondis et barres « pilule » (les blocs se collent encore) ; 2. lanceurs ronds, icône seule (rejoint les médaillons) ; 3. hexagones en nid d'abeille pour les lanceurs (une vraie mosaïque) ; 4. bannière ou ruban pour les titres de groupe (espaces avec texte). Formes libres (blason, bouclier) écartées : le texte s'y place mal et elles ne s'assemblent pas. À vérifier : découpe d'images (masques) sur Forever ; images dessinées exprès ; zone de clic toujours rectangulaire. Va avec le style « écran de sélection » et les médaillons (une version « look »).

### Look « HD » (15 octobre 2026, à l'étude)

Souhait de Braincell1980 : un Tessera beaucoup plus HD, même sur Forever (il fait « 2006 » aujourd'hui). Pistes :
1. Lignes nettes au pixel près : bordures de 1 pixel réel calées sur les pixels de l'écran, à toutes les échelles.
2. Images faites pour Tessera, dessinées en grand (256-512 px) : bordures, coins, léger dégradé, ombre douce, lueur au survol.
3. Une police moderne libre de droits (licence OFL) livrée avec Tessera.
4. Icônes : Masque, taille plafonnée à ce qui reste net (voir « Icônes nettes » plus haut).
5. Petites animations : fondu, valeur qui glisse, survol qui s'allume.
Le 20/10 : le jeu contient 37 cadres HD tout faits (`NineSliceLayouts`), visibles dans la galerie `/tes debug hd` des zips de test ; pas encore testée en jeu.
Méthode proposée : d'abord un nouveau style « HD » (points 1 à 3) à côté des autres, puis étendre ses images aux autres styles s'il plaît. Plutôt en 1.1. Avant de coder : une maquette (même barre, style actuel et style HD côte à côte).

### Cadres de Blizzard (16 octobre 2026)

- [Fait, rc6] Tessera ne déplace plus les cadres de Blizzard : blocs devant ou derrière (bouton temporaire en mode placement, question au verrouillage, onglet Apparence).
- [Fait, rc6] Une seule disposition collée en haut, « Chemin de ronde », à la place des dispositions façon système.
- Faire découvrir les boutons utiles (16/10, décidé par Braincell1980, après la sortie, vers une 1.0.5) : la bulle d'aide des tutoriels de Blizzard (le système existe sur Forever), une seule fois, qui pointe le bouton et explique à quoi il sert ; ensuite le bouton « respire » (sa propre surbrillance qui s'allume et s'éteint doucement) jusqu'au premier survol. D'abord pour le bouton devant / derrière du mode Édition ; pistes : celui du bandeau, « Mode démo », les flèches de remplacement. Le halo doré carré essayé dans la test9 est écarté (trop moche).

### Icônes nettes sur les grands écrans (4K) (11 octobre 2026)

Constat de Braincell1980 : en dehors des bordures, ce sont surtout les **icônes** des blocs qui pixelisent sur un grand écran (les icônes du jeu sont souvent en 64 × 64 et deviennent floues une fois agrandies). À travailler dans une version future.

Pistes, par ordre d'intérêt :

- **Prise en charge de Masque** : le joueur habille les icônes de ses blocs avec le skin Masque de son choix (beaucoup existent, dont des skins HD), assorti à ses barres d'action. Tessera n'a aucune image à fournir.
- **Icônes HD du jeu** : le client de Forever est moderne et contient peut-être des versions haute définition de certaines icônes et images (atlas) ; les utiliser quand elles existent. À vérifier en jeu avec une version debug.
- **Ne pas agrandir au-delà du net** : option « icône nette » qui limite la taille de l'icône à ce qui reste propre, et calage sur la grille de pixels de l'écran.
- **Jeu d'icônes HD propre à Tessera** (dessins originaux, 256 px), pour les blocs de Tessera seulement : échantillon fait le 11 octobre 2026 (`Tessera-apercu-HD.png`, icônes or, sacs, horloge, latence, Compréhension, camping, héritage et cadre « Mosaïque »). Les lanceurs et les blocs DataBroker gardent l'icône de leur addon.
- Format des images à vérifier sur Forever (TGA sûr, PNG à tester).
- 21/10 : le pack non officiel « forever-icons » (github.com/hastecraft/forever-icons) agrandit toutes les icônes du jeu en 256 px ; s'il marche, les icônes des blocs deviennent nettes sans rien changer à Tessera. Pas livrable ni utilisable comme dépendance (icônes de Blizzard) : au mieux une astuce dans la doc, après un test en jeu.

## Accessibilité et manette

### Se démarquer : accessibilité et manette (18 octobre 2026)

Idée de Braincell1980 : que Tessera se démarque en pensant aux joueurs avec un handicap, et à la manette (plutôt pour une 2.0).

#### Accessibilité (par petits morceaux, dès une 1.1 ou 1.2)
Déjà là : couleurs pour daltoniens, contraste renforcé, taille de texte minimale.
- Lecture à voix haute : un raccourci ou un clic fait lire les valeurs par la synthèse vocale du jeu (« Durabilité 34 %, sacs 3 places libres »). Aucune barre d'infos connue ne le fait.
- Alertes sonores : un son distinct pour la durabilité au rouge, les sacs pleins, un courrier.
- Moins de mouvement : une option qui coupe clignotements, fondus et animations.
- Police adaptée à la dyslexie, sous licence libre, livrée avec Tessera.
- Mode simplifié : moins de réglages visibles, blocs plus grands, clics plus tolérants.
- Tout au clavier : chaque action d'un bloc atteignable par un raccourci, pour jouer d'une main.
- Avant de construire : demander l'avis de joueurs concernés (Reddit, Discord) après la 1.0.0.

#### Manette (2.0, après le nettoyage du code de la 1.1)
Le jeu gère les manettes ; FlareUI a déjà un mode manette et un menu radial.
- Naviguer entre les blocs avec la croix directionnelle : un bouton pour cliquer, un autre pour l'infobulle.
- Menu radial : maintenir un bouton ouvre une roue avec ses blocs (sacs, carte, métiers, pierre de foyer), le stick choisit.
- Fenêtre d'options navigable à la manette, avec de grosses cibles (le plus gros du travail).
- Dispositions pensées pour la manette : moins de blocs, plus grands, lisibles de loin.

### Accessibilité : ne pas refaire ce que le jeu fait déjà (24 octobre 2026)

Règle de Braincell1980 : le jeu a déjà ses options d'accessibilité (Réglages de Blizzard). Tessera ne les recode pas : il les **suit** et **indique qu'elles existent**.
- Suivre : l'échelle de l'interface s'applique déjà aux blocs ; le mode daltonien du jeu pourrait choisir tout seul la palette « daltoniens » de Tessera ; la synthèse vocale de Tessera utiliserait la voix, la vitesse et le volume choisis dans le jeu (`C_TTSSettings`, présent dans l'API de Forever).
- Indiquer : dans l'onglet Accessibilité de Tessera, une partie « Réglages du jeu » qui les liste et un bouton qui ouvre la page Accessibilité des Réglages de Blizzard (`C_SettingsUtil.OpenSettingsPanel`, présent dans l'API de Forever).
- Tessera ne fait que ce que le jeu ne fait pas pour ses blocs : formes en plus des couleurs dans les valeurs, polices d'accessibilité, contraste élevé des blocs, moins d'animations dans Tessera, lecture vocale d'un bloc, navigation à la manette dans ses fenêtres.
- À sonder en jeu avant la 1.4 : la liste exacte des options d'accessibilité de WoW Forever. Ce sont surtout des réglages (CVars, par exemple le mode daltonien), absents de la doc de l'API d'Atraeau : impossible de les lister sans le jeu.

### Polices pour l'accessibilité (24 octobre 2026, pour la 1.4)

Idée de Braincell1980 : donner le choix de polices pensées pour l'accessibilité, et les rendre disponibles pour les autres addons. Licences vérifiées en ligne le 24/10 ; toutes compatibles avec la licence MIT de Tessera (livrées sans modification, avec leur fichier de licence).

| Police | Pour qui | Licence |
|---|---|---|
| OpenDyslexic | Dyslexie (lettres lestées en bas) ; études partagées sur son efficacité, mais appréciée | SIL OFL |
| Atkinson Hyperlegible et Next (2025) | Malvoyance (I, l, 1 et O, 0 bien distincts) ; Braille Institute | SIL OFL 1.1 |
| Luciole | Malvoyance ; projet français (Centre Technique Régional pour la Déficience Visuelle) | CC BY 4.0 (polices de texte) : citer les auteurs (onglet À propos) |
| Lexend | Fluidité de lecture ; plusieurs largeurs (utile pour un réglage d'espacement des lettres) | SIL OFL 1.1 |
| Andika | Lecteurs débutants ; SIL International | SIL OFL 1.1 (noms « Andika » et « SIL » réservés) |
| Inclusive Sans | Lisibilité générale | SIL OFL 1.1 |

À éviter : Dyslexie et Read Regular (payantes), Tiresias (GPL).

- Partage avec les autres addons : les enregistrer dans LibSharedMedia (elles apparaissent alors dans ElvUI, Details, WeakAuras, FlareUI...). Soit Tessera les enregistre quand LibSharedMedia est présent, soit un petit addon `Tessera_Fonts` dans le même zip emporte LibSharedMedia (rejoint `docs/etudes/PLAN-modules.md`). Licence de LibSharedMedia à vérifier avant de l'embarquer.
- À vérifier en jeu : WoW lit les TTF de façon sûre (prendre les versions fixes des polices variables, Lexend et Inclusive Sans) ; couverture du russe police par police ; coréen et chinois : police du jeu.
- Zip : environ 1 à 2 Mo de plus pour les styles normal et gras des 6 polices ; aucun coût en mémoire Lua (le jeu charge une police seulement si elle sert).
- Avec la règle de la 1.3 : la fenêtre d'options doit rester lisible avec chacune de ces polices (largeurs différentes : OpenDyslexic et Lexend sont larges).

### Manette native de WoW Forever (25 octobre 2026) : bâtir dessus, pas à côté

Forever a une prise en charge native de la manette (annoncée à la BlizzCon, « alpha » en septembre) : menus en cercle, barres d'action propres à la manette, modificateurs sur les gâchettes. Dans le code de Blizzard pour Forever : `Blizzard_Gamepad`, `Blizzard_GamepadActionBars` (chargés seulement sur Forever, « camelot »), `Blizzard_GamepadSmartNavigation` (curseur qui saute de bouton en bouton dans les fenêtres), `Blizzard_GamepadSharedUtility` (invites de boutons, dialogues). Le Mode Édition garde une disposition séparée pour la manette (notes de l'API 1.60.1).
- Règle « ne pas refaire ce que le jeu fait » : la 2.0 de Tessera s'appuie sur cette navigation au lieu de recoder la sienne. ConsolePort n'est plus le modèle.
- À étudier avant la 2.0 : une fenêtre d'addon peut-elle entrer dans la navigation de Blizzard (`SmartNavigationMixin:GetPanelInfo`, groupes de boutons) ? Les menus en cercle de Blizzard sont-ils réutilisables pour le menu rapide d'un bloc ? Les dispositions de Tessera doivent-elles suivre la disposition « manette » du Mode Édition ?

## Traductions

### Traduire nous-mêmes plus de langues (25 octobre 2026, à faire après la 1.0.0)

Décidé avec Braincell1980 :
- **Termes du jeu** : prendre les textes officiels de Blizzard (liste de Ketho, branche `forever`, `Resources/GlobalStrings/*.lua`, 11 langues) pour le vocabulaire : noms des blocs, mots courants. Là où un texte de Blizzard correspond exactement, Tessera peut même le lire en jeu (zéro traduction). Attention aux abréviations de Blizzard (« Репут. » en russe).
- **Phrases** (aide, infobulles, environ 1 000 textes) : traduites par Claude avec ce vocabulaire. Allemand, espagnol, portugais, russe d'abord, puis italien ; chinois et coréen seulement avec un relecteur natif.
- **Pas dans le dépôt** (règle de CLAUDE.md : anglais et français seulement) : Claude génère un fichier `.lua` par langue au format de `docs/localization/`, l'envoie à Braincell1980, qui l'**importe à la main** dans l'outil de traduction de CurseForge. Les traducteurs restent libres de tout corriger. Vérifier d'abord sur CurseForge qu'aucun traducteur n'a déjà commencé une langue : ne jamais écraser son travail.
- **Rien ne dépasse des boutons** : l'allemand et le russe sont environ 30 % plus longs que l'anglais. Avant d'envoyer une langue, tester les fenêtres avec des textes allongés : une commande de dev (pseudo-langue qui rallonge chaque texte de 40 %, dans `TesseraDev.lua`) montre les débordements sans attendre les traductions ; corriger la mise en page (boutons qui s'élargissent, texte qui passe à la ligne) plutôt que raccourcir à l'excès.
- **Avertissement** : une nouvelle clé (par exemple `ABOUT_TRANSLATION_NOTE`), vide en anglais et en français. Dans nos traductions : « Traduction générée par Claude (IA), pas encore relue. Tu peux la corriger sur CurseForge. » dans la langue concernée, affichée dans l'onglet À propos (et peut-être une fois au premier lancement). Le traducteur qui relit sa langue vide ce texte.
- **Crédit** : la clé `ABOUT_TRANSLATORS` existe déjà (onglet À propos, ligne « Traduction ») ; le traducteur y met son nom. L'expliquer dans le texte d'appel aux traducteurs.

### Une interface qui s'adapte à la longueur des textes (idée de Braincell1980, 25 octobre 2026)

But : ne plus avoir peur qu'un texte dépasse, quelle que soit la langue ou la taille du texte.
- **Aujourd'hui** : les boutons ont une largeur fixe ; un texte trop long passe en petite police, puis il est coupé par « ... » (`FitButtonText` dans `Options.lua`), l'infobulle garde le texte entier. C'est un filet de sécurité, pas une solution.
- **À faire** : chaque bouton mesure son texte et s'élargit jusqu'à la place disponible dans sa colonne ; au-delà, le texte passe sur deux lignes et le bouton grandit en hauteur. Les rangées de boutons côte à côte passent l'une sous l'autre quand elles ne tiennent plus. Même chose pour les cases à cocher, les listes déroulantes et les onglets : la mise en page se calcule à partir des textes, pas l'inverse.
- **Pourquoi c'est la même chose que l'accessibilité** : le test « texte deux fois plus grand » de la feuille de route 1.3 pose exactement ce problème. Un seul chantier règle les deux ; à faire avec la 1.3, en commençant par les fenêtres les plus visibles (barre d'onglets, bandeau de placement, visite rapide).
- En attendant, les traductions gardent les libellés de boutons courts (outil `tools/check_translation.py`, avertissement sur les textes courts qui s'allongent).

### Choisir la langue de Tessera (idée de Braincell1980, 25 octobre 2026)

Une liste « Langue » (onglet Général) : « Comme le jeu » par défaut, puis chaque langue livrée. Un choix de plus pour le joueur (un francophone qui joue avec un client anglais, par exemple), et un moyen de tester toutes les traductions sans changer la langue du client.
- **Faisable** : toutes les langues sont déjà dans le zip (`Locales/*.lua`, remplies par CurseForge à la publication). Aujourd'hui chaque fichier sort tout de suite si `GetLocale()` n'est pas sa langue ; il faudrait qu'il range ses textes dans une table par langue, et que Tessera choisisse.
- **Difficulté principale** : les réglages sauvegardés ne sont lus qu'après le chargement des fichiers (événement `ADDON_LOADED`), alors que certains textes sont lus dès le chargement (noms des styles dans `Themes.lua`, par exemple). Il faut donc remplir `L` au moment du choix et vérifier que plus aucun texte n'est copié avant. Changer de langue demande un rechargement de l'interface (la liste le dit et propose le bouton).
- **Limites à afficher** : les mots que Tessera prend au jeu (noms de classes, de zones, d'objets, textes de Blizzard) restent dans la langue du client. Chinois et coréen : les polices d'un client occidental n'ont pas ces caractères ; ne les proposer que si le client les affiche, sinon des carrés apparaissent.
- **Quand** : après la 1.0.0 (1.0.1 ou 1.1), car il touche au chargement de tous les textes ; à vérifier avec le mock dans chaque langue. Accessibilité et manette : une liste déroulante ordinaire, déjà utilisable au clavier.

## Code

### Tessera en modules optionnels (24 octobre 2026, à l'étude)

Idée de Braincell1980 : une base et des modules de blocs par catégorie (Forever, Personnage, Monde, Progression, Social, Système) dans le même zip, que le joueur active dans la liste des addons. Étude complète, avec mesures, rétrocompatibilité (blocs « fantômes » qui gardent leur place et leur configuration), packaging, risques et inconnues : `docs/etudes/PLAN-modules.md`. Proposé pour la 1.1, après le nettoyage du code et avant les nouveaux blocs. Trouvé pendant l'étude : le vrai poids mémoire vient des profils (environ 200 Ko chacun, tous les réglages enregistrés), pas du code des blocs.

