# Sources et études des autres

Ce qu'on a appris en lisant d'autres addons, le code de Blizzard et les retours d'autres développeurs (sorti de `IDEES-FUTUR.md` le 25 octobre 2026). Les idées qui en découlent pour Tessera sont reprises dans `docs/IDEES-FUTUR.md` ou `docs/A-REPRENDRE.md`.

## Autres addons de barres et d'interface

### Idées tirées des autres addons de barres (13 octobre 2026)

Comparaison avec Titan Panel, Arcana (ex-ChocolateBar), Bazooka, XIV_Databar Continued,
TitanData Texts, ForeverPlus et les textes de données d'ElvUI. Liste du plus simple au plus
compliqué ; Braincell1980 choisit la version de chaque idée.

1. [Fait, rc4] Taille des infobulles réglable (option globale).
2. [Fait, rc4] Infobulle seulement en tenant Alt (option globale).
3. (Pas de combats de mascottes sur Forever pour le moment : mis de côté, voir plus bas.)
4. [Fait, rc4] Coût de réparation et état de chaque pièce dans l'infobulle de durabilité.
5. Fondu des barres en entrant ou en sortant de combat (au lieu de les masquer d'un coup).
6. Or filtré : tous les personnages / ce jeu de règles / ce jeu de règles et cette faction / ce personnage.
7. [Fait, rc4 : mana seulement, le jeu ne donne pas la régénération de vie] Régénération de vie et de mana (nouveau bloc).
8. [Fait, rc4] Statistiques du personnage (critique, hâte, toucher, puissance d'attaque et des sorts, armure, esquive) (nouveau bloc).
9. [Fait, rc4] Méthode de butin du groupe (maître du butin, seuil, /roll) (nouveau bloc).
10. Zones dans un groupe : gauche / centre / droite, le centre restant centré quand les largeurs changent ; réglage par groupe et option globale. (L'alignement du texte dans chaque bloc existe déjà, onglet Blocs > Texte.) Validé, plutôt pour la v1.1. Intérêt surtout pour les barres pleine largeur (dispositions barre des tâches). Exigence de Braincell1980 : à expliquer très très clairement (infobulles, aide, visite rapide, exemple visuel gauche / centre / droite, changelog).
11. Mélangeur de volume : une glissière par canal dans l'infobulle du bloc volume.
12. Micro-menu : un bloc qui ouvre tous les panneaux du jeu.
13. Bloc de voyage : pierre de foyer + téléportations de classe, clic droit pour choisir.
14. Recharges de métiers sur tous les personnages (Étoffe lunaire, transmutations...).
15. Options chargées seulement à l'ouverture (moins de mémoire en jeu) : gros chantier, avec le nettoyage du code.

#### À garder pour plus tard (pas sur Forever, pour une version multi-versions)
- Grande Chambre forte, clés mythiques +, téléportations mythiques +.
- Changement de spécialisation de butin.
- Masquer les barres pendant les combats de mascottes (pas sur Forever pour le moment).
- Outils de raid (appel, compte à rebours, marqueurs) : à revoir selon la demande.

### Idées tirées de FlareUI 2.1.1 (17 octobre 2026)

- [Fait, rc6] Style FlareUI : lignes bronze éteint (#9C7A4A) entre les blocs collés, barres de progression à la texture « FlareUI Forever », couleurs des seuils adoucies (palette « FlareUI » de ses cadres d'unité).
- Recherche dans les options, avec sous chaque résultat l'endroit du réglage (« Blocs › Tous les blocs › Cadre »), comme la fenêtre de réglages de FlareUI. Plutôt en 1.1.
- Style « Forever » fait de l'anneau bronze et de la plaque des cadres d'unité du jeu (atlas `UI-HUD-UnitFrame-*-PortraitOn`), avec les icônes en médaillon. FlareUI découpe déjà une image en rond sur Forever (masque) : la question des masques (voir « Formes de blocs ») a sa réponse. Avec la version « look ».

### Ce qu'on a appris d'EllesmereUI 9.6.1 (21 octobre 2026)
Licence « tous droits réservés » : idées seulement, aucun code ni donnée repris.
- Son style « moderne » des barres de données : fond 0.067 à 95 %, comme notre style EllesmereUI (rien à changer).
- [Fait, 1.0.0, pas testé en jeu] Cadres ajoutés à `ns.KNOWN_UI_FRAMES` (avertissement de chevauchement seulement, pas d'aimantation) : `EllesmereUIUnitFrames_Player`, `_Target`, `_Focus`, `_Pet`, `_TargetTarget`, `_FocusTarget`, `EllesmereUIPlayerAuraBars_Buffs` / `_Debuffs`, `EllesmereUIQTBackground` (suivi des quêtes), `EllesmereUIMicroMenu`, `ERB_CastBarFrame`, `EllesmereEAB_XPBar_*`.
- Une seule version pour Retail et Forever : un .toc avec `## Interface: 120000, ..., 120105, 16001`, et un module propre à Forever livré seulement avec un .toc `_Camelot` (le suffixe que seul le client de WoW Forever lit). Utile si la version Retail revient un jour.
- Ses barres de données (concurrentes de Tessera) : blocs Voyage (pierres de foyer, téléportations), Micro-menu, Fournitures (composants et munitions par classe), Grande Chambre forte, Écus, et un bloc LDB (il affiche les objets DataBroker, donc aussi les blocs partagés par Tessera). Mise en page : un bloc « remplissage » qui prend la place restante et un bloc « toujours centré » (rejoint l'idée des zones gauche / centre / droite).
- Idées de blocs Forever vues dans ses « Forever Essentials » : temps de vol restant, niveaux de la zone, compétence de cueillette, menace.

### ElvUI 16.00 et Tukui 20.463 (21 octobre 2026)
- [Fait, 1.0.0, pas testé en jeu] Cadres d'ElvUI dans `ns.KNOWN_UI_FRAMES` (seulement quand ElvUI est chargé) : `ElvUF_Player`, `_Target`, `_TargetTarget`, `_Focus`, `_Pet`, `ElvUIPlayerBuffs` / `Debuffs`, `ElvUI_ExperienceBar` (aimantation), `ElvUI_ReputationBar`, `ElvUI_MinimapHolder`, `ObjectiveFrameHolder`, `LeftChatPanel` / `RightChatPanel`, `ElvUI_MicroBar`, `ElvUI_StanceBar`, `ElvUI_BarPet`, `ElvUI_Bar1` à `15`.
- Notre style ElvUI lit toujours les bons réglages (`E.media.backdropfadecolor`, `bordercolor`, `E.db.general.valuecolor`, police) ; mêmes valeurs par défaut.
- Les textes de données d'ElvUI affichent les objets DataBroker : les blocs partagés par Tessera peuvent y apparaître.
- ElvUI charge sur Forever grâce aux directives du .toc (`[AllowLoadGameType camelot]` dans le titre ; « camelot » = WoW Forever).
- Tukui 20.463 n'a pas de .toc pour Forever (Classic, Mists, Retail seulement) : rien à faire ; un style Tukui reste possible plus tard.

### GW2 UI 12.0.0 (21 octobre 2026)
- Charge sur Forever (même .toc multi-versions qu'ElvUI, `[AllowLoadGameType camelot]`).
- [Fait, 1.0.0, pas testé en jeu] Cadres dans `ns.KNOWN_UI_FRAMES` (seulement quand GW2_UI est chargé) : `GwPlayerUnitFrame`, `GwTargetUnitFrame`, `GwFocusUnitFrame`, `GwPlayerPetFrame`, `GwPlayerPowerBar`, `GwPlayerClassPower`, `GwQuestTracker`, `GwExperienceFrame` (aimantation), `Gw2MicroBarFrame`, `GwStanceBar`, `GwTotemBar`.
- Style GW2 UI possible (1.1) : avec l'addon, son fond d'infobulle (LSM « GW2_UI_2 ») et sa bordure (`textures/uistuff/ui-tooltip-border.png`, pas dans LSM : à enregistrer par Tessera), sa police Menomonia (LSM « GW2_UI »), texte crème (#FFEDBA) ; sans l'addon, une imitation (gris foncé, fine bordure claire, police du jeu).
- Style Tukui possible aussi (fond gris 0.11, bordure noire, police « Tukui »), mais Tukui ne tourne pas sur Forever : intérêt faible, plutôt pour une version Retail.

## Code de Blizzard, API et retours d'autres développeurs

### Code de l'interface de Blizzard pour Forever (25 octobre 2026)

Source donnée par Braincell1980 : [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), branche `forever` (code Lua/XML de l'interface du client, version 1.60.1 au 22/10). Dans ce code, Forever s'appelle « Camelot » (`[AllowLoadGameType camelot]`, dossiers `Camelot/`). Cloner : `git clone --depth 1 -b forever https://github.com/Gethe/wow-ui-source`. Plus fiable que la doc d'Atraeau pour savoir ce que le client charge vraiment.

Réponses trouvées le 25/10 :
- **Réglages d'accessibilité de Forever** (`Blizzard_SettingsDefinitions_Frame`, `_Shared`) : mode daltonien et filtre daltonien (CVars `colorblindMode`, `colorblindSimulator`, `colorblindWeaknessFactor`), effets d'écran alternatifs pour la photosensibilité (`overrideScreenFlash`), mal des transports et secousses de caméra / d'interface, taille du curseur, taille minimale des noms, pavé de déplacement, icônes et infobulles de ciblage doux, narrateur d'écran et synthèse vocale, alertes sonores de combat, sous-titres.
- **Absents de Forever** (chargés seulement sur Retail) : taille du texte de l'interface et contraste du texte des quêtes. Les options « taille du texte » et « contraste élevé » de Tessera ne font donc pas doublon.
- Tessera peut **suivre** : `colorblindMode` (palette daltoniens de Tessera automatique), `overrideScreenFlash` (pas de clignotement des blocs, alertes sans flash), secousses d'interface réduites (moins d'animations dans Tessera), la voix du narrateur pour une lecture vocale.
- **Horloge** : l'alarme de l'horloge de Blizzard existe sur Forever (`Blizzard_TimeManager`, fichier `Camelot/`). Pour « Je m'arrête à 23h » (bloc Session) : ne pas recoder, ouvrir l'horloge de Blizzard. Idée pour la 1.0.1, à valider : un clic (droit ou Alt) sur le bloc Heure ouvre l'horloge (alarme, chronomètre) ; le clic gauche ouvre déjà le calendrier.
- **Bateaux et zeppelins** : aucun horaire dans le code de l'interface. Il faudrait les apprendre en jeu, comme Ultimate Panel. Temps de vol : pas de durées fournies non plus.

### Retours d'autres développeurs d'addons avec IA (Reddit r/wowaddons, 25 octobre 2026)

Fil « AI assisted addon development questions », copié par Braincell1980.
- **Repris** : le code de l'interface de Blizzard (`Gethe/wow-ui-source`, branche `forever`) et la liste des fonctions, CVars et événements du vrai client Forever (`Ketho/BlizzardInterfaceResources`, branche `forever`). Nouveau test `tools/forever_api_check.py`, aussi sur GitHub à chaque envoi : 52 fonctions `C_` utilisées, toutes présentes sur Forever ou avec un repli (`C_AddOns.GetAddOnMemoryUsage` manque, le global `GetAddOnMemoryUsage` prend le relais).
- Niveaux de risque T0 / T1 / T2 et relecture séparée des changements T2 : skill `tessera-gate2`. Tri des retours joueurs : `tessera-report-triage`. Nettoyage de la 1.1 : `tessera-refactor`.
- Pièges cités, déjà évités par Tessera : valeurs secrètes (lues dans `pcall`), remplacer des fonctions de Blizzard (jamais ; règle écrite dans le README).
- **UIForever** : trois développeurs disent que leurs addons, corrects en jeu, y ont des bugs visuels. Bon pour un premier coup d'œil, jamais une preuve.
- **1.1 (mesures)** : Forever a l'outil de performances des addons de Blizzard (`Blizzard_AddOnPerformance`) et `C_AddOnProfiler` (temps processeur par addon). Mesurer avec eux avant / après l'optimisation, ne pas recoder un profileur.
- **Idée 1.2** : le bloc Mémoire pourrait montrer aussi le temps processeur par addon (`C_AddOnProfiler.GetAddOnMetric`), à sonder en jeu.
- **Avant de poster sur r/wowaddons** : la règle 1 du sous-forum porte sur la qualité du code, la responsabilité et la **déclaration de l'IA**. La section « À propos du projet » des descriptions le fait déjà ; la reprendre dans le post. Le reproche fréquent : « des clones d'addons qui existent déjà » ; la règle « bloc de base ou propre à Forever » y répond.
- Wiki de référence pour l'API : warcraft.wiki.gg (pas l'ancien wowpedia).

#### Deuxième fil Reddit (« AI-assisted addon development », il y a 7 mois, lu le 25/10)
- **JBurlison/WoWAddonAPIAgents** (MIT, février 2026, pour Copilot, Retail 12.0) : skills par domaine de l'API. Utile surtout pour les valeurs secrètes : `issecretvalue`, `canaccessvalue`, `scrubsecretvalues`, `hasanysecretvalues`, `issecrettable` existent toutes sur Forever (liste de Ketho). **Idée 1.1** : là où Tessera protège une lecture par `pcall` seulement à cause des valeurs secrètes, tester `issecretvalue` / `scrubsecretvalues` (plus clair, moins coûteux) ; garder `pcall` pour les fonctions propres à Forever qui peuvent disparaître. Rappel de ce fil : `SendAddonMessage` est bloqué en instance (Tessera ne l'utilise pas ; à retenir pour un partage d'horaires de bateaux).
- **falkicon/mechanic** (GPL, alpha, déclare WoW Forever 16001) : addon de diagnostic + outil de bureau (Python) qui met en file des bouts de Lua ou des tests d'API, recharge en jeu et relit les résultats dans les SavedVariables. Même idée que nos sondes de `TesseraDev.lua`, en automatisé. Pas pour nous aujourd'hui : il faut l'outil sur le PC de Braincell1980 (Windows le mieux pris en charge, il est sous Fedora) et un ordinateur relié à la session. Licence GPL : s'en inspirer, ne rien copier dans Tessera (MIT). Pas de risque de bannissement : il n'utilise que l'API des addons.

#### Troisième fil Reddit (« What would I need to make an addon? », lu le 25/10)
Fil pour débutants ; trois choses servent :
- **Atlas de Blizzard** (`:SetAtlas`, addon Texture Atlas Viewer) : les images du jeu prêtes à l'emploi. Pour la 1.3 (« Comme chez Blizzard », styles HD), la liste des atlas du vrai client Forever est dans `Ketho/BlizzardInterfaceResources`, branche `forever`, `Resources/AtlasInfo.lua` : choisir là-dedans, rien de dessiné à la main.
- **WowLua** (addon « bac à sable » Lua en jeu) : pour une petite sonde, Braincell1980 pourrait coller quelques lignes dans WowLua au lieu d'attendre un zip de test. À vérifier : existe-t-il pour Forever ?
- **townlong-yak.com/framexml** : le code de Blizzard lisible dans un navigateur, pour montrer une fenêtre ou une fonction à Braincell1980.

#### forever-addon-kit (Thunderz96, MIT, relevés de la bêta, septembre 2026 ; lu le 25/10)
Relevés faits sur le vrai client, page par page. Vérifié pour Tessera :
- **Événement inconnu = erreur qui arrête le fichier** : les 49 événements que Tessera enregistre existent tous dans la liste de Ketho pour Forever (1 814). À ajouter un jour à `tools/forever_api_check.py`.
- **Piège du numéro de version** (`GetBuildInfo() >= 100000` pour « client moderne », Forever répond 16001) : Tessera ne lit `GetBuildInfo` que pour le rapport de bug, pas de souci.
- **`ReloadUI()` protégé** sur la bêta : à vérifier avant la 1.0.0 (voir A-REPRENDRE).
- **Plafond de 100 erreurs Lua par session** : après, le client ne transmet plus rien. Si Braincell1980 voit une avalanche d'erreurs, la première compte, pas les suivantes.
- Les sauvegardes jamais relues (bug de la bêta de septembre) : corrigé depuis, les profils de Tessera survivent aux reconnexions dans les tests de Braincell1980.
- Boîte à outils des valeurs secrètes plus complète que prévu (`C_Secrets`, 27 questions, `canaccesssecrets`, `scrub`…) ; la santé est secrète en combat, les montants de dégâts (`UNIT_COMBAT`) non : utile pour le bloc DPS de la 1.2.
- Liste d'autres projets Forever à lire pour la technique (BetterBlizzFrames, forever-addon-dev, hated-wow-mcp, smore-skills pour le camping).

#### WoWAddonDevGuide (Amadeus-, lu le 25/10)
Guide de développement d'addons en 16 fichiers, écrit par Claude avec relecture humaine, pour Retail jusqu'à 12.0.5 (mai 2026). Rien sur Forever. Pas de licence dans le dépôt : le lire, ne rien copier.
- Utile pour la 1.1 : `12a_Secret_Safe_APIs.md` (toutes les fonctions des valeurs secrètes, avec exemples : passer une valeur secrète directement à `SetText`, `canaccessvalue`, `scrubsecretvalues`…) et `05_Patterns_And_Best_Practices.md` (performances). À vérifier contre la liste de Ketho pour Forever avant d'utiliser une fonction.
- Ses commandes pour Claude Code (agent « WoWAddon-Expert », `/wow`) : pas besoin, CLAUDE.md et les skills Tessera font ce travail.

