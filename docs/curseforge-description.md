# Tessera – Mosaic Info Bars & Data Blocks

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

- **More than 40 information blocks**: gold (with a 7-day history and your characters' gold), bags (with junk value), durability, FPS and latency (with graphs), local and server time, XP and rested XP, coordinates, zone and subzone, friends, guild, group, quests, reputation, currencies, one block per profession (plus cooking, first aid and fishing), talent points, hearthstone, mail, whispers, class reagents, ammo, item level, speed, volume, addon memory, instances, played time, a personal goal, mana regeneration, character stats, group loot... plus the WoW Forever blocks above.
- **Blocks that hide themselves** when they have nothing to show (mail, whispers, reputation, camping...), in a second row under the main bar.
- **Launcher blocks** made from minimap buttons and addon compartment entries.
- **DataBroker support**:
  - add any DataBroker object of your other addons as a block;
  - share Tessera's blocks with DataBroker display addons;
  - when such an addon is installed, Tessera switches to a DataBroker mode (your display addon shows Tessera's blocks). This mode is explained on first use and can be turned off at any time, to use both.
- **Merging in every direction**, with alignment guides, snapping (also to Blizzard frames), undo (Ctrl + Z), frozen groups, spacers (empty, separator line or text), global and per-group scale. Groups can look fused, like tiles with small joints, or separate. Groups can be stuck to the screen edges, and a bar stretched over the whole width like a taskbar. Blizzard's Edit Mode can unlock the blocks too, and one click brings back blocks lost off screen.
- **Replace a block in place**: hover it in placement mode, click its arrows, pick another block: it shows up exactly there, with the same look, and nothing else moves. A block already shown swaps places with it, and the empty spacers of the ready-made layouts are there to be filled this way. A cross on the block hides it.
- **Styles** matching FlareUI 2.x and 1.x, ElvUI, EllesmereUI and Blizzard, Square styles (FlareUI, Blizzard Modern, Blizzard Classic), plus Clean and Transparent (text and icons only), and four fantasy styles: Runestone (text only, black and white), Grimoire, Parchment and Arcane. When a supported interface is installed, Tessera shows its style on sample blocks and offers it; it never changes your style on its own. The interface styles can also be picked without that addon, as an imitation.
- **Per-block settings**: text, frame, icons (same size for all, square or round frame, black and white), opacity, progress bar, color thresholds, show on hover, alerts, Shift + click and middle-click actions, and how the value is shown (gold with or without coin icons, rounded; free or used bag slots; XP in percent or to go; average durability; latency home or world; seconds; decimals...).
- **Profiles**: per account or per character, export / import as text, ready-made layouts (top bar, Double bar with a second bar of WoW Forever blocks, bottom bar, left column, compact, around the gryphons with the WoW Forever blocks, and taskbar or menu bar layouts: Stormwind Stained Glass, Cathedral Rose Window, Tirisfal Orchard, Gnomeregan), automatic dungeon / raid profile. "Reset everything" really starts again from scratch.
- **Share a style or a layout**: export only the look or only the placement as text. On import, Tessera first lists what is missing on your computer (another addon's blocks, LibSharedMedia fonts or frames, WoW Forever blocks) and asks before applying.
- **Blizzard's Edit Mode**: when a Tessera bar stuck to the top or bottom covers the action bars or the minimap, Tessera offers a copy of your Edit Mode layout with room for it; your own layout is never changed. Tested on Blizzard's interface (Modern, Classic) and on FlareUI unchanged; with another interface, unexpected results may occur.
- **Tooltips your way**: bigger or smaller, or only while holding Alt.
- **Help built in**: a quick tour on first launch (try the ready-made layouts right on your screen), a demo mode with every block and a style switcher, a Help tab split into short topics, and a tooltip on every option.
- **Accessibility**: colorblind-friendly colors, high contrast, minimum text size.

## Getting started

Type **/tessera** (or **/tes**) to open the options. The **Help** tab explains everything. Click **Unlock blocks** to move them, **Lock** when you are done. The WoW Forever blocks are in the **Blocks** tab.

| Command | Effect |
|---|---|
| /tessera | Options |
| /tessera lock, /tessera unlock | Lock or unlock the blocks |
| /tessera reset | Reset everything (all settings, then the interface reloads) |
| /tessera minimap | Show or hide the minimap button |
| /tessera preview | Sample values in every block (for screenshots) |
| /tessera preview forever | The WoW Forever blocks alone, with sample values |
| /tessera demo | Demo mode: every block by category, sample values, style switcher (again to leave) |
| /tessera broker | DataBroker mode on or off |
| /tessera recover | Bring back blocks that stick out of the screen |
| /tessera bug | Report to copy into a bug report |
| /tessera help | The list of commands in the chat |

## Bugs and ideas

Type **/tessera bug**, copy the report and post it on the [GitHub issue tracker](https://github.com/Brainc3ll/Tessera/issues) (or in the comments here). Ideas are welcome too, especially about WoW Forever systems Tessera could show.

## About this project: how Tessera is made

Tessera is a collaboration between me, a player, and an AI.

**Me (Braincell1980).** I don't write code. Life never gave me the chance to learn programming, and AI finally lets me give free rein to my addon ideas. It is not "one prompt and the AI does everything": I also use the AI to learn quickly how things work and why (GitHub, CurseForge, WoW's Lua and its interface, what a clean release looks like) so I can make the decisions myself and understand what is done. What I do:
- I had the idea of Tessera and I decide what it does: every feature, block, option and layout comes from my requests or was approved by me.
- I choose the look: styles, colors, layouts, names, what goes in the menus.
- I test a lot, on WoW Forever: every version, with strange experiments, unusual placements and odd setups, to find the problems before you do.
- I try to think ahead, for every kind of player: other interfaces, other screens, other languages, other habits.
- I run the in-game checks (debug versions) used to find out how WoW Forever works, and I report bugs with screenshots.
- I review the texts, the French translation and the help.
- I decide when a version is published, and I manage the CurseForge and GitHub pages.

**Claude (an AI by Anthropic)** writes everything else, from my instructions:
- all the code of the addon (Lua), and the automatic tests that run it outside the game;
- the English and French texts: options, tooltips, help, changelog, this page;
- the release tools (GitHub workflows, CurseForge upload) and the debug versions;
- the banner images.

**What this means for you.** The code is checked by automatic tests and by my many tests in game, but it has not been reviewed line by line by a human programmer. Bugs can remain: please report them with `/tessera bug`. Developers are welcome to read the code (MIT license, on [GitHub](https://github.com/Brainc3ll/Tessera)) and to suggest improvements.

**Translations**: English and French are included. Other languages can be added by the community through the CurseForge localization tool.

---

# Tessera – Barres d'infos en mosaïque (français)

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

- **Plus de 40 blocs d'informations** : or (avec l'historique sur 7 jours et l'or de tes personnages), sacs (avec la valeur des objets gris), durabilité, FPS et latence (avec graphiques), heure locale, heure du serveur, XP et XP de repos, coordonnées, zone et sous-zone, amis, guilde, groupe, quêtes, réputation, monnaies, un bloc par métier (plus cuisine, secourisme et pêche), points de talent, pierre de foyer, courrier, chuchotements, composants de classe, munitions, niveau d'objet, vitesse, volume, mémoire des addons, instances, temps de jeu, objectif personnel, régénération de mana, statistiques, butin du groupe... en plus des blocs WoW Forever ci-dessus.
- **Des blocs qui se masquent** quand ils n'ont rien à montrer (courrier, chuchotements, réputation, camping...), dans une deuxième rangée sous la barre principale.
- **Des blocs lanceurs** créés à partir des boutons de la minicarte et du compartiment d'addons.
- **Support DataBroker** :
  - ajoute en bloc n'importe quel objet DataBroker de tes autres addons ;
  - partage les blocs de Tessera avec les addons d'affichage DataBroker ;
  - quand un tel addon est installé, Tessera passe en mode DataBroker (ton addon d'affichage montre les blocs de Tessera). Ce mode est expliqué à la première utilisation et se désactive à tout moment, pour utiliser les deux.
- **Fusion dans tous les sens**, avec guides d'alignement, aimantation (aussi aux cadres de Blizzard), annulation (Ctrl + Z), groupes figés, espaces (vide, ligne de séparation ou texte), échelle globale et par groupe. Les groupes peuvent être fusionnés, en tuiles avec de petits joints, ou séparés. Les groupes se collent aux bords de l'écran, et une barre peut s'étirer sur toute la largeur comme une barre des tâches. Le mode Édition de Blizzard peut aussi déverrouiller les blocs, et un clic ramène les blocs perdus hors de l'écran.
- **Remplacer un bloc sur place** : survole-le en mode placement, clique sur ses flèches, choisis un autre bloc : il apparaît exactement là, avec la même apparence, et rien d'autre ne bouge. Un bloc déjà affiché échange sa place avec lui, et les espaces vides des dispositions toutes prêtes sont faits pour être remplis ainsi. Une croix sur le bloc le masque.
- **Styles** assortis à FlareUI 2.x et 1.x, ElvUI, EllesmereUI et Blizzard, styles Carré (FlareUI, Blizzard Moderne, Blizzard Classique), plus Épuré et Transparent (seulement le texte et les icônes), et quatre styles fantasy : Pierre runique (seulement le texte, en noir et blanc), Grimoire, Parchemin et Arcanes. Quand une interface prise en charge est installée, Tessera montre son style sur des blocs d'exemple et te le propose ; il ne change jamais ton style tout seul. Les styles des interfaces se choisissent aussi sans l'addon, en imitation.
- **Réglages par bloc** : texte, cadre, icônes (même taille pour toutes, cadre carré ou rond, noir et blanc), opacité, barre de progression, couleurs de seuil, affichage au survol, alertes, actions du Maj + clic et du clic milieu, et la façon d'afficher la valeur (or avec ou sans icônes des pièces, arrondi ; places libres ou utilisées des sacs ; XP en pourcentage ou restante ; durabilité moyenne ; latence locale ou monde ; secondes ; décimales...).
- **Profils** : par compte ou par personnage, export / import en texte, dispositions toutes prêtes (barre en haut, Double barre avec une deuxième barre de blocs WoW Forever, barre en bas, colonne à gauche, compacte, autour des gryphons avec les blocs WoW Forever, et des dispositions façon barre des tâches ou barre de menus : Vitraux de Hurlevent, Rosace de la cathédrale, Vergers de Tirisfal, Gnomeregan), profil automatique en donjon / raid. « Tout réinitialiser » repart vraiment de zéro.
- **Partager un style ou une disposition** : exporte seulement l'allure ou seulement le placement en texte. À l'import, Tessera liste d'abord ce qui manque sur ton ordinateur (blocs d'un autre addon, polices ou cadres LibSharedMedia, blocs WoW Forever) et demande avant d'appliquer.
- **Mode Édition de Blizzard** : quand une barre de Tessera collée en haut ou en bas recouvre les barres d'action ou la minicarte, Tessera propose une copie de ta disposition du mode Édition avec la place qu'il faut ; ta disposition n'est jamais modifiée. Testé sur l'interface de Blizzard (Moderne, Classique) et sur FlareUI non modifié ; avec une autre interface, des résultats inattendus peuvent survenir.
- **Infobulles à ta façon** : plus grandes ou plus petites, ou seulement en tenant Alt.
- **Aide intégrée** : une visite rapide au premier lancement (essaie les dispositions toutes prêtes directement sur ton écran), un mode démo avec tous les blocs et un sélecteur de styles, un onglet Aide découpé en sujets courts, et une infobulle sur chaque option.
- **Accessibilité** : couleurs pour daltoniens, contraste renforcé, taille de texte minimale.

## Pour commencer

Tape **/tessera** (ou **/tes**) pour ouvrir les options. L'onglet **Aide** explique tout. Clique sur **Déverrouiller les blocs** pour les déplacer, puis sur **Verrouiller** quand tu as fini. Les blocs WoW Forever sont dans l'onglet **Blocs**.

| Commande | Effet |
|---|---|
| /tessera | Options |
| /tessera lock, /tessera unlock | Verrouiller ou déverrouiller les blocs |
| /tessera reset | Tout réinitialiser (tous les réglages, puis l'interface se recharge) |
| /tessera minimap | Afficher ou masquer le bouton de la minicarte |
| /tessera preview | Valeurs d'exemple dans tous les blocs (pour les captures) |
| /tessera preview forever | Les blocs WoW Forever seuls, avec des valeurs d'exemple |
| /tessera demo | Mode démo : tous les blocs par catégorie, valeurs d'exemple, sélecteur de styles (à nouveau pour quitter) |
| /tessera broker | Activer ou désactiver le mode DataBroker |
| /tessera recover | Ramener les blocs qui dépassent de l'écran |
| /tessera bug | Rapport à copier dans un signalement de bug |
| /tessera help | La liste des commandes dans la discussion |

## Bugs et idées

Tape **/tessera bug**, copie le rapport et poste-le sur [GitHub](https://github.com/Brainc3ll/Tessera/issues) (ou dans les commentaires ici). Les idées sont les bienvenues aussi, surtout sur les systèmes de WoW Forever que Tessera pourrait afficher.

## À propos du projet : comment Tessera est fait

Tessera est une collaboration entre moi, un joueur, et une IA.

**Moi (Braincell1980).** Je ne code pas. Les aléas de la vie ne m'ont pas permis d'apprendre la programmation, et l'IA me permet enfin de laisser libre cours à mes idées d'addons. Ce n'est pas « un prompt et l'IA fait tout » : je me sers aussi de l'IA pour apprendre vite comment les choses fonctionnent et pourquoi (GitHub, CurseForge, le Lua de WoW et son interface, les bonnes manières de faire une publication propre) afin de prendre moi-même les décisions et de comprendre ce qui est fait. Ce que je fais :
- J'ai eu l'idée de Tessera et je décide de ce qu'il fait : chaque fonction, bloc, option et disposition vient de mes demandes ou a été validé par moi.
- Je choisis l'allure : styles, couleurs, dispositions, noms, contenu des menus.
- Je teste beaucoup, sur WoW Forever : chaque version, avec des essais étranges, des placements inhabituels et des configurations improbables, pour trouver les problèmes avant toi.
- J'essaie de voir plus loin, pour tous les joueurs : autres interfaces, autres écrans, autres langues, autres habitudes.
- Je fais les relevés en jeu (versions debug) qui servent à comprendre le fonctionnement de WoW Forever, et je signale les bugs avec des captures.
- Je relis les textes, la traduction française et l'aide.
- Je décide quand une version est publiée, et je gère les pages CurseForge et GitHub.

**Claude (une IA d'Anthropic)** écrit tout le reste, à partir de mes consignes :
- tout le code de l'addon (Lua), et les tests automatiques qui le font tourner hors du jeu ;
- les textes en anglais et en français : options, infobulles, aide, changelog, cette page ;
- les outils de publication (workflows GitHub, envoi sur CurseForge) et les versions debug ;
- les images de la bannière.

**Ce que ça veut dire pour toi.** Le code est vérifié par des tests automatiques et par mes nombreux tests en jeu, mais il n'a pas été relu ligne par ligne par un programmeur. Des bugs peuvent rester : signale-les avec `/tessera bug`. Les développeurs sont les bienvenus pour lire le code (licence MIT, sur [GitHub](https://github.com/Brainc3ll/Tessera)) et proposer des améliorations.

**Traductions** : l'anglais et le français sont inclus. D'autres langues peuvent être ajoutées par la communauté avec l'outil de traduction de CurseForge.
