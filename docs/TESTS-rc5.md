# Tests de la rc5 (jeudi 15 octobre)

Version à tester : **Tessera-1.0.0-rc5-test10.zip** (version de test : elle a les commandes `/tes test`).
Note chaque souci avec une capture et, s'il y a une erreur, le texte de l'erreur Lua.

## 0. Préparation (5 min)

- [ ] Jeu fermé : renommer `WTF`, `Cache` et `Interface` (dossier du client Forever) en `..._old`.
- [ ] Installer seulement Tessera (dossier `Interface/AddOns/Tessera`).
- [ ] En jeu, afficher les erreurs Lua : `/console scriptErrors 1` (sinon le jeu les cache).
- [ ] `/tes test` : la liste des commandes de test s'affiche dans la discussion.

## 1. Premier lancement, interface Blizzard seule (5 min)

- [ ] Fenêtre de bienvenue, visite rapide jusqu'au bout.
- [ ] Barre par défaut en haut, propre, aucune erreur.
- [ ] Bouton rond de la minicarte : clic = options, clic droit = verrouiller / déverrouiller.
- [ ] Si la barre couvre des cadres de Blizzard (barres d'action, minicarte…), Tessera propose de faire de la place dans le mode Édition.

## 1 bis. Visite rapide : les dispositions (3 min)

- [ ] Onglet Aide, « Visite rapide », étape 2 : les flèches < et > montrent chaque disposition tout de suite à l'écran, avec son nom et sa description.
- [ ] Quitter l'étape (Suivant, Retour ou la croix) sans garder : ta disposition revient.
- [ ] « Garder cette disposition » : elle reste, message dans la discussion.
- [ ] La disposition « Double barre » (ancien nom : Moderne Forever).

## 2. Les blocs (10 min) : `/tes test blocs`

Profil « Test » avec tous les blocs à vérifier (même vides). Pour chacun : survol, clic, Maj + clic.

- [ ] Durabilité : **coût de réparation** en bas de l'infobulle (il faut un objet abîmé : prendre quelques coups ou mourir une fois).
- [ ] Statistiques : la statistique affichée correspond à ta classe ; dans l'infobulle, **hâte et toucher** apparaissent-ils ? (s'ils manquent, c'est que Forever ne les donne pas : à noter).
- [ ] Clic droit sur Statistiques, « Statistique affichée » : en changer, le bloc suit.
- [ ] Régénération de mana : valeur hors combat, et en combat elle change (classe à mana).
- [ ] Butin du groupe : « Seul » ; si possible, en groupe : mode de butin, seuil, et clic = /roll.
- [ ] Blocs Forever : Héritage, Compréhension, Camping, Honneur, Compétences d'armes, métiers : infobulle et clic (ouvre la bonne fenêtre).
- [ ] Volume : molette = volume.

## 3. Noms des blocs en mode placement (5 min)

- [ ] `/tes test compacte` : les noms sous les blocs ne se chevauchent plus et ne sortent pas de l'écran ; un nom trop long est raccourci (« Composants de… ») ou masqué (le survol le montre).
- [ ] `/tes test colonne` : les noms sont à droite des blocs, dans l'écran.
- [ ] Verrouiller : les noms disparaissent.

## 3 bis. Croix, flèches et remplacement (5 min)

- [ ] Déverrouiller, survoler un bloc : une croix en haut à droite, des flèches en haut à gauche ; elles disparaissent quand la souris s'en va, pendant un glisser et en verrouillant.
- [ ] Sous le bandeau, un cadre « Survole un bloc... » ; au survol d'un bloc, il montre ce qu'on peut en faire (plus d'infobulle sur la croix et les flèches). Bandeau déplacé en bas de l'écran : le cadre passe au-dessus. Glisser le cadre déplace le bandeau.
- [ ] La croix masque le bloc ; Ctrl + Z le remet.
- [ ] Les flèches : la liste montre d'abord les blocs masqués, puis les blocs affichés. Un bloc masqué prend la place exacte (même apparence, rien ne bouge) ; un bloc affiché échange sa place.
- [ ] Un espace (disposition « Vitraux de Hurlevent » par exemple) : flèches, choisir un bloc : l'espace disparaît, le bloc prend sa place ; Ctrl + Z ramène l'espace.
- [ ] Remplacer le premier bloc (le plus à gauche) d'une barre collée en haut et étirée : la barre reste collée et sur toute la largeur.
- [ ] Simple clic droit sur un bloc en mode placement : le menu rapide ; Alt + clic droit aussi.
- [ ] Bloc d'un groupe figé : ni croix ni flèches.
- [ ] Onglet Aide : le sujet « Remplacer des blocs ».

## 4. Infobulles (3 min)

- [ ] `/tes test infobulles` : les infobulles des blocs sont plus grandes et n'apparaissent qu'en tenant Alt (appuyer / relâcher Alt au-dessus d'un bloc).
- [ ] Les autres infobulles du jeu (sorts, objets) gardent leur taille.
- [ ] `/tes test infobulles` à nouveau : tout revient comme avant.
- [ ] Onglet Général, section Infobulles : les mêmes réglages, à la main.

## 5. Combat (10 min) : le plus important

Contre un ou plusieurs mobs, avec la barre de test (`/tes test blocs`) :

- [ ] Pendant le combat : les blocs sont figés (impossible de les déplacer).
- [ ] Survol en combat : les infobulles s'affichent.
- [ ] Clics en combat : sacs, personnage, carte, métiers, Héritage… s'ouvrent sans erreur.
- [ ] Ouvrir et fermer les options en combat.
- [ ] Un bloc réglé sur « Masquer en combat » disparaît puis revient.
- [ ] Raccourci « afficher / masquer tous les blocs » en combat : le masquage attend la fin du combat.
- [ ] Après le combat : aucune erreur, tout revient normal.

## 6. Styles et FlareUI (10 min)

- [ ] Onglet Apparence : passer par les styles (Blizzard Moderne, Classique, les Carrés, Épuré, Transparent).
- [ ] Installer FlareUI, `/reload` : la fenêtre qui propose le style FlareUI apparaît (une seule fois).
- [ ] Style FlareUI : `/tes test flare`, puis comparer la police des blocs avec la **barre d'XP de FlareUI** (Arial Narrow).
- [ ] Avec FlareUI : pas de bouton rond, Tessera est dans le sac d'addons de FlareUI.

## 6 bis. Nouveaux styles (5 min)

- [ ] Onglet Apparence : Pierre runique : seulement le texte, blanc et gris, aucune couleur (or, durabilité...), bords argentés ; les lanceurs gardent une icône grise.
- [ ] Grimoire, Parchemin, Arcanes : lisibles ? (Parchemin : les valeurs en couleur restent-elles lisibles sur le fond clair ?)
- [ ] Revenir à un autre style : les icônes et les couleurs reviennent.
- [ ] Sans FlareUI / ElvUI / EllesmereUI : leurs styles sont dans la liste, marqués « (sans l'addon) » ; en choisir un écrit dans la discussion ce qui change.
- [ ] Avec FlareUI installé : la fenêtre qui propose son style apparaît toujours (une seule fois).

## 7. DataBroker (5 min, si le temps)

- [ ] Installer Bazooka : la fenêtre « mode DataBroker » apparaît ; les blocs de Tessera sont dans Bazooka.
- [ ] Quitter le mode DataBroker : les blocs de Tessera reviennent.

## 8. Instance (si le temps)

- [ ] Onglet Profils : choisir un « Profil en donjon et en raid ».
- [ ] Entrer dans un donjon : ce profil se charge ; quelques clics en combat ; en sortant, le profil normal revient.

## 9. Fin

- [ ] `/tes test fin` : retour à ton profil, le profil « Test » est supprimé.
- [ ] Une erreur ou un souci : `/tessera bug`, copier le rapport, et me l'envoyer avec la capture.
- [ ] Remettre tes anciens dossiers `WTF`, `Cache`, `Interface` si tu veux retrouver ta configuration.
