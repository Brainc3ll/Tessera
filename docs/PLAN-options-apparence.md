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

## Étapes prévues

1. Maquette de la nouvelle fenêtre (onglet par onglet) et des trois apparences de groupe, à valider.
2. Code : nouvel onglet et déplacement des réglages, fenêtre adaptée à l'écran, apparence des groupes.
3. Aide, infobulles, README, description CurseForge.
4. Tests automatiques, puis test en jeu à plusieurs résolutions.
