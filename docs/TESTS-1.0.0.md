# Tests de la 1.0.0 (avant le 22 octobre)

Version testée : **Tessera-1.0.0-test4.zip**, puis **Tessera-1.0.0-test10.zip**, puis **Tessera-1.0.0-test12.zip**, puis **Tessera-1.0.0-test16.zip** pour les points ci-dessous. Le 16/10, Braincell1980 valide tout le reste à 99 % :
nouveau joueur, Styles mélangés, barre d'XP de FlareUI, bloc Date et dispositions, deuxième rangée,
changelog trié, et le nouveau build de WoW Forever du 16/10 (sans FlareUI, cassé par ce build).

## Test6 à test10 : validées le 16/10

Devant / derrière (bandeau, question au verrouillage, onglet Apparence, bouton sous la fenêtre du mode Édition), Chemin de ronde, style gardé en appliquant une disposition, aide et visite rapide, `/tessera preview forever` retirée.

## Test11 et test12 : validées le 16/10

Bouton du mode Édition qui respire, question seulement après avoir utilisé le bouton, plus de « n/d » après un chargement (bateau, pierre de foyer).

## Test13 à test16 : validées le 17/10

Noms complets de WoW Forever (Or, profils, jeu de règles), police de FlareUI, raccourcis « Cadre / Texte de tous les blocs », style FlareUI (lignes bronze, barre de progression texturée), couleurs des seuils.

## Publiée en rc6 le 17/10

Tout ce qui précède est dans la 1.0.0-rc6 (GitHub, CurseForge, Wago).

## Test17 et test18 = 1.0.0-rc6-hotfix (5 min)

- [x] (test17) Poser Cuisine (ou un autre bloc toujours visible) au bout de la deuxième rangée, verrouiller : elle garde sa taille, centrée sous la barre, au lieu de s'étirer sur toute la largeur.
- [x] (test17) Coller le groupe BugSack + Mémoire des addons au bout de la barre du haut : rien ne se superpose, la deuxième rangée descend sous Mémoire des addons.
- [x] (test17) Bloc Mémoire des addons : 3-4 Mo au repos après un rechargement.
- [ ] (test18) Même chose après quelques minutes de mode placement (déplacer des blocs, des groupes) : la mémoire de Tessera ne monte plus à 43 Mo.

## Reste à faire

- [ ] Instance : profil donjon, masquer en instance, clics sur les blocs en combat ; aucune erreur Lua.
