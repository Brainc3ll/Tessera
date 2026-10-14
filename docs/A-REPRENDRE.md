# À reprendre (état au 13 octobre 2026, soir)

## Calendrier jusqu'à la 1.0.0 (validé le 13/10)
La bêta de WoW Forever ferme le **22 octobre** : après, plus aucun test en jeu avant la sortie.
Tout ce qui part le 4 novembre doit avoir été testé en jeu avant le 22.
- **15-16/10 : rc5** (bugs d'étiquettes, retours de la rc4, blocs Forever sans erreur si une info disparaît). Tests de Braincell1980 à partir du jeudi 15.
- **16-19/10 :** tests larges (instance, raid, combat, groupe ; Blizzard seul, FlareUI, Bazooka).
- **19-20/10 : version candidate 1.0.0** ; **20-21/10 :** dernier test de cette version exacte (c'est elle qui part le 4/11, sans retouche).
- **Avant le 22, en jeu :** captures en client anglais, vidéo du mode placement (GIF), relevés debug utiles plus tard (ex. jeu de règles pour l'or filtré).
- **22/10 - 3/11 : hors jeu seulement** : pages CurseForge / Wago (texte « sortie », sans « bêta »), résumé 1.0.0 du changelog, post Reddit, messages Discord.
- **4/11 :** publication de la 1.0.0 et promotion ; garder de la marge pour une 1.0.1 rapide si la sortie change des identifiants.
- Pas avant la 1.0.0 (en 1.1) : nettoyage du code, styles pour tous, zones, bloc voyage, recharges de métiers, or filtré, fondu des barres.

## Versions
- **1.0.0-rc3** : publiée (GitHub + CurseForge), traductions envoyées.
- **1.0.0-rc4** : publiée le 13/10 (GitHub, CurseForge, Wago) : logo HD, « À propos » à la première personne, section Infobulles (taille, Alt), coût de réparation, blocs Régénération de mana / Statistiques / Butin du groupe. À vérifier en jeu par Braincell1980 : coût de réparation, hâte/toucher, butin en groupe.
- **1.1.0-alpha1** (autres versions du jeu : Classic Era, BC Classic, MoP Classic, jeu actuel ; pas Forever) : branche `multi-versions`, zip de test donné, en attente des tests de Braincell1980. Publication en Alpha seulement pour les versions testées. Si un jour elle est fusionnée dans `main` : retirer le suffixe « -forever » du nom du zip (voulu par Braincell1980 tant que l'addon est Forever seul).

## Prochaines étapes proposées (ordre validé à confirmer)
1. Corriger les deux bugs d'étiquettes ci-dessous (version suivante). Wago est branché (X-Wago-ID dans le .toc, WAGO_API_TOKEN dans release.yml).
2. Nettoyage / allègement du code, seul, sans changement de comportement, compatibilité des profils intacte (outils de dev vers la version debug, regroupements, mesure mémoire avant/après).
3. Styles pour tout le monde (vraies images si l'interface est installée, version approchante sinon) + nouveaux styles d'interface (TukUI, GW2 UI, NDui, KkthnxUI, SpartanUI…).

## rc5 (en préparation, zip de test donné le 13/10, tests de Braincell1980 à partir du jeudi 15)
- Corrigé : étiquettes du mode placement (Compacte, Colonne à gauche) : plus de chevauchement ni de sortie d'écran, nom raccourci si la place manque.
- Blocs Forever et nouveaux blocs : testés contre un jeu qui change (`tools/fuzz_blocks.lua`), corrigés.
- Audit de l'API WoW (Ketho, comme les modérateurs de r/WoWUI) : 0 fonction obsolète, 0 globale inconnue ; anciens secours classiques retirés (la branche multi-versions les garde : conflits à prévoir si fusion). Tourne à chaque push (`tools/api_audit.py`).
- Placement : insertion d'un bloc seul entre deux blocs fusionnés ; plus d'accroche sur le côté d'une barre où pend sa deuxième rangée (bug signalé le 14/10 : bloc de la 2e rangée impossible à remettre). À vérifier en jeu (test5) ; vidéo du 14/10 analysée : la 2e rangée déplacée en entier perdait son accroche (devenait un groupe ordinaire, plus centré ni pleine largeur) : reposée contre sa barre, elle reste maintenant accrochée (test6).
- Nouvelle disposition « Moderne Forever » (demande du 14/10) : barre du haut de base + deuxième barre toujours affichée avec les blocs Forever (les blocs de la 2e rangée habituelle s'y ajoutent quand ils ont quelque chose à montrer). À tester (test6).
- Mode placement plus intuitif (demande du 14/10, après avoir cherché comment retirer le bloc Honneur) : une croix sur le bloc survolé le masque, des flèches le remplacent ; simple clic droit = menu rapide. Remplacement mis en avant : liste en deux parties (masqués / affichés), un espace peut être remplacé par un bloc (Ctrl + Z le ramène), le premier bloc d'une barre se remplace sans perdre le bord de l'écran ni l'étirement ; nouveau sujet d'aide « Remplacer des blocs ». À tester (test7).
- Commandes de développement retirées de l'addon (debug, sondes, test de formes, atelier) : elles sont dans `TesseraDev.lua`, hors dépôt (`/home/claude/tessera-dev/` dans la session), ajouté seulement aux zips de test avec `/tessera test` (blocs à vérifier, Compacte, Colonne, infobulles, flare, fin).
- Scénario donjon + combat ajouté au test automatique (le donjon ne pourra peut-être pas être testé en jeu).

## Déjà sur main pour la version suivante
- Aide : blocs masqués au départ, infobulle avec Alt, clic /roll du butin, « statistique affichée » ; liste des commandes avec /tessera help (à mettre dans le changelog de la prochaine version).
- Vérification automatique de la doc (`tools/check_docs.lua`) à chaque push et avant chaque publication ; guide `docs/RELEASE.md` réécrit ; règles du projet dans `CLAUDE.md`.

## À faire avec la rc5 : anciens blocs d'aide sur CurseForge (rappeler chaque étape à Braincell1980)
L'aide est maintenant découpée en petites clés (HELP_<SUJET>_<n>). Les deux anciens blocs
`HELP_TEXT` et `HELP_TEXT_BROKER` restent sur l'outil de traduction de CurseForge (l'envoi ne
supprime jamais rien) alors que l'addon ne les lit plus.
1. Publier la rc5 : les nouvelles petites clés partent sur CurseForge.
2. Regarder sur CurseForge (page Localization) si un traducteur a traduit `HELP_TEXT` ou
   `HELP_TEXT_BROKER` dans une langue (espagnol, allemand...).
3. Si oui : récupérer sa traduction, la découper ligne par ligne dans les nouvelles clés (même
   ordre de sujets et de lignes que l'ancien bloc), et l'envoyer dans sa langue, pour que son
   travail serve au nouveau système.
4. Ensuite seulement : Braincell1980 supprime `HELP_TEXT` et `HELP_TEXT_BROKER` à la main sur la
   page Localization de CurseForge.

## Bugs corrigés dans la rc5 (à vérifier en jeu)
- Disposition « Compacte », mode placement : les étiquettes sous les blocs se chevauchent (blocs compacts plus étroits que leur étiquette, ex. « Monnaies » / « Composants de classe » / « Munitions », « Instances » sur « 2 verrouillée(s) »).
- Disposition « Colonne à gauche », mode placement : les étiquettes sortent de l'écran à gauche (on ne voit que leur fin).
- Les 26 captures FR sont dans cette session (uploads du 13/10) : refaire ici les visuels si besoin.

## Visibilité (échanges du 12/10 dans une autre conversation)
- Tessera est sur Wago (projet ANz7wj64, description = docs/wago-description.md). Fin de liste normale pour un addon récent.
- Pistes : Reddit (r/WoWUI, subreddit Forever), Discords Forever (MP à Malkkav envoyé pour demander s'il accepte un message sur son Discord), WoWInterface (pas de section Forever : catégorie la plus proche en précisant « WoW Forever »), pic de promotion vers le 4 novembre (sortie de Forever).
- Images faites dans l'autre conversation à partir de ~26 captures FR : barre du haut zoomée, collage et GIF des 4 styles, GIF des dispositions (chat flouté), groupe libre + infobulle Honneur. Pas présentes ici : les redemander si besoin.
- À faire : GIF de 5-10 s du mode placement (glisser/fusionner), 2-3 captures en client anglais, masquer « Issue Reporter » et la notification GNOME, description de page et post Reddit en anglais.

## En attente de Braincell1980
- Captures d'écran en jeu → GIF de défilement pour la description CurseForge.
- Tests de l'alpha multi-versions ; tests en instance (profil donjon, masquer en instance, clics en combat).

## Version multi-versions (après la 1.0.0, en 1.1) : approche validée le 14/10
- Repartir de `main` (propre, audit Ketho à 0), pas de l'ancienne branche `multi-versions`.
- Tous les secours pour Classic Era / BC / MoP dans un seul fichier de compatibilité (`Compat.lua`) : fonction moderne si elle existe, sinon l'ancienne, avec un commentaire par version du jeu ; le reste du code n'appelle que ces fonctions.
- Tester chaque client (faux client `TESSERA_FLAVOR` + tests en jeu) avant toute publication.
- Rien avant le 4/11 : `main` reste centré sur Forever.

## Idées notées (docs/IDEES-FUTUR.md et conversation)
- Icônes nettes en 4K (Masque, icônes HD du jeu, option « icône nette », jeu d'icônes maison).
- Réactifs de classe affichés à 0 en rouge, seuil réglable, liste complétée.
- Bannière à refaire avec le nouveau logo et le titre « Tessera – Mosaic Info Bars & Data Blocks ».
- WoWInterface dans la publication automatique (Wago : prévu avec la rc4).
- Cadres décoratifs autour des groupes.
