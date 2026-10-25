# Addons de WoW Forever : liste vivante

But : savoir quels addons Tessera peut afficher (DataBroker), lesquels recoupent un bloc, et ce qui marche sur Forever. Chaque session repart d'ici au lieu de tout rechercher. Une ligne = ce qu'on sait, avec sa source et sa date. « DataBroker : ? » = pas encore testé (`/tes debug broker`, dans Tessera-dev).

Règle pour les blocs (24 octobre 2026) : un nouveau bloc se justifie s'il est **de base** (ce qu'a toute barre d'infos) ou **propre à Forever**. Sinon, chercher d'abord un addon qui le fait, avec un objet DataBroker, le tester et l'ajouter ici. Blocs gelés (plus de nouvelles fonctions, jamais retirés) : Instances (→ Nova Instance Tracker), Chuchotements (→ addons de chat).

## Constat du 24 octobre 2026

- Aucune liste de recommandations (ForeverDB, wowforevertierlist, Overgear, Kami-Labs, forums Blizzard) ne cite de barre d'infos : ni Titan Panel, ni ChocolateBar, ni Bazooka, ni Tessera. Place à prendre, et listes à contacter pour y figurer (Kami-Labs est en français).
- Forever a déjà, en natif : Mode Édition, compteur de dégâts, gestionnaire de temps de recharge, clic pour soigner.
- Les téléchargements de CurseForge mélangent toutes les versions de WoW : un gros total ne veut pas dire « populaire sur Forever ». Les pages triées par date de création sont interdites aux robots ; Wago demande JavaScript : passer par des captures ou le navigateur intégré.

## Outils

- [UIForever](https://uiforever.com/) (bêta, projet de fans non officiel, Patreon, éditeur nommé seulement dans l'impressum) : simulateur d'interface Forever dans le navigateur (addons + dossier WTF, solo / donjon / raid, export). Liste de compatibilité de 195 addons testés chaque nuit ([compat](https://uiforever.com/compat), 24/10) : Titan Panel, EllesmereUI, HidingBar, MinimapButtonButton, LibDBIcon « Works » ; Tessera, ChocolateBar, Bazooka, Ultimate Panel, FlareUI absents. Baganator et Syndicator y sont « Broken » alors qu'ils ont une version Forever : le simulateur a ses propres trous, ce n'est pas le jeu. À essayer pour Tessera (zip seul, sans téléverser tout le WTF).

## Concurrent direct

| Addon | Ce qu'il fait | DataBroker | Source |
|---|---|---|---|
| Ultimate Panel, ex-The Forever Panel (Neill83, GPLv3 ; changement de nom sans reprise des réglages) | Barre d'infos sur un bord : or de tous les personnages, sacs et recherche banque multi-personnages, enchères en cours par personnage, bascule Herbes / Minerais, temps de vol restant, prochain bateau ou zeppelin, métiers, coordonnées, vitesse, heure, boutons de minicarte regroupés. 212 téléchargements. | Pas mentionné | [CurseForge](https://www.curseforge.com/wow/addons/the-forever-panel), 24/10 |

Repris : bloc Vol et prochain bateau ou zeppelin (1.2, à sonder), sacs de chaque personnage et or de la faction seulement dans les infobulles, couleur de faction (1.0.1). Laissé aux addons spécialisés : recherche multi-personnages (Syndicator, Baganator), enchères (Auctionator), bascule de pistage et lueur des filons (addons de récolte), regroupement des boutons de minicarte.

## Addons propres à Forever

| Addon | Ce qu'il fait | Recoupe Tessera | DataBroker |
|---|---|---|---|
| Forever Companion | Tableau de bord des personnages (niveaux, métiers, Legacy, repos), suggestions, liste de préparation avant donjon. 2 400 téléchargements, bêta. | Legacy, XP de repos, munitions, composants | Pas mentionné |
| Chart My Legacy | Points Legacy, classement des personnages, défis Legacy. 18 téléchargements. | Legacy | Pas mentionné |
| Campfire Tooltips: Forever | Bonus de camp dans les infobulles. 85 téléchargements. | Camping (complémentaire) | Pas mentionné |
| Farmin' Forever | Sessions de farm : butin par zone, or, XP / heure, ventes. 118 téléchargements. | Or de la session | Pas mentionné |
| Farmboard Forever | Tableaux d'objets avec objectifs (bêta). 183 téléchargements. | Objectif | Pas mentionné |
| AtlasLoot Classic Forever | Tables de butin, meilleur équipement. Dans le top 25 de CurseForge. | — | ? |
| DungeonJournal | Quêtes, emplacements et butin des donjons. | — | ? |
| ForeverMeter, ForeverAuras, ForeverDB, QuestTrail, Shortest Path Forever, SkillUp Forever, Forever Fishing, Forever Quick Fish, Extended Vendor Forever, ClassicUI Forever, Forever Move, Better Forever Chat, Forever Voiceover, Forever Quest Tint, Forever Dungeon Quests, HandyNotes: WoW Forever | Cités par les listes de recommandations | Better Forever Chat → Chuchotements | ? |

## Addons historiques avec une version Forever (à tester en DataBroker)

Sources de données probables : BugSack (erreurs), TomTom (coordonnées), Details!, Nova Instance Tracker (verrouillages), Syndicator (objets de tous les personnages), Gathering (farm et valeur à l'hôtel des ventes).
Lanceurs probables : Questie, DBM, BigWigs, Bagnon, Baganator, HandyNotes, RareScanner, Leatrix Plus, Auctionator, Pawn.
Pour la manette (2.0) : Dialogue UI (dialogues de quête compatibles manette), à étudier.
Non disponibles sur Forever (d'après les listes) : WeakAuras (remplacé par ForeverAuras), TradeSkillMaster, AdiBags.

## Les addons de Funkeh (étude du 25 octobre 2026)

Funkeh (funkydude sur GitHub) a écrit StatBlock Core, la première inspiration de Tessera (plus mis à jour depuis 2022, remercié dans l'onglet À propos). Il maintient aujourd'hui BigWigs, LittleWigs, SexyMap, BadBoy, Capping, oRA3... Ses addons ont été mis à jour les 22 et 23/10 et leurs fichiers `.toc` visent tous Forever (16001), sauf oRA3 (retail seulement). Le packager qui construit les zips de Tessera vient aussi de son équipe (BigWigsMods).
- **BigWigs** : publie un objet DataBroker « BigWigs » (`Loader.lua`) ; il marche donc comme bloc DataBroker ou comme lanceur de Tessera. Rien à faire ; à mettre dans la liste des addons testés.
- **SexyMap** : peut cacher les boutons de la minicarte (toujours ou hors survol). Les boutons LibDBIcon restent proposés comme lanceurs par Tessera (lus par la bibliothèque) ; un bouton ordinaire caché par SexyMap n'est plus un enfant de la minicarte et n'apparaît plus dans la liste. On ne lit pas les variables internes de SexyMap (règle des adaptateurs) : c'est acceptable. Combinaison à tester et à conseiller : boutons cachés dans SexyMap, lanceurs dans une barre Tessera. SexyMap a aussi une horloge et des coordonnées sur la minicarte, qui font doublon avec les blocs de Tessera (choix du joueur).
- **SharedMedia_Noto** : 72 variantes de Noto Sans (latin, grec, cyrillique ; pas de chinois ni de coréen) via LibSharedMedia. Tessera les propose déjà dans ses listes de polices. Police très lisible : piste à citer dans l'aide d'accessibilité (1.3), sans rien recoder.
- **Capping** (timers de champs de bataille), **BadBoy** (spam), **ErrorMonster**, **TargetPercent** : sans lien avec Tessera.
- Toute la compatibilité passe par des normes publiques (DataBroker, LibDBIcon, LibSharedMedia) : elle survit aux mises à jour de ses addons.

## Sources (24 octobre 2026)

- [ForeverDB : best addons, octobre 2026](https://foreverdb.net/addons/best) (vérifié le 11/10)
- [WoW Forever Tier List : addons testés](https://wowforevertierlist.com/addons) (mis à jour le 18/10)
- [Overgear (FR) : meilleurs addons par activité](https://overgear.com/guides/fr/wow-forever/best-addons-for-every-activity/) (30/09)
- [Kami-Labs : addons WoW Forever](https://kami-labs.fr/addons-wow-forever/)
- [Forums Blizzard EU : vos addons indispensables](https://eu.forums.blizzard.com/en/wow/t/wow-forever-share-your-must-have-add-ons/634933)
- [CurseForge, Forever, par popularité](https://www.curseforge.com/wow/search?class=addons&page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568)
