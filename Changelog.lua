local _, ns = ...

-- ========================================================================
-- Changelog.lua: version history shown in the options "About" tab (Changelog topic)
-- ========================================================================
-- Newest entry first. Each entry has a version, a date (YYYY-MM-DD) and its changes
-- in English (en) and French (fr). Players see the French list when their game is in
-- French, the English one otherwise. The changelog is not sent to CurseForge's
-- translation tool: it stays in this file, in English and French only.
-- Since 1.0.0, changes are sorted by kind: entry.sections = { { kind = ..., en = {...},
-- fr = {...} }, ... }, kinds in this order: intro (no title), new, improved, fixed.
-- Older entries keep a plain list (entry.en / entry.fr).
-- Keep CHANGELOG.md (for GitHub and CurseForge) in sync: tools/changelog_md.lua.

-- Titles of the kinds of changes
ns.CHANGELOG_KINDS = {
    new = { en = "New", fr = "Nouveautés" },
    improved = { en = "Improvements", fr = "Améliorations" },
    fixed = { en = "Fixes", fr = "Corrections" },
}

-- The changes of an entry as a list of { title = text or nil, lines = { ... } }
function ns.ChangelogSections(entry, lang)
    if not entry.sections then
        return { { lines = entry[lang] or entry.en or {} } }
    end
    local out = {}
    for _, section in ipairs(entry.sections) do
        local kind = ns.CHANGELOG_KINDS[section.kind]
        local lines = section[lang] or section.en or {}
        if #lines > 0 then
            table.insert(out, { title = kind and (kind[lang] or kind.en), lines = lines })
        end
    end
    return out
end

ns.CHANGELOG = {
    {
        version = "1.0.1",
        date = "",
        sections = {
            { kind = "new",
              en = {
                "New Tessera style, in the addon's own colors: turquoise on dark slate, with the game's "
                    .. "tooltip border. The default style does not change. The options window's background now "
                    .. "reaches its border in every style.",
                "New The War Within and Midnight styles: the frames Blizzard draws for these expansions on "
                    .. "the options window, and their colors on the blocks.",
                "New Blizzard Forever style: the game's current tooltip frame in gold, on WoW Forever and on "
                    .. "Retail. Blizzard modern is now silver on both. A WoW Forever profile that used Blizzard "
                    .. "modern (gold there) moves to Blizzard Forever and keeps its look. The square versions "
                    .. "follow: Blizzard modern square turns silver, and a profile that used it moves to the new "
                    .. "Blizzard Forever square, in gold as before.",
              },
              fr = {
                "Nouveau style Tessera, aux couleurs de l'addon : turquoise sur ardoise sombre, avec la "
                    .. "bordure des infobulles du jeu. Le style par défaut ne change pas. Le fond de la fenêtre "
                    .. "d'options touche maintenant sa bordure, dans tous les styles.",
                "Nouveaux styles The War Within et Midnight : les cadres que Blizzard dessine pour ces "
                    .. "extensions sur la fenêtre d'options, et leurs couleurs sur les blocs.",
                "Nouveau style Blizzard Forever : le cadre actuel des infobulles du jeu en doré, sur WoW "
                    .. "Forever comme sur Retail. Blizzard moderne est maintenant argenté sur les deux. Un profil "
                    .. "WoW Forever qui utilisait Blizzard moderne (doré là-bas) passe à Blizzard Forever et garde "
                    .. "son allure. Les versions carrées suivent : Blizzard moderne carré devient argenté, et un "
                    .. "profil qui l'utilisait passe au nouveau Blizzard Forever carré, doré comme avant.",
              } },
        },
    },
    {
        version = "1.0.0",
        date = "",
        sections = {
            { kind = "new",
              en = {
                "German, Spanish (Spain and Mexico) and Brazilian Portuguese translations. Claude (an AI) "
                    .. "made them and nobody has reviewed them yet: you can correct them with CurseForge's "
                    .. "localization tool.",
                "Streamer mode, for streams and videos: other players' names, your other characters, your "
                    .. "guild's name and your gold show as ***. Turn it on in the General tab, with a "
                    .. "key binding, or with the new Streamer mode block (hidden by default).",
              },
              fr = {
                "Traductions en allemand, en espagnol (Espagne et Mexique) et en portugais du Brésil. "
                    .. "Claude (une IA) les a faites et personne ne les a encore relues : tu peux les corriger "
                    .. "avec l'outil de traduction de CurseForge.",
                "Mode streamer, pour les streams et les vidéos : les noms des autres joueurs, tes autres "
                    .. "personnages, le nom de ta guilde et ton or s'affichent en ***. Il s'active dans "
                    .. "l'onglet Général, avec un raccourci clavier ou avec le nouveau bloc Mode streamer (masqué au "
                    .. "départ).",
              } },
            { kind = "improved",
              en = {
                "New icon: a T and a gold tile on turquoise, easier to spot in the addon list and on the "
                    .. "minimap button.",
                "The About tab thanks Funkeh, whose StatBlock Core gave me the idea of Tessera's "
                    .. "free-floating blocks.",
              },
              fr = {
                "Nouvelle icône : un T et une tesselle dorée sur fond turquoise, plus facile à repérer dans "
                    .. "la liste des addons et sur le bouton de la minicarte.",
                "L'onglet À propos remercie Funkeh, dont l'addon StatBlock Core m'a donné l'idée des blocs "
                    .. "libres de Tessera.",
              } },
            { kind = "fixed",
              en = {
                "Each character's data (its own profile, its gold and gold history) is now saved under its "
                    .. "full name, as WoW Forever has no realms: it no longer depends on the server's name, which "
                    .. "may change. Your settings carry over on their own at your next login.",
                "Arcana, ChocolateBar's new name, now switches Tessera to DataBroker mode like ChocolateBar "
                    .. "did, and the help names it.",
              },
              fr = {
                "Les données de chaque personnage (son profil à lui, son or et l'historique de l'or) sont "
                    .. "maintenant rangées sous son nom complet, car WoW Forever n'a pas de royaumes : elles ne "
                    .. "dépendent plus du nom du serveur, qui peut changer. Tes réglages suivent tout seuls à ta "
                    .. "prochaine connexion.",
                "Arcana, le nouveau nom de ChocolateBar, fait de nouveau passer Tessera en mode DataBroker "
                    .. "comme le faisait ChocolateBar, et l'aide le cite.",
              } },
        },
    },
    {
        version = "1.0.0-rc9-hotfix",
        date = "2026-10-23",
        sections = {
            { kind = "improved",
              en = {
                "Exported texts are about ten times shorter: a profile takes 5 to 7 KB instead of 70 KB, a "
                    .. "style or a layout under 4 KB. Texts exported by earlier versions still import.",
              },
              fr = {
                "Les textes exportés sont environ dix fois plus courts : un profil fait 5 à 7 Ko au lieu de "
                    .. "70 Ko, un style ou une disposition moins de 4 Ko. Les textes exportés par les versions "
                    .. "précédentes s'importent toujours.",
              } },
            { kind = "fixed",
              en = {
                "Importing a profile or a style keeps the stat shown by the Stats block and the texture of "
                    .. "the progress bars.",
              },
              fr = {
                "Importer un profil ou un style garde la statistique affichée par le bloc Statistiques et la "
                    .. "texture des barres de progression.",
              } },
        },
    },
    {
        version = "1.0.0-rc9",
        date = "2026-10-22",
        sections = {
            { kind = "improved",
              en = {
                "With EllesmereUI, ElvUI or GW2 UI, Tessera also asks \"in front or behind\" when blocks cover "
                    .. "their unit frames, buffs, quest tracker, action bars, chat or menu. Blocks snap to the XP bar of "
                    .. "ElvUI and GW2 UI.",
                "The FlareUI and FlareUI square styles have a 50% background, like FlareUI's quest tracker. "
                    .. "Blocks already in one of these styles keep theirs: pick the style again to get it.",
              },
              fr = {
                "Avec EllesmereUI, ElvUI ou GW2 UI, Tessera demande aussi « devant ou derrière » quand des blocs "
                    .. "recouvrent leurs portraits, buffs, suivi des quêtes, barres d'action, discussion ou menu. Les "
                    .. "blocs s'aimantent à la barre d'XP d'ElvUI et de GW2 UI.",
                "Les styles FlareUI et FlareUI carré ont un fond à 50 %, comme le suivi des quêtes de FlareUI. "
                    .. "Les blocs déjà dans un de ces styles gardent le leur : choisis à nouveau le style pour l'avoir.",
              } },
            { kind = "fixed",
              en = {
                "Leaving the demo mode no longer moves a block of a second row: its hidden neighbours no longer "
                    .. "keep the width of the demo's sample values.",
                "Quick tour: your layout comes back after a /reload, a crash or a logout while you try the "
                    .. "ready-made layouts, and goes back to its own profile if another one became active meanwhile.",
                "Ctrl + Z also gives a group back its scale and its frozen state (after a merge or a "
                    .. "\"Replace with...\").",
              },
              fr = {
                "Quitter le mode démo ne déplace plus un bloc de la deuxième rangée : ses voisins masqués ne "
                    .. "gardent plus la largeur des valeurs d'exemple de la démo.",
                "Visite rapide : ta disposition revient après un /reload, un plantage ou une déconnexion pendant "
                    .. "que tu essaies les dispositions toutes prêtes, et retourne dans son propre profil si un "
                    .. "autre est devenu actif entre-temps.",
                "Ctrl + Z rend aussi à un groupe son échelle et son état figé (après une fusion ou un "
                    .. "« Remplacer par... »).",
              } },
        },
    },
    {
        version = "1.0.0-rc8",
        date = "2026-10-21",
        sections = {
            { kind = "improved",
              en = {
                "A block hidden because it has nothing to show (or in combat, in an instance...) keeps its "
                    .. "place: the blocks around it no longer move, close up or overlap.",
                "A ready-made bar and its second row are placed once at the top (or the bottom) of the screen, "
                    .. "then stay where they are, like any group: no recentering when a block moves away or hides, "
                    .. "and the bar no longer follows another addon's bar. The second row starts under the bar's "
                    .. "left edge and stays flush with it; you can now merge blocks on top of it.",
                "The bars of the ready-made layouts only hold blocks that are always shown (Guild and Friends, "
                    .. "and on Rampart Walk Mail, Camping and Comprehension, no longer hide there).",
                "Double bar has three rows of the same width: the top bar, the WoW Forever bar, then the row "
                    .. "where mail, whispers, reputation... appear when they have something to show.",
                "A dragged group lines up by its outer edges only (snapping and gold guides), never by a block "
                    .. "inside it: it lands where you drop it.",
              },
              fr = {
                "Un bloc masqué parce qu'il n'a rien à montrer (ou en combat, en instance...) garde sa place : "
                    .. "les blocs autour ne bougent plus, ne se resserrent plus et ne se chevauchent plus.",
                "Une barre toute prête et sa deuxième rangée sont placées une fois en haut (ou en bas) de "
                    .. "l'écran, puis restent où elles sont, comme n'importe quel groupe : plus de recentrage quand "
                    .. "un bloc s'en va ou se masque, et la barre ne suit plus celle d'un autre addon. La deuxième "
                    .. "rangée commence sous le bord gauche de la barre et reste bord à bord avec elle ; on peut "
                    .. "maintenant fusionner des blocs au-dessus.",
                "Les barres des dispositions toutes prêtes ne contiennent que des blocs toujours affichés "
                    .. "(Guilde et Amis, et sur le Chemin de ronde Courrier, Camping et Compréhension, ne s'y "
                    .. "masquent plus).",
                "La Double barre a trois rangées de la même largeur : la barre du haut, la barre WoW Forever, "
                    .. "puis la rangée où courrier, chuchotements, réputation... apparaissent quand ils ont quelque "
                    .. "chose à montrer.",
                "Un groupe déplacé s'aligne seulement par ses bords extérieurs (aimantation et lignes dorées), "
                    .. "jamais par un bloc à l'intérieur : il se pose là où tu le lâches.",
              } },
            { kind = "fixed",
              en = {
                "Merged blocks no longer keep small pieces of border from an earlier shape after they move or "
                    .. "resize (a reload used to clear them).",
                "The quick tour's buttons (Unlock blocks, Open the Look tab...) are no longer greyed out after "
                    .. "the ready-made layouts step.",
                "\"In front\" or \"Behind\" now applies to a whole bar with its rows, including the blocks hidden "
                    .. "at that moment: a row no longer comes back in front in Edit Mode.",
              },
              fr = {
                "Les blocs fusionnés ne gardent plus de petits morceaux de bordure d'une forme précédente après "
                    .. "un déplacement ou un changement de taille (il fallait recharger l'interface).",
                "Les boutons de la visite rapide (Déverrouiller les blocs, Ouvrir l'onglet Apparence...) ne sont "
                    .. "plus grisés après l'étape des dispositions toutes prêtes.",
                "« Devant » ou « Derrière » s'applique maintenant à toute la barre avec ses rangées, blocs masqués "
                    .. "compris : une rangée ne repasse plus devant en mode Édition.",
              } },
        },
    },
    {
        version = "1.0.0-rc7",
        date = "2026-10-20",
        sections = {
            { kind = "new",
              en = {
                "Class color wherever you pick a color: besides the text and the border, the background (it keeps "
                    .. "its opacity), the icon frame, the lines between merged blocks and the line of spacer blocks.",
              },
              fr = {
                "La couleur de classe partout où l'on choisit une couleur : en plus du texte et de la bordure, le "
                    .. "fond (il garde son opacité), le cadre de l'icône, les lignes entre les blocs fusionnés et la "
                    .. "ligne des blocs espace.",
              } },
            { kind = "improved",
              en = {
                "\"Colors: bright or soft\" (General tab, was \"Threshold colors\") also acts on the class colors: "
                    .. "soft makes them a little darker. The colorblind palette leaves them bright.",
                "Picking a style unchecks the class color options (each style starts with its own look). The "
                    .. "list of styles is in alphabetical order, accents ignored, and every name is written the same "
                    .. "way (\"Blizzard modern square\").",
                "\"Replace with...\" shows one alphabetical list: a green + marks a hidden block (it takes the "
                    .. "place), gold arrows a shown block (the two swap). In the Blocks tab, a green dot marks the "
                    .. "blocks shown in the game.",
                "The memory the options window used is freed once you close it (never in combat).",
              },
              fr = {
                "« Couleurs : vives ou adoucies » (onglet Général, avant « Couleurs des seuils ») agit aussi sur les "
                    .. "couleurs de classe : adoucies les assombrit un peu. La palette pour daltoniens les laisse vives.",
                "Choisir un style décoche les options de couleur de classe (chaque style part de sa propre allure). "
                    .. "La liste des styles est rangée par ordre alphabétique, sans tenir compte des accents, et "
                    .. "tous les noms s'écrivent de la même façon (« Blizzard moderne carré »).",
                "« Remplacer par... » montre une seule liste alphabétique : un + vert marque un bloc masqué (il "
                    .. "prend la place), des flèches dorées un bloc affiché (les deux s'échangent). Dans l'onglet "
                    .. "Blocs, un point vert marque les blocs affichés dans le jeu.",
                "La mémoire utilisée par la fenêtre d'options est libérée dès que tu la fermes (jamais en combat).",
              } },
            { kind = "fixed",
              en = {
                "Borders where merged blocks meet are clean again: no pieces of the previous style after "
                    .. "switching styles, and no thin vertical marks along the bottom of a bar above a short second row.",
                "In the Tiles look, the second row is as wide as its bar again (the joints were left out), and a "
                    .. "bar stays centered when a hidden block under it still holds another block.",
                "No more rare Lua error (\"Cannot anchor to a region dependent on it\") when the demo mode or a "
                    .. "profile rebuilds every group.",
              },
              fr = {
                "Les bordures entre blocs fusionnés sont de nouveau propres : plus de morceaux de l'ancien style "
                    .. "après un changement de style, ni de petits traits verticaux sous une barre au-dessus d'une "
                    .. "deuxième rangée courte.",
                "Avec l'aspect Tuiles, la deuxième rangée est de nouveau aussi large que sa barre (les joints "
                    .. "étaient oubliés), et une barre reste centrée quand un bloc masqué sous elle tient encore un "
                    .. "autre bloc.",
                "Plus d'erreur Lua rare (« Cannot anchor to a region dependent on it ») quand le mode démo ou un "
                    .. "profil reconstruit tous les groupes.",
              } },
        },
    },
    {
        version = "1.0.0-rc6-hotfix",
        date = "2026-10-17",
        sections = {
            { kind = "fixed",
              en = {
                "A block left alone in the second row (the others hidden because they are empty) keeps its own "
                    .. "width instead of stretching over the whole bar.",
                "A group of several rows merged into a bar that has a second row no longer covers that row: the "
                    .. "row moves down below it.",
                "Much less memory shown for Tessera: values that change every second (FPS, latency, coordinates, "
                    .. "clock) no longer rebuild every bar each time, moving blocks in placement mode no longer piles "
                    .. "up work at every frame, and Tessera frees what placing the blocks used when you lock them.",
              },
              fr = {
                "Un bloc resté seul dans la deuxième rangée (les autres masqués parce que vides) garde sa propre "
                    .. "largeur au lieu de s'étirer sur toute la barre.",
                "Un groupe de plusieurs rangées collé à une barre qui a une deuxième rangée ne recouvre plus cette "
                    .. "rangée : elle descend en dessous.",
                "Beaucoup moins de mémoire affichée pour Tessera : les valeurs qui changent chaque seconde (FPS, "
                    .. "latence, coordonnées, heure) ne reconstruisent plus toutes les barres à chaque fois, déplacer des "
                    .. "blocs en mode placement n'accumule plus de travail à chaque image, et Tessera libère ce que le placement a "
                    .. "utilisé quand tu verrouilles les blocs.",
              } },
        },
    },
    {
        version = "1.0.0-rc6",
        date = "2026-10-17",
        sections = {
            { kind = "intro",
              en = {
                "Release candidate 6, the last one before 1.0.0 (November 4): everything planned for 1.0.0 is in. "
                    .. "New here? Type /tessera: the quick tour shows the essentials, and the demo mode (Help tab) "
                    .. "shows every block and every style.",
              },
              fr = {
                "Version candidate 6, la dernière avant la 1.0.0 (4 novembre) : tout ce qui est prévu pour la 1.0.0 "
                    .. "y est. Nouveau ? Tape /tessera : la visite rapide montre l'essentiel, et le mode démo "
                    .. "(onglet Aide) montre tous les blocs et tous les styles.",
              } },
            { kind = "new",
              en = {
                "Date block (hidden by default, add it from the Blocks tab): short or long, numbers in several "
                    .. "orders, local or server date; click: calendar. The Rampart Walk layout shows it next to "
                    .. "the clock.",
                "Demo mode: after the styles, the switcher shows \"Mixed styles\", each column in its own style, "
                    .. "to compare them side by side.",
                "Gold block: remove a character you deleted or renamed from the tooltip (Alt + right-click on the "
                    .. "block, \"Forget a character\").",
                "Ready-made layout \"Rampart Walk\": a bar stuck to the top of the screen over its whole width, "
                    .. "the WoW Forever blocks in the center and system information (FPS, latency, clock, date) on "
                    .. "the right.",
                "Blocks over Blizzard's frames (action bars, minimap, buffs): you choose whether they stay in front "
                    .. "or behind. In placement mode (and in Blizzard's Edit Mode, under its window, where it glows "
                    .. "until you hover it) a button switches every block for a while to see what is underneath; "
                    .. "when you are done, Tessera asks which to keep. Look tab: all blocks in front or behind.",
              },
              fr = {
                "Bloc Date (masqué au départ, ajoute-le depuis l'onglet Blocs) : courte ou longue, en chiffres dans "
                    .. "plusieurs ordres, date locale ou du serveur ; clic : calendrier. La disposition Chemin de ronde "
                    .. "l'affiche à côté de l'horloge.",
                "Mode démo : après les styles, le sélecteur montre les « Styles mélangés », chaque colonne dans son "
                    .. "propre style, pour les comparer côte à côte.",
                "Bloc Or : retire de l'infobulle un personnage supprimé ou renommé (Alt + clic droit sur le "
                    .. "bloc, « Oublier un personnage »).",
                "Disposition toute prête « Chemin de ronde » : une barre collée en haut de l'écran sur toute sa "
                    .. "largeur, les blocs WoW Forever au centre et les infos système (FPS, latence, heure, date) à "
                    .. "droite.",
                "Blocs par-dessus les cadres de Blizzard (barres d'action, minicarte, buffs) : tu choisis s'ils "
                    .. "restent devant ou derrière. En mode placement (et dans le mode Édition de Blizzard, sous sa "
                    .. "fenêtre, où il brille jusqu'à ce que tu le survoles) un bouton bascule tous les blocs un moment "
                    .. "pour voir ce qu'il y a dessous ; quand tu as fini, Tessera demande quoi garder. Onglet "
                    .. "Apparence : tous les blocs devant ou derrière.",
              } },
            { kind = "improved",
              en = {
                "\"Around the gryphons\" layout: two neat rectangles, the date and the clock in the corner on the "
                    .. "right (pick the layout again to get it).",
                "Look tab: \"Frame of all blocks...\" and \"Text of all blocks...\" lead straight to those settings "
                    .. "(Blocks tab, All blocks).",
                "FlareUI style: bronze lines between merged blocks and, when its addon is installed, progress bars "
                    .. "with a grained texture (pick the style again to get them).",
                "Threshold colors (General tab, Accessibility): automatic, bright, soft or colorblind. Automatic "
                    .. "gives the soft colors with the FlareUI style.",
              },
              fr = {
                "Disposition « Autour des gryphons » : deux rectangles nets, la date et l'heure dans le coin à "
                    .. "droite (choisis à nouveau la disposition pour l'avoir).",
                "Onglet Apparence : « Cadre de tous les blocs... » et « Texte de tous les blocs... » mènent tout droit "
                    .. "à ces réglages (onglet Blocs, Tous les blocs).",
                "Style FlareUI : lignes bronze entre les blocs collés et, quand son addon est installé, barres "
                    .. "de progression à la texture granuleuse (choisis à nouveau le style pour les avoir).",
                "Couleurs des seuils (onglet Général, Accessibilité) : automatiques, vives, adoucies ou pour "
                    .. "daltoniens. Automatiques donne les couleurs adoucies avec le style FlareUI.",
              } },
            { kind = "fixed",
              en = {
                "The top bar stays under your interface's XP bar also when that interface or its XP bar is turned on after Tessera "
                    .. "(it stayed at the top of the screen, under the XP bar), and keeps its width when the XP bar "
                    .. "changes size.",
                "A second row (\"Double bar\", the rows of blocks that hide when empty) dropped right against "
                    .. "its bar keeps its place and its full width: it merged into the bar and shrank, its names "
                    .. "cut short.",
                "Applying a ready-made layout keeps your style (it went back to the automatic one).",
                "After a loading screen (boat, portal, instance), the durability and other blocks no longer stay "
                    .. "on \"n/a\": Tessera reads them again once the game is ready.",
                "WoW Forever characters with the same first name (Ellen Kemp, Ellen Sept) no longer share their "
                    .. "gold line and their profile: Tessera recognizes each one by its full name and its ruleset, and "
                    .. "the FlareUI styles find their font for it again.",
              },
              fr = {
                "La barre du haut reste sous la barre d'XP de ton interface aussi quand cette interface ou sa barre d'XP est activée "
                    .. "après Tessera (elle restait en haut de l'écran, sous la barre d'XP), et garde sa largeur "
                    .. "quand la barre d'XP change de taille.",
                "Une deuxième rangée (« Double barre », les rangées de blocs qui se masquent quand ils sont vides) "
                    .. "reposée tout contre sa barre garde sa place et toute sa largeur : elle se fondait dans la "
                    .. "barre et rétrécissait, ses noms coupés.",
                "Appliquer une disposition toute prête garde ton style (il revenait au style automatique).",
                "Après un écran de chargement (bateau, portail, instance), la durabilité et les autres blocs ne restent "
                    .. "plus sur « n/d » : Tessera les relit une fois le jeu prêt.",
                "Les personnages de WoW Forever qui ont le même prénom (Ellen Kemp, Ellen Sept) ne partagent plus "
                    .. "leur ligne d'or ni leur profil : Tessera reconnaît chacun par son nom complet et son jeu de règles, "
                    .. "et les styles FlareUI retrouvent leur police pour lui.",
              } },
        },
    },
    {
        version = "1.0.0-rc5",
        date = "2026-10-15",
        en = {
            "Demo mode (Help tab, welcome window, /tessera demo): every block at once, sorted by category, with "
                .. "sample values. Its banner switches the styles and can hide the game's interface, for screenshots. "
                .. "Your layout comes back when you leave.",
            "Placement mode made easier: a cross on the hovered block hides it, arrows replace it with another "
                .. "block in the exact same place, and a right-click opens the quick menu. What you can do with the "
                .. "hovered block shows in a panel under the banner.",
            "Replacing blocks: a hidden block takes the place, a shown block swaps places, and the spacers of the "
                .. "ready-made layouts can be replaced by blocks. New help topic \"Replacing blocks\".",
            "Nine new styles: Runestone (text only, black and white), Grimoire, Parchment and Arcane, and five "
                .. "made of the game's own frames: Royal Seal, Ironforge, Runeblade, Ember and Sylvan.",
            "The FlareUI, ElvUI and EllesmereUI styles can be picked without that addon: they are then an "
                .. "imitation, and the chat says what differs. ElvUI and EllesmereUI no longer look alike. The FlareUI "
                .. "styles use the font of FlareUI's XP bar (pick the style again to get it).",
            "\"Value shown\" (Blocks tab, Text): gold (coin icons or letters, gold and silver, rounding, "
                .. "thousands separator), bags, XP, durability, FPS, latency, seconds on the clocks, coordinates, "
                .. "friends and guild, reputation.",
            "New ready-made layout \"Double bar\": the top bar and a second bar of WoW Forever blocks. The quick "
                .. "tour lets you try every layout on your screen.",
            "Placement: a single block slips in between two merged blocks, a second row put back against its bar "
                .. "stays centered under it, and the names under the blocks no longer overlap.",
            "Group loot block: the game's official names for the loot methods. WoW Forever blocks show nothing "
                .. "rather than an error if the game changes.",
            "Help completed, and split into short texts that are easier to translate on CurseForge.",
        },
        fr = {
            "Mode démo (onglet Aide, fenêtre de bienvenue, /tessera demo) : tous les blocs d'un coup, rangés par "
                .. "catégorie, avec des valeurs d'exemple. Son bandeau change de style et peut masquer l'interface du "
                .. "jeu, pour les captures. Ta disposition revient quand tu le quittes.",
            "Mode placement plus simple : une croix sur le bloc survolé le masque, des flèches le remplacent par "
                .. "un autre bloc exactement à la même place, et un clic droit ouvre le menu rapide. Ce qu'on peut faire "
                .. "avec le bloc survolé s'affiche dans un cadre sous le bandeau.",
            "Remplacer des blocs : un bloc masqué prend la place, un bloc affiché échange sa place, et les "
                .. "espaces des dispositions toutes prêtes peuvent être remplacés par des blocs. Nouveau sujet d'aide « "
                .. "Remplacer des blocs ».",
            "Neuf nouveaux styles : Pierre runique (seulement le texte, en noir et blanc), Grimoire, Parchemin et "
                .. "Arcanes, et cinq faits des cadres du jeu : Sceau royal, Forgefer, Lame runique, Braise et Sylvestre.",
            "Les styles FlareUI, ElvUI et EllesmereUI se choisissent aussi sans l'addon : c'est alors une "
                .. "imitation, et la discussion dit ce qui change. ElvUI et EllesmereUI ne se ressemblent plus. Les "
                .. "styles FlareUI prennent la police de la barre d'XP de FlareUI (choisis à nouveau le style pour "
                .. "l'avoir).",
            "« Valeur affichée » (onglet Blocs, Texte) : or (icônes des pièces ou lettres, or et argent, arrondi, "
                .. "séparateur des milliers), sacs, XP, durabilité, FPS, latence, secondes des horloges, coordonnées, "
                .. "amis et guilde, réputation.",
            "Nouvelle disposition toute prête « Double barre » : la barre du haut et une deuxième barre de blocs "
                .. "WoW Forever. La visite rapide permet d'essayer toutes les dispositions sur ton écran.",
            "Placement : un bloc seul se glisse entre deux blocs fusionnés, une deuxième rangée remise contre sa "
                .. "barre reste centrée dessous, et les noms sous les blocs ne se chevauchent plus.",
            "Bloc butin du groupe : les noms officiels du jeu pour les modes de butin. Les blocs WoW Forever "
                .. "n'affichent rien plutôt qu'une erreur si le jeu change.",
            "Aide complétée, et découpée en petits textes plus faciles à traduire sur CurseForge.",
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
                .. "the minimap. /tessera minimap still hides or shows it.",
            "Blizzard's Edit Mode: when a Tessera bar stuck to the top or bottom covers Blizzard frames (action bars, "
                .. "menu, minimap...), Tessera offers a copy of your Edit Mode layout, \"My layout (Tessera 1)\", where "
                .. "only those frames move, and activates it. Your layout is never changed. \"Back to my layout\" and "
                .. "\"Delete the copies\" (only Tessera's unchanged copies, never a layout of yours) are in the Look tab. "
                .. "Tested on Blizzard's interface (Modern, Classic); with another interface, results may be unexpected.",
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
                .. "blocs, glisser pour le déplacer autour de la minicarte. /tessera minimap le masque "
                .. "ou l'affiche toujours.",
            "Mode Édition de Blizzard : quand une barre de Tessera collée en haut ou en bas recouvre des cadres de "
                .. "Blizzard (barres d'action, menu, minicarte...), Tessera propose une copie de ta disposition du mode "
                .. "Édition, « Ma dispo (Tessera 1) », où seuls ces cadres bougent, et l'active. Ta disposition n'est "
                .. "jamais modifiée. « Revenir à ma disposition » et « Supprimer les copies » (seulement les copies de "
                .. "Tessera non modifiées, jamais une disposition à toi) sont dans l'onglet Apparence. Testé sur "
                .. "l'interface de Blizzard (Moderne, Classique) ; avec une autre interface, des résultats inattendus "
                .. "peuvent survenir.",
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
