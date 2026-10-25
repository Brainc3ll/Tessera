# Tessera – Info Blocks That Snap Together for WoW Forever

**I play WoW Forever and test each version in game before I release it. I released 11 updates in the first two weeks, and your settings carry over from one version to the next.**

**Works out of the box: a ready-made bar shows up at first launch. Rearrange it in seconds if you like.**

Drag a block against another and they snap into one bar, like the tiles (*tesserae*) of a mosaic. Your gold, bags, durability, FPS, time and Legacy points sit where you put them, in the style of your UI: FlareUI, ElvUI, EllesmereUI or Blizzard.

40+ blocks, 19 styles, and launchers for your minimap buttons. English and French.

> **Made for WoW Forever.** I build and test Tessera on WoW Forever. Its new systems (Legacy, camping, Comprehension, PvP) are still young and may change, so a game update can break a block until Tessera catches up. Tell me when something looks wrong.

## How I look after Tessera

- Your layouts, styles and profiles carry over to each new version. If a change ever has to break them, Tessera warns you and converts them.
- Export texts from older versions still import.
- GitHub runs automatic checks on each change: static analysis, the API audit that addon reviewers use, a check against WoW Forever's own function list, a full run of the addon in English and French, and a robustness test of the Forever blocks.
- Each version has a full changelog, and the code is open (MIT) on [GitHub](https://github.com/Brainc3ll/Tessera).

I can't promise how many years I'll keep this up. Today, this is how I run it.

## Blocks made for WoW Forever

Tessera reads WoW Forever's own systems and gives each one a block:

- **Legacy points**: your points on the Legacy track, the next reward, every reward of the track, and your Legacy challenges completed per category (Classes, Crafting, PvP, Dungeons, Raids, Adventure). A click opens the Legacy panel.
- **Comprehension**: your skill for reading magical scrolls, and the scrolls in your bags. A click casts Scroll Comprehension.
- **Camping**: time left on your camp buffs, or your campfire kit's cooldown; it hides itself when you have neither. A click lights a campfire with your kit.
- **Honor**: your honor points (PvP ranks will follow in a later version).
- **Weapon skills**: read from Forever's skill list, with every skill in the tooltip.
- Profession, talent and Legacy blocks open Forever's own windows.

**Also in your DataBroker bar**: you can share the WoW Forever blocks, like every Tessera block, with **Titan Panel, ChocolateBar, Bazooka** and other DataBroker display addons. Use them on Tessera's own bars, in your favorite panel, or both.

## Features

- **More than 40 information blocks**: gold (with a 7-day history and your characters' gold; forget a deleted character from its menu), bags (with junk value), durability, FPS and latency (with graphs), local and server time, date, XP and rested XP, coordinates, zone and subzone, friends, guild, group, quests, reputation, currencies, one block per profession (plus cooking, first aid and fishing), talent points, hearthstone, mail, whispers, class reagents, ammo, item level, speed, volume, addon memory, instances, played time, a personal goal, mana regeneration, character stats, group loot... plus the WoW Forever blocks above.
- **Demo mode**: every block at once, sorted by category, with sample values, and a banner to switch the styles (or show them side by side, one per column) and hide the game's interface. Your layout comes back when you leave.
- **Blocks that hide themselves** when they have nothing to show (mail, whispers, reputation, camping...), in a second row under the main bar. A hidden block keeps its place: nothing else moves.
- **Launcher blocks** made from minimap buttons and addon compartment entries.
- **DataBroker support**:
  - add any DataBroker object of your other addons as a block;
  - share Tessera's blocks with DataBroker display addons;
  - when such an addon is installed, Tessera switches to a DataBroker mode (your display addon shows Tessera's blocks). A window explains this mode the first time, and you can turn it off at any time to use both.
- **Merging in every direction**, with alignment guides, snapping (also to Blizzard frames), undo (Ctrl + Z), frozen groups, spacers (empty, separator line or text), global and per-group scale. You choose how groups look: fused, tiles with small joints, or separate. Stick a group to a screen edge, or stretch a bar over the whole width. Blizzard's Edit Mode can unlock the blocks too, and one click brings back blocks lost off screen.
- **Replace a block in place**: hover it in placement mode, click its arrows, pick another block: it shows up exactly there, with the same look, and nothing else moves. A block already shown swaps places with it, and you fill the empty spacers of the ready-made layouts the same way. A cross on the block hides it.
- **19 styles**: matching FlareUI, ElvUI, EllesmereUI and Blizzard (Modern, Classic), Square styles, Clean, Transparent, four fantasy styles (Runestone: text only, black and white; Grimoire; Parchment; Arcane) and five made of the game's own frames (Royal seal, Ironforge, Runeblade, Ember, Sylvan). When a supported interface is installed, Tessera shows its style on sample blocks and offers it; it never changes your style on its own. You can also pick the interface styles without their addon, as an imitation.
- **Per-block settings**: text, frame, icons (same size for all, square or round frame, black and white), your class color on the text, background, border, icon frame and lines, opacity, progress bar, color thresholds, show on hover, alerts, Shift + click and middle-click actions, and how the value is shown (gold with or without coin icons, rounded; free or used bag slots; XP in percent or to go; average durability; latency home or world; seconds; decimals...).
- **Profiles**: per account or per character, export / import as text, ready-made layouts (top bar, Double bar with a second bar of WoW Forever blocks, bottom bar, left column, compact, around the gryphons with the WoW Forever blocks, Rampart Walk: a bar stuck to the top over the whole width, system information on the right), automatic dungeon / raid profile. "Reset everything" starts again from scratch.
- **Share a style or a layout**: export only the look or only the placement as text. On import, Tessera first lists what is missing on your computer (another addon's blocks, LibSharedMedia fonts or frames, WoW Forever blocks) and asks before applying.
- **In front of or behind Blizzard's frames**: Tessera never moves them. When blocks cover the action bars, the minimap or the buffs, you choose whether they stay in front or behind; placement mode (and Blizzard's Edit Mode) switches every block for a while to see what is underneath.
- **Tooltips your way**: bigger or smaller, or only while holding Alt.
- **Help built in**: a quick tour on first launch (try the ready-made layouts on your screen), a demo mode with every block and a style switcher, a Help tab split into short topics, and a tooltip on every option.
- **Accessibility**: bright or soft colors for the values and the class colors (or colorblind-friendly values), high contrast, minimum text size.

## Getting started

Type **/tessera** (or **/tes**) to open the options. The **Help** tab explains everything. Click **Unlock blocks** to move them, **Lock** when you are done. The WoW Forever blocks are in the **Blocks** tab.

| Command | Effect |
|---|---|
| /tessera | Options |
| /tessera lock, /tessera unlock | Lock or unlock the blocks |
| /tessera reset | Reset everything (all settings, then the interface reloads) |
| /tessera minimap | Show or hide the minimap button |
| /tessera preview | Sample values in every block (for screenshots) |
| /tessera demo | Demo mode: every block by category, sample values, style switcher (again to leave) |
| /tessera broker | DataBroker mode on or off |
| /tessera recover | Bring back blocks that stick out of the screen |
| /tessera bug | Report to copy into a bug report |
| /tessera help | The list of commands in the chat |

## Known issues
- A hidden block keeps its place: the blocks around it no longer close up. An option to let them close up again is being studied, carefully: that behaviour caused most of the placement bugs.
- Moving a block inside the second row of a bar can shift its neighbours: use the Replace arrows, or Ctrl + Z in placement mode.

## Bugs and ideas

Type **/tessera bug**, copy the report and post it on the [GitHub issue tracker](https://github.com/Brainc3ll/Tessera/issues) (or in the comments on CurseForge). Ideas are welcome too, especially about WoW Forever systems Tessera could show.

## About this project: how Tessera is made

Tessera is a collaboration between me, a player, and an AI.

**Me (Braincell1980).** I don't write code. Life never gave me the chance to learn programming, and AI now lets me give free rein to my addon ideas. I also use the AI to learn how things work and why (GitHub, CurseForge, WoW's Lua and its interface, what a clean release looks like), so I make the decisions myself and understand what goes into each version. What I do:
- I had the idea of Tessera and I decide what it does: every feature, block, option and layout comes from my requests or got my approval.
- I choose the look: styles, colors, layouts, names, what goes in the menus.
- I test a lot, on WoW Forever: every version, with strange experiments, unusual placements and odd setups, to find the problems before you do.
- I try to think ahead, for every kind of player: other interfaces, other screens, other languages, other habits.
- I run the in-game checks (debug versions) that show how WoW Forever works, and I report bugs with screenshots.
- I review the texts, the French translation and the help.
- I decide when a version goes out, and I manage the CurseForge, Wago and GitHub pages.

**Claude (an AI by Anthropic)** writes everything else, from my instructions:
- all the code of the addon (Lua), and the automatic tests that run it outside the game;
- the English and French texts: options, tooltips, help, changelog, this page;
- the release tools (GitHub workflows, CurseForge upload) and the debug versions;
- the logo (set in Marcellus, a free font) and the banner images.

**What this means for you.** Automatic tests and my own testing in game check the code, but no human programmer has reviewed it line by line. Bugs can remain: please report them with `/tessera bug`. Developers are welcome to read the code (MIT license, on [GitHub](https://github.com/Brainc3ll/Tessera)) and to suggest improvements.

**Translations**: Tessera comes in English and French. Players can add other languages with CurseForge's localization tool.

---

# Tessera – Des blocs d'infos qui s'emboîtent, pour WoW Forever (français)

**Je joue à WoW Forever et je teste chaque version en jeu avant de la publier. J'ai publié 11 mises à jour en deux semaines, et tes réglages passent d'une version à l'autre.**

**Prêt dès l'installation : une barre toute prête s'affiche au premier lancement. Réarrange-la en quelques secondes si tu veux.**

Pose un bloc contre un autre et ils s'emboîtent en une seule barre, comme les tesselles d'une mosaïque. Ton or, tes sacs, ta durabilité, tes FPS, l'heure et tes points d'héritage restent là où tu les mets, dans le style de ton interface : FlareUI, ElvUI, EllesmereUI ou Blizzard.

Plus de 40 blocs, 19 styles, et des lanceurs pour les boutons de ta minicarte. En anglais et en français.

> **Fait pour WoW Forever.** Je développe et teste Tessera sur WoW Forever. Ses nouveaux systèmes (héritage, camping, Compréhension, JcJ) sont encore jeunes et peuvent changer : une mise à jour du jeu peut casser un bloc jusqu'à ce que Tessera suive. Dis-moi quand quelque chose te paraît bizarre.

## Comment je suis Tessera

- Tes dispositions, styles et profils passent à chaque nouvelle version. Si un changement devait un jour les casser, Tessera te prévient et les convertit.
- Les textes d'export des anciennes versions s'importent toujours.
- GitHub lance des contrôles automatiques à chaque changement : analyse du code, l'audit de l'API qu'utilisent les relecteurs d'addons, une vérification avec la liste des fonctions de WoW Forever, un lancement complet de l'addon en anglais et en français, et un test de robustesse des blocs Forever.
- Chaque version a son journal des changements complet, et le code est ouvert (MIT) sur [GitHub](https://github.com/Brainc3ll/Tessera).

Je ne peux pas promettre combien d'années je tiendrai. Aujourd'hui, voilà comment je le fais tourner.

## Des blocs pensés pour WoW Forever

Tessera lit les systèmes propres à WoW Forever et donne un bloc à chacun :

- **Points d'héritage** : tes points sur le parcours Héritage, la prochaine récompense, toutes les récompenses du parcours et tes défis d'héritage accomplis par catégorie (Classes, Artisanat, JcJ, Donjons, Raids, Aventure). Un clic ouvre le panneau Héritage.
- **Compréhension** : ta compétence pour lire les parchemins magiques, et les parchemins dans tes sacs. Un clic lance Compréhension de parchemin.
- **Camping** : le temps restant de tes buffs de camp, ou la recharge de ton kit de feu de camp ; il se masque quand tu n'as ni l'un ni l'autre. Un clic allume un feu de camp avec ton kit.
- **Honneur** : tes points d'honneur (les rangs JcJ suivront dans une prochaine version).
- **Compétences d'armes** : lues dans la liste de compétences de Forever, toutes les compétences dans l'infobulle.
- Les blocs métiers, talents et héritage ouvrent les fenêtres propres à Forever.

**Aussi dans ta barre DataBroker** : comme tous les blocs de Tessera, tu peux partager les blocs WoW Forever avec **Titan Panel, ChocolateBar, Bazooka** et les autres addons d'affichage DataBroker. Utilise-les dans les barres de Tessera, dans ton panneau préféré, ou les deux.

## Fonctions

- **Plus de 40 blocs d'informations** : or (avec l'historique sur 7 jours et l'or de tes personnages ; un personnage supprimé s'oublie depuis son menu), sacs (avec la valeur des objets gris), durabilité, FPS et latence (avec graphiques), heure locale, heure du serveur, date, XP et XP de repos, coordonnées, zone et sous-zone, amis, guilde, groupe, quêtes, réputation, monnaies, un bloc par métier (plus cuisine, secourisme et pêche), points de talent, pierre de foyer, courrier, chuchotements, composants de classe, munitions, niveau d'objet, vitesse, volume, mémoire des addons, instances, temps de jeu, objectif personnel, régénération de mana, statistiques, butin du groupe... en plus des blocs WoW Forever ci-dessus.
- **Mode démo** : tous les blocs d'un coup, rangés par catégorie, avec des valeurs d'exemple, et un bandeau pour changer de style (ou les voir côte à côte, un par colonne) et masquer l'interface du jeu. Ta disposition revient quand tu le quittes.
- **Des blocs qui se masquent** quand ils n'ont rien à montrer (courrier, chuchotements, réputation, camping...), dans une deuxième rangée sous la barre principale. Un bloc masqué garde sa place : rien d'autre ne bouge.
- **Des blocs lanceurs** créés à partir des boutons de la minicarte et du compartiment d'addons.
- **Support DataBroker** :
  - ajoute en bloc n'importe quel objet DataBroker de tes autres addons ;
  - partage les blocs de Tessera avec les addons d'affichage DataBroker ;
  - quand un tel addon est installé, Tessera passe en mode DataBroker (ton addon d'affichage montre les blocs de Tessera). Une fenêtre explique ce mode la première fois, et tu peux le désactiver à tout moment pour utiliser les deux.
- **Fusion dans tous les sens**, avec guides d'alignement, aimantation (aussi aux cadres de Blizzard), annulation (Ctrl + Z), groupes figés, espaces (vide, ligne de séparation ou texte), échelle globale et par groupe. Tu choisis l'allure des groupes : fusionnés, en tuiles avec de petits joints, ou séparés. Colle un groupe à un bord de l'écran, ou étire une barre sur toute la largeur. Le mode Édition de Blizzard peut aussi déverrouiller les blocs, et un clic ramène les blocs perdus hors de l'écran.
- **Remplacer un bloc sur place** : survole-le en mode placement, clique sur ses flèches, choisis un autre bloc : il apparaît exactement là, avec la même apparence, et rien d'autre ne bouge. Un bloc déjà affiché échange sa place avec lui, et tu remplis de la même façon les espaces vides des dispositions toutes prêtes. Une croix sur le bloc le masque.
- **19 styles** : assortis à FlareUI, ElvUI, EllesmereUI et Blizzard (Moderne, Classique), styles Carré, Épuré, Transparent, quatre styles fantasy (Pierre runique : seulement le texte, en noir et blanc ; Grimoire ; Parchemin ; Arcanes) et cinq faits des cadres du jeu (Sceau royal, Forgefer, Lame runique, Braise, Sylvestre). Quand une interface prise en charge est installée, Tessera montre son style sur des blocs d'exemple et te le propose ; il ne change jamais ton style tout seul. Tu peux aussi choisir les styles des interfaces sans leur addon, en imitation.
- **Réglages par bloc** : texte, cadre, icônes (même taille pour toutes, cadre carré ou rond, noir et blanc), ta couleur de classe sur le texte, le fond, la bordure, le cadre de l'icône et les lignes, opacité, barre de progression, couleurs de seuil, affichage au survol, alertes, actions du Maj + clic et du clic milieu, et la façon d'afficher la valeur (or avec ou sans icônes des pièces, arrondi ; places libres ou utilisées des sacs ; XP en pourcentage ou restante ; durabilité moyenne ; latence locale ou monde ; secondes ; décimales...).
- **Profils** : par compte ou par personnage, export / import en texte, dispositions toutes prêtes (barre en haut, Double barre avec une deuxième barre de blocs WoW Forever, barre en bas, colonne à gauche, compacte, autour des gryphons avec les blocs WoW Forever, Chemin de ronde : une barre collée en haut sur toute la largeur, les infos système à droite), profil automatique en donjon / raid. « Tout réinitialiser » repart de zéro.
- **Partager un style ou une disposition** : exporte seulement l'allure ou seulement le placement en texte. À l'import, Tessera liste d'abord ce qui manque sur ton ordinateur (blocs d'un autre addon, polices ou cadres LibSharedMedia, blocs WoW Forever) et demande avant d'appliquer.
- **Devant ou derrière les cadres de Blizzard** : Tessera ne les déplace jamais. Quand des blocs recouvrent les barres d'action, la minicarte ou les buffs, tu choisis s'ils restent devant ou derrière ; le mode placement (et le mode Édition de Blizzard) bascule tous les blocs un moment pour voir ce qu'il y a dessous.
- **Infobulles à ta façon** : plus grandes ou plus petites, ou seulement en tenant Alt.
- **Aide intégrée** : une visite rapide au premier lancement (essaie les dispositions toutes prêtes sur ton écran), un mode démo avec tous les blocs et un sélecteur de styles, un onglet Aide découpé en sujets courts, et une infobulle sur chaque option.
- **Accessibilité** : couleurs vives ou adoucies pour les valeurs et les couleurs de classe (ou valeurs pour daltoniens), contraste renforcé, taille de texte minimale.

## Pour commencer

Tape **/tessera** (ou **/tes**) pour ouvrir les options. L'onglet **Aide** explique tout. Clique sur **Déverrouiller les blocs** pour les déplacer, puis sur **Verrouiller** quand tu as fini. Les blocs WoW Forever sont dans l'onglet **Blocs**.

| Commande | Effet |
|---|---|
| /tessera | Options |
| /tessera lock, /tessera unlock | Verrouiller ou déverrouiller les blocs |
| /tessera reset | Tout réinitialiser (tous les réglages, puis l'interface se recharge) |
| /tessera minimap | Afficher ou masquer le bouton de la minicarte |
| /tessera preview | Valeurs d'exemple dans tous les blocs (pour les captures) |
| /tessera demo | Mode démo : tous les blocs par catégorie, valeurs d'exemple, sélecteur de styles (à nouveau pour quitter) |
| /tessera broker | Activer ou désactiver le mode DataBroker |
| /tessera recover | Ramener les blocs qui dépassent de l'écran |
| /tessera bug | Rapport à copier dans un signalement de bug |
| /tessera help | La liste des commandes dans la discussion |

## Problèmes connus
- Un bloc masqué garde sa place : les blocs autour ne se resserrent plus. Une option pour qu'ils se resserrent à nouveau est à l'étude, avec prudence : ce fonctionnement causait la plupart des bugs de placement.
- Déplacer un bloc à l'intérieur de la deuxième rangée d'une barre peut décaler ses voisins : utilise les flèches Remplacer, ou Ctrl + Z en mode placement.

## Bugs et idées

Tape **/tessera bug**, copie le rapport et poste-le sur [GitHub](https://github.com/Brainc3ll/Tessera/issues) (ou dans les commentaires sur CurseForge). Les idées sont les bienvenues aussi, surtout sur les systèmes de WoW Forever que Tessera pourrait afficher.

## À propos du projet : comment Tessera est fait

Tessera est une collaboration entre moi, un joueur, et une IA.

**Moi (Braincell1980).** Je ne code pas. Les aléas de la vie ne m'ont pas permis d'apprendre la programmation, et l'IA me permet maintenant de laisser libre cours à mes idées d'addons. Je me sers aussi de l'IA pour apprendre comment les choses fonctionnent et pourquoi (GitHub, CurseForge, le Lua de WoW et son interface, les bonnes manières de faire une publication propre) : je prends moi-même les décisions et je comprends ce qui entre dans chaque version. Ce que je fais :
- J'ai eu l'idée de Tessera et je décide de ce qu'il fait : chaque fonction, bloc, option et disposition vient de mes demandes ou a reçu mon accord.
- Je choisis l'allure : styles, couleurs, dispositions, noms, contenu des menus.
- Je teste beaucoup, sur WoW Forever : chaque version, avec des essais étranges, des placements inhabituels et des configurations improbables, pour trouver les problèmes avant toi.
- J'essaie de voir plus loin, pour tous les joueurs : autres interfaces, autres écrans, autres langues, autres habitudes.
- Je fais les relevés en jeu (versions debug) qui servent à comprendre le fonctionnement de WoW Forever, et je signale les bugs avec des captures.
- Je relis les textes, la traduction française et l'aide.
- Je décide quand une version sort, et je gère les pages CurseForge, Wago et GitHub.

**Claude (une IA d'Anthropic)** écrit tout le reste, à partir de mes consignes :
- tout le code de l'addon (Lua), et les tests automatiques qui le font tourner hors du jeu ;
- les textes en anglais et en français : options, infobulles, aide, changelog, cette page ;
- les outils de publication (workflows GitHub, envoi sur CurseForge) et les versions debug ;
- le logo (en Marcellus, une police libre) et les images de la bannière.

**Ce que ça veut dire pour toi.** Des tests automatiques et mes propres tests en jeu vérifient le code, mais aucun programmeur ne l'a relu ligne par ligne. Des bugs peuvent rester : signale-les avec `/tessera bug`. Les développeurs sont les bienvenus pour lire le code (licence MIT, sur [GitHub](https://github.com/Brainc3ll/Tessera)) et proposer des améliorations.

**Traductions** : Tessera est en anglais et en français. Les joueurs peuvent ajouter d'autres langues avec l'outil de traduction de CurseForge.
