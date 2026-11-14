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
- **D. Remise à zéro de la session** : Ctrl + clic (ou menu) repart de zéro pour la session et l'or par heure ; une ligne d'aide dans l'infobulle.

## Guilde (choix validés le 14/11, à coder dans le lot Social)
Infobulle actuelle : nom de la guilde, puis les membres en ligne (nom, niveau, zone, couleur de classe), 20 lignes au plus. À ajouter, chacun avec sa case à cocher : message du jour, compteur en-tête (en ligne sur total), rang du membre, note publique (souvent le métier). Deux colonnes, celles de l'infobulle du jeu : à gauche niveau, nom et rang, à droite note et zone. Mode streamer : noms masqués comme aujourd'hui.

## Blocs à voir ensuite
Ordre à choisir avec Braincell1980. Social d'abord (guild, friends, mail, loot, group, whispers), puis Personnage, Progression, Monde, Système, Forever.
