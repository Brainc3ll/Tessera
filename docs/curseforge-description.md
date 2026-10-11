# Tessera

**Customizable information and launcher blocks that merge like mosaic tiles, made for WoW Forever.**

Tessera shows small blocks with the information you want (gold, bags, durability, FPS, latency, time, XP, professions, mail...) and turns minimap buttons into blocks too. Place them anywhere: blocks dropped against each other merge into a single frame, like the tiles (*tesserae*) of a mosaic.

English and French.

> **WoW Forever is in beta.** Tessera is developed and tested on the WoW Forever beta. Its new systems (Legacy, camping, Comprehension, PvP) have no official addon documentation yet and may change before or after release: a block may then need a Tessera update. Please report anything odd.

## Blocks made for WoW Forever

Tessera reads WoW Forever's own systems and gives each one a block:

- **Legacy points**: your points on the Legacy track, the next reward, every reward of the track, and your Legacy challenges completed per category (Classes, Crafting, PvP, Dungeons, Raids, Adventure). A click opens the Legacy panel.
- **Comprehension**: your skill for reading magical scrolls, and the scrolls in your bags. A click casts Scroll Comprehension.
- **Camping**: time left on your camp buffs, or your campfire kit's cooldown; it hides itself when you have neither. A click lights a campfire with your kit.
- **Honor**: your honor points (PvP ranks will follow once WoW Forever is released).
- **Weapon skills**: read from Forever's skill list, with every skill in the tooltip.
- Profession, talent and Legacy blocks open Forever's own windows.

**Also in your DataBroker bar**: like every Tessera block, the WoW Forever blocks can be shared with **Titan Panel, ChocolateBar, Bazooka** and other DataBroker display addons. Use them on Tessera's own bars, in your favorite panel, or both.

## Features

- **More than 40 information blocks**: gold (with a 7-day history and your characters' gold), bags (with junk value), durability, FPS and latency (with graphs), local and server time, XP and rested XP, coordinates, zone, friends, guild, group, quests, reputation, currencies, one block per profession, hearthstone, mail, whispers, reagents, ammo, item level, speed, volume, instances, played time, a personal goal... plus the WoW Forever blocks above.
- **Blocks that hide themselves** when they have nothing to show (mail, whispers, reputation, camping...), in a second row under the main bar.
- **Launcher blocks** made from minimap buttons and addon compartment entries.
- **DataBroker support**:
  - add any DataBroker object of your other addons as a block;
  - share Tessera's blocks with DataBroker display addons;
  - when such an addon is installed, Tessera switches to a DataBroker mode (your display addon shows Tessera's blocks). This mode is explained on first use and can be turned off at any time, to use both.
- **Merging in every direction**, with alignment guides, snapping (also to Blizzard frames), undo (Ctrl + Z), frozen groups, spacers (empty, separator line or text), global and per-group scale. Groups can look fused, like tiles with small joints, or separate, and a block can be replaced in place from the quick menu. Groups can be stuck to the screen edges, and a bar stretched over the whole width like a taskbar. Blizzard's Edit Mode can unlock the blocks too, and one click brings back blocks lost off screen.
- **Styles** matching FlareUI 2.x and 1.x, ElvUI, EllesmereUI and Blizzard, Square styles (FlareUI, Blizzard Modern, Blizzard Classic), plus Clean and Transparent (text and icons only). When a supported interface is installed, Tessera shows its style on sample blocks and offers it; it never changes your style on its own.
- **Per-block settings**: text, frame, icons (same size for all, square or round frame, black and white), opacity, progress bar, color thresholds, show on hover, alerts, Shift + click and middle-click actions.
- **Profiles**: per account or per character, export / import as text, ready-made layouts (top bar, bottom bar, left column, compact, around the gryphons with the WoW Forever blocks, and taskbar or menu bar layouts: Stormwind Stained Glass, Cathedral Rose Window, Tirisfal Orchard, Gnomeregan), automatic dungeon / raid profile. "Reset everything" really starts again from scratch.
- **Share a style or a layout**: export only the look or only the placement as text. On import, Tessera first lists what is missing on your computer (another addon's blocks, LibSharedMedia fonts or frames, WoW Forever blocks) and asks before applying.
- **Blizzard's Edit Mode**: when a Tessera bar stuck to the top or bottom covers the action bars or the minimap, Tessera offers a copy of your Edit Mode layout with room for it; your own layout is never changed. Tested on Blizzard's interface (Modern, Classic) and on FlareUI unchanged; with another interface, unexpected results may occur.
- **Help built in**: a quick tour on first launch, a Help tab split into short topics, and a tooltip on every option.
- **Accessibility**: colorblind-friendly colors, high contrast, minimum text size.

## Getting started

Type **/tessera** (or **/tes**) to open the options. The **Help** tab explains everything. Click **Unlock blocks** to move them, **Lock** when you are done. The WoW Forever blocks are in the **Blocks** tab.

| Command | Effect |
|---|---|
| /tessera | Options |
| /tessera lock / unlock | Lock or unlock the blocks |
| /tessera reset | Reset everything (all settings, then the interface reloads) |
| /tessera minimap | Show or hide the minimap button |
| /tessera preview | Sample values in every block (for screenshots) |
| /tessera broker | DataBroker mode on or off |
| /tessera recover | Bring back blocks that stick out of the screen |
| /tessera bug | Report to copy into a bug report |

## Bugs and ideas

Type **/tessera bug**, copy the report and post it on the [GitHub issue tracker](https://github.com/Brainc3ll/Tessera/issues) (or in the comments here). Ideas are welcome too, especially about WoW Forever systems Tessera could show.

## About this project

Tessera was designed by Braincell1980, who came up with the ideas, the features and the look, and tested every version in game. The code was written with the help of an AI (Claude, by Anthropic). It has been reviewed and tested, but it may still contain bugs: please report them. The source code is on [GitHub](https://github.com/Brainc3ll/Tessera) under the MIT license; contributions and code reviews are welcome.

**Translations**: English and French are included. Other languages can be added by the community through the CurseForge localization tool.

---

# Tessera (français)

**Des blocs d'informations et des lanceurs personnalisables qui s'assemblent comme une mosaïque, conçus pour WoW Forever.**

Tessera affiche de petits blocs avec les informations que tu veux (or, sacs, durabilité, FPS, latence, heure, XP, métiers, courrier...) et transforme aussi les boutons de la minicarte en blocs. Place-les où tu veux : des blocs posés les uns contre les autres fusionnent en un seul cadre, comme les tesselles d'une mosaïque.

En anglais et en français.

> **WoW Forever est en bêta.** Tessera est développé et testé sur la bêta de WoW Forever. Ses nouveaux systèmes (héritage, camping, Compréhension, JcJ) n'ont pas encore de documentation officielle pour les addons et peuvent changer avant ou après la sortie : un bloc peut alors demander une mise à jour de Tessera. Signale-nous tout ce qui te paraît bizarre.

## Des blocs pensés pour WoW Forever

Tessera lit les systèmes propres à WoW Forever et donne un bloc à chacun :

- **Points d'héritage** : tes points sur le parcours Héritage, la prochaine récompense, toutes les récompenses du parcours et tes défis d'héritage accomplis par catégorie (Classes, Artisanat, JcJ, Donjons, Raids, Aventure). Un clic ouvre le panneau Héritage.
- **Compréhension** : ta compétence pour lire les parchemins magiques, et les parchemins dans tes sacs. Un clic lance Compréhension de parchemin.
- **Camping** : le temps restant de tes buffs de camp, ou la recharge de ton kit de feu de camp ; il se masque quand tu n'as ni l'un ni l'autre. Un clic allume un feu de camp avec ton kit.
- **Honneur** : tes points d'honneur (les rangs JcJ suivront à la sortie de WoW Forever).
- **Compétences d'armes** : lues dans la liste de compétences de Forever, toutes les compétences dans l'infobulle.
- Les blocs métiers, talents et héritage ouvrent les fenêtres propres à Forever.

**Aussi dans ta barre DataBroker** : comme tous les blocs de Tessera, les blocs WoW Forever peuvent être partagés avec **Titan Panel, ChocolateBar, Bazooka** et les autres addons d'affichage DataBroker. Utilise-les dans les barres de Tessera, dans ton panneau préféré, ou les deux.

## Fonctions

- **Plus de 40 blocs d'informations** : or (avec l'historique sur 7 jours et l'or de tes personnages), sacs (avec la valeur des objets gris), durabilité, FPS et latence (avec graphiques), heure locale et du serveur, XP et XP de repos, coordonnées, zone, amis, guilde, groupe, quêtes, réputation, monnaies, un bloc par métier, pierre de foyer, courrier, chuchotements, composants, munitions, niveau d'objet, vitesse, volume, instances, temps de jeu, objectif personnel... en plus des blocs WoW Forever ci-dessus.
- **Des blocs qui se masquent** quand ils n'ont rien à montrer (courrier, chuchotements, réputation, camping...), dans une deuxième rangée sous la barre principale.
- **Des blocs lanceurs** créés à partir des boutons de la minicarte et du compartiment d'addons.
- **Support DataBroker** :
  - ajoute en bloc n'importe quel objet DataBroker de tes autres addons ;
  - partage les blocs de Tessera avec les addons d'affichage DataBroker ;
  - quand un tel addon est installé, Tessera passe en mode DataBroker (ton addon d'affichage montre les blocs de Tessera). Ce mode est expliqué à la première utilisation et se désactive à tout moment, pour utiliser les deux.
- **Fusion dans tous les sens**, avec guides d'alignement, aimantation (aussi aux cadres de Blizzard), annulation (Ctrl + Z), groupes figés, espaces (vide, ligne de séparation ou texte), échelle globale et par groupe. Les groupes peuvent être fusionnés, en tuiles avec de petits joints, ou séparés, et un bloc se remplace sur place depuis le menu rapide. Les groupes se collent aux bords de l'écran, et une barre peut s'étirer sur toute la largeur comme une barre des tâches. Le mode Édition de Blizzard peut aussi déverrouiller les blocs, et un clic ramène les blocs perdus hors de l'écran.
- **Styles** assortis à FlareUI 2.x et 1.x, ElvUI, EllesmereUI et Blizzard, styles Carré (FlareUI, Blizzard Moderne, Blizzard Classique), plus Épuré et Transparent (seulement le texte et les icônes). Quand une interface prise en charge est installée, Tessera montre son style sur des blocs d'exemple et te le propose ; il ne change jamais ton style tout seul.
- **Réglages par bloc** : texte, cadre, icônes (même taille pour toutes, cadre carré ou rond, noir et blanc), opacité, barre de progression, couleurs de seuil, affichage au survol, alertes, actions du Maj + clic et du clic milieu.
- **Profils** : par compte ou par personnage, export / import en texte, dispositions toutes prêtes (barre en haut, barre en bas, colonne à gauche, compacte, autour des gryphons avec les blocs WoW Forever, et des dispositions façon barre des tâches ou barre de menus : Vitraux de Hurlevent, Rosace de la cathédrale, Vergers de Tirisfal, Gnomeregan), profil automatique en donjon / raid. « Tout réinitialiser » repart vraiment de zéro.
- **Partager un style ou une disposition** : exporte seulement l'allure ou seulement le placement en texte. À l'import, Tessera liste d'abord ce qui manque sur ton ordinateur (blocs d'un autre addon, polices ou cadres LibSharedMedia, blocs WoW Forever) et demande avant d'appliquer.
- **Mode Édition de Blizzard** : quand une barre de Tessera collée en haut ou en bas recouvre les barres d'action ou la minicarte, Tessera propose une copie de ta disposition du mode Édition avec la place qu'il faut ; ta disposition n'est jamais modifiée. Testé sur l'interface de Blizzard (Moderne, Classique) et sur FlareUI non modifié ; avec une autre interface, des résultats inattendus peuvent survenir.
- **Aide intégrée** : une visite rapide au premier lancement, un onglet Aide découpé en sujets courts, et une infobulle sur chaque option.
- **Accessibilité** : couleurs pour daltoniens, contraste renforcé, taille de texte minimale.

## Pour commencer

Tape **/tessera** (ou **/tes**) pour ouvrir les options. L'onglet **Aide** explique tout. Clique sur **Déverrouiller les blocs** pour les déplacer, puis sur **Verrouiller** quand tu as fini. Les blocs WoW Forever sont dans l'onglet **Blocs**.

| Commande | Effet |
|---|---|
| /tessera | Options |
| /tessera lock / unlock | Verrouiller ou déverrouiller les blocs |
| /tessera reset | Tout réinitialiser (tous les réglages, puis l'interface se recharge) |
| /tessera minimap | Afficher ou masquer le bouton de la minicarte |
| /tessera preview | Valeurs d'exemple dans tous les blocs (pour les captures) |
| /tessera broker | Activer ou désactiver le mode DataBroker |
| /tessera recover | Ramener les blocs qui dépassent de l'écran |
| /tessera bug | Rapport à copier dans un signalement de bug |

## Bugs et idées

Tape **/tessera bug**, copie le rapport et poste-le sur [GitHub](https://github.com/Brainc3ll/Tessera/issues) (ou dans les commentaires ici). Les idées sont les bienvenues aussi, surtout sur les systèmes de WoW Forever que Tessera pourrait afficher.

## À propos du projet

Tessera a été conçu par Braincell1980, qui a apporté les idées, les fonctions et le style, et a testé chaque version en jeu. Le code a été écrit avec l'aide d'une IA (Claude, d'Anthropic). Il a été relu et testé, mais peut encore contenir des bugs : merci de les signaler. Le code source est sur [GitHub](https://github.com/Brainc3ll/Tessera) sous licence MIT ; les contributions et relectures sont les bienvenues.

**Traductions** : l'anglais et le français sont inclus. D'autres langues peuvent être ajoutées par la communauté avec l'outil de traduction de CurseForge.
