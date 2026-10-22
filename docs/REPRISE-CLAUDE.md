# Reprise rapide (pour Claude)

But : reprendre le travail sans relire toute l'histoire. À lire dans cet ordre : `CLAUDE.md` (les règles de Braincell1980), ce fichier, puis `docs/A-REPRENDRE.md` (l'état du projet et le calendrier). Les idées pour plus tard sont dans `docs/IDEES-FUTUR.md`.

## En une phrase
1.0.0-rc8 publiée le 21/10 ; la 1.0.0 sort le 4/11 (WoW Forever ouvre le 5/11 à minuit, heure belge) ; jusque-là, corrections seulement. L'entrée « 1.0.0 » du changelog est ouverte, version 1.0.0 dans le .toc.

## Travailler avec Braincell1980
- Il ne code pas : il donne les idées et teste en jeu (Linux, Fedora). Lui répondre en français, court et clair ; code, commentaires et commits en anglais.
- Il signale les bugs avec des captures ; chaque correction part dans un zip de test numéroté (test42 est le prochain), qu'il teste avant tout commit de publication.
- Proposer avant de coder une nouveauté ; corriger directement un bug.
- Ne jamais publier sans « on publie » (ou un « go » clair en réponse à la question).
- Signaler ses biais quand ils apparaissent ; ne rien inventer (lire le code ou la source, sinon le dire).
- Textes anglais pour les joueurs : skill `stop-slop` ; français : mêmes principes.

## Outils et commandes
- Textes du jeu : modifier `tools/gen/*.py` (une clé par ligne ; une ligne ajoutée = une nouvelle clé), puis, sur `main` :
  `TESSERA_EXCLUDE="ROWS_,MENU_ROW_ALIGN,ROW_ALIGN_" python3 tools/gen/build.py`
  puis `lua5.1 tools/export_locales.lua . enUS docs/localization/enUS.lua` (et `frFR`).
- Vérifications (toutes, à chaque changement) :
  `luacheck .` ; `lua5.1 tools/mock_run.lua . enUS` (et `frFR`, `"frFR broker"`) en cherchant **`ERROR` dans toute la sortie** (pas seulement la dernière ligne) ; `lua5.1 tools/fuzz_blocks.lua .` ; `lua5.1 tools/check_docs.lua .` (`release` avant une publication) ; `python3 tools/api_audit.py <lua-language-server> <vscode-wow-api>`.
- Simulateur avec les vraies positions des cadres : `MOCK_GEOMETRY = true` après avoir chargé `tools/mock_run.lua` (voir le test des dispositions toutes prêtes dans `mock_run.lua`).
- Changelog : `Changelog.lua` puis `lua5.1 tools/changelog_md.lua > CHANGELOG.md`.
- Zip de test : `TesseraDev.lua` (commandes de test, galerie `/tes debug hd`) et `make_test_zip.sh` ne sont pas dans `main` (règle : jamais publiés). Voir `docs/A-REPRENDRE.md` pour leur emplacement.
- Publier (après « on publie ») : version dans le .toc, entrée datée en haut de `Changelog.lua`, `check_docs.lua . release`, pousser `main`, puis
  `gh api -X POST repos/Brainc3ll/Tessera/actions/workflows/release.yml/dispatches -f ref=main`
  et suivre le run par l'API REST. Le workflow envoie l'anglais et le français à CurseForge. Les descriptions (`docs/curseforge-description.md`, `docs/wago-description.md`), le titre et le résumé (`docs/summary.md`) se recollent à la main.

## Limites de cet environnement
- GitHub : pas de suppression de branche, pas de réglages du dépôt (description « About »...), pas de GraphQL : Braincell1980 le fait.
- Ne jamais toucher aux secrets `CF_API_KEY` et `WAGO_API_TOKEN`.
- Le réseau du terminal ne sort que vers GitHub et les dépôts de paquets ; le web passe par WebSearch / WebFetch.

## Décisions déjà prises (ne pas les reproposer)
- Placement libre au pixel (rc8) : plus de recentrage automatique ; un bloc masqué garde sa place ; les rangées des barres toutes prêtes partent du bord gauche de la barre et restent bord à bord ; un groupe s'aligne par ses bords extérieurs. Le resserrement des voisins d'un bloc masqué : option « à l'étude » (il causait la plupart des bugs).
- Rien ne disparaît pour un joueur qui avait une option ; ses dispositions continuent de marcher.
- FlareUI est traité comme ElvUI, EllesmereUI, GW2 UI : dans les textes du jeu, seulement le nom de son style. Les cadres des interfaces connues (chevauchements, aimantation) sont dans `ns.KNOWN_UI_FRAMES` (Core.lua), avec des noms lus dans leur code.
- Le mode démo reste (il ne faut pas le retirer : il existe depuis la rc5).
- La version Retail n'est pas une priorité. La bêta des rangées (branche `refonte-rangees`) est rangée.
- Titre CurseForge « Tessera – Info Bars That Snap Together » ; le mot « data » est évité (les joueurs le prenaient pour un enregistreur de statistiques).
- Styles FlareUI et FlareUI carré : fond à 50 %, comme FlareUI 2.4.1.

## Pièges déjà rencontrés
- Ne jamais ajouter une ligne à une entrée du changelog déjà publiée : ouvrir l'entrée suivante.
- Les tests : lire toute la sortie (une erreur de `mock_run` s'affichait avant la dernière ligne).
- Bordures fusionnées : le cache `seamKey` compte la taille ; `ReanchorAll` le vide.
- Bloc masqué : sa largeur est `cfg.slotW` (la dernière fois qu'il était affiché), jamais son texte, qui peut être un vieil exemple.
- Une barre et ses rangées comptent comme un seul ensemble (`GetVisualRoot`) pour devant / derrière.
- Le cadre d'aide de la visite rapide partage un seul bouton d'action entre les étapes : le réactiver à chaque étape.
