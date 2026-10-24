# Bloc « Farm » : étude (24 octobre 2026)

Étude sans code. Idée de Braincell1980 : suivre un objet qu'on récolte, avec un objectif. Prévu pour la 1.2 (nouveaux blocs).

## Ce que le joueur voit

- Dans le bloc : l'icône de l'objet et `47 / 100`. Sans objectif : `47`.
- Plusieurs objets : le bloc reste petit. Il montre les 1 à 3 premiers objets côte à côte (`47[icône]  12[icône]`, nombre au choix), ou un résumé (`5 objets · 2 objectifs atteints`). Le détail va dans le panneau épinglé (ci-dessous), pas dans un bloc qui s'allonge.
- Infobulle, pour chaque objet :
  - dans les sacs (et en banque si le jeu le permet, voir « Ce que je ne sais pas ») ;
  - récoltés pendant la session : `+23` ;
  - rythme : `≈ 40 / heure` ;
  - temps restant avant l'objectif : `≈ 1 h 20` (le point fort pour ceux qui jouent peu : « est-ce que je finis ce soir ? ») ;
  - valeur chez un marchand : `47 × 1 pa 25 pc`.
- Objectif atteint : la valeur passe au vert et le bloc clignote une fois (le système d'alertes de Tessera existe déjà).
- Clic gauche : épingle ou détache le panneau (ouvrir les sacs, le jeu le fait déjà avec sa touche). Maj + clic : copie dans le chat, comme les autres blocs (« Tissu de laine : 47 / 100 »).
- Aucun objet choisi : le bloc dit « Choisir un objet » ; un clic ouvre son réglage.

## Le panneau épinglé (idée de Braincell1980)

Un farmeur veut voir ses chiffres en direct, sans survoler le bloc. Un bloc qui s'allonge avec beaucoup d'objets serait une mauvaise idée.
- Un clic sur le bloc épingle un petit panneau collé au bloc : le contenu de l'infobulle, toujours visible, mis à jour en direct (à chaque changement des sacs ; rythme et temps restant toutes les quelques secondes).
- Une ligne par objet : icône, nom, `47 / 100`, `+23`, `≈ 40 / h`, `≈ 1 h 20`. Pas de limite à 5 objets : le panneau défile au-delà d'une dizaine.
- Le panneau suit le bloc, prend son style (cadre, police, taille du texte), se verrouille avec les blocs, se cache en combat si on le veut, et reste épinglé après un rechargement.
- Raccourci clavier (catégorie Tessera des touches du jeu) pour l'épingler sans souris : prêt pour la manette.
- **À généraliser** : « épingler l'infobulle » a du sens pour d'autres blocs (or de la session, FPS, réputation, temps de jeu). Construire le panneau pour tous les blocs, le Farm en premier. Plus de travail au départ, mais rien à refaire ensuite.
- Prototype : `/tes debug farm live` dans Tessera-dev (fenêtre sur laquelle on dépose des objets, mise à jour en direct).

## Choisir les objets

Trois façons, pour la souris, le clavier et la manette :
1. **Glisser un objet des sacs sur le bloc** (mode placement ou bloc déverrouillé) : le plus rapide à la souris. `GetCursorInfo()` donne l'objet tenu ; il existe dans l'API de Forever.
2. **« Choisir dans mes sacs »** dans les réglages du bloc : une liste des objets présents dans les sacs, avec icône et nom. Marche sans souris, donc prête pour la manette (règle de la 1.3).
3. **Taper le numéro de l'objet** (pour les joueurs qui le connaissent via un site de base de données) : en secours.

Pour chaque objet : objectif (facultatif), retirer, remonter / descendre dans la liste.

## Comment ça marche

- Compte : `C_Item.GetItemCount(id, includeBank)`, présent dans l'API de Forever et déjà utilisé par les blocs Composants et Camping. Mise à jour sur `BAG_UPDATE_DELAYED`, comme eux : aucun coût hors des changements de sacs.
- Récoltés pendant la session : on garde le compte de la connexion et on additionne **seulement les hausses**. Vendre ou détruire des objets ne fait pas baisser le « +23 ». Ranger en banque ne compte pas comme une perte si la banque est incluse.
- Rythme : récoltés ÷ temps de session (le temps de session existe déjà dans Tessera). Pas affiché avant 5 minutes et quelques objets, sinon les chiffres n'ont pas de sens.
- Noms et icônes : `C_Item.GetItemIconByID` répond tout de suite ; le nom peut arriver plus tard (le jeu le charge). En attendant, `#2592` puis le nom dès que le jeu l'envoie.
- Sauvegarde : les numéros d'objets et les objectifs, dans les réglages du bloc. Donc dans le profil, l'export et l'import, sans rien changer au format TESSERA2 (des nombres).
- Le compte de la session n'est pas sauvegardé : il repart de zéro à chaque connexion, comme l'or de la session.

## Ce qui existe déjà et sert de base

- Bloc **Objectif** (or ou niveau) : barre de progression, pourcentage, objectif atteint en vert.
- Bloc **Composants** : compte d'objets avec icônes côte à côte, alerte quand le stock baisse.
- Bloc **Or** : gain de la session.
- Temps de session, alertes, copie dans le chat, barre de progression.

Le bloc Farm assemble ces morceaux. Le plus gros travail neuf : la liste « Choisir dans mes sacs » et la gestion de plusieurs objets dans les réglages.

## Ce que je ne sais pas (à sonder en jeu avant de coder)

- **La banque.** Sur Retail, `GetItemCount(id, true)` compte la banque partout. Sur les clients Classic, il ne la compte parfois qu'après une visite à la banque pendant la session. Comportement de Forever inconnu : une commande de dev (`/tessera debug farm`, dans Tessera-dev) le dira ; `/tessera debug farm live` montre le direct.
- **Valeurs secrètes.** Aucune raison connue que le compte d'objets soit secret, mais Forever a surpris ailleurs : la même sonde le vérifiera.
- **Prix à l'hôtel des ventes.** Le jeu ne donne pas de prix sans fouiller l'hôtel des ventes. Seul un addon comme Auctionator les connaît. Je ne sais pas s'il existe sur Forever ni si son interface publique est la même que sur Retail. Pour la première version : prix marchand seulement.
- **Glisser sur le bloc.** Certains blocs ont une surface de clic par-dessus (lanceurs). Il faut vérifier que le dépôt d'un objet arrive bien au bloc. Si ça coince, la liste « Choisir dans mes sacs » suffit.

## Hors sujet pour la première version

- Plusieurs blocs Farm séparés : Tessera n'a qu'un bloc par sorte. Un seul bloc et son panneau épinglé couvrent le besoin. À revoir si les joueurs le demandent.
- Suivi par personnage de l'historique de farm, graphiques : plus tard si ça sert.

## Accessibilité et manette (règle de la 1.3, appliquée dès maintenant)

- Objectif atteint : couleur **et** une coche, pas la couleur seule.
- Choix des objets sans souris (liste des sacs), ordre de focus simple, bouton « Retour ».
- Texte deux fois plus gros : l'infobulle et le panneau restent lisibles (une ligne par objet, pas de tableau large ; le panneau défile).

## Charge de travail estimée

Bloc seul : moyenne, un peu plus que le bloc Objectif plus le bloc Composants. Le cœur (compte, session, rythme, temps restant) est court ; la liste des sacs et les réglages de plusieurs objets prennent l'essentiel. Avec les textes en deux langues, l'aide et les tests du simulateur : une à deux sessions de travail. Panneau épinglé pour tous les blocs : une à deux sessions de plus.
