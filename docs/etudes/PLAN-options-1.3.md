# Plan d'architecture : fenêtre d'options 1.3 (11 novembre 2026)

**Statut : plan, rien n'est codé.** Écrit par Claude (Fable 5.2) après lecture du code de `next` (commit `556c162`), de FlareUI 5.1.2 (MIT, idées seulement) et du code de Blizzard pour Forever (dépôt Gethe/wow-ui-source, branche `forever`). Les décisions de Braincell1980 sont dans `docs/A-REPRENDRE.md` (11/11) ; la structure des pages dans `docs/IDEES-FUTUR.md`, « Fenêtre d'options 1.3 ». Ce que je n'ai pas pu vérifier est listé à la fin.

## 1. Ce que le code fait déjà (lu, pas supposé)

| Sujet | Aujourd'hui | Conséquence |
|---|---|---|
| Curseurs | `CreateSlider` utilise déjà `MinimalSliderWithSteppersTemplate`, le curseur à flèches du jeu | Rien à refaire, seulement la mise en ligne (libellé à gauche, commande à droite) |
| Listes | `CreateDropdown` utilise `WowStyle1DropdownTemplate` (menu `SetupMenu`) | `SettingsDropdownWithButtonsTemplate` (◄ valeur ►) existe dans le code de Forever et accepte le même `SetupMenu` : le remplacement se fait dans une seule fonction |
| Cases | `CreateCheck` utilise `UICheckButtonTemplate` | `SettingsCheckboxTemplate` existe dans le code de Forever |
| Sections repliables | Aucune | `SettingsExpandableSectionTemplate` existe ; à essayer, sinon un bouton maison |
| Tous les réglages | Passent par `Create*(parent, label, getter, setter, isShown, tip)` puis `P.Place(widget, col)` (`NewLayout`) | Changer les 5 fonctions `Create*` et `NewLayout` change toutes les pages d'un coup |
| Bloc affiché ou non | Un seul champ, `cfg.enabled`. `ns:HideBlock` le met à faux et garde la place dans la barre | « Retirer » n'a pas besoin d'un nouveau champ : il change ce qui arrive à la place |
| Style | `db.theme` par profil ; `ns:ApplyThemeToCfg(cfg, key)` écrit les valeurs d'un style dans les réglages d'UN bloc | Le style par bloc est possible sans nouveau champ (voir 3.4) |
| Placement | Déverrouiller cache toute la fenêtre (`optionsTucked`) et montre le bandeau (`ns:UpdatePlacementBanner`) | « Réduire à la barre du haut » remplace « cacher » |
| Clavier du bandeau | Le bandeau écoute déjà Ctrl + Z, laisse passer les autres touches, et n'écoute plus en combat | Les flèches s'ajoutent au même endroit, avec la même prudence |
| Icône | `Core.lua` plafonne l'icône à 2 × la hauteur du bloc ; le curseur s'arrête à 40 | Monter le curseur ne suffit pas (voir 3.6) |
| Langue | Chaque fichier de `Locales/` s'arrête si `GetLocale()` n'est pas sa langue ; ces fichiers se chargent avant `Core.lua` | Le choix de langue doit être connu avant le chargement des textes (voir 3.7) |

## 2. Principe : changer les fondations, pas les pages

`Options.lua` fait 3 382 lignes. Le réécrire d'un bloc serait le plus sûr moyen de perdre un réglage ou d'en casser un. Le plan garde les pages et change ce sur quoi elles reposent, en quatre couches, chacune testable seule.

1. **La ligne.** Un réglage devient une « ligne » : libellé à gauche, commande à droite, hauteur qui suit le texte. Les fonctions `Create*` gardent leur signature et rendent une ligne. Chaque ligne s'inscrit dans une liste (`ns.optionRows`) avec son libellé, son infobulle, sa page et sa section. Cette liste sert quatre fois : bandeau d'aide, recherche, ordre de focus pour la manette, et test automatique « aucun réglage perdu ».
2. **La mise en page.** `NewLayout` passe de deux colonnes fixes à une colonne de lignes avec sections (titre, repliable ou non). Les libellés longs passent sur deux lignes au lieu d'être coupés : c'est le chantier « texte qui s'adapte » du 25/10, et la condition du texte × 2.
3. **Le cadre de la fenêtre.** Barre du haut (logo, titre, recherche, réduire, fermer), onglets à gauche, page au milieu, bandeau d'aide à droite.
4. **Le rangement.** Les réglages changent de place (Essentiel, Position, sections repliées, onglet Accessibilité) en déplaçant des appels `P.Place`, sans toucher à ce qu'ils font.

**Filet de sécurité avant de commencer** : un test dans le faux jeu qui relève la liste de tous les réglages (clé de texte + page) sur `main`, et qui échoue si l'un d'eux manque après la refonte. La règle « une refonte n'enlève rien » devient vérifiable par la machine.

## 3. Les chantiers

### 3.1 Cadre de la fenêtre
- **Un seul cadre parent, une seule strate.** Chaque partie de la fenêtre est un enfant du panneau ; aucune ne fixe sa strate ou son niveau. Les fenêtres annexes (copie de lien, visite, offre de style) passent par `ns:ShowSideWindow` et sont posées au-dessus du panneau. Je n'ai trouvé aucune strate fautive dans le panneau lui-même : la cause de l'observation du 7/11 reste à reproduire en jeu (voir 5).
- **Réduire** : le panneau garde sa barre du haut, cache le reste et change de hauteur. État non sauvegardé (décision : toujours rouverte dépliée).
- **Logo** : `Media/Icon.png` (128 px) dans la barre du haut ; le grand logo dans le bandeau d'aide au repos et dans « À propos ».
- **Bandeau d'aide** : il affiche le titre, l'infobulle `TIP_*` déjà écrite et un conseil facultatif de la ligne survolée ou sélectionnée. Les infobulles au survol restent (elles servent quand le bandeau est sous la page, en texte × 2).
- **Recherche** : sur `ns.optionRows`, sans accents (`ns.SortKey` existe), avec une table d'anciens noms (« Afficher » trouve « Sur l'écran »).

### 3.2 « Sur l'écran » et « Retirer » (T2, tessera-gate2)
- L'interrupteur écrit `cfg.enabled`, comme aujourd'hui. Ce qui change : éteindre fait sortir le bloc de sa barre (les voisins se resserrent), au lieu de garder une place invisible.
- Le code existe en partie : « Remplacer par » fait déjà sortir un bloc proprement (`ns:ReplaceBlock`, correctif 1.1.1 de la boucle de chaînage). Le retrait doit passer par la même porte.
- **Conversion des données** : un bloc déjà éteint qui garde une place (`dock`) est rangé à la mise à jour, en silence (décision du 6/11). C'est la partie risquée : profils, export et import, annulation (Ctrl + Z). Tests avec d'anciens fichiers de sauvegarde avant tout zip.
- « Se cache quand vide » garde sa place (décision du 6/11) : ce n'est pas un retrait.
- Rallumer un bloc : il apparaît en haut à droite de la fenêtre, les suivants en dessous sans être collés (décision du 6/11).

### 3.3 Placement au pixel
- **Ce qui bouge** : un bloc dans une barre n'a pas de position à lui, seule la tête du groupe en a une (`cfg.point`). Les flèches déplacent donc le groupe entier du bloc choisi. À dire clairement dans le bandeau (« Placement : groupe de Or »).
- **Bandeau** : pad à 4 flèches + ✓, X et Y affichés, rappel des touches. Les flèches du clavier passent par le `OnKeyDown` existant : flèche = 1 px, Maj = 10 px, touche gardée = 0,5 s puis 10 px/s, Entrée valide, Échap annule (retour au point de départ, via `ns:PushUndo`).
- **Touches avalées** : pendant le placement, les flèches ne font plus bouger le personnage. Le jeu interdit de changer cela en combat : comme aujourd'hui, le bandeau cesse d'écouter dès qu'un combat commence, et le dit.
- **Première fois** : un message explique que la fenêtre s'est réduite et comment la rouvrir (décision du 11/11). Un drapeau au niveau du compte (`sv.placeNoticeSeen`).
- **Pixel réel** : un « pixel » doit être un pixel de l'écran, pas une unité d'interface. `ns:PixelSize` existe déjà pour les bordures ; le déplacement l'utilisera.

### 3.4 Style d'un bloc ou d'un groupe
Deux façons, à choisir par Braincell1980 :
- **A. Une action (recommandée).** « Appliquer le style … à : ce bloc / son groupe / tous ». Elle écrit les valeurs du style dans les réglages des blocs visés (`ApplyThemeToCfg`, déjà là), annulable. Aucun nouveau champ, aucune conversion, pas de T2. Limite : le bloc ne « suit » pas le style ; si le style général change ensuite, le bloc garde son allure, ce qui est le but.
- **B. Un état mémorisé.** Chaque bloc retient son style (`cfg.theme`). Permet d'afficher « Style : FlareUI » sur le bloc et de suivre les mises à jour d'un style. Coût : nouveau champ, export, import, conversion, T2.

### 3.5 Échelle « Pixel perfect »
Le curseur d'échelle générale existe (`GLOBAL_SCALE`). « Pixel perfect » serait un choix qui calcule l'échelle où une unité de Tessera vaut un pixel de l'écran. Tessera ne touche pas à l'échelle du jeu (FlareUI, lui, règle toute l'interface) : seulement à celle de ses blocs. Formule à vérifier en jeu avec `GetPhysicalScreenSize`.

### 3.6 Icône jusqu'à 200 et flèche du bloc Corps
- **Icône** : aujourd'hui l'icône ne dépasse pas 2 × la hauteur du bloc. Proposition : le bloc grandit avec l'icône (la hauteur suit), plutôt qu'une icône qui déborde sur les blocs voisins. Dans une barre, tous les blocs de la rangée grandissent : à montrer en test avant de trancher.
- **Flèche du Corps × 1,5** (décision du 11/11, sans capture) : l'icône d'un bloc peut déjà porter une rotation ; elle portera aussi un facteur de taille, lu au même endroit que `iconSize`. Rien d'autre ne change. Si la flèche paraît encore petite en jeu, le facteur est un seul nombre.

### 3.7 Sélecteur de langue
- Les textes se chargent avant les données sauvegardées. Deux voies :
  - **A.** `## LoadSavedVariablesFirst: 1` dans le `.toc` : les données sont lues d'abord, et chaque fichier de `Locales/` teste la langue choisie au lieu de `GetLocale()`. FlareUI 5.1.2 utilise cette ligne sur Forever. Changement de 10 lignes. À vérifier en jeu avant de compter dessus.
  - **B.** Si A ne marche pas : chaque fichier range ses textes dans une table par langue, et `Core.lua` choisit au chargement. Plus de mémoire, plus de travail.
- Changer de langue demande un rechargement (les textes sont copiés à la construction des fenêtres) : proposer « Recharger maintenant / Plus tard ».
- `Options.lua` lit aussi `GetLocale()` pour l'aide (l. 2207) : à passer par la même fonction.
- Chinois, coréen, russe : la police du jeu pour une autre langue peut manquer (FlareUI a eu des carrés à la place des lettres). Les fichiers ruRU, koKR, zhCN, zhTW sont vides aujourd'hui : ne proposer que les langues qui ont des textes.

### 3.8 Manette : préparer, ne pas coder
- Chaque ligne déclare ce que font « valider » et « gauche / droite ». L'ordre de focus est l'ordre de `ns.optionRows`. La sélection est visible (cadre), pas seulement une couleur.
- **Contradiction à trancher plus tard** : la note du 25/10 veut s'appuyer sur la navigation manette de Blizzard ; le code de FlareUI dit qu'un clic manette dans cette navigation peut bloquer le client, et il écoute la manette lui-même. Le plan ne choisit pas : les lignes portent l'information, les deux voies restent ouvertes.

## 4. Ordre de travail (un zip de test par lot)

| Lot | Contenu | Risque | Modèle |
|---|---|---|---|
| 0 | Installer les outils ; test « aucun réglage perdu » ; essai de `LoadSavedVariablesFirst` et des modèles du jeu dans un zip sonde | Faible | Sonnet 5.5 |
| 1 | Flèche du Corps × 1,5 ; icône jusqu'à 200 ; crédit à Malkkav dans « À propos » | Faible | Sonnet 5.5 |
| 2 | « Sur l'écran » / « Retirer » : plan, relecture indépendante, anciens fichiers, puis zip | Élevé (T2) | Opus 5.5 |
| 3 | Lignes, mise en page, cadre de la fenêtre (logo, réduire, aide, recherche). Coupé en 3a (lignes, une colonne, défilement : test92, fait le 11/11) et 3b (cadre : test93, fait le 11/11) | Moyen | Opus 5.5 |
| 4 | Rangement des pages, onglet Accessibilité, sections repliées, style par bloc (fait le 11/11 : test96) | Moyen | Opus 5.5 |
| 5 | Placement au pixel (bandeau, pad, flèches, message de première fois) : fait (test102 à test105). Échelle pixel perfect : reportée après la 1.3 (11/11) | Moyen | Opus 5.5 |
| 6 | Revoir la première expérience du joueur (bienvenue, visite guidée, premiers pas, mode démo) avec la nouvelle fenêtre et le placement au pixel, et montrer aux joueurs ce qui change en 1.3 (11/11). Sélecteur de langue : reporté après la 1.3 (11/11) | Faible | Sonnet 5.5 |
| 7 | Aide, infobulles, README, pages, traductions, visite guidée ; vérifications ; publication sur « on publie » | Faible | Sonnet 5.5 |

Le lot 2 passe avant la fenêtre : la liste « Sur l'écran / Disponibles » de la nouvelle page dépend de lui, et le coder après obligerait à refaire la page.

## 5. Ce que je ne sais pas

- Si `SettingsDropdownWithButtonsTemplate`, `SettingsCheckboxTemplate` et `SettingsExpandableSectionTemplate` se comportent bien hors de la fenêtre de réglages de Blizzard. Ils existent dans le code de Forever ; FlareUI utilise le premier. Les deux autres : à essayer dans le zip sonde.
- Si `LoadSavedVariablesFirst` marche sur le client de Forever (FlareUI l'utilise, je ne l'ai pas vu tourner).
- La cause de l'observation du 7/11 (parties de la fenêtre devant un autre addon) : rien trouvé à la lecture.
- L'allure de la flèche du Corps à × 1,5 : pas de capture.
- Le comportement d'une rangée quand un seul bloc a une grande icône.
- La formule exacte de l'échelle pixel perfect sur Forever.
