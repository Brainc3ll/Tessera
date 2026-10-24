# Addons de WoW Forever : liste vivante

But : savoir quels addons Tessera peut afficher (DataBroker), lesquels recoupent un bloc, et ce qui marche sur Forever. Chaque session repart d'ici au lieu de tout rechercher. Une ligne = ce qu'on sait, avec sa source et sa date. « DataBroker : ? » = pas encore testé (`/tes debug broker`, dans Tessera-dev).

Règle pour les blocs (24 octobre 2026) : un nouveau bloc se justifie s'il est **de base** (ce qu'a toute barre d'infos) ou **propre à Forever**. Sinon, chercher d'abord un addon qui le fait, avec un objet DataBroker, le tester et l'ajouter ici. Blocs gelés (plus de nouvelles fonctions, jamais retirés) : Instances (→ Nova Instance Tracker), Chuchotements (→ addons de chat).

## Constat du 24 octobre 2026

- Aucune liste de recommandations (ForeverDB, wowforevertierlist, Overgear, Kami-Labs, forums Blizzard) ne cite de barre d'infos : ni Titan Panel, ni ChocolateBar, ni Bazooka, ni Tessera. Place à prendre, et listes à contacter pour y figurer (Kami-Labs est en français).
- Forever a déjà, en natif : Mode Édition, compteur de dégâts, gestionnaire de temps de recharge, clic pour soigner.
- Les téléchargements de CurseForge mélangent toutes les versions de WoW : un gros total ne veut pas dire « populaire sur Forever ». Les pages triées par date de création sont interdites aux robots ; Wago demande JavaScript : passer par des captures ou le navigateur intégré.

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

## Sources (24 octobre 2026)

- [ForeverDB : best addons, octobre 2026](https://foreverdb.net/addons/best) (vérifié le 11/10)
- [WoW Forever Tier List : addons testés](https://wowforevertierlist.com/addons) (mis à jour le 18/10)
- [Overgear (FR) : meilleurs addons par activité](https://overgear.com/guides/fr/wow-forever/best-addons-for-every-activity/) (30/09)
- [Kami-Labs : addons WoW Forever](https://kami-labs.fr/addons-wow-forever/)
- [Forums Blizzard EU : vos addons indispensables](https://eu.forums.blizzard.com/en/wow/t/wow-forever-share-your-must-have-add-ons/634933)
- [CurseForge, Forever, par popularité](https://www.curseforge.com/wow/search?class=addons&page=1&pageSize=50&sortBy=popularity&gameVersionTypeId=88568)
