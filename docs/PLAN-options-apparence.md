# Projet : onglet Apparence, fenêtre d'options aérée, apparence des groupes

État : **idées validées, pas encore codées** (11 octobre 2026). Maquette à montrer avant de coder.

## 1. Onglet « Apparence » et nouveau rangement

Aujourd'hui, les styles sont dans l'onglet Général et les dispositions toutes prêtes dans l'onglet Profils : ce n'est pas logique.

Nouvel onglet **Apparence**, pour tout ce qui change le look d'ensemble :
- le style des blocs (déplacé depuis Général) ;
- les dispositions toutes prêtes (déplacées depuis Profils) ;
- les bords de l'écran (coller, étirer) ;
- plus tard : la copie de la disposition du mode Édition (voir `PLAN-edit-mode.md`) ;
- l'apparence des groupes (section 3).

Les autres onglets :
- **Général** : seulement le comportement (verrouillage, combat, discussion, minicarte, mode Édition, aimantation, grille).
- **Profils** : seulement les profils (créer, dupliquer, supprimer, exporter, importer, profil de donjon et de raid, tout réinitialiser).

Ordre des onglets proposé : Blocs, Apparence, Général, Lanceurs, Broker, Profils, Aide, À propos (8 onglets). En mode DataBroker, l'onglet Apparence est masqué comme les autres onglets de réglages.

À mettre à jour en même temps : l'aide (sujets « Onglet Général », « Profils »…), les infobulles qui citent un onglet, le README et la description CurseForge.

## 2. Fenêtre d'options plus grande et plus aérée

- **Largeur** d'environ 720 pixels au lieu de 600, plus d'espace entre les réglages, titres de section plus marqués, groupes de réglages séparés par un vrai vide.
- **Largeur adaptée à l'écran** : les blocs affichés depuis les options se placent à gauche et à droite de la fenêtre. Sur un petit écran (par exemple 1366 × 768), la fenêtre reste assez étroite pour garder une colonne de blocs de chaque côté ; sur un grand écran, elle prend sa largeur complète.
- **Maquette** de chaque onglet à valider avant de coder.

## 3. Trois apparences de groupe

Réponse à la question « et si un joueur ne veut pas fusionner ? » :

- **Fusionnés** (comme aujourd'hui) : un seul cadre, les bordures entre les blocs disparaissent.
- **Mosaïque à joints** (nouveau) : les blocs restent groupés et se déplacent ensemble, mais chacun garde son cadre, avec un petit espace réglable entre eux, comme les joints entre les tesselles d'une mosaïque.
- **Séparés** : pas de groupe ; c'est l'actuelle case « Fusionner les blocs » décochée (onglet Général), aujourd'hui trop discrète.

Le réglage va dans l'onglet Apparence, pour tous les groupes, et peut aussi se choisir groupe par groupe.

Points à prévoir :
- l'espace des joints doit rester cohérent avec les barres collées aux bords et étirées (les blocs espace s'allongent, les joints gardent leur taille) ;
- le passage d'une apparence à l'autre ne doit pas casser une disposition existante (les accroches entre blocs ne changent pas, seul le dessin change) ;
- aide, infobulles et chaînes en anglais et en français.

## 4. Aide revue et mini tutoriel

Constat (11 octobre 2026) : « Remplacer par... » et « Ajouter un espace » existent dans le menu rapide (Alt + clic droit), mais rien ne l'indique en mode placement ; même l'auteur ne les a pas trouvés.

- **Revoir toute l'aide** : vérifier que chaque fonction y figure, au bon endroit, avec des mots simples ; réorganiser les sujets après le passage à l'onglet Apparence.
- **Rendre les actions visibles** : le bandeau de placement et les infobulles des blocs déverrouillés citent le menu rapide et ce qu'il contient (masquer, détacher, figer, ajouter un espace, remplacer par...).
- **Mini tutoriel** (premier lancement, et relançable depuis l'aide) : quelques étapes courtes, par exemple déverrouiller, déplacer et fusionner un bloc, ouvrir le menu rapide, remplacer un bloc, ajouter un espace, coller une barre au bord, verrouiller.
- **Plus tard** : un tutoriel interactif (étapes guidées en jeu, qui attendent que le joueur fasse l'action).

## 5. Export / import d'un style ou d'une disposition

Aujourd'hui, on exporte et importe un **profil entier**. En plus, pouvoir partager séparément :

- **un style** : l'apparence seulement (polices, couleurs, cadres, icônes, apparence des groupes), à appliquer sur ses propres blocs sans toucher à leur placement ;
- **une disposition** : le placement seulement (quels blocs, où, fusionnés comment, collés aux bords, étirés), sans toucher à l'apparence.

Les deux se rangent dans l'onglet Apparence, à côté des styles et des dispositions toutes prêtes.

**Addons dont dépend l'export** : un style ou une disposition peut s'appuyer sur d'autres addons, absents sur un autre PC, un autre profil ou un autre personnage. L'export note donc ce dont il a besoin :
- lanceurs (boutons de la minicarte de tel addon) et blocs DataBroker (fournis par tel addon) ;
- polices, fonds et bordures venant de LibSharedMedia (fournis par tel addon) ;
- style assorti à une interface (FlareUI, ElvUI, EllesmereUI) ;
- blocs propres à WoW Forever (héritage, camping, Compréhension, honneur).

**À l'import**, Tessera compare avec ce qui est installé et affiche un résumé avant d'appliquer, par exemple :
« Il manque : Bazooka (2 blocs DataBroker), SharedMedia_MyFonts (1 police). Ces éléments seront ignorés ou remplacés par la police par défaut. Importer quand même ? »
- rien n'est appliqué sans confirmation ;
- un élément manquant est ignoré proprement (bloc non créé, police par défaut), sans casser le reste ;
- le même contrôle peut servir à l'import d'un profil entier.

## Étapes prévues

1. Maquette de la nouvelle fenêtre (onglet par onglet) et des trois apparences de groupe, à valider.
2. Code : nouvel onglet et déplacement des réglages, fenêtre adaptée à l'écran, apparence des groupes.
3. Aide revue, mini tutoriel, infobulles, README, description CurseForge.
4. Tests automatiques, puis test en jeu à plusieurs résolutions.
