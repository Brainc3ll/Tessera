# Tests de la 1.0.0 (avant le 22 octobre)

Version testée : **Tessera-1.0.0-test4.zip**, puis **Tessera-1.0.0-test9.zip** pour les points ci-dessous. Le 16/10, Braincell1980 valide tout le reste à 99 % :
nouveau joueur, Styles mélangés, barre d'XP de FlareUI, bloc Date et dispositions, deuxième rangée,
changelog trié, et le nouveau build de WoW Forever du 16/10 (sans FlareUI, cassé par ce build).

## Nouveau dans la test6 et la test7 (10 min)

- [ ] Mode placement : bouton en haut à droite du bandeau « Tessera : devant » / « Tessera : derrière » : tous les blocs passent derrière les cadres de Blizzard, puis devant. Rien n'est enregistré.
- [ ] Disposition « Chemin de ronde » (onglet Apparence) : barre collée en haut sur toute la largeur ; à gauche zone, or, sacs, durabilité ; au centre les blocs WoW Forever ; à droite courrier, FPS, latence, heure, date. Ton style est gardé.
- [ ] Une barre qui recouvre les barres d'action (par exemple collée en bas) : en verrouillant, Tessera demande « Devant » ou « Derrière ». Essayer les deux : derrière, les barres d'action restent visibles et cliquables. La question ne revient pas pour la même situation.
- [ ] Onglet Apparence, « Cadres de Blizzard » : « Tous les blocs devant » / « Tous les blocs derrière ».
- [ ] Aide : le sujet « Devant ou derrière les cadres de Blizzard » ; la visite rapide parle de Chemin de ronde.
- [ ] Si tu avais une copie de disposition du mode Édition faite par Tessera (« … (Tessera 1) ») : à la connexion, Tessera propose de revenir à ta disposition.

- [ ] Test8 : mode Édition de Blizzard : un bouton « Tessera : devant / derrière » sous sa fenêtre, sans la recouvrir, qui brille doucement jusqu'au premier survol ; il bascule les blocs ; en fermant le mode Édition, Tessera demande quoi garder (si des blocs recouvrent des cadres).
- [ ] Test7 : `/tessera preview forever` n'existe plus (`/tessera help` ne la liste plus) ; l'aide WoW Forever renvoie au mode démo.

## Reste à faire

- [ ] Instance : profil donjon, masquer en instance, clics sur les blocs en combat ; aucune erreur Lua.
