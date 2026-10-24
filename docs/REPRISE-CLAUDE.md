# Reprise rapide (pour Claude)

But : reprendre le travail sans relire toute l'histoire. À lire dans cet ordre : `CLAUDE.md` (les règles de Braincell1980), ce fichier, puis `docs/A-REPRENDRE.md` (l'état du projet et le calendrier). Les idées pour plus tard sont dans `docs/IDEES-FUTUR.md`.

## En une phrase
1.0.0-rc9-hotfix publiée le 23/10 (exports compacts) ; la 1.0.0 sort le 4/11 (WoW Forever ouvre le 5/11 à minuit, heure belge) : le hotfix avec la version 1.0.0 et l'intro « Première version stable » du changelog (historique git de `Changelog.lua`, juste avant « Release 1.0.0-rc9 »). Jusque-là, corrections seulement.

## Travailler avec Braincell1980
- Il ne code pas : il donne les idées et teste en jeu (Linux, Fedora). Lui répondre en français, court et clair ; code, commentaires et commits en anglais.
- Il signale les bugs avec des captures ; chaque correction part dans un zip de test numéroté (test43 est le prochain), qu'il teste avant tout commit de publication.
- Proposer avant de coder une nouveauté ; corriger directement un bug.
- Ne jamais publier sans « on publie » (ou un « go » clair en réponse à la question).
- Signaler ses biais quand ils apparaissent ; ne rien inventer (lire le code ou la source, sinon le dire).
- Textes anglais pour les joueurs : skill `stop-slop` ; français : mêmes principes.

## Skills (compte de Braincell1980)
`tessera-checks`, `tessera-test-zip`, `tessera-release`, `tessera-bug-fix`, `tessera-ui-addon-study`, `tessera-wrap-up` : les utiliser plutôt que de relire les commandes ci-dessous. Les skills génériques « Lua » publiques (ex. Mindrally) ne conviennent pas à WoW (snake_case, `require`) : ne pas les installer.

## Outils et commandes
- Textes du jeu : modifier `tools/gen/*.py` (une clé par ligne ; une ligne ajoutée = une nouvelle clé), puis, sur `main` :
  `TESSERA_EXCLUDE="ROWS_,MENU_ROW_ALIGN,ROW_ALIGN_" python3 tools/gen/build.py`
  puis `lua5.1 tools/export_locales.lua . enUS docs/localization/enUS.lua` (et `frFR`).
- Vérifications (toutes, à chaque changement) :
  `luacheck .` ; `lua5.1 tools/mock_run.lua . enUS` (et `frFR`, `"frFR broker"`) en cherchant **`ERROR` dans toute la sortie** (pas seulement la dernière ligne) ; `lua5.1 tools/fuzz_blocks.lua .` ; `lua5.1 tools/check_docs.lua .` (`release` avant une publication) ; `python3 tools/api_audit.py <lua-language-server> <vscode-wow-api>`.
- Simulateur avec les vraies positions des cadres : `MOCK_GEOMETRY = true` après avoir chargé `tools/mock_run.lua` (voir le test des dispositions toutes prêtes dans `mock_run.lua`).
- Changelog : `Changelog.lua` puis `lua5.1 tools/changelog_md.lua > CHANGELOG.md`.
- Zip de test : `TesseraDev.lua` (commandes de test, galerie `/tes debug hd`) et `make_test_zip.sh` sont dans le dépôt **privé** `Brainc3ll/Tessera-dev` (jamais dans ce dépôt public ni dans une publication). Le cloner dans `/home/claude/tessera-dev`, puis `sh /home/claude/tessera-dev/make_test_zip.sh test42 <dossier>`.
- Publier (après « on publie ») : version dans le .toc, entrée datée en haut de `Changelog.lua`, `check_docs.lua . release`, pousser `main`, puis
  `gh api -X POST repos/Brainc3ll/Tessera/actions/workflows/release.yml/dispatches -f ref=main`
  et suivre le run par l'API REST. Le workflow envoie l'anglais et le français à CurseForge. Les descriptions (`docs/curseforge-description.md`, `docs/wago-description.md`), le titre et le résumé (`docs/summary.md`) se recollent à la main.

## Limites de cet environnement
- GitHub : pas de suppression de branche, pas de réglages du dépôt (description « About »...), pas de GraphQL : Braincell1980 le fait.
- Ne jamais toucher aux secrets `CF_API_KEY` et `WAGO_API_TOKEN`.
- Le réseau du terminal ne sort que vers GitHub et les dépôts de paquets ; le web passe par WebSearch / WebFetch.

## Décisions déjà prises (ne pas les reproposer)
- Dès la 1.3, chaque chantier prépare l'accessibilité et la manette (règle dans CLAUDE.md, détail dans A-REPRENDRE) : rien ne doit être refait pour elles.
- Placement libre au pixel (rc8) : plus de recentrage automatique ; un bloc masqué garde sa place ; les rangées des barres toutes prêtes partent du bord gauche de la barre et restent bord à bord ; un groupe s'aligne par ses bords extérieurs. Le resserrement des voisins d'un bloc masqué : option « à l'étude » (il causait la plupart des bugs).
- Rien ne disparaît pour un joueur qui avait une option ; ses dispositions continuent de marcher.
- FlareUI est traité comme ElvUI, EllesmereUI, GW2 UI : dans les textes du jeu, seulement le nom de son style. Les cadres des interfaces connues (chevauchements, aimantation) sont dans `ns.KNOWN_UI_FRAMES` (Core.lua), avec des noms lus dans leur code.
- Le mode démo reste (il ne faut pas le retirer : il existe depuis la rc5).
- La version Retail n'est pas une priorité. La bêta des rangées est rangée (branche `archive/refonte-rangees`). L'accessibilité puis la manette se font sur la branche `accessibilite-manette`.
- Titre CurseForge « Tessera – Info Bars That Snap Together » ; le mot « data » est évité (les joueurs le prenaient pour un enregistreur de statistiques).
- Styles FlareUI et FlareUI carré : fond à 50 %, comme FlareUI 2.4.1.

## Pièges déjà rencontrés
- Export : ne jamais casser la lecture des anciens textes (`TESSERA1:`, `TESSERA2:`) ; `tools/fixtures/` contient de vrais textes de la rc9 que le simulateur doit toujours importer.
- Ne jamais ajouter une ligne à une entrée du changelog déjà publiée : ouvrir l'entrée suivante.
- Les tests : lire toute la sortie (une erreur de `mock_run` s'affichait avant la dernière ligne).
- Bordures fusionnées : le cache `seamKey` compte la taille ; `ReanchorAll` le vide.
- Bloc masqué : sa largeur est `cfg.slotW` (la dernière fois qu'il était affiché), jamais son texte, qui peut être un vieil exemple.
- Une barre et ses rangées comptent comme un seul ensemble (`GetVisualRoot`) pour devant / derrière.
- Le cadre d'aide de la visite rapide partage un seul bouton d'action entre les étapes : le réactiver à chaque étape.
- Sous Linux (Wine), après une capture d'écran, les menus déroulants du jeu ne répondent plus jusqu'à un Alt-Tab : c'est le focus de Wine, pas Tessera. Un Alt-Tab peut aussi relancer une mise en page.

## Journal court (une ligne par décision ; le détail est dans CHANGELOG.md, A-REPRENDRE, IDEES-FUTUR)
- 20/10 : rc7 publiée.
- 21/10 : placement simplifié (rc8) ; bêta des rangées rangée ; FlareUI neutre ; cadres des interfaces connues ; dispositions toutes prêtes corrigées (Double barre en trois rangées, Chemin de ronde sans bloc masqué) ; visite rapide et devant / derrière corrigés ; rc8 publiée ; Retail pas une priorité ; galerie HD refaite (dépôt privé) ; mode démo gardé et corrigé ; fond 50 % des styles FlareUI ; cadres d'EllesmereUI, ElvUI, GW2 UI ajoutés (noms lus dans leur code) ; styles GW2 UI et Tukui notés pour la 1.1 ; pack d'icônes « forever-icons » noté.
- 21/10 : bêta Forever fermée le 23/10 à 19 h (heure belge) ; sortie de Forever le 5/11 à minuit (heure belge), publier la 1.0.0 le 4/11 dans la journée.
- 22/10 : titre « Info Bars That Snap Together », résumé et début des descriptions réécrits ; générateur de textes dans `tools/gen` ; outils de dev dans le dépôt privé `Tessera-dev` ; ce fichier créé.
- 22/10 : six skills Tessera enregistrées ; prochain sujet : review du code (voir A-REPRENDRE).
- 22/10 : review du code ; corrections visite rapide (`sv.tourBackup`) et Ctrl+Z (échelle, figé) dans test42, validé en jeu ; le reste noté pour la 1.1 dans A-REPRENDRE.
- 22/10 : sondes de l'API de WoW Forever (test43, test44) : blocs DPS, Corps, Mode de jeu, Météo validés pour la 1.1 (IDEES-FUTUR) ; commandes de dev révisées ; rc9 publiée.
- 23/10 : exports 10 fois plus courts (`TESSERA2:`), anciens textes toujours lus (fixtures dans `tools/fixtures`, à garder) ; statistique et texture des barres gardées à l'import ; rc9-hotfix publiée avant la fermeture de la bêta.
- 24/10 : branche `accessibilite-manette` créée depuis `main` ; rangées archivées dans `archive/refonte-rangees` ; disposition « Portable » notée pour après la 2.0.
- 24/10 : étude des modules (`PLAN-modules.md`) et des bibliothèques ; bilan bon / bof / non dans IDEES-FUTUR ; après la 1.0 : corriger, nettoyer, optimiser d'abord (1.1), nouveaux blocs ensuite (1.2).
