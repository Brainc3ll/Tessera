# Projet : adapter les dispositions du mode Édition (Blizzard / FlareUI)

État : **idée validée, pas encore codée** (11 octobre 2026). À reprendre après le relevé décrit plus bas.

## Le besoin

Certaines dispositions Tessera prennent de la place là où se trouvent des éléments de l'interface : par exemple une barre des tâches collée en bas (« Vitraux de Hurlevent », « Rosace de la cathédrale ») passe sous la première rangée de barres d'action.

Plutôt que de demander au joueur de tout déplacer à la main, Tessera propose de créer une **copie** de sa disposition du mode Édition, avec les éléments décalés.

## Le comportement voulu

1. Le joueur a sa disposition du mode Édition, par exemple « Ma dispo ».
2. Il applique une disposition Tessera qui a besoin de place.
3. Tessera **propose** (jamais automatiquement) de créer une copie : « Ma dispo (Tessera 1) ».
   - Si « Ma dispo (Tessera 1) » existe déjà : « Ma dispo (Tessera 2) », etc.
   - Variante discutée : mettre le nom de la disposition Tessera, par exemple « Ma dispo (Tessera : Vitraux de Hurlevent) », avec un numéro si le nom existe déjà. À trancher, en tenant compte de la longueur maximale d'un nom de disposition dans le jeu (à vérifier).
4. Dans la copie, les éléments qui seraient recouverts sont décalés (par exemple les barres d'action remontées de la hauteur de la barre Tessera).
5. Tessera active la copie.
6. **« Ma dispo » n'est jamais modifiée** : le joueur peut y revenir à tout moment avec la liste des dispositions du mode Édition.
7. Un message prévient le joueur, par exemple : « Ta disposition « Ma dispo » n'a pas été modifiée. Tessera a créé « Ma dispo (Tessera 1) », où tes barres d'action sont remontées pour laisser la place à la barre Tessera. Tu peux revenir à l'ancienne à tout moment dans le mode Édition. »
8. L'aide (sujet « Placer les blocs » ou un sujet dédié) et les infobulles concernées l'expliquent aussi.

## Faisabilité (à confirmer)

- **Éléments de Blizzard (barres d'action, cadres)** : probablement faisable. Le jeu moderne permet aux addons de lire les dispositions du mode Édition, d'en enregistrer et d'en activer (espace de noms `C_EditMode` : lecture des dispositions, enregistrement, activation). Une bibliothèque publique (LibEditModeOverride) et des addons le font déjà. **À vérifier sur WoW Forever** avec un relevé.
- **FlareUI** : incertain. Si FlareUI s'appuie sur le mode Édition (ou sur une bibliothèque comme LibEditMode), même principe. Sinon, Tessera n'a pas de moyen propre de déplacer ses cadres : regarder le code de FlareUI 2.0, et au besoin demander à Malkav.

## Limites connues

- Impossible en combat (le jeu l'interdit) : refuser avec un message, ou attendre la fin du combat.
- Les dispositions de base (« Moderne », « Classique ») ne sont pas modifiables, mais on peut les copier comme le fait Blizzard : la copie fonctionne dans tous les cas.
- Le jeu limite le nombre de dispositions personnalisées : si la limite est atteinte, prévenir et ne rien créer.
- Modifier le mode Édition depuis un addon peut provoquer des erreurs d'interface protégée (« taint ») : ne le faire que sur un clic du joueur, hors combat, et tester soigneusement.
- La copie reflète l'état au moment de sa création : si le joueur change ensuite « Ma dispo », la copie ne suit pas.

## Étapes prévues

1. **Relevé en jeu** (commande de debug, comme pour l'héritage) : fonctions `C_EditMode` présentes sur Forever, structure d'une disposition (systèmes, ancrages, décalages), noms et limites, présence de LibEditMode ou d'un équivalent chez FlareUI.
2. **Schéma** à valider : quels éléments sont décalés, de combien, pour chaque disposition Tessera concernée.
3. **Code** : création de la copie, nom unique, décalage, activation, message, aide, infobulles, chaînes EN et FR.
4. **Tests** : tests automatiques (simulation de `C_EditMode`), puis test en jeu avec et sans FlareUI.
