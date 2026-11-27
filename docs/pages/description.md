# Tessera: little info blocks you put anywhere

Gold, bags, FPS, Legacy points... each in its own little block. Put a block anywhere on your screen, or drop it against another one and they stick together into a bar. A bar shows up at first launch, so you can start from there.

Made by a player who can't code and an AI that can't play (yet). So I test it a lot.

## At a glance

- Over 50 blocks: gold, bags, durability, FPS and latency, time, XP, quests, reputation, professions and more. Most let you choose what they show, in the block and in its tooltip.
- Made for WoW Forever, with blocks for its own systems: Legacy points, talents (points per tree, change spec), Comprehension, camping, honor, weapon skills.
- 31 styles to match your UI: Blizzard, FlareUI, ElvUI, EllesmereUI, DaylightUI, fantasy looks made from the game's own frames and four new styles with rounded corners. Pick yours in a gallery of real blocks, sorted by family. The whole look sits in one box.
- Place a bar to the exact pixel with the arrow keys. Style a whole bar at once.
- DataBroker both ways: your Data Broker plugins become blocks, or Tessera's blocks go into Titan Panel, Bazooka or Arcana (formerly ChocolateBar).
- Guild member list: hover the Guild block to see who is online, in a list that looks like a tooltip. Click a name to whisper, right-click to invite. Search field and scroll bar for big guilds.
- What's new: one line per new thing in the About tab, with a Show me button that opens the setting.
- Group list: hover the Group block to see your party or raid members. Click a name to whisper.
- Friends list: hover the Friends block to see your WoW and Battle.net friends online. Click a name to whisper, right-click to invite.
- Volume list: set every sound channel with a click and keep up to four named presets.
- Whispers history: the last 5, 10 or 20 whispers in a list you can click to reply. Right-click pins one, Ctrl + click deletes it, Clear removes the loose ones.
- Streamer mode hides, as you choose, other players' names, your other characters, your guild and your gold.
- Accessibility: high contrast, fewer animations, a window shadow you can turn off, a minimum text size and six reading fonts.
- Language list: Tessera follows your game language, or you pick English, French, German, Spanish or Portuguese.
- An options window in stone and metal, the game's rock and the metal of its dialogs in your style's colors, with a search and a help panel for each setting. Each block's settings sit in three tabs: Content, Appearance and Behaviour. English, French, German, Spanish and Brazilian Portuguese.
- Your layouts and profiles carry over between versions.

Type **/tessera** for the options, or **/tessera demo** to see every block at once. The [README on GitHub](https://github.com/Brainc3ll/Tessera#readme) lists every block, command and setting.

## Memory, FPS and refresh rates

An addon manager counts live data plus garbage that Lua has not collected yet, so the figure for Tessera rises and falls. The game never frees a window an addon has built, so the options window stays in memory once you open it. Memory use does not lower your frame rate by itself; you feel the pauses when a lot of garbage is collected at once, and 1.5.1 removes the main ones. Each block updates at its own pace, from four times a second (coordinates) to once a minute (honor, Legacy), or only on a game event. Hidden blocks do not update. The README lists every block.

## Made by a player and an AI

I don't write code. Claude (an AI by Anthropic) writes all of it, from my instructions, along with the tests and most texts. I decide what Tessera does, I test it in game and I review the French. No human programmer reads the code line by line ([AI Code Rating](https://aicoderating.com): E4d), so bugs can remain. Claude translated the German, Spanish and Brazilian Portuguese texts and nobody has reviewed them yet: you can [correct them or add your language](https://github.com/Brainc3ll/Tessera/blob/main/docs/TRANSLATING.md).

Type **/tessera bug**, copy the report and post it on [GitHub](https://github.com/Brainc3ll/Tessera/issues) or in the comments here. Tessera is free and open source (MIT), with no premium version.

---

# Tessera : des petits blocs d'infos à placer où tu veux (français)

Or, sacs, FPS, points d'Héritage... chacun dans son petit bloc. Pose un bloc où tu veux sur ton écran, ou colle-le contre un autre : ils forment une barre. Une barre s'affiche au premier lancement, tu peux partir de là.

Fait par un joueur qui ne sait pas coder et une IA qui ne sait pas jouer (pour le moment). Alors je teste beaucoup.

## En un coup d'œil

- Plus de 50 blocs : or, sacs, durabilité, FPS et latence, heure, XP, quêtes, réputation, métiers et plus encore. La plupart te laissent choisir ce qu'ils affichent, dans le bloc et dans leur infobulle.
- Fait pour WoW Forever, avec des blocs pour ses systèmes à lui : points d'Héritage, Compréhension, Camping, honneur, compétences d'armes.
- 31 styles assortis à ton interface : Blizzard, FlareUI, ElvUI, EllesmereUI, DaylightUI, des looks fantasy du jeu, quatre styles arrondis. Choisis-le dans une galerie de vrais blocs. Toute l'allure en un cadre.
- Place une barre au pixel près avec les flèches du clavier. Donne un style à toute une barre d'un coup.
- DataBroker dans les deux sens : les plugins Data Broker de tes autres addons deviennent des blocs, ou les blocs de Tessera vont dans Titan Panel, Bazooka ou Arcana (ex-ChocolateBar).
- Liste des membres de la guilde : survole le bloc Guilde pour voir qui est en ligne. Clique sur un nom pour chuchoter, clic droit pour inviter. Recherche et barre de défilement pour les grosses guildes.
- « Quoi de neuf ? » : une ligne par nouveauté dans l'onglet À propos, avec un bouton Montre-moi qui ouvre le réglage.
- Liste du groupe : survole le bloc Groupe pour voir les membres de ton groupe ou raid. Clique sur un nom pour chuchoter.
- Liste des amis : survole le bloc Amis pour voir tes amis du jeu et Battle.net en ligne. Clique sur un nom pour chuchoter, clic droit pour inviter.
- Liste du volume : règle chaque canal d'un clic et garde jusqu'à quatre préréglages nommés.
- Historique des chuchotements : les 5, 10 ou 20 derniers dans une liste pour répondre. Clic droit épingle, Ctrl + clic supprime, Vider retire les autres.
- Le mode streamer cache, au choix, les noms des autres joueurs, tes personnages, ta guilde et ton or.
- Accessibilité : contraste élevé, moins d'animations, ombre des fenêtres à couper, texte minimal, six polices. Langue au choix.
- Une fenêtre d'options en pierre et métal aux couleurs de ton style, avec une recherche et un panneau d'aide pour chaque réglage. Les réglages de chaque bloc tiennent en trois onglets : Contenu, Apparence et Comportement. Anglais, français, allemand, espagnol et portugais du Brésil.
- Tes dispositions et tes profils passent d'une version à l'autre.

Tape **/tessera** pour les options, ou **/tessera demo** pour voir tous les blocs d'un coup. Le [README sur GitHub](https://github.com/Brainc3ll/Tessera#readme) liste chaque bloc, commande et réglage.

## Mémoire, FPS et rythmes de mise à jour

Un gestionnaire d'addons compte les données vivantes et les déchets que Lua n'a pas encore ramassés : le chiffre de Tessera monte et descend. Le jeu ne libère jamais une fenêtre construite par un addon, donc la fenêtre d'options reste en mémoire une fois ouverte. La mémoire utilisée ne fait pas baisser les FPS à elle seule ; tu sens les pauses quand beaucoup de déchets sont ramassés d'un coup, et la 1.5.1 supprime les principales. Chaque bloc se met à jour à son rythme, de quatre fois par seconde (coordonnées) à une fois par minute (honneur, Legacy), ou seulement sur un événement du jeu. Les blocs masqués ne se mettent pas à jour. Le README liste chaque bloc.

## Fait par un joueur et une IA

Je ne code pas. Claude (une IA d'Anthropic) écrit tout le code à partir de mes consignes, ainsi que les tests et la plupart des textes. Je décide de ce que fait Tessera, je le teste en jeu et je relis le français. Aucun programmeur humain ne relit le code ligne par ligne ([AI Code Rating](https://aicoderating.com) : E4d), donc des bugs peuvent rester. Claude a traduit l'allemand, l'espagnol et le portugais du Brésil et personne ne les a encore relus : tu peux [les corriger ou ajouter ta langue](https://github.com/Brainc3ll/Tessera/blob/main/docs/TRANSLATING.md).

Tape **/tessera bug**, copie le rapport et poste-le sur [GitHub](https://github.com/Brainc3ll/Tessera/issues) ou dans les commentaires ici. Tessera est gratuit et open source (MIT), sans version premium.
