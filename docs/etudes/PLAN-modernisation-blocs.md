# Moderniser les blocs, un par un (plan ouvert le 14 novembre 2026, Sonnet 5.5)

Demande de Braincell1980 (14/11) : améliorer tous les blocs avec des options pratiques. Méthode : un bloc à la fois, on brainstorme, il valide ou non, on écrit ici, on code, zip de test, puis le bloc suivant. Rien n'est codé tant que la section du bloc n'est pas validée.

Garde-fous (notes du 12/11 et règles de CLAUDE.md) : chaque option coûte des textes à traduire en 4 langues, de l'aide et des tests ; on ne recode pas ce que le jeu offre ; les profils et exports existants restent valides (nouveaux réglages avec valeur par défaut = l'ancien comportement) ; le mode streamer masque noms et montants dans toute nouvelle infobulle ; pas de couleur seule (signes + / - ou texte).

Inventaire (14/11, 46 blocs déclarés un par un ; les métiers sont créés autrement) : 16 blocs sans option (regen, talents, pet, longBuffs, corpse, camping, ammo, reagents, goldSession, guild, mail, loot, group, streamer, serverTime, subzone, hearthstone) ; 4 sans infobulle (time, serverTime, zone, subzone). Social est la catégorie la plus pauvre.

Autres idées déjà validées pour étude (14/11) : Amis, infobulle enrichie comme la Guilde ; clic réglable et réglage « nombre seul » (notes Broker_Everything) ; changer en un clic l'ensemble d'équipement, la difficulté, le pistage ou le titre (à vérifier en combat) ; petits ajouts de la sonde (Compréhension par numéro avec sa description, honneur d'hier, durabilité dans les sacs) ; tableau des personnages (Alts, notes SimplePanel).

## Or (validé le 14/11, pas encore codé ; sur `next`, nouveauté)
Aujourd'hui : 4 options (format, icônes, arrondi, séparateur) ; infobulle avec gain de la session, or par heure, historique de 7 jours, or par personnage et total ; clic = sacs, Maj + clic = copie dans le chat ; historique figé à 7 jours (`Core.lua`) ; la session repart à la connexion, sans remise à zéro.
- **A. Choisir l'infobulle** : quatre cases (session, or par heure, historique, personnages), toutes cochées par défaut.
- **B. Total du compte** : liste « Montrer : ce personnage / total des personnages ». Décidé le 14/11 : le total ne compte que les personnages de **ta faction et de ton serveur** (l'or ne passe pas d'un serveur à l'autre) ; l'infobulle ne montre que ceux-là. `ns.sv.chars` ne garde que l'or et la classe : on y ajoute la faction (`UnitFactionGroup("player")`) et le royaume (`GetRealmName()`) à la connexion. Un personnage ancien reste exclu de tous les totaux jusqu'à sa prochaine connexion (décidé le 14/11). Sur Forever il n'y a pas de royaume d'après le code (données rangées sous le nom complet, `ns.FullCharName`) : le filtre par serveur n'y change rien (tous les personnages ont la même étiquette) et ne compte que là où des royaumes existent ; à vérifier en jeu. Les autres personnages gardent la dernière valeur vue à leur connexion.
- **C. Historique de 7, 14 ou 30 jours** : liste ; défaut 7 (ancien comportement). Le nettoyage de `goldHistory` suit le réglage ; les anciens profils gardent 7.
- **D. Remise à zéro de la session** : Ctrl + clic (ou menu) repart de zéro pour la session et l'or par heure ; une ligne d'aide dans l'infobulle. Action commune avec l'XP (voir XP, idée C).

## Sacs (validé le 14/11, pas encore codé)
Aujourd'hui : une option (libres / total, libres, utilisés / total), couleur par seuils, barre de progression ; infobulle avec chaque sac, les sacs de métier à part et la valeur du bric-à-brac gris ; le total ne compte que les sacs qui prennent tout (`GeneralBagSlots`). Écarté : vendre le bric-à-brac d'un clic (le jeu l'offre peut-être déjà chez le marchand, non vérifié ; règle « ne pas recoder ce que le jeu offre »).
- **A. Choisir l'infobulle** : trois cases (détail de chaque sac, sacs de métier, valeur du bric-à-brac), cochées par défaut.
- **B. Compter les sacs de métier** : case, décochée par défaut (comportement actuel) ; cochée, ils entrent dans le total et la barre.
- **C. Valeur du bric-à-brac dans le bloc** : case, décochée par défaut ; ajoute la valeur du gris à côté des places. Le prix n'est connu qu'une fois l'objet en cache : afficher seulement ce qui est connu.
- **D. Alerte quand c'est plein** : le bloc se met en évidence quand il reste peu de places (seuils existants) ; mécanisme d'alerte du bloc, et respect du réglage « moins d'animations » (pas de clignotement). Case décochée par défaut.

## Durabilité (validé le 14/11, pas encore codé)
Aujourd'hui : une option (pièce la plus abîmée ou moyenne), seuils, barre ; infobulle avec chaque pièce équipée, les objets abîmés des sacs et le coût de réparation (`RepairCost`).
- **A. Choisir l'infobulle** : trois cases (pièces équipées, objets des sacs, coût de réparation), cochées par défaut.
- **B. Coût de réparation dans le bloc** : case, décochée par défaut ; ajoute le coût à côté du pourcentage. Mode streamer : montant masqué.
- **C. Alerte sous un seuil** : le bloc se met en évidence quand une pièce passe sous le seuil ; même alerte commune que les Sacs (voir « Alerte commune »).
- **D. Seulement les pièces abîmées** : case, décochée par défaut ; l'infobulle cache les pièces à 100 % et trie les plus usées en premier.

## XP (validé le 14/11, pas encore codé)
Aujourd'hui : deux options (format, bonus de repos), barre ; infobulle avec niveau, XP actuelle, reste, repos, XP de la session, XP par heure et temps avant le niveau suivant ; pas de clic.
- **A. Choisir l'infobulle** : quatre cases (niveau, repos, session, rythme et temps restant), cochées par défaut.
- **B. Temps restant dans le bloc** : case, décochée par défaut ; calculé sur la session, rien affiché tant que la session est trop courte (comme l'infobulle).
- **C. Session remise à zéro, commune** : une seule action partagée avec l'Or (la session `Tools.session` sert aux deux) : Ctrl + clic remet à zéro la session (XP, or, par heure) ; ligne d'aide dans les infobulles. À coder une fois (voir l'Or, idée D).
- **D. XP des quêtes à rendre** : case, décochée par défaut ; l'XP des quêtes terminées mais pas rendues, vue sur la capture d'un autre addon (14/11). Fonctions du jeu à vérifier sur Forever avant de coder (`forever_api_check.py`, forever-lint).

## Alerte commune (décidé le 14/11, pour Sacs et Durabilité, puis d'autres blocs)
Une seule alerte réutilisable, pas une par bloc : une case « Alerte » dans le bloc, qui s'appuie sur les seuils déjà en place et sur le mécanisme `alertOnShow`. Elle respecte le réglage « moins d'animations » (la mise en évidence ne clignote pas) et ne repose pas sur la couleur seule. À coder une fois, dans le premier lot qui en a besoin, puis à brancher bloc par bloc.

## Guilde (choix validés le 14/11, à coder dans le lot Social)
Infobulle actuelle : nom de la guilde, puis les membres en ligne (nom, niveau, zone, couleur de classe), 20 lignes au plus. À ajouter, chacun avec sa case à cocher : message du jour, compteur en-tête (en ligne sur total), rang du membre, note publique (souvent le métier). Deux colonnes, celles de l'infobulle du jeu : à gauche niveau, nom et rang, à droite note et zone. Mode streamer : noms masqués comme aujourd'hui.

## Blocs à voir ensuite
Ordre à choisir avec Braincell1980. Social d'abord (guild, friends, mail, loot, group, whispers), puis Personnage, Progression, Monde, Système, Forever.
