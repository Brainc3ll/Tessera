# Projet : adapter les dispositions du mode Édition (Blizzard / FlareUI)

État : **codé pour la 1.0.0-rc3** (11 octobre 2026), à tester en jeu. Nom de disposition limité à 30 caractères (mesuré en jeu). FlareUI remet ses cadres à leur place par défaut dans une copie (testé en jeu) : Tessera prévient avant.

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

## Améliorations retenues

1. **Ne décaler que ce qui gêne vraiment** : comparer la place des barres Tessera avec celle de chaque élément du mode Édition, et ne décaler que ceux qui se superposent, du minimum nécessaire (barre en bas : remonter ce qui est accroché en bas, barres d'action, barre d'XP, sacs ; barre en haut : descendre ce qui est en haut, minicarte, buffs). Le reste ne bouge pas.
2. **Montrer avant d'appliquer** : la question liste ce qui va bouger (« Barre d'action 1, Barre d'action 2, barre d'XP : remontées de 24 px »).
3. **Réutiliser la copie** créée par Tessera pour la même disposition d'origine et la même disposition Tessera, plutôt que d'en créer une nouvelle (« Tessera 2 », « Tessera 3 »…) : liste propre, limite du jeu respectée.
4. **Bouton « Revenir à ma disposition »** dans les options de Tessera : réactive l'originale en un clic.
5. **Lier la copie à la disposition Tessera** : en changeant de disposition ou de profil Tessera, proposer de basculer la disposition du mode Édition qui va avec, ou de revenir à l'originale.
6. **Faire le ménage** : Tessera propose de supprimer les copies qu'il a créées, et seulement celles-là (voir « Sécurité du ménage »).
7. **Vérifier et revenir en arrière** : après l'enregistrement, vérifier que la copie est active et les éléments au bon endroit ; en cas d'échec, réactiver l'originale et le dire.
8. **Même type de disposition** que l'originale (compte ou personnage).
9. **Résolution ou échelle changée** : proposer de recalculer (voir « Résolutions et échelles »).
10. **Rapport de bug** : `/tessera bug` indique la disposition active du mode Édition et s'il s'agit d'une copie Tessera.

## Sécurité du ménage

Un joueur peut créer lui-même une disposition qui porte exactement le nom d'une copie Tessera. Tessera ne doit **jamais** la supprimer :

- Tessera ne reconnaît pas ses copies à leur nom, mais à une **empreinte** enregistrée au moment de la création (dans ses variables sauvegardées) : nom, type (compte / personnage) et contenu exact de la disposition (positions de chaque élément).
- Avant de supprimer, Tessera recalcule l'empreinte : si la disposition n'existe plus, a été modifiée, ou ne correspond pas à ce que Tessera a enregistré, elle est **laissée intacte** (une copie modifiée par le joueur devient la sienne).
- Jamais de suppression sans confirmation, avec la liste exacte des dispositions concernées ; jamais la disposition active ; jamais une disposition que Tessera n'a pas créée lui-même.

## Résolutions et échelles

La fonction doit marcher à toutes les résolutions et à toutes les échelles d'interface, ce qui est difficile à tester entièrement en jeu :

- **Calculs en unités de l'interface**, à partir de la taille réelle des barres Tessera et des éléments au moment de l'application, jamais avec des valeurs en pixels écrites en dur.
- **Tests automatiques** sur une série de résolutions et d'échelles simulées (1280 × 720 à 3840 × 2160, échelles 0,64 à 1,15, écrans larges et ultralarges), pour vérifier les calculs sans dépendre des tests en jeu.
- **Vérification en jeu après application** : Tessera mesure le résultat réel. S'il reste une superposition, ou si un élément sort de l'écran, il le **signale par un message** (et propose de revenir à l'originale) plutôt que de supposer que tout va bien.
- En cas de doute (résolution ou échelle inhabituelle, autre interface détectée), le message avant application le dit clairement.

## Interfaces testées et avertissement

- La fonction sera testée sur :
  - l'interface de base de Blizzard, dispositions « Moderne » et « Classique » ;
  - l'interface de base de FlareUI, sans modification.
- Avec une autre interface (ElvUI, EllesmereUI, etc.), **des résultats inattendus peuvent survenir** : ces interfaces déplacent ou remplacent les éléments de Blizzard à leur façon.
- Cet avertissement doit apparaître :
  - dans le message affiché avant de créer la copie (quand une autre interface est détectée, le dire clairement) ;
  - dans l'aide et l'infobulle de la fonction ;
  - dans la description CurseForge / le README, au moment de la sortie de la fonction.
- Plus tard : Braincell1980 testera les interfaces populaires ; la liste des interfaces testées sera alors complétée.

## Relevé du 11 octobre 2026 (interface de Blizzard, disposition perso « Modern++ », 1920 × 1080)

- **`C_EditMode` est complet sur Forever** : GetLayouts, SaveLayouts, SetActiveLayout, IsValidLayoutName, GetEditModeDefaultLayout, ConvertLayoutInfoToString / ConvertStringToLayoutInfo (le texte d'import / export du jeu). La copie de disposition est donc faisable avec les fonctions du jeu.
- **Limite** : 5 dispositions par type (compte, personnage) (`EditModeMaxLayoutsPerType = 5`).
- `activeLayout` compte d'abord les dispositions de base : « Modern++ » était l'index 4 alors que la liste n'en contenait qu'une. Le relevé ne savait pas en tenir compte (corrigé dans la version debug suivante, qui teste aussi la longueur maximale des noms).
- **Bas de l'écran** : barre d'action principale de y = 2 à 47, barre d'XP de 51 à 68, barres en bas à gauche et à droite de 72 à 117, menu et sacs de 2 à 47, gryphons (« MainActionBarEndCap ») de 0 à 95. Une barre Tessera de 24 px collée en bas recouvre donc la barre principale, le menu, les sacs et les gryphons ; il faudrait remonter tout ce bloc d'environ 26 px. Barre de cast (158), discussion (153) et barre de droite (182) ne gênent pas.
- **Haut de l'écran** : minimap (x 1647 à 1920, jusqu'en haut), buffs (x 1265 à 1665, haut à 1070), compteur de dégâts (x 0 à 400, jusqu'en haut). Une barre pleine largeur en haut les recouvre.
- FlareUI n'était pas chargé pendant ce relevé : à refaire avec FlareUI.

## Relevé du 11 octobre 2026, 2ᵉ passage (FlareUI 2.0.3 + « Modern++ »)

- **Dispositions de base** : 3 (Moderne, Classique, Manette). `activeLayout` = 3 + le rang de la disposition perso.
- **Accroches en bas** (dans « Modern++ ») :
  - menu (MicroMenu) : BOTTOM de l'écran, +116,5 / +6 ;
  - barre d'action principale : accrochée au menu (BOTTOMRIGHT sur BOTTOMLEFT du menu) ; sacs : accrochés au menu ;
  - gryphon gauche : accroché à la barre principale ; **gryphon droit : position fixe** (TOPLEFT de l'écran, 1516,5 / -987) ;
  - barres en bas à gauche / à droite et barres d'XP : « position par défaut » (le jeu les place lui-même au-dessus de la barre principale) ;
  - barres de familier, de posture et de totems : accrochées aux barres du bas.
  - Conséquence : pour une barre Tessera de hauteur H en bas, remonter le menu de H et le gryphon droit de H ; le reste suit par ses accroches. Les barres « par défaut » devraient suivre : à vérifier en jeu.
- **Noms** : IsValidLayoutName accepte tout (même un nom vide et 64 caractères) ; il ne vérifie donc pas la longueur. Choix prudent : un nom court, « Ma dispo (Tessera 1) ».
- **Disposition de base « Moderne »** (3ᵉ passage) : tout est en « position par défaut » ; menu au bas de l'écran (+116,5 / +6), barre principale et sacs accrochés au menu, gryphon gauche à la barre principale, **gryphon droit accroché aux sacs** (dans « Modern++ », le joueur l'avait déplacé, d'où sa position fixe). Dans « Moderne », remonter le menu suffit donc pour tout le bas.
- **FlareUI 2.0.3** (relevé v3, « Modern++ ») :
  - « FlareEditMode » ressemble à LibEditMode : AddFrame, GetActiveLayoutName, GetFrameDefaultPosition, RegisterCallback, layoutCache. Ses cadres apparaissent dans le mode Édition de Blizzard, mais **leurs positions sont enregistrées par FlareUI lui-même** (FlareUI_DB), probablement par nom de disposition. Une copie « Modern++ (Tessera 1) » risque donc de remettre les cadres FlareUI à leur place par défaut : à vérifier (structure de FlareUI_DB), et à discuter avec Malkav plutôt que d'écrire dans les réglages de FlareUI.
  - **En bas**, FlareUI n'a aucun cadre collé au bord : les barres d'action, le menu et les sacs sont ceux de Blizzard (barres du bas à y = 51, sans barre d'XP de Blizzard). Une barre Tessera en bas ne demande donc de décaler que la disposition de Blizzard, comme sans FlareUI. Totems (y = 134) et jets de butin (173) ne gênent pas pour une barre de 24 px.
  - **En haut**, la barre d'XP de FlareUI est collée au bord (x 676 à 1244, y 1057 à 1079), les buffs en haut à droite (TOPRIGHT -260 / -3) et la minimap au coin. Une barre Tessera en haut demanderait de décaler des cadres FlareUI : seulement après accord ou API de FlareUI.

## Étapes prévues

1. **Relevé en jeu** (commande de debug, comme pour l'héritage) : fonctions `C_EditMode` présentes sur Forever, structure d'une disposition (systèmes, ancrages, décalages), noms et limites, présence de LibEditMode ou d'un équivalent chez FlareUI.
2. **Schéma** à valider : quels éléments sont décalés, de combien, pour chaque disposition Tessera concernée.
3. **Code** : création de la copie, nom unique, décalage, activation, message, aide, infobulles, chaînes EN et FR.
4. **Tests** : tests automatiques (simulation de `C_EditMode`), puis test en jeu sur l'interface de base de Blizzard (« Moderne » et « Classique ») et sur FlareUI non modifié.
