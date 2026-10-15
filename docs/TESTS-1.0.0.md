# Tests de la 1.0.0 (avant le 22 octobre)

Version à tester : **Tessera-1.0.0-test3.zip** (version de test : elle a les commandes `/tes test`).
C'est la future 1.0.0 : elle se teste comme un nouveau joueur qui découvre l'addon.
Note chaque souci avec une capture et, s'il y a une erreur, le texte de l'erreur Lua.

## 0. Préparation (5 min)

- [ ] Jeu fermé : renommer `WTF`, `Cache` et `Interface` (dossier du client Forever) en `..._old`.
- [ ] Installer seulement Tessera (dossier `Interface/AddOns/Tessera`).
- [ ] En jeu, afficher les erreurs Lua : `/console scriptErrors 1`.

## 1. Comme un nouveau joueur (10 min)

- [ ] Fenêtre de bienvenue : tout se comprend sans connaître l'addon.
- [ ] Visite rapide jusqu'au bout, essayer deux dispositions, en garder une.
- [ ] Onglet À propos > Historique : la 1.0.0 commence par « Première version stable » et se lit bien pour quelqu'un qui n'a pas connu les versions de test.
- [ ] Onglet Aide > WoW Forever : plus de « bêta » ; la phrase dit que ces systèmes n'ont pas encore de documentation officielle.
- [ ] Infobulle du bloc Honneur : « Les rangs JcJ seront ajoutés dans une prochaine version. »

## 2. Mode démo : Styles mélangés (5 min)

- [ ] Mode démo, flèche `>` jusqu'après le dernier style : le bandeau affiche « Styles mélangés (1/4) ».
- [ ] Chaque colonne a son propre style, et son nom est dans le titre de la colonne (« Personnage : Grimoire »…).
- [ ] Les 4 étapes : aucune colonne cassée, aucun titre coupé, textes lisibles.
- [ ] Continuer `>` : retour au premier style, titres des colonnes sans nom de style.
- [ ] `<` depuis le premier style : on arrive sur « Styles mélangés (4/4) ».
- [ ] Quitter la démo : ta disposition et ton style reviennent.

## 3. Barre d'XP de FlareUI (5 min)

- [ ] Partir de zéro avec FlareUI, valider le style FlareUI proposé, PUIS activer la barre d'XP de FlareUI : la barre de Tessera se place sous la barre d'XP sans /reload.
- [ ] Désactiver la barre d'XP : la barre de Tessera remonte.

## 3 bis. Bloc Date et dispositions (5 min) : nouveau dans la test3

- [ ] Onglet Blocs : ajouter le bloc Date ; sous-onglet Texte : essayer les 6 formats (noms des jours et mois en français, « Jeu. 15 oct. »).
- [ ] Date du serveur : même date que la locale (sauf autour de minuit) ; infobulle : la date complète.
- [ ] Clic sur le bloc : le calendrier s'ouvre.
- [ ] Dispositions Vitrail de Hurlevent, Rosace, Verger de Tirisfal, Gnomeregan : la date est à côté de l'horloge.
- [ ] « Autour des gryphons » : deux rectangles nets, bords bien droits ; à droite, heure et date dans le coin.
- [ ] Mode démo : la date est dans la colonne Monde.

## 4. Instance (si le temps)

- [ ] Profil donjon, masquer en instance, clics sur les blocs en combat.

## 5. Fin

- [ ] Aucune erreur Lua pendant tout le test.
