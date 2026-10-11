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
        version = "1.0.0-rc3",
        date = "", -- set when the version is published
        en = {
            "Fix: choosing a ready-made layout showed the \"reset everything\" message in the chat; it now says "
                .. "which layout was applied.",
            "Fix: switching to another layout or profile could raise a Lua error (\"Cannot anchor to a region "
                .. "dependent on it\") when two blocks swapped places.",
            "Fix: a column stuck to the bottom of the screen piled up its blocks; the whole column now stays "
                .. "visible above the edge.",
            "Releases: the English and French strings are sent to CurseForge's localization tool automatically, "
                .. "and community translations are added to the addon.",
            "New ready-made layout \"Around the gryphons\": two groups in the bottom corners of the screen, on both "
                .. "sides of the action bars, WoW Forever blocks included. Ready-made layouts are now picked in a list "
                .. "(Profiles tab), with a description of each one.",
            "New \"Replace with...\" (quick menu, or next to the block list in the Blocks tab): puts another block "
                .. "exactly in a block's place, with its look, without moving the others; or swaps two shown blocks.",
            "Screen edges: drop a group against an edge and Tessera offers to stick it there (no border on that "
                .. "side, stays put on any screen). Along the top or bottom, a bar can be stretched over the whole "
                .. "width: spacer blocks fill the room (blocks on the left, center, right or spread) and the blocks "
                .. "keep their size. Setting in the General tab (ask, always, never).",
            "New ready-made layouts in the spirit of desktop taskbars and menu bars: Stormwind Stained Glass, Cathedral "
                .. "Rose Window, Tirisfal Orchard and Gnomeregan, with the "
                .. "clock, FPS, latency and volume where you expect them.",
            "New \"Add a spacer\" (quick menu): an empty block on the left, right, above or below a block, slipped in "
                .. "between if another block is already there; in a stretched bar it takes room from the other spacers.",
        },
        fr = {
            "Correction : choisir une disposition toute prête affichait dans la discussion le message de « tout "
                .. "réinitialiser » ; il indique maintenant la disposition appliquée.",
            "Correction : changer de disposition ou de profil pouvait provoquer une erreur Lua (« Cannot anchor to "
                .. "a region dependent on it ») quand deux blocs échangeaient leur place.",
            "Correction : une colonne collée en bas de l'écran empilait ses blocs ; toute la colonne reste maintenant "
                .. "visible au-dessus du bord.",
            "Publications : l'anglais et le français sont envoyés automatiquement à l'outil de traduction de "
                .. "CurseForge, et les traductions de la communauté sont ajoutées à l'addon.",
            "Nouvelle disposition toute prête « Autour des gryphons » : deux groupes dans les coins bas de l'écran, "
                .. "de part et d'autre des barres d'action, blocs WoW Forever compris. Les dispositions toutes prêtes "
                .. "se choisissent maintenant dans une liste (onglet Profils), avec la description de chacune.",
            "Nouveau « Remplacer par... » (menu rapide, ou à côté de la liste des blocs dans l'onglet Blocs) : met un "
                .. "autre bloc exactement à la place d'un bloc, avec son apparence, sans bouger les autres ; ou échange "
                .. "deux blocs affichés.",
            "Bords de l'écran : lâche un groupe contre un bord et Tessera propose de l'y coller (plus de bordure de "
                .. "ce côté, il reste en place sur tous les écrans). En haut ou en bas, une barre peut être étirée sur "
                .. "toute la largeur : des blocs espace comblent la place (blocs à gauche, au centre, à droite ou "
                .. "répartis) et les blocs gardent leur taille. Réglage dans l'onglet Général (demander, toujours, jamais).",
            "Nouvelles dispositions toutes prêtes façon barres des tâches et barres de menus : Vitraux de Hurlevent, "
                .. "Rosace de la cathédrale, Vergers de Tirisfal et Gnomeregan, avec "
                .. "l'horloge, les FPS, la latence et le volume là où on les attend.",
            "Nouveau « Ajouter un espace » (menu rapide) : un bloc vide à gauche, à droite, au-dessus ou en dessous "
                .. "d'un bloc, glissé entre les deux si un autre bloc est déjà là ; dans une barre étirée, il prend la "
                .. "place sur les autres espaces.",
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
