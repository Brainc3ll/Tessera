# À reprendre (état au 15 octobre 2026)

## Calendrier jusqu'à la 1.0.0 (validé le 13/10)
La bêta de WoW Forever ferme le **22 octobre** : après, plus aucun test en jeu avant la sortie.
Tout ce qui part le 4 novembre doit avoir été testé en jeu avant le 22.
- **15/10 : rc5** publiée (tests de la test17 réussis, mode DataBroker testé dans les deux sens ; seule l'instance n'a pas été testée).
- **16-19/10 :** tests larges (instance, raid, combat, groupe ; Blizzard seul, FlareUI, Bazooka).
- **19-20/10 : version candidate 1.0.0** ; **20-21/10 :** dernier test de cette version exacte (c'est elle qui part le 4/11, sans retouche).
- **Avant le 22, en jeu :** captures en client anglais (pour les images et le GIF des styles du mode démo).
- **22/10 - 3/11 : hors jeu seulement** : pages CurseForge / Wago (texte « sortie », sans « bêta »), résumé 1.0.0 du changelog, post Reddit, messages Discord.
- **4/11 :** publication de la 1.0.0 et promotion ; garder de la marge pour une 1.0.1 rapide si la sortie change des identifiants.
- Pas avant la 1.0.0 (en 1.1) : nettoyage du code, styles pour tous, zones, bloc voyage, recharges de métiers, or filtré, fondu des barres, version multi-versions.

## Versions
- **1.0.0-rc4** : publiée le 13/10 (GitHub, CurseForge, Wago).
- **1.0.0-rc5** : publiée le 15/10 (GitHub, CurseForge, Wago). Décision de Braincell1980 : s'il n'y a pas de nouvelle version de test avant le 22/10, la rc5 devient la 1.0.0 finale (même code, version renommée 1.0.0 et publiée le 4/11).
- **1.1.0-alpha1** (autres versions du jeu) : ancienne branche `multi-versions`, abandonnée au profit de l'approche ci-dessous.

## Après la publication de la rc5 : anciens blocs d'aide sur CurseForge (rappeler chaque étape à Braincell1980)
L'aide est découpée en petites clés (HELP_<SUJET>_<n>). Les deux anciens blocs `HELP_TEXT` et
`HELP_TEXT_BROKER` restent sur l'outil de traduction de CurseForge (l'envoi ne supprime jamais
rien) alors que l'addon ne les lit plus. Dix autres textes inutilisés ont été retirés de l'addon
le 15/10 (ex. MERGE, THEME_PREVIEW) : même traitement.
1. Publier la rc5 : les nouvelles petites clés partent sur CurseForge.
2. Regarder sur CurseForge (page Localization) si un traducteur a traduit `HELP_TEXT` ou
   `HELP_TEXT_BROKER` dans une langue (espagnol, allemand...).
3. Si oui : récupérer sa traduction, la découper ligne par ligne dans les nouvelles clés (même
   ordre de sujets et de lignes que l'ancien bloc), et l'envoyer dans sa langue, pour que son
   travail serve au nouveau système.
4. Ensuite seulement : Braincell1980 supprime les textes inutilisés à la main sur la page
   Localization de CurseForge.

## En attente de Braincell1980
- Captures d'écran en client anglais (une par style en mode démo, « Masquer l'interface du jeu » coché, caméra fixe) → GIF des styles et images de présentation ; une capture en français pour montrer les deux langues.
- Test en instance (profil donjon, masquer en instance, clics en combat).

## Visibilité
- Tessera est sur CurseForge et Wago (projet ANz7wj64, description = `docs/wago-description.md`).
- Pistes : Reddit (r/WoWUI avec le paragraphe « AI Disclaimer », subreddit Forever), Discords Forever (publicité autorisée par Malkkav), WoWInterface (catégorie la plus proche en précisant « WoW Forever »), pic de promotion vers le 4 novembre.
- Images à faire : GIF des styles du mode démo, captures en anglais, bannière avec le nouveau logo.

## Version multi-versions (après la 1.0.0, en 1.1) : approche validée le 14/10
- Repartir de `main` (propre, audit Ketho à 0), pas de l'ancienne branche `multi-versions`.
- Tous les secours pour Classic Era / BC / MoP dans un seul fichier de compatibilité (`Compat.lua`) : fonction moderne si elle existe, sinon l'ancienne, avec un commentaire par version du jeu ; le reste du code n'appelle que ces fonctions.
- Tester chaque client (faux client `TESSERA_FLAVOR` + tests en jeu) avant toute publication.
- Si un jour elle est publiée : retirer le suffixe « -forever » du nom du zip.

## Outils de la session (hors dépôt)
- `TesseraDev.lua` (commandes de test et de développement) et `make_test_zip.sh` : `/home/claude/tessera-dev/`, ajoutés seulement aux zips de test.
- Générateur des textes (`help_struct.py`, `help_texts.py`...) : `/home/claude/tessera-tools/gen`, `python3 build.py`.

Les idées pour plus tard sont dans `docs/IDEES-FUTUR.md`. Les plans terminés (mode Édition, onglet Apparence) sont gardés comme archive dans `docs/archive/`.
