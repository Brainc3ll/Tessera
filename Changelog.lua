local _, ns = ...

-- ========================================================================
-- Changelog.lua: version history shown in the options "About" tab (Changelog topic)
-- ========================================================================
-- Newest entry first. Each entry has a version, a date (YYYY-MM-DD) and the
-- list of changes in English (en) and French (fr). Players see the French
-- list when their game is in French, the English one otherwise.
-- Keep CHANGELOG.md (for GitHub and CurseForge) in sync with this file.

ns.CHANGELOG = {
    {
        version = "1.0.0-rc5",
        date = "", -- set when the version is published
        en = {
            "Placement mode: the names under the blocks no longer overlap each other nor go off screen "
                .. "(Compact and Left column layouts); when room is short, a name is shortened to its block's width.",
            "New ready-made layout \"Modern Forever\" (Look tab): the top bar with the basics, and a second bar "
                .. "always shown with WoW Forever's blocks (Legacy, Comprehension, Camping, Honor, weapon skills).",
            "Placement: a single block dropped against a side already taken slips in between (the block that was "
                .. "there moves along), so a block taken out of a bar can be put back in its place. Nothing docks any "
                .. "more on the side of a bar where its second row hangs (that mixed both groups). A second row "
                .. "dragged and dropped back against its bar keeps hanging there, centered and full width.",
            "Blocks made for WoW Forever's own systems are more robust: if the game changes at release, they "
                .. "show nothing rather than an error.",
            "Help: where to find the blocks hidden at first, tooltips while holding Alt, /roll on the group loot "
                .. "block, the stat shown on the stats block; /tessera help is in the chat command list.",
            "Help split into small texts: easier to translate with CurseForge's tool, and a change to one line "
                .. "no longer asks translators to redo the whole help.",
            "FlareUI styles (2.x, 1.x and Square): the font of FlareUI's XP bar, Arial Narrow by default, or the "
                .. "one picked in FlareUI's settings. Blocks already in a FlareUI style keep their font: pick the style "
                .. "again in the Look tab to get it.",
            "Development commands removed from released versions: only the commands useful to players remain.",
            "Code checked with Ketho's WoW API annotations (the tool addon reviewers use): no deprecated function, "
                .. "no unknown global; old fallbacks for other game versions removed.",
        },
        fr = {
            "Mode placement : les noms sous les blocs ne se chevauchent plus et ne sortent plus de l'écran "
                .. "(dispositions Compacte et Colonne à gauche) ; quand la place manque, un nom est raccourci à la "
                .. "largeur de son bloc.",
            "Nouvelle disposition toute prête « Moderne Forever » (onglet Apparence) : la barre du haut avec "
                .. "l'essentiel, et une deuxième barre toujours affichée avec les blocs WoW Forever (héritage, "
                .. "Compréhension, Camping, Honneur, compétences d'armes).",
            "Placement : un bloc seul posé contre un côté déjà pris se glisse entre les deux (le bloc qui était là se "
                .. "décale) : un bloc sorti d'une barre peut être remis à sa place. Plus rien ne s'accroche sur le côté "
                .. "d'une barre où pend sa deuxième rangée (les deux groupes se mélangeaient). Une deuxième rangée "
                .. "déplacée puis reposée contre sa barre y reste accrochée, centrée et sur toute la largeur.",
            "Les blocs des systèmes propres à WoW Forever sont plus solides : si le jeu change à sa sortie, ils "
                .. "n'affichent rien plutôt qu'une erreur.",
            "Aide : où trouver les blocs masqués au départ, infobulles en tenant Alt, /roll sur le bloc butin du "
                .. "groupe, statistique affichée du bloc statistiques ; /tessera help dans la liste des commandes.",
            "Aide découpée en petits textes : plus facile à traduire avec l'outil de CurseForge, et changer une ligne "
                .. "ne demande plus aux traducteurs de refaire toute l'aide.",
            "Styles FlareUI (2.x, 1.x et Carré) : la police de la barre d'XP de FlareUI, Arial Narrow par défaut, ou "
                .. "celle choisie dans les réglages de FlareUI. Les blocs déjà en style FlareUI gardent leur police : "
                .. "choisis à nouveau le style dans l'onglet Apparence pour l'avoir.",
            "Commandes de développement retirées des versions publiées : il ne reste que les commandes utiles aux joueurs.",
            "Code vérifié avec les annotations de l'API WoW de Ketho (l'outil des relecteurs d'addons) : aucune "
                .. "fonction obsolète, aucune variable globale inconnue ; anciens secours pour d'autres versions du jeu retirés.",
        },
    },
    {
        version = "1.0.0-rc4",
        date = "2026-10-13",
        en = {
            "Three new blocks (hidden by default, add them from the Blocks tab): Mana regeneration (per 5 seconds, "
                .. "the value while casting in combat), Character stats (the stat of your choice on the block, all of them "
                .. "in the tooltip) and Group loot (loot method, threshold, master looter; click: /roll).",
            "Durability tooltip: the repair cost of your equipment.",
            "General tab, new Tooltips section: tooltip size, and tooltips only while holding Alt.",
            "New logo, drawn in high definition: sharp in the addon list, on the minimap button and on large screens.",
            "About tab: a fuller account of how Tessera is made, what the author does and what the AI does.",
        },
        fr = {
            "Trois nouveaux blocs (masqués par défaut, à ajouter depuis l'onglet Blocs) : Régénération de mana (toutes "
                .. "les 5 secondes, la valeur en incantation pendant un combat), Statistiques (la statistique de ton choix "
                .. "sur le bloc, toutes dans l'infobulle) et Butin du groupe (mode de butin, seuil, responsable du butin ; "
                .. "clic : /roll).",
            "Infobulle de durabilité : le coût de réparation de ton équipement.",
            "Onglet Général, nouvelle section Infobulles : taille des infobulles, et infobulles seulement en tenant Alt.",
            "Nouveau logo, dessiné en haute définition : net dans la liste des addons, sur le bouton de la minicarte "
                .. "et sur les grands écrans.",
            "Onglet À propos : un récit plus complet de la façon dont Tessera est fait, ce que fait l'auteur et ce que "
                .. "fait l'IA.",
        },
    },
    {
        version = "1.0.0-rc3",
        date = "2026-10-11",
        en = {
            "New ready-made layout \"Around the gryphons\": two groups in the bottom corners of the screen, on both "
                .. "sides of the action bars, WoW Forever blocks included. Ready-made layouts are now picked in a list "
                .. "(Look tab), with a description of each one.",
            "New \"Replace with...\" (quick menu, or next to the block list in the Blocks tab): puts another block "
                .. "exactly in a block's place, with its look, without moving the others; or swaps two shown blocks.",
            "Screen edges: drop a group against an edge and Tessera offers to stick it there (no border on that "
                .. "side, stays put on any screen). Along the top or bottom, a bar can be stretched over the whole "
                .. "width: spacer blocks fill the room (blocks on the left, center, right or spread) and the blocks "
                .. "keep their size. Setting in the Look tab (ask, always, never).",
            "New ready-made layouts in the spirit of desktop taskbars and menu bars: Stormwind Stained Glass, Cathedral "
                .. "Rose Window, Tirisfal Orchard and Gnomeregan, with the "
                .. "clock, FPS, latency and volume where you expect them.",
            "New \"Add a spacer\" (quick menu): an empty block on the left, right, above or below a block, slipped in "
                .. "between if another block is already there; in a stretched bar it takes room from the other spacers.",
            "New styles \"FlareUI Square\", \"Blizzard Modern Square\" and \"Blizzard Classic Square\": square corners, a "
                .. "plain dark background, a thin border and a thin line between merged blocks. The line is also an option "
                .. "of every style (Frame tab, Separators), on by default in the layouts showing the WoW Forever blocks.",
            "New Look tab: the style of the blocks, how groups look, screen edges, ready-made layouts and sharing are "
                .. "now in one place (they were spread over the General and Profiles tabs). The options window is larger "
                .. "and roomier, and shrinks on small screens so blocks still fit on both sides of it.",
            "Group look (Look tab): fused (one bar, one border, as before), tiles (each block keeps its frame, with a "
                .. "small adjustable joint, like a mosaic) or separate (each block keeps its whole frame and blocks no "
                .. "longer merge; replaces the \"Merge blocks\" option). A single group can have its own look: quick "
                .. "menu, Group look. Existing profiles keep their look.",
            "Share only a style (the look) or only a layout (the placement) as text, from the Look tab. One import "
                .. "window reads a style, a layout or a whole profile, and first lists what is missing on this computer "
                .. "(another addon's blocks, LibSharedMedia fonts or frames, the interface a style matches, WoW Forever "
                .. "blocks): those parts are skipped or replaced by the default font or frame.",
            "Quick tour: seven short steps on first launch, and again from the Help tab. The help was reviewed for the "
                .. "new tab, and the placement banner and the tooltip of unlocked blocks now mention what the quick menu "
                .. "offers (add a spacer, replace with..., group look).",
            "Round minimap button: click for the options, right-click to lock or unlock the blocks, drag it around "
                .. "the minimap. With FlareUI, Tessera stays in FlareUI's addon bag instead (no duplicate). "
                .. "/tessera minimap still hides or shows it.",
            "Blizzard's Edit Mode: when a Tessera bar stuck to the top or bottom covers Blizzard frames (action bars, "
                .. "menu, minimap...), Tessera offers a copy of your Edit Mode layout, \"My layout (Tessera 1)\", where "
                .. "only those frames move, and activates it. Your layout is never changed. \"Back to my layout\" and "
                .. "\"Delete the copies\" (only Tessera's unchanged copies, never a layout of yours) are in the Look tab. "
                .. "Tested on Blizzard's interface (Modern, Classic) and FlareUI unchanged; with FlareUI, its own frames "
                .. "go back to their default place in the copy (Tessera warns before). With another interface, results "
                .. "may be unexpected.",
            "New blocks and ready-made layouts are drawn above Blizzard's action bars (layer \"High\"), so a bar "
                .. "along the bottom passes in front of the gryphons; the layer can still be changed (Blocks tab, Display). "
                .. "Existing blocks keep their layer.",
            "The Broker tab becomes the DataBroker tab, in two parts: \"Plugins as blocks\" (other addons' DataBroker "
                .. "plugins as Tessera blocks, moved from the Launchers tab) and \"Sharing and mode\" (sharing Tessera's "
                .. "blocks with Titan Panel, Bazooka..., DataBroker mode). The Launchers tab keeps the minimap buttons.",
            "Help rewritten with one topic per tab (Blocks, Look, Blizzard's Edit Mode, General, Launchers, DataBroker, "
                .. "Profiles, Help and About), tooltips updated, and /tessera preview forever (the WoW Forever blocks with "
                .. "sample values) added to the help and the command list. Button texts too long for their button (in any "
                .. "language) are made smaller instead of spilling out.",
            "Fix: choosing a ready-made layout showed the \"reset everything\" message in the chat; it now says "
                .. "which layout was applied.",
            "Fix: switching to another layout or profile could raise a Lua error (\"Cannot anchor to a region "
                .. "dependent on it\") when two blocks swapped places.",
            "Fix: a column stuck to the bottom of the screen piled up its blocks; the whole column now stays "
                .. "visible above the edge.",
            "Fix: spacers did not follow the layer (strata), opacity or hide options chosen for all blocks, and could "
                .. "stay hidden behind the action bars.",
            "Releases: the English and French strings are sent to CurseForge's localization tool automatically, "
                .. "and community translations are added to the addon.",
        },
        fr = {
            "Nouvelle disposition toute prête « Autour des gryphons » : deux groupes dans les coins bas de l'écran, "
                .. "de part et d'autre des barres d'action, blocs WoW Forever compris. Les dispositions toutes prêtes "
                .. "se choisissent maintenant dans une liste (onglet Apparence), avec la description de chacune.",
            "Nouveau « Remplacer par... » (menu rapide, ou à côté de la liste des blocs dans l'onglet Blocs) : met un "
                .. "autre bloc exactement à la place d'un bloc, avec son apparence, sans bouger les autres ; ou échange "
                .. "deux blocs affichés.",
            "Bords de l'écran : lâche un groupe contre un bord et Tessera propose de l'y coller (plus de bordure de "
                .. "ce côté, il reste en place sur tous les écrans). En haut ou en bas, une barre peut être étirée sur "
                .. "toute la largeur : des blocs espace comblent la place (blocs à gauche, au centre, à droite ou "
                .. "répartis) et les blocs gardent leur taille. Réglage dans l'onglet Apparence (demander, toujours, jamais).",
            "Nouvelles dispositions toutes prêtes façon barres des tâches et barres de menus : Vitraux de Hurlevent, "
                .. "Rosace de la cathédrale, Vergers de Tirisfal et Gnomeregan, avec "
                .. "l'horloge, les FPS, la latence et le volume là où on les attend.",
            "Nouveau « Ajouter un espace » (menu rapide) : un bloc vide à gauche, à droite, au-dessus ou en dessous "
                .. "d'un bloc, glissé entre les deux si un autre bloc est déjà là ; dans une barre étirée, il prend la "
                .. "place sur les autres espaces.",
            "Nouveaux styles « FlareUI Carré », « Blizzard Moderne Carré » et « Blizzard Classique Carré » : coins "
                .. "carrés, fond sombre uni, bordure fine et fine ligne entre les blocs fusionnés. Cette ligne est aussi une "
                .. "option de tous les styles (onglet Cadre, Séparateurs), activée par défaut dans les dispositions qui "
                .. "mettent en avant les blocs WoW Forever.",
            "Nouvel onglet Apparence : le style des blocs, l'apparence des groupes, les bords de l'écran, les "
                .. "dispositions toutes prêtes et le partage sont maintenant au même endroit (ils étaient répartis entre "
                .. "les onglets Général et Profils). La fenêtre d'options est plus grande et plus aérée, et rétrécit sur "
                .. "les petits écrans pour laisser la place à des blocs de chaque côté.",
            "Apparence des groupes (onglet Apparence) : fusionnés (une barre, une bordure, comme avant), tuiles "
                .. "(chaque bloc garde son cadre, avec un petit joint réglable, comme une mosaïque) ou séparés (chaque "
                .. "bloc garde tout son cadre et les blocs ne fusionnent plus ; remplace l'option « Fusionner les "
                .. "blocs »). Un groupe peut avoir sa propre apparence : menu rapide, Apparence du groupe. Les profils "
                .. "existants gardent leur apparence.",
            "Partager seulement un style (l'allure) ou seulement une disposition (le placement) en texte, depuis "
                .. "l'onglet Apparence. Une seule fenêtre d'import lit un style, une disposition ou un profil entier, et "
                .. "liste d'abord ce qui manque sur cet ordinateur (blocs d'un autre addon, polices ou cadres "
                .. "LibSharedMedia, interface assortie à un style, blocs WoW Forever) : ces éléments sont ignorés ou "
                .. "remplacés par la police ou le cadre par défaut.",
            "Visite rapide : sept courtes étapes au premier lancement, et à nouveau depuis l'onglet Aide. L'aide a été "
                .. "revue pour le nouvel onglet, et le bandeau de placement et l'infobulle des blocs déverrouillés "
                .. "indiquent maintenant ce que propose le menu rapide (ajouter un espace, remplacer par..., apparence du "
                .. "groupe).",
            "Bouton rond sur la minicarte : clic pour les options, clic droit pour verrouiller ou déverrouiller les "
                .. "blocs, glisser pour le déplacer autour de la minicarte. Avec FlareUI, Tessera reste dans le sac à "
                .. "boutons de FlareUI à la place (pas de doublon). /tessera minimap le masque ou l'affiche toujours.",
            "Mode Édition de Blizzard : quand une barre de Tessera collée en haut ou en bas recouvre des cadres de "
                .. "Blizzard (barres d'action, menu, minicarte...), Tessera propose une copie de ta disposition du mode "
                .. "Édition, « Ma dispo (Tessera 1) », où seuls ces cadres bougent, et l'active. Ta disposition n'est "
                .. "jamais modifiée. « Revenir à ma disposition » et « Supprimer les copies » (seulement les copies de "
                .. "Tessera non modifiées, jamais une disposition à toi) sont dans l'onglet Apparence. Testé sur "
                .. "l'interface de Blizzard (Moderne, Classique) et FlareUI non modifié ; avec FlareUI, ses propres "
                .. "cadres reviennent à leur place par défaut dans la copie (Tessera prévient avant). Avec une autre "
                .. "interface, des résultats inattendus peuvent survenir.",
            "Les nouveaux blocs et les dispositions toutes prêtes s'affichent au-dessus des barres d'action de "
                .. "Blizzard (plan « Haut ») : une barre en bas passe devant les gryphons ; le plan se change toujours "
                .. "(onglet Blocs, Affichage). Les blocs existants gardent leur plan.",
            "L'onglet Broker devient l'onglet DataBroker, en deux parties : « Plugins en blocs » (les plugins DataBroker "
                .. "des autres addons en blocs Tessera, déplacés depuis l'onglet Lanceurs) et « Partage et mode » (partager "
                .. "les blocs de Tessera avec Titan Panel, Bazooka..., mode DataBroker). L'onglet Lanceurs garde les "
                .. "boutons de la minicarte.",
            "Aide réécrite avec un sujet par onglet (Blocs, Apparence, Mode Édition de Blizzard, Général, Lanceurs, "
                .. "DataBroker, Profils, Aide et À propos), infobulles mises à jour, et /tessera preview forever (les blocs "
                .. "WoW Forever avec des valeurs d'exemple) ajouté à l'aide et à la liste des commandes. Les textes trop "
                .. "longs pour leur bouton (dans toutes les langues) sont réduits au lieu de déborder.",
            "Correction : choisir une disposition toute prête affichait dans la discussion le message de « tout "
                .. "réinitialiser » ; il indique maintenant la disposition appliquée.",
            "Correction : changer de disposition ou de profil pouvait provoquer une erreur Lua (« Cannot anchor to "
                .. "a region dependent on it ») quand deux blocs échangeaient leur place.",
            "Correction : une colonne collée en bas de l'écran empilait ses blocs ; toute la colonne reste maintenant "
                .. "visible au-dessus du bord.",
            "Correction : les espaces ne suivaient pas le plan d'affichage (strata), l'opacité ni les options de "
                .. "masquage choisis pour tous les blocs, et pouvaient rester cachés derrière les barres d'action.",
            "Publications : l'anglais et le français sont envoyés automatiquement à l'outil de traduction de "
                .. "CurseForge, et les traductions de la communauté sont ajoutées à l'addon.",
        },
    },
    {
        version = "1.0.0-rc2",
        date = "2026-10-11",
        en = {
            "When an interface with a matching style is installed (FlareUI 1.x or 2.x, ElvUI, EllesmereUI), a "
                .. "window shows that style on sample blocks and offers it. Tessera no longer changes the style "
                .. "of your blocks on its own.",
            "DataBroker mode: turning it off now only applies to the display addon detected at that moment "
                .. "(another one installed later offers the mode again, with its explanation window). The "
                .. "Broker tab shows the current state and can go back to the automatic choice.",
            "Opening Blizzard's Edit Mode also unlocks the blocks (option in the General tab).",
            "New \"Bring blocks back on screen\" button and /tessera recover command, for groups that stick "
                .. "out of the screen.",
            "Icons (Frame tab): the same size for every block, a square or round frame with a thin border "
                .. "(the color you want), and black and white, for Tessera's blocks, launchers and DataBroker blocks. "
                .. "The Transparent style uses square icons of the same size by default.",
            "After an update, a window offers to read what's new.",
            "The Help tab is now split into topics: a short summary first, then pick a topic on the left. Several tooltips were updated.",
            "The Version tab becomes About, laid out like the Help tab: an About topic (version, author, "
                .. "translators, license, source code) and a Changelog topic.",
            "Key bindings now have their own Tessera category in the game's key bindings, like other addons.",
            "New WoW Forever blocks: Comprehension (scroll-reading skill and the scrolls in your bags), "
                .. "Camping (camp buffs and campfire kit cooldown, a click lights a campfire) and Honor. The "
                .. "Legacy points tooltip now shows your challenges completed per category. Like every block, "
                .. "they can be shared with DataBroker display addons. WoW Forever is in beta: these systems may change.",
            "Reset everything (Profiles tab, Blizzard's AddOns settings or /tessera reset) now really erases all "
                .. "of Tessera's saved data and reloads the interface, as on a first install.",
            "Ready for community translations with CurseForge's localization tool.",
            "Blocks shown from the options are now placed evenly on both sides of the window, and never "
                .. "over Blizzard's action bars, minimap or chat.",
            "The placement banner steps aside while the options window is open, and remembers where it is "
                .. "dragged; it is not shown while Blizzard's Edit Mode is open.",
            "Professions: a click on a gathering profession (herbalism, mining, skinning) opens the professions "
                .. "book on WoW Forever; the talents block opens the talents with Blizzard's own button. The weapon "
                .. "skills block now works on WoW Forever.",
            "New Legacy points block (WoW Forever): your points, the next reward and every reward of the "
                .. "track in the tooltip, a progress bar toward the next reward, and a click opens the Legacy panel.",
            "Fix: hiding all blocks with the key binding during combat left their invisible click buttons "
                .. "active; the blocks are now hidden when combat ends.",
        },
        fr = {
            "Quand une interface qui a un style assorti est installée (FlareUI 1.x ou 2.x, ElvUI, EllesmereUI), "
                .. "une fenêtre montre ce style sur des blocs d'exemple et te le propose. Tessera ne change plus "
                .. "le style de tes blocs tout seul.",
            "Mode DataBroker : le désactiver ne vaut plus que pour l'addon d'affichage détecté à ce moment-là "
                .. "(un autre installé plus tard propose à nouveau le mode, avec sa fenêtre d'explication). "
                .. "L'onglet Broker affiche l'état actuel et permet de revenir au choix automatique.",
            "Ouvrir le mode Édition de Blizzard déverrouille aussi les blocs (option dans l'onglet Général).",
            "Nouveau bouton « Ramener les blocs à l'écran » et commande /tessera recover, pour les groupes qui "
                .. "dépassent de l'écran.",
            "Icônes (onglet Cadre) : la même taille pour tous les blocs, un cadre carré ou rond avec une fine "
                .. "bordure (de la couleur voulue), et le noir et blanc, pour les blocs de Tessera, les lanceurs et les "
                .. "blocs DataBroker. Le style Transparent utilise par défaut des icônes carrées de même taille.",
            "Après une mise à jour, une fenêtre propose de lire les nouveautés.",
            "L'onglet Aide est maintenant découpé en sujets : un court résumé d'abord, puis tu choisis un sujet "
                .. "à gauche. Plusieurs infobulles ont été mises à jour.",
            "L'onglet Version devient À propos, présenté comme l'aide : un sujet À propos (version, auteur, "
                .. "traducteurs, licence, code source) et un sujet Changelog.",
            "Les raccourcis clavier ont maintenant leur propre catégorie Tessera dans les raccourcis du jeu, comme les autres addons.",
            "Nouveaux blocs WoW Forever : Compréhension (compétence de lecture des parchemins et parchemins "
                .. "dans tes sacs), Camping (buffs de camp et recharge du kit de feu de camp, un clic allume un feu) "
                .. "et Honneur. L'infobulle des points d'héritage montre maintenant tes défis accomplis par catégorie. "
                .. "Comme tous les blocs, ils se partagent avec les addons d'affichage DataBroker. WoW Forever est en "
                .. "bêta : ces systèmes peuvent changer.",
            "Tout réinitialiser (onglet Profils, réglages AddOns de Blizzard ou /tessera reset) efface maintenant "
                .. "vraiment toutes les données de Tessera et recharge l'interface, comme à la première installation.",
            "Prêt pour les traductions de la communauté avec l'outil de traduction de CurseForge.",
            "Les blocs affichés depuis les options se placent maintenant des deux côtés de la fenêtre, à parts "
                .. "égales, et plus jamais sur les barres d'action, la minicarte ou la discussion de Blizzard.",
            "Le bandeau de placement s'efface quand la fenêtre d'options est ouverte et retient l'endroit où tu "
                .. "le poses ; il n'est pas affiché pendant le mode Édition de Blizzard.",
            "Métiers : un clic sur un métier de récolte (herboristerie, minage, dépeçage) ouvre le livre des "
                .. "métiers sur WoW Forever ; le bloc talents ouvre les talents avec le bouton de Blizzard. Le bloc "
                .. "compétences d'armes fonctionne maintenant sur WoW Forever.",
            "Nouveau bloc Points d'héritage (WoW Forever) : tes points, la prochaine récompense et toutes celles "
                .. "du parcours dans l'infobulle, une barre de progression vers la prochaine, et un clic ouvre le "
                .. "panneau Héritage.",
            "Correction : masquer tous les blocs avec le raccourci clavier pendant un combat laissait leurs "
                .. "boutons de clic invisibles actifs ; les blocs sont maintenant masqués à la fin du combat.",
        },
    },
    {
        version = "1.0.0-rc1",
        date = "2026-10-10",
        en = {
            "First public version (release candidate).",
            "More than 35 information blocks: gold (with history), bags, durability, FPS, latency, time, XP, "
                .. "coordinates, friends, guild, group, quests, reputation, currencies, professions, weapon skills, "
                .. "talents, mail, whispers, reagents, ammo, instances, played time, goal and more.",
            "Launcher blocks made from minimap buttons and addon compartment entries.",
            "DataBroker: add other addons' DataBroker objects as blocks, share Tessera's blocks with Titan Panel, "
                .. "ChocolateBar, Bazooka and others, and a DataBroker mode used automatically when such an addon "
                .. "is installed, explained on first use and easy to turn off.",
            "Blocks merge like mosaic tiles in every direction; spacers (empty, line or text), undo, alignment "
                .. "guides, snapping to Blizzard frames, frozen groups, global and group scale.",
            "Blocks with nothing to show hide themselves, in a second row under the main bar.",
            "Styles matching FlareUI (2.x and 1.x looks), ElvUI, EllesmereUI and Blizzard, plus Clean and Transparent; per-block "
                .. "text, frame, opacity, progress bar, thresholds, show on hover, alerts and click actions.",
            "Profiles with export / import, ready-made layouts and an automatic dungeon / raid profile; "
                .. "accessibility options; English and French.",
        },
        fr = {
            "Première version publique (version candidate).",
            "Plus de 35 blocs d'informations : or (avec historique), sacs, durabilité, FPS, latence, heure, XP, "
                .. "coordonnées, amis, guilde, groupe, quêtes, réputation, monnaies, métiers, compétences d'armes, "
                .. "talents, courrier, chuchotements, composants, munitions, instances, temps de jeu, objectif et plus.",
            "Blocs lanceurs créés à partir des boutons de la minicarte et du compartiment d'addons.",
            "DataBroker : ajoute en blocs les objets DataBroker des autres addons, partage les blocs de Tessera avec "
                .. "Titan Panel, ChocolateBar, Bazooka et d'autres, et un mode DataBroker utilisé automatiquement "
                .. "quand un tel addon est installé, expliqué à la première utilisation et facile à désactiver.",
            "Les blocs s'assemblent comme une mosaïque dans tous les sens ; espaces (vide, ligne ou texte), "
                .. "annulation, guides d'alignement, aimantation aux cadres de Blizzard, groupes figés, échelle "
                .. "globale et par groupe.",
            "Les blocs qui n'ont rien à montrer se masquent, dans une deuxième rangée sous la barre principale.",
            "Styles assortis à FlareUI (looks 2.x et 1.x), ElvUI, EllesmereUI et Blizzard, plus Épuré et Transparent ; texte, cadre, "
                .. "opacité, barre de progression, seuils, affichage au survol, alertes et actions de clic par bloc.",
            "Profils avec export / import, dispositions toutes prêtes et profil automatique en donjon / raid ; "
                .. "options d'accessibilité ; anglais et français.",
        },
    },
}
