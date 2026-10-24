# À reprendre (état au 22 octobre 2026)

## Où on en est
- **1.0.0-rc9-hotfix publiée le 23/10** : textes d'export compacts (`TESSERA2:` : une base commune par famille de blocs, puis seulement ce qui diffère ; profil 70 Ko → 5-7 Ko, style et disposition < 4 Ko ; les textes `TESSERA1:` s'importent toujours, vérifié par `tools/fixtures/rc9-*.txt` dans le simulateur) ; l'import garde la statistique du bloc Statistiques et la texture des barres. La 1.0.0 du 4/11 = ce hotfix + version 1.0.0 et intro « Première version stable ».
- **1.0.0-rc9 publiée le 22/10** (GitHub, CurseForge, Wago ; test42 validé en jeu) : la rc8 + les corrections du 22/10. La 1.0.0 du 4/11 sera la rc9 avec seulement la version et l'intro « Première version stable » du changelog. Le détail de chaque version est dans `CHANGELOG.md`.
- La bêta de WoW Forever ferme le **vendredi 23/10 à 19 h (heure belge ; 10 h PDT)**. Ensuite, plus de test en jeu jusqu'à la sortie de Forever.
- Branches : `main` (la rc9-hotfix) ; `accessibilite-manette` (créée le 24/10 depuis `main` : l'accessibilité d'abord, puis la manette ; faire d'abord le nettoyage du code de la 1.1 sur `main`, puis remettre cette branche à jour) ; `archive/refonte-rangees` (la bêta du placement par rangées, gardée pour l'option « laisser les voisins se resserrer » ; les étiquettes git sont refusées par l'environnement, d'où une branche). `refonte-rangees` : à supprimer par Braincell1980 (même contenu que l'archive).

- **1.0.0 en préparation** : depuis la rc9, rien de nouveau ; le 4/11, nouvelle entrée « 1.0.0 » avec l'intro (dans l'historique git de `Changelog.lua`, juste avant le commit « Release 1.0.0-rc9 » (l'intro a été retirée là)) et version 1.0.0 dans le .toc. Correction : quitter le mode démo ne déplace plus un bloc de la deuxième rangée (un bloc masqué garde la largeur qu'il avait affiché, `cfg.slotW` ; la démo efface ses valeurs d'exemple ; `/tessera preview` ne change plus `slotW`). Styles FlareUI et FlareUI carré à 50 % de fond (comme FlareUI 2.4.1, vérifié). Cadres d'EllesmereUI 9.6.1, d'ElvUI 16.00 et de GW2 UI 12.0 ajoutés à `ns.KNOWN_UI_FRAMES` (noms lus dans son code, pas testés en jeu : Braincell1980 n'a pas le temps).

- **Review du code faite le 22/10** : deux corrections pour la 1.0.0 (test42, validé en jeu le 22/10) : la visite rapide garde la disposition du joueur dans les variables sauvegardées (`sv.tourBackup`, rendue au chargement et dans son propre profil) ; Ctrl+Z rend aussi l'échelle et l'état figé d'un groupe. Notés pour la 1.1 : Ctrl+Z après un import de disposition incomplet, `AttachNewBlock` dépend de l'ordre de `pairs()`, `UNIT_AURA` non filtré (Camping), caches de `GetRoot` / `GetSubtree`, étiquettes recalculées blocs verrouillés, rappel des styles à chaque média LibSharedMedia, `collectgarbage` au verrouillage, découpage de Core.lua et Options.lua.

## Calendrier jusqu'à la 1.0.0
- **22/10 - 3/11 : hors jeu** : images dans les galeries de CurseForge et Wago, post Reddit, messages Discord ; corrections seulement.
- **Sortie de WoW Forever : 4/11 à 15 h PST = 5/11 à minuit, heure belge.** Publier la 1.0.0 le 4/11 dans la journée (vérification de CurseForge comprise), pour qu'elle soit en ligne à l'ouverture.
- **4/11 : publication de la 1.0.0** (après « on publie ») : nouvelle entrée « 1.0.0 » en haut du changelog avec l'intro « Première version stable » (dans l'historique git de `Changelog.lua`, juste avant le commit « Release 1.0.0-rc9 » (l'intro a été retirée là)), version dans le .toc. Garder de la marge pour une 1.0.1 rapide.

## Le placement depuis la rc8 (décidé le 21/10)
Le joueur décide au pixel près ; Tessera ne recentre plus rien.
- Un bloc activé mais masqué garde sa place (`ns:HasPlace`, largeur `cfg.slotW`).
- Barres toutes prêtes : la barre est placée une fois (`FreezeAnchoredGroups`, après le premier chargement) ; ses rangées sont accrochées sous le bord gauche de la barre (`anchor.fixed`, `anchor.offset = 0`) et prennent sa largeur (`fill`, deux passes pour une rangée sous une rangée) ; bord à bord quand elles sont alignées aux deux bouts (8 px de marge). La première barre ne contient que des blocs toujours affichés.
- Un groupe déplacé s'aligne par ses bords extérieurs seulement. On peut fusionner des blocs sur une rangée figée.
- Devant / derrière s'applique à une barre avec ses rangées (`GetVisualRoot`), blocs masqués compris.
- FlareUI est traité comme les autres interfaces : seul le nom de son style apparaît dans les textes du jeu. Ses cadres (barre d'XP pour l'aimantation, cadres pour les chevauchements) sont dans `ns.KNOWN_UI_FRAMES` (Core.lua), où ajouter d'autres interfaces après un test en jeu.
- « Problèmes connus » (descriptions) : un bloc masqué ne fait plus resserrer ses voisins ; option à l'étude.

## Feuille de route
Décidé le 24/10 : **les versions après la 1.0 servent d'abord à corriger, nettoyer et optimiser Tessera.** Le détail (bon / bof / non) est dans IDEES-FUTUR, « Bilan du 24 octobre ».
1. **1.0.0 le 4/11** : la 1.0.0-rc9-hotfix, avec seulement la version et l'intro « Première version stable ».
2. **1.0.x** : corrections des bugs trouvés en jouant (un bug bloquant passe avant tout).
   **1.0.1** : en plus, tous les petits ajustements (décision du 24/10 : rien de neuf dans la 1.0.0) : couleur de faction (Horde / Alliance) au choix à la place de la couleur de classe (teintes plus claires pour le texte, repli sur la classe sans faction, défaut « classe ») ; espace des sacs de chaque personnage dans l'infobulle des Sacs ; option « personnages de cette faction seulement » dans l'infobulle de l'Or. Hors code, avant le 4/11 : titre et résumé CurseForge / Wago avec « WoW Forever », première capture lisible, appel aux traducteurs.
3. **1.1 « Nettoyage et optimisation »** :
   - nettoyage du code : découper `Core.lua` et `Options.lua`, retirer le code mort, commentaires à jour ;
   - étapes de conversion des sauvegardes rangées dans la base (`sv.dbVersion`, étapes « 1 → 2 → 3 » jouées une fois au chargement) ;
   - profils allégés faits maison : à la déconnexion, retirer les réglages égaux à leur valeur par défaut (environ 200 Ko par profil aujourd'hui) ;
   - pas de cadres de blocs en mode DataBroker ;
   - catalogue des blocs et blocs « fantômes » (un bloc absent garde sa place et sa configuration ; voir `PLAN-modules.md`, section 3) ;
   - performances : filtrer `UNIT_AURA` (Camping), caches de `GetRoot` / `GetSubtree` par passe de mise en page, étiquettes non recalculées blocs verrouillés, un seul rechargement des styles pour les médias LibSharedMedia au lancement ;
   - changelog plus léger en jeu (à partir de la 1.0.0 ; l'historique des rc reste sur GitHub) ;
   - petits bugs de la review du 22/10 : Ctrl+Z après l'import d'une disposition, `AttachNewBlock` (ordre de `pairs()`), `FreezeAnchoredGroups` après un combat, bloc Temps de jeu qui peut laisser la discussion muette ;
   - audit de l'API avec la doc de Forever (`WowForeverAPI.lua` d'Atraeau).
4. **1.2 « Nouveaux blocs »** : DPS, Corps, Mode de jeu, Météo, Vol (destination, temps restant) et prochain bateau ou zeppelin (à sonder ; idées d'Ultimate Panel, voir `ADDONS-FOREVER.md`), type « Objet » dans le bloc Objectif (voir `PLAN-bloc-farm.md`), épingler l'infobulle de n'importe quel bloc (testés en jeu le 22/10) ; Compréhension lue par son numéro, honneur d'hier, durabilité des pièces dans les sacs ; modules par catégorie **à décider** (plan prêt : `PLAN-modules.md`) ; ensuite les idées déjà notées : déplacer un bloc au pixel, l'agrandir ou le rétrécir, option « laisser les voisins se resserrer » à l'étude, cadres et styles d'autres interfaces (GW2 UI d'abord), recherche dans les options, mode DataBroker plus simple.
5. **1.3 « Comme chez Blizzard »** : styles HD (galerie `/tes debug hd` dans les zips de test), fenêtre d'options avec les pièces des Réglages du jeu, bouton « ? », étiquette « Nouveau ».
   **Règle (24/10) : dès la 1.3, chaque chantier prépare l'accessibilité (1.4) et la manette (2.0), pour ne rien refaire ensuite.** Pour la 1.3, ça veut dire :
   - la nouvelle fenêtre d'options se met en page toute seule (pas de colonnes de largeur fixe) : un texte plus gros pousse les réglages au lieu de déborder ;
   - chaque pièce (case, curseur, liste, couleur, bouton « ? ») passe par l'usine à widgets, avec dès le départ un ordre de navigation, un état « sélectionné » bien visible (pas seulement une couleur) et une action « valider » / « retour » : la manette n'aura qu'à s'y brancher ;
   - chaque style HD a une variante lisible en contraste élevé, et le texte reste lisible quand sa taille augmente ;
   - toute nouvelle animation respecte un réglage « moins d'animations » (même s'il n'est montré qu'en 1.4) ;
   - l'étiquette « Nouveau » est un mot ou une forme, pas seulement une couleur ;
   - chaque maquette est vérifiée avec trois questions : « avec un texte deux fois plus gros ? », « sans souris, à la croix ? », « en contraste élevé ? ».
6. **1.4 « Accessibilité »** (branche `accessibilite-manette`, remise à jour depuis `main` avant de commencer ; ne pas refaire ce que les Réglages de Blizzard font déjà : les suivre et les indiquer, voir IDEES-FUTUR) : polices pour l'accessibilité (OpenDyslexic, Atkinson Hyperlegible, Luciole, Lexend, Andika, Inclusive Sans, partagées avec les autres addons ; voir IDEES-FUTUR), taille du texte, contraste élevé partout, moins d'animations, formes en plus des couleurs, lecture vocale et alertes, assistant du premier lancement.
7. **2.0 « Manette »** (même branche) : Tessera prend la manette seulement quand ses fenêtres sont ouvertes, navigation à la croix, menu en cercle, vibration et barre lumineuse ; bloc « Batterie de la manette » à sonder (`C_GamePad.GetPowerLevel`).
8. **Après la 2.0** : disposition « Portable » (Steam Deck, ROG Ally ; texte et blocs plus gros).
Maquettes des options (deux volets, mosaïque, accessibilité, manette) : artefact « Tessera – idées d'interface des options » (20/10).
Maquette selon la règle de la 1.3 (24/10) : artefact « Tessera – options accessibles (maquette 1.3) » : fenêtre normale, texte ×2, contraste élevé, menu en cercle à la manette.

## Version Forever + Retail (pas une priorité, décidé le 21/10)
- Retail 12.1.5 (interface 120105) et le PTR 12.1.7 ont la même API (Midnight) que Forever.
- Les modules propres à Forever ne s'enregistrent que si leurs fonctions existent ; les fonctions propres à Forever passent par `_G["Nom"]`.
- Zips de test Retail : TOC `## Interface: 16001, 120105, 120107`.
- Repartir de `main` (l'ancienne branche `multi-versions` est supprimée).

## Textes sur CurseForge
- Le workflow de publication envoie l'anglais et le français à CurseForge (`missing-phrase-handling: DoNothing` : une clé supprimée y reste). Pour un gros ménage : import anglais à la main avec suppression des phrases absentes, puis import français (fait le 16/10).
- Descriptions : à recoller à la main sur CurseForge et Wago quand elles changent.

## Documentation de l'API de WoW Forever (trouvée le 18/10)
- Documentation générée par Blizzard, recopiée par Ketho : dépôt `Ketho/wow-ui-source-forever`, dossier `Interface/AddOns/Blizzard_APIDocumentationGenerated` (`C_SkillInfo`, `LegacyConsts`, `C_GameRules`...), avec le code de l'interface de Blizzard.
- warcraft.wiki.gg : « Patch 1.60.1/API changes » et la catégorie « Exclusive API/forever ». `GetInspectHonorData` donne l'honneur et le seuil du niveau suivant (rangs JcJ en 1.1).
- À faire après la 1.0.0 : relire les blocs WoW Forever (Compréhension, Camping, Honneur) avec cette documentation.

## Visibilité
- CurseForge et Wago (projet ANz7wj64). Pistes : Reddit (r/WoWUI avec le paragraphe « AI Disclaimer », subreddit Forever), Discords Forever (publicité autorisée par Malkkav), WoWInterface, pic de promotion vers le 4/11.
- Images (`docs/media`, dans le README) : bannière animée, trois GIF des styles, image anglais / français (sa moitié française vient d'une version plus ancienne : une capture récente du mode démo en français permettrait de la refaire). À envoyer dans les galeries de CurseForge et Wago.

## Outils de la session (hors dépôt)
- `TesseraDev.lua` (commandes de test : `/tes test`, rapport de debug, galerie `/tes debug hd`...) et `make_test_zip.sh` : dépôt privé `Brainc3ll/Tessera-dev` (cloné dans `/home/claude/tessera-dev/`), ajoutés seulement aux zips de test (prochain : test46).
- Générateur des textes : dans le dépôt, `tools/gen` (anglais et français) ; `TESSERA_EXCLUDE="ROWS_,MENU_ROW_ALIGN,ROW_ALIGN_" python3 tools/gen/build.py` pour `main` (les textes de la branche des rangées restent dehors). Le fichier français utilise des espaces normales.
- Simulateur avec vraies positions : `MOCK_GEOMETRY = true` dans un script qui charge `tools/mock_run.lua` (voir le test des dispositions toutes prêtes).

Reprise rapide pour Claude : `docs/REPRISE-CLAUDE.md`. Les idées pour plus tard sont dans `docs/IDEES-FUTUR.md`. Les plans et listes de tests terminés sont dans `docs/archive/`.
