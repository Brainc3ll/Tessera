# Tests de la 1.0.0 (avant le 22 octobre)

Version testée : **Tessera-1.0.0-test4.zip**, puis **Tessera-1.0.0-test10.zip**, puis **Tessera-1.0.0-test12.zip**, puis **Tessera-1.0.0-test16.zip** pour les points ci-dessous. Le 16/10, Braincell1980 valide tout le reste à 99 % :
nouveau joueur, Styles mélangés, barre d'XP de FlareUI, bloc Date et dispositions, deuxième rangée,
changelog trié, et le nouveau build de WoW Forever du 16/10 (sans FlareUI, cassé par ce build).

## Test6 à test10 : validées le 16/10

Devant / derrière (bandeau, question au verrouillage, onglet Apparence, bouton sous la fenêtre du mode Édition), Chemin de ronde, style gardé en appliquant une disposition, aide et visite rapide, `/tessera preview forever` retirée.

## Test11 et test12 : validées le 16/10

Bouton du mode Édition qui respire, question seulement après avoir utilisé le bouton, plus de « n/d » après un chargement (bateau, pierre de foyer).

## Nouveau dans la test13 et la test14 (5 min)

- [ ] Infobulle du bloc Or : tes personnages apparaissent avec leur nom complet (« Ellen Kemp ») ; deux personnages au même prénom ont chacun leur ligne (se connecter avec chacun une fois). Un personnage d'un autre jeu de règles (PvP par exemple) a sa propre ligne, suivie du nom du jeu de règles.
- [ ] Ton profil (par personnage, si tu en utilises) et ton or sont gardés après la mise à jour.
- [ ] Avec FlareUI : changer la police des raccourcis dans FlareUI, puis reprendre le style FlareUI dans Tessera : le texte des blocs prend cette police.

- [ ] Onglet Apparence, sous le style : « Cadre de tous les blocs... » ouvre l'onglet Blocs sur « Tous les blocs », sous-onglet Cadre ; « Texte de tous les blocs... » pareil sur Texte. Les deux boutons sont côte à côte, comme « Exporter le style » et « Exporter la disposition » : textes lisibles, rien de coupé.

## Nouveau dans la test15 et la test16 (3 min, avec FlareUI)

- [ ] Onglet Apparence : reprendre le style FlareUI. Des lignes bronze discrètes séparent les blocs collés.
- [ ] Bloc XP avec « Barre de progression » cochée (onglet Blocs) : le fond qui se remplit a le grain des barres de vie de FlareUI, et il est coupé net à la valeur (pas écrasé).
- [ ] Onglet Général, Accessibilité : « Couleurs des seuils » sur Automatiques ; avec le style FlareUI, latence et FPS ont des vert / jaune / rouge adoucis. Essayer Vives, puis Pour daltoniens (bleu, orange, violet).
- [ ] Si tu avais coché « Couleurs pour daltoniens » avant : la liste affiche « Pour daltoniens » après la mise à jour.

## Reste à faire

- [ ] Instance : profil donjon, masquer en instance, clics sur les blocs en combat ; aucune erreur Lua.
