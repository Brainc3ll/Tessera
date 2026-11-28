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

-- The "What's new" lines of an entry: { { text = ..., show = spec or nil }, ... } (spec: where the
-- "Show me" button goes, see ns:ShowWhatsNewTarget in OptionsTour.lua)
function ns.ChangelogHighlights(entry, lang)
    local out = {}
    for _, h in ipairs(entry.highlights or {}) do
        out[#out + 1] = { text = h[lang] or h.en, show = h.show }
    end
    return out
end

ns.CHANGELOG = {
    {
        version = "2.0.0",
        date = "2026-11-28",
        demo = "styles", -- the update window shows the new styles on real blocks (Options/OptionsNewsDemo.lua)
        highlights = {
            { en = "Tessera's windows in stone and metal, in your style's colors.",
              fr = "Les fenêtres de Tessera en pierre et métal, aux couleurs de ton style." },
            { en = "Six new block styles: Gilded, Blue rune, Silver, Brazen, Jade and Amethyst, with rounded corners.",
              fr = "Six nouveaux styles de blocs : Doré, Runique bleu, Argent, Airain, Jade et Améthyste, aux coins arrondis.",
              show = { page = "PAGE_LOOK", label = "THEME" } },
            { en = "Pick your style in a gallery of real blocks, set its font and effects beside it, and try it in game.",
              fr = "Choisis ton style dans une galerie de vrais blocs, règle sa police et ses effets à côté, et essaie-le en jeu.",
              show = { page = "PAGE_LOOK", label = "THEME" } },
            { en = "Style, font, corners and effects together in one Style box.",
              fr = "Style, police, coins et effets réunis dans un seul cadre Style.",
              show = { page = "PAGE_LOOK", label = "FONT" } },
            { en = "Between merged blocks: a line, a dash, a diamond, runes or a dot.",
              fr = "Entre les blocs fusionnés : une ligne, un tiret, un losange, des runes ou un point.",
              show = { page = "PAGE_LOOK", label = "SEPARATOR_SHAPE" } },
            { en = "Volume list: set every sound channel with a click or the wheel, and keep up to four named presets.",
              fr = "Liste du volume : règle chaque canal d'un clic ou à la molette, et garde quatre préréglages nommés.",
              show = { block = "volume", label = "VOLUME_SHOW" } },
        },
        sections = {
            { kind = "new",
              en = {
                "Stone and metal: Tessera draws its windows (options, placement banner, See all, What's new, copy boxes, confirmations) with the game's rock,"
                    .. " the metal frame of its dialogs and a soft shadow, in your style's colors. Blocks and the lists under the mouse keep their style.",
                "Confirmation windows open one at a time, at the top of the screen. Tab, arrows or d-pad pick a button,"
                    .. " Enter or A presses it, Escape or B cancels when the window allows it. When the answer erases something, Cancel is picked first.",
                "Options window: an icon for each page, the quest log's soft light under the mouse and on the open page, bigger titles,"
                    .. " and the version beside the name.",
                "Buttons, text fields, lists and sliders take rounded shapes in your style's colors; sliders use the classic knob and the spell book's arrows.",
                "Switches: a rounded rail in your style's color and a round knob that slides when you click (it jumps with Fewer animations).",
                "High contrast draws these windows plain black with a thick white edge, without rock or shadow.",
                "Accessibility: Window shadow turns off the shadow under Tessera's windows, if it bothers you.",
                "Sharper drawings: the page icons, the switch and the arrows are drawn at 128 px, and the logo at 256 px,"
                    .. " so they stay sharp on big screens.",
                "Six new block styles: Gilded, Blue rune, Silver, Brazen, Jade and Amethyst. A tinted, see-through background, a rounded edge"
                    .. " drawn by Tessera and an ornament between merged blocks. Your other styles stay as they were.",
                "Corners: rounded, or square with a line one screen pixel wide.",
                "Two fonts come with these styles: Cinzel (Blue rune) and Inter (Silver). You can pick them for any block,"
                    .. " and addons that use LibSharedMedia get them too.",
                "Effects, for any style: the edge lights up under the mouse, and a number that changes counts"
                    .. " to its new value. The six new styles turn them on; Fewer animations turns them off."
                    .. " The glow has four shapes (Halo, Edge, Inner, Pulse) and takes the style's color or your class color;"
                    .. " your blocks keep the halo they had.",
                "One Style box for the whole look: style, font, text size, corners, separators, effects,"
                    .. " glow shape and color, in this order,"
                    .. " in the Style and layouts tab for every block and at the top of a block's Appearance tab."
                    .. " The block's style leaves the Content tab. Blocks whose style is locked keep theirs.",
                "Separator shape, for any style: a line, a short line, a dash, a diamond, three runes, a dot or a big dot between merged blocks"
                    .. " (Style box or Groups of blocks for every block, or Separators for one block).",
                "Progress bar: a new look, a thin line under the value (Bar look). The six new styles use it on the blocks"
                    .. " that have a progress; the other styles keep the band.",
                "Style gallery: a click on the style list (Style and layouts tab, or a block's page) shows every style as a real block,"
                    .. " in rows by family, two merged blocks each. On the right, set the font, text size, corners, separators and effects:"
                    .. " every thumbnail shows them, and can light up and move (Animate the thumbnails)."
                    .. " Click a style, then Apply, or Try in game to see it on your blocks and then keep it or go back."
                    .. " Arrows or d-pad, Enter or A, and Escape or B work too.",
                "The window after this update shows the six new styles on real blocks that light up while their numbers glide."
                    .. " Click one, then See opens the gallery on it. Tab or the d-pad lets you use the window"
                    .. " with the keyboard or a gamepad.",
                "Volume block: \"Hover shows\" now offers a clickable list in place of the tooltip. Click a bar or use the wheel to set the"
                    .. " general, music, effects, ambience or dialogue volume, and one button mutes or restores all sound."
                    .. " When the game lists several output devices, a button picks one. The list is the default; the tooltip stays a choice.",
                "Volume presets: up to four, with names you choose (14 characters at most). A preset keeps the five volumes, whether sound"
                    .. " is muted and the output device. A click on a preset in the list applies it; a right click renames, replaces or deletes it.",
                "\"Click on the block\" chooses what a left click does: mute or restore sound (the default), or go to the next preset.",
                "\"Block text\" can show the name of the preset in use, with the volume or alone. It shows only while the sound matches a preset exactly.",
                "Presets are shared by all your characters. Create, name and delete them in the Volume block's settings too, without the mouse over the block.",
              },
              fr = {
                "Pierre et métal : Tessera dessine ses fenêtres (options, bandeau de placement, Tout voir, Quoi de neuf ?, boîtes de copie, confirmations)"
                    .. " avec la roche du jeu, le cadre de métal de ses dialogues et une ombre douce, aux couleurs de ton style."
                    .. " Les blocs et les listes au survol gardent leur style.",
                "Les fenêtres de confirmation s'ouvrent une à une, en haut de l'écran. Tab, les flèches ou la croix choisissent un bouton,"
                    .. " Entrée ou A l'active, Échap ou B annule quand la fenêtre le permet."
                    .. " Quand la réponse efface quelque chose, Annuler est choisi d'abord.",
                "Fenêtre d'options : une icône pour chaque page, la lumière douce du journal de quêtes sous la souris et sur la page ouverte,"
                    .. " des titres plus grands et la version à côté du nom.",
                "Les boutons, champs de texte, listes et curseurs prennent des formes arrondies aux couleurs de ton style ;"
                    .. " les curseurs reprennent le bouton classique et les flèches du grimoire.",
                "Interrupteurs : un rail arrondi à la couleur de ton style et un bouton rond qui glisse quand tu cliques (il saute avec Moins d'animations).",
                "Le contraste renforcé dessine ces fenêtres en noir uni avec un bord blanc épais, sans roche ni ombre.",
                "Accessibilité : Ombre des fenêtres enlève l'ombre sous les fenêtres de Tessera, si elle te gêne.",
                "Dessins plus nets : les icônes des pages, l'interrupteur et les flèches sont dessinés en 128 px, et le logo en 256 px,"
                    .. " pour rester nets sur les grands écrans.",
                "Six nouveaux styles de blocs : Doré, Runique bleu, Argent, Airain, Jade et Améthyste. Un fond teinté un peu transparent,"
                    .. " un bord arrondi dessiné par Tessera et un ornement entre les blocs fusionnés. Tes autres styles restent tels quels.",
                "Coins : arrondis, ou droits avec un trait d'un pixel de l'écran.",
                "Deux polices arrivent avec ces styles : Cinzel (Runique bleu) et Inter (Argent). Tu peux les choisir pour n'importe quel bloc,"
                    .. " et les addons qui utilisent LibSharedMedia les reçoivent aussi.",
                "Effets, pour tous les styles : le bord s'éclaire sous la souris, et un nombre qui change"
                    .. " glisse jusqu'à sa nouvelle valeur. Les six nouveaux styles les allument ; Moins d'animations les coupe."
                    .. " La lueur a quatre formes (Halo, Liseré, Intérieure, Pulsation) et prend la couleur du style ou celle de ta classe ;"
                    .. " tes blocs gardent le halo qu'ils avaient.",
                "Un seul cadre Style pour toute l'allure : style, police, taille du texte, coins, séparateurs, effets,"
                    .. " forme et couleur de la lueur, dans cet ordre,"
                    .. " dans l'onglet Style et dispositions pour tous les blocs et en haut de l'onglet Apparence d'un bloc."
                    .. " Le style du bloc quitte l'onglet Contenu. Les blocs au style verrouillé gardent le leur.",
                "Forme des séparateurs, pour tous les styles : une ligne, un petit trait, un tiret, un losange, trois runes,"
                    .. " un point ou un gros point entre les blocs fusionnés"
                    .. " (cadre Style ou Groupes de blocs pour tous les blocs, ou Séparateurs pour un seul bloc).",
                "Barre de progression : une nouvelle allure, une fine ligne sous la valeur (Allure de la barre). Les six nouveaux"
                    .. " styles l'utilisent sur les blocs qui ont une progression ; les autres styles gardent la bande.",
                "Galerie des styles : un clic sur la liste des styles (onglet Style et dispositions, ou page d'un bloc) montre tous les styles"
                    .. " en vrais blocs, rangés par famille, deux blocs fusionnés chacun. À droite, règle la police, la taille du texte,"
                    .. " les coins, les séparateurs et les effets : chaque vignette les montre, et peut s'allumer et bouger"
                    .. " (Animer les vignettes). Clique sur un style, puis sur Appliquer, ou sur Essayer en jeu pour le voir"
                    .. " sur tes blocs puis le garder ou revenir. Les flèches ou la croix,"
                    .. " Entrée ou A, et Échap ou B marchent aussi.",
                "La fenêtre qui suit cette mise à jour montre les six nouveaux styles sur de vrais blocs qui s'allument pendant que leurs nombres glissent."
                    .. " Clique sur un style, puis Voir ouvre la galerie sur ce style. Tab ou la croix permettent"
                    .. " d'utiliser la fenêtre au clavier ou à la manette.",
                "Bloc Volume : « Le survol affiche » propose une liste cliquable à la place de l'infobulle. Clique sur une barre ou utilise la"
                    .. " molette pour régler le volume général, la musique, les effets, l'ambiance ou les dialogues. Un bouton coupe ou remet tout le son."
                    .. " Si le jeu liste plusieurs sorties audio, un bouton en choisit une. La liste est le choix par défaut ; l'infobulle reste un choix.",
                "Préréglages de volume : jusqu'à quatre, avec le nom de ton choix (14 caractères au plus). Un préréglage garde les cinq volumes,"
                    .. " l'état du son coupé et la sortie audio. Un clic sur un préréglage dans la liste l'applique ;"
                    .. " un clic droit le renomme, le remplace ou le supprime.",
                "« Clic sur le bloc » choisit ce que fait un clic gauche : couper ou remettre le son (par défaut),"
                    .. " ou passer au préréglage suivant.",
                "« Texte du bloc » peut afficher le nom du préréglage en cours, avec le volume ou seul."
                    .. " Il s'affiche seulement quand le son correspond exactement à un préréglage.",
                "Les préréglages sont communs à tous tes personnages. Tu peux aussi les créer, les nommer et les supprimer dans les réglages du bloc Volume,"
                    .. " sans passer la souris sur le bloc.",
              },
            },
            { kind = "improved",
              en = {
                "Eleven blocks have a new icon: FPS, Latency, Addon memory, Quests, Reputation, Currencies, Speed, Volume, Talents,"
                    .. " Time played and Comprehension. Time played no longer looks like the two other clocks.",
              },
              fr = {
                "Onze blocs ont une nouvelle icône : FPS, Latence, Mémoire des addons, Quêtes, Réputation, Monnaies, Vitesse, Volume,"
                    .. " Talents, Temps de jeu et Compréhension. Le Temps de jeu ne ressemble plus aux deux autres horloges.",
              },
            },
            { kind = "fixed",
              en = {
                "Icon frames, square or round: the icon now sits on whole screen pixels, so its frame is one pixel wide on every side.",
                "A group that grows past the screen edge (a wider font, a longer text) stays one bar: the game used to push"
                    .. " back only the block past the edge, which opened a gap in the group.",
                "Lists with arrows in the options: an arrow could stay grey (or lit) after a change, as if the list were"
                    .. " at its first or last choice. The arrows now follow the value.",
                "Locked styles: when a style goes to all blocks or to a group, the warning about locked blocks offers"
                    .. " Skip locked (the others take the style, the locked ones stay as they are), Them too, or Cancel."
                    .. " No used to leave every block as it was.",
                "Rampart layout: its spacers no longer show an icon. Apply the layout again to clear the ones you have.",
              },
              fr = {
                "Cadre des icônes, carré ou rond : l'icône tombe maintenant sur des pixels entiers de l'écran, et son cadre fait un pixel de chaque côté.",
                "Un groupe qui dépasse le bord de l'écran (police plus large, texte plus long) reste une seule barre : le jeu"
                    .. " repoussait seulement le bloc qui dépassait, ce qui ouvrait un écart dans le groupe.",
                "Listes à flèches des options : une flèche pouvait rester grisée (ou allumée) après un changement, comme si"
                    .. " la liste était à son premier ou dernier choix. Les flèches suivent maintenant la valeur.",
                "Styles verrouillés : quand un style va à tous les blocs ou à un groupe, l'avertissement sur les blocs verrouillés"
                    .. " propose Sauf verrouillés (les autres prennent le style, les verrouillés restent tels quels), Eux aussi ou Annuler."
                    .. " Non laissait tous les blocs tels quels.",
                "Disposition Chemin de ronde : ses espaces n'affichent plus d'icône. Applique de nouveau la disposition pour effacer celles qui restent.",
              },
            },
        },
    },
    {
        version = "1.8.0",
        date = "2026-11-25",
        highlights = {
            { en = "Language list in the General tab: pick the language of Tessera's texts, whatever your game language.",
              fr = "Liste Langue dans l'onglet Général : choisis la langue des textes de Tessera, quelle que soit celle du jeu.",
              show = { page = "PAGE_GENERAL", label = "LANGUAGE" } },
            { en = "See all: every block in one window, with the count of blocks on your screen.",
              fr = "Tout voir : tous les blocs dans une fenêtre, avec le nombre de blocs à l'écran.",
              show = { block = "gold", label = "SEE_ALL_BLOCKS" } },
        },
        sections = {
            { kind = "new",
              en = {
                "\"See all\" under the block list (Blocks tab): one window with every block, a green dot on the ones on your screen,"
                    .. " a search box and the count (\"12 of 54 blocks on screen\"). Click a block to select it.",
                "Language list in the General tab. \"As the game\" is the default. Pick English, French, German, Spanish (Spain or Mexico)"
                    .. " or Portuguese (Brazil), then reload the interface. The choice covers your whole account, not one profile.",
                "Names that come from the game, such as classes, zones and items, stay in the game's language."
                    .. " The changelog exists in English and French only.",
              },
              fr = {
                "« Tout voir » sous la liste des blocs (onglet Blocs) : une fenêtre avec tous les blocs, un point vert sur ceux de ton écran,"
                    .. " une recherche et le nombre (« 12 blocs à l'écran sur 54 »). Clique sur un bloc pour le choisir.",
                "Liste Langue dans l'onglet Général. « Comme le jeu » est le choix par défaut. Choisis l'anglais, le français, l'allemand,"
                    .. " l'espagnol (Espagne ou Mexique) ou le portugais (Brésil), puis recharge l'interface."
                    .. " Le choix vaut pour tout ton compte, pas pour un seul profil.",
                "Les noms qui viennent du jeu, comme les classes, les zones et les objets, restent dans la langue du jeu."
                    .. " Le journal des changements existe seulement en anglais et en français.",
              },
            },
        },
    },
    {
        version = "1.7.2",
        date = "2026-11-21",
        sections = {
            { kind = "fixed",
              en = {
                "Style lock: on a page with several blocks (All blocks, All launchers, a group), no setting reaches a block whose style is locked."
                    .. " That covers every setting, the \"Enabled\" switch and Reset."
                    .. " In 1.7.1 a change such as the border also changed locked blocks.",
                "\"Copy style to all\" and \"Copy style to group\" ask first when a locked block is among the targets."
                    .. " The block takes the style after you say yes and stays locked.",
              },
              fr = {
                "Verrou du style : sur une page à plusieurs blocs (Tous les blocs, Tous les lanceurs, un groupe),"
                    .. " aucun réglage n'atteint un bloc au style verrouillé."
                    .. " Cela couvre tous les réglages, l'interrupteur « Activé » et Réinitialiser."
                    .. " En 1.7.1, un changement comme la bordure modifiait aussi les blocs verrouillés.",
                "« Copier sur tous » et « Copier sur le groupe » demandent d'abord confirmation quand un bloc verrouillé fait partie des cibles."
                    .. " Le bloc prend le style après ton accord et reste verrouillé.",
              },
            },
        },
    },
    {
        version = "1.7.1",
        date = "2026-11-21",
        highlights = {
            { en = "Style lock: a block keeps its look when you change the style or an interface addon is removed.",
              fr = "Verrou de style : un bloc garde son allure si tu changes de style ou si un addon d'interface est retiré.",
              show = { block = "gold", label = "STYLE_LOCK" } },
        },
        sections = {
            { kind = "intro",
              en = {
                "Quick update: a few things that should have been in 1.7.0. I need a coffee. ;)",
              },
              fr = {
                "Petite mise à jour : quelques trucs qui auraient dû être dans la 1.7.0. J'ai besoin d'un café. ;)",
              },
            },
            { kind = "new",
              en = {
                "\"Lock this block's style\" (Blocks and groups tab, Appearance, Style lock): a style change for the whole profile"
                    .. " leaves the block as it is, also when FlareUI, ElvUI or another interface addon is removed or comes back."
                    .. " \"Apply this style to\" still changes it, after a warning. Unlocking asks whether the block takes the profile's style.",
              },
              fr = {
                "« Verrouiller le style de ce bloc » (onglet Blocs et groupes, Apparence, Verrou du style) : un changement de style pour tout le profil"
                    .. " laisse le bloc tel quel, même quand FlareUI, ElvUI ou un autre addon d'interface est retiré ou revient."
                    .. " « Appliquer ce style à » le change quand même, après un avertissement."
                    .. " Au déverrouillage, Tessera demande si le bloc prend le style du profil.",
              },
            },
            { kind = "improved",
              en = {
                "When the interface addon your automatic style follows is removed or comes back, a window says so"
                    .. " (instead of a chat line) and names the blocks whose style is locked. Your settings and profiles keep working as before.",
              },
              fr = {
                "Quand l'addon d'interface que suit ton style automatique est retiré ou revient, une fenêtre le dit"
                    .. " (au lieu d'une ligne dans la discussion) et nomme les blocs dont le style est verrouillé."
                    .. " Tes réglages et profils marchent comme avant.",
              },
            },
            { kind = "fixed",
              en = {
                "In DataBroker mode, the minimap button's tooltip names the DataBroker tab, where you can hide the button."
                    .. " The tab it named before is hidden in that mode. Thanks to ReiceG on CurseForge for pointing it out.",
                "Tessera's entry in the addon compartment (and in FlareUI's button bag) shows the same tooltip as the minimap"
                    .. " button, and a right-click on it locks or unlocks the blocks, as on the button.",
              },
              fr = {
                "En mode DataBroker, l'infobulle du bouton de la minicarte nomme l'onglet DataBroker, où tu peux masquer le bouton."
                    .. " L'onglet nommé avant est caché dans ce mode."
                    .. " Merci à ReiceG, sur CurseForge, de l'avoir signalé.",
                "L'entrée de Tessera dans le menu des addons (et dans le sac de boutons de FlareUI) montre la même infobulle"
                    .. " que le bouton de la minicarte, et un clic droit dessus verrouille ou déverrouille les blocs, comme sur le bouton.",
              },
            },
        },
    },
    {
        version = "1.7.0",
        date = "2026-11-21",
        highlights = {
            { en = "Talents block: show your unspent points, the points per tree, your main tree or your active spec.",
              fr = "Bloc Talents : affiche tes points à dépenser, les points par arbre, ton arbre principal ou ta spé active.",
              show = { block = "talents", label = "TALENTS_SHOWN" } },
            { en = "Talents block: a middle click changes your spec out of combat.",
              fr = "Bloc Talents : un clic du milieu change ta spé hors combat." },
            { en = "Legacy block: show your available points, with the points spent in each tree in its tooltip.",
              fr = "Bloc Héritage : affiche tes points disponibles, avec les points dépensés dans chaque arbre en infobulle.",
              show = { block = "legacy", label = "LEGACY_SHOWN" } },
        },
        sections = {
            { kind = "new",
              en = {
                "Talents block: the Shown choice offers unspent points, points per tree (for example 31/20/0),"
                    .. " your main tree and your active spec. The tooltip lists the points of each tree, your specs"
                    .. " and the next milestone. Each line has its own box.",
                "Talents block: a middle click changes your spec with the game's own spell, out of combat."
                    .. " You can move this action to Shift + click in the block's settings.",
                "Legacy block: the Shown choice offers your available points."
                    .. " The tooltip adds the points spent out of the total of each Legacy tree.",
              },
              fr = {
                "Bloc Talents : le choix Affichage propose les points à dépenser, les points par arbre (par exemple 31/20/0),"
                    .. " ton arbre principal et ta spé active. L'infobulle liste les points de chaque arbre, tes spés"
                    .. " et le prochain palier. Chaque ligne a sa case.",
                "Bloc Talents : un clic du milieu change ta spé avec le sort du jeu, hors combat."
                    .. " Tu peux déplacer cette action sur Maj + clic dans les réglages du bloc.",
                "Bloc Héritage : le choix Affichage propose tes points disponibles."
                    .. " L'infobulle ajoute les points dépensés sur le total de chaque arbre d'Héritage.",
              },
            },
            { kind = "improved",
              en = {
                "The Talent points and Legacy points blocks are now called Talents and Héritage in French.",
                "Legacy block: \"Hide when empty\" hides the block when no point is left to spend.",
                "The minimap button's tooltip says how to hide it, and the DataBroker tab has the same"
                    .. " \"Show the minimap button\" box as the Placement and more tab.",
              },
              fr = {
                "Les blocs Points de talent et Points d'héritage s'appellent maintenant Talents et Héritage.",
                "Bloc Héritage : « Masquer si vide » cache le bloc quand il ne reste aucun point à dépenser.",
                "L'infobulle du bouton de la minicarte dit comment le masquer, et l'onglet DataBroker a la même case"
                    .. " « Afficher le bouton de la minicarte » que l'onglet Placement et général.",
              },
            },
        },
    },
    {
        version = "1.6.3",
        date = "2026-11-19",
        sections = {
            { kind = "fixed",
              en = {
                "FlareUI styles: when the XP bar font is set to Global in FlareUI, Tessera follows FlareUI's Global Font,"
                    .. " including a font that Tessera lends to FlareUI (Lexend, Atkinson...). In 1.6.2 it fell back to Arial.",
                "Durability block: the repair cost counts the damaged items in your bags too, as the vendor's Repair all does."
                    .. " Before, it counted only the items you wear. The box \"Count items in bags in the cost\" turns it off.",
              },
              fr = {
                "Styles FlareUI : quand la police de la barre d'XP est sur Global dans FlareUI, Tessera suit la police globale de FlareUI,"
                    .. " même une police que Tessera lui prête (Lexend, Atkinson...). En 1.6.2, il retombait sur Arial.",
                "Bloc Durabilité : le coût de réparation compte aussi les pièces abîmées dans tes sacs, comme le « Tout réparer » du vendeur."
                    .. " Avant, il ne comptait que les pièces portées. La case « Compter les pièces en sac dans le coût » le désactive.",
              },
            },
        },
    },
    {
        version = "1.6.2",
        date = "2026-11-18",
        sections = {
            { kind = "fixed",
              en = {
                "Separators: the lines follow the \"Line between merged blocks\" box and the line color as you change them."
                    .. " In 1.6.1 they updated only after a reload or a style change.",
                "Separators: each line stays one sharp pixel wide, wherever the bar sits."
                    .. " In 1.6.1 some lines showed doubled and faint, or vanished, and changed when a block's text changed width.",
              },
              fr = {
                "Séparateurs : les traits suivent la case « Ligne entre les blocs fusionnés » et la couleur de la ligne dès que tu les changes."
                    .. " En 1.6.1, ils ne se mettaient à jour qu'après un rechargement ou un changement de style.",
                "Séparateurs : chaque trait reste net, large d'un pixel, où que soit la barre."
                    .. " En 1.6.1, certains traits apparaissaient en double et pâles, ou disparaissaient,"
                    .. " et changeaient quand le texte d'un bloc changeait de largeur.",
              },
            },
        },
    },
    {
        version = "1.6.1",
        date = "2026-11-18",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "Streamer mode: choose what it hides (other players, your characters, guild name, gold).",
              fr = "Mode streamer : choisis ce qu'il cache (autres joueurs, tes personnages, nom de guilde, or).",
              show = { block = "streamer", label = "STREAMER_HIDE_PLAYERS" } },
            { en = "Guild block: show your guild's name before the member count.",
              fr = "Bloc Guilde : affiche le nom de ta guilde avant le nombre de membres.",
              show = { block = "guild", label = "GUILD_SHOW_NAME" } },
            { en = "New Essentials layout: one bar where every block stays shown, the start of a first install.",
              fr = "Nouvelle disposition L'essentiel : une barre où chaque bloc reste affiché, le départ d'une première installation." },
        },
        sections = {
            { kind = "new",
              en = {
                "Streamer mode: four checkboxes in the Streamer block's own settings choose what it hides: other players' names, your other characters, the"
                    .. " guild name and your gold. All four are on, as before; uncheck the guild name if your guild is part of your stream.",
                "Guild block: a new setting, Show the guild name (off by default), writes your guild's name before the member count.",
                "New layout, Essentials: one bar at the top with talents, gold, bags, durability, guild, friends, FPS, played time"
                    .. " and whispers, every block shown even at zero. A first install starts with it; your layout does not change.",
              },
              fr = {
                "Mode streamer : quatre cases dans les réglages du bloc Streamer choisissent ce qu'il cache :"
                    .. " les noms des autres joueurs, tes autres personnages,"
                    .. " le nom de guilde et ton or. Les quatre sont cochées, comme avant ; décoche le nom de guilde si ta guilde fait partie de ton stream.",
                "Bloc Guilde : un nouveau réglage, Afficher le nom de guilde (décoché par défaut), écrit le nom de ta guilde avant le nombre de membres.",
                "Nouvelle disposition, L'essentiel : une barre en haut avec talents, or, sacs, durabilité, guilde, amis, FPS, temps de jeu"
                    .. " et chuchotements, chaque bloc affiché même à zéro. Une première installation part de celle-ci ; ta disposition ne change pas.",
              },
            },
            { kind = "improved",
              en = {
                "Quick tour: the layouts step says in big letters that the layouts are examples and that Tessera has more than 50 blocks.",
                "After an update, a window in Tessera's style lists the first news since your version, each with its Show me button.",
                "Goal block, items: its settings say how to add an item and how many (up to 3), and its tooltip counts them.",
                "Whispers list: the same List look setting as the other lists (tooltip or window), and more room between whispers.",
                "Lists on hover: switching a list between the tooltip look and the window look no longer leaves the old look showing through.",
              },
              fr = {
                "Visite guidée : l'étape des dispositions dit en gros qu'elles ne sont que des exemples et que Tessera a plus de 50 blocs.",
                "Après une mise à jour, une fenêtre au style de Tessera liste les premières nouveautés depuis ta version,"
                    .. " chacune avec son bouton Montre-moi.",
                "Bloc Objectif, objets : ses réglages expliquent comment ajouter un objet et combien (jusqu'à 3), et son infobulle les compte.",
                "Liste des chuchotements : le même réglage Aspect de la liste que les autres listes (infobulle ou fenêtre),"
                    .. " et plus d'air entre les chuchotements.",
                "Listes au survol : passer une liste du style infobulle au style fenêtre ne laisse plus l'ancien style transparaître.",
              },
            },
            { kind = "fixed",
              en = {
                "Lists on hover: they no longer take the border color of the last tooltip the game showed (green after hovering a"
                    .. " friendly character, for one).",
              },
              fr = {
                "Listes au survol : elles ne prennent plus la couleur de bordure de la dernière infobulle du jeu (verte après avoir"
                    .. " survolé un personnage amical, par exemple).",
              },
            },
        },
    },
    {
        version = "1.6.0",
        date = "2026-11-17",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "Guild, Friends and Group: hover the block for a clickable list (whisper, invite, search).",
              fr = "Guilde, Amis et Groupe : survole le bloc pour une liste cliquable (chuchoter, inviter, rechercher).",
              show = { block = "guild", label = "GUILD_SHOW" } },
            { en = "Whispers: the last 20 stay after a reload; pin the ones you must not forget.",
              fr = "Chuchotements : les 20 derniers restent après un rechargement ; épingle ceux à ne pas oublier.",
              show = { block = "whispers", label = "WHISPERS_HOVER" } },
            { en = "Shift + click a name in a list: copy it, add a friend, /who or ignore.",
              fr = "Maj + clic sur un nom d'une liste : le copier, ajouter en ami, /qui ou ignorer." },
            { en = "\"Hide when empty\" sits next to \"Enabled\", at the top of each block's page.",
              fr = "« Masquer si vide » se place à côté de « Activé », en haut de la page de chaque bloc.",
              show = { block = "friends", widget = "hideEmptySwitch" } },
            { en = "Placement: choose whether dropped blocks merge and whether they snap to the grid.",
              fr = "Placement : choisis si les blocs posés fusionnent et s'ils s'aimantent à la grille.",
              show = { page = "PAGE_GENERAL", label = "MERGE_DROP" } },
            { en = "Freeze a group from its settings: no block joins it any more.",
              fr = "Fige un groupe depuis ses réglages : plus aucun bloc ne s'y ajoute.",
              show = { block = "gold", label = "FREEZE_GROUP" } },
            { en = "/tessera preview fills the lists with made-up players.",
              fr = "/tessera preview remplit les listes de joueurs inventés." },
        },
        sections = {
            {
                kind = "new",
                en = {
                    "Guild block: a new setting, On hover, shows the members online in a list under the mouse in place of the"
                        .. " tooltip (Tooltip brings back the old one)."
                        .. " A click on a name whispers, a right click invites and Shift + click opens a menu.",
                    "The list has a search field (name, zone, rank or note), the mouse wheel and a scroll bar for big guilds."
                        .. " It follows the tooltip settings (sort, leaders, message, count, rank, note, size)."
                        .. " A click on the block still opens the game's guild window.",
                    "Block settings: a \"Hide when empty\" switch sits next to the block's \"Enabled\" switch (the \"On screen\" switch, renamed),"
                        .. " for blocks that can have nothing to show.",
                    "What's new, in the About tab: one short line for each new thing, version by version, with a Show me button that opens"
                        .. " the setting and a button to come back. After an update, the window that announces it lists the new version's lines.",
                    "Guild, friends, group and whispers lists: the Shift + click menu also copies the name into the chat, adds the player"
                        .. " as a friend, shows the player's info (/who) and ignores the player. In the whispers list it also pins and deletes.",
                    "Whispers list: each row has a star to pin it and a red cross to delete it (click twice)."
                        .. " Ctrl + click on a row also deletes that whisper (a pinned one stays until you unpin it); a Clear button at the top"
                        .. " removes every whisper that is not pinned (a second click confirms).",
                    "Lists on hover: they take the look and the fonts of the game's tooltip, open on the side and with the alignment of the"
                        .. " block's tooltip settings, show the blue click hints under the list in two parts (in the list, on the block),"
                        .. " and close when you hover another block, so two lists never overlap."
                        .. " The Friends list also shows your status, the friends' notes and the same away and busy tags as the tooltip.",
                    "Preview mode and the demo fill the Guild, Friends and Group lists with made-up players, so you can see every list"
                        .. " without a guild, a group or friends.",
                    "Group block: the same On hover setting. The list of your party or raid members shows under the mouse in place of the"
                        .. " tooltip, with their role and state and a search field (a raid is sorted by group). A click on a name whispers and"
                        .. " Shift + click opens a menu.",
                    "Friends block: the same On hover setting as the Guild block. The friends list (your WoW and Battle.net friends online)"
                        .. " shows under the mouse in place of the tooltip, with a search field. A click on a name whispers,"
                        .. " a right click invites and Shift + click opens a menu. It follows the block's sort, notes and parts settings.",
                    "Whispers block: it now keeps the last 5, 10 or 20 whispers, even after you answered and after a reload, with the time"
                        .. " and the start of each message. A new setting, On hover, shows them as a clickable list or as a tooltip."
                        .. " In the list, a click replies and a right click pins a whisper so you do not forget it.",
                    "Four settings shape the list: Class icons, List rows (5 to 100), List size (80 to 150 percent)"
                        .. " and List look (tooltip or window).",
                    "New setting in General, Movement: Merge blocks dropped together."
                        .. " Unchecked, a block dropped against another one does not merge with it.",
                    "Freeze this block / group is now also a setting of the block (Behaviour tab), not only in the quick menu.",
                    "New setting in General, Movement: Snap to the grid. Off, the grid stays shown and blocks do not snap to it.",
                    "The placement banner has the checkboxes Snap blocks to each other, Merge blocks dropped together and Snap to the grid.",
                },
                fr = {
                    "Bloc Guilde : un nouveau réglage, Au survol, affiche les membres en ligne dans une liste sous la souris"
                        .. " à la place de l'infobulle (Infobulle remet l'ancienne)."
                        .. " Un clic sur un nom chuchote, un clic droit invite et Maj + clic ouvre un menu.",
                    "La liste a un champ de recherche (nom, zone, rang ou note), la molette et une barre de défilement pour les"
                        .. " grosses guildes. Elle suit les réglages de l'infobulle (tri, chefs, message, compte,"
                        .. " rang, note, taille). Un clic sur le bloc ouvre toujours la fenêtre de guilde du jeu.",
                    "Réglages du bloc : un interrupteur « Masquer si vide » se place à côté de l'interrupteur « Activé » du bloc"
                        .. " (l'ancien « Sur l'écran », renommé), pour les blocs qui peuvent n'avoir rien à montrer.",
                    "« Quoi de neuf ? », dans l'onglet À propos : une ligne courte par nouveauté, version par version, avec un bouton Montre-moi"
                        .. " qui ouvre le réglage et un bouton pour revenir. Après une mise à jour, la fenêtre qui l'annonce liste"
                        .. " les lignes de la nouvelle version.",
                    "Listes de guilde, d'amis, de groupe et de chuchotements : le menu Maj + clic copie aussi le nom dans la discussion,"
                        .. " ajoute le joueur en ami, montre ses infos (/qui) et l'ignore. Dans les chuchotements, il épingle et supprime aussi.",
                    "Liste des chuchotements : chaque ligne a une étoile pour l'épingler et une croix rouge pour la supprimer (deux clics)."
                        .. " Ctrl + clic sur une ligne supprime aussi ce chuchotement (un épinglé reste jusqu'à ce que tu retires l'épingle) ;"
                        .. " un bouton Vider, en haut, retire tous les chuchotements non épinglés (un second clic confirme).",
                    "Listes au survol : elles prennent l'aspect et les polices de l'infobulle du jeu, montrent l'aide bleue sous la liste"
                        .. " en deux parties (dans la liste, sur le bloc), et se ferment quand tu survoles un autre bloc :"
                        .. " deux listes ne se chevauchent plus. Elles s'ouvrent du côté et avec l'alignement des réglages d'infobulle du bloc."
                        .. " La liste des amis montre aussi ton statut, les notes des amis et les mêmes marques absent et occupé que l'infobulle.",
                    "Le mode aperçu et la démo remplissent les listes Guilde, Amis et Groupe de joueurs inventés, pour voir chaque liste"
                        .. " sans guilde, sans groupe et sans amis.",
                    "Bloc Groupe : le même réglage Au survol. La liste des membres de ton groupe ou raid s'affiche sous la souris à la place de"
                        .. " l'infobulle, avec leur rôle, leur état et un champ de recherche (un raid est classé par groupe)."
                        .. " Un clic sur un nom chuchote et Maj + clic ouvre un menu.",
                    "Bloc Amis : le même réglage Au survol que le bloc Guilde. La liste des amis (tes amis du jeu et Battle.net en ligne)"
                        .. " s'affiche sous la souris à la place de l'infobulle, avec un champ de recherche. Un clic sur un nom chuchote,"
                        .. " un clic droit invite et Maj + clic ouvre un menu. Elle suit les réglages de tri, de notes et de parties du bloc.",
                    "Bloc Chuchotements : il garde maintenant les 5, 10 ou 20 derniers chuchotements, même après ta réponse et un"
                        .. " rechargement, avec l'heure et le début de chaque message. Un nouveau réglage, Au survol, les montre en liste"
                        .. " cliquable ou en infobulle. Dans la liste, un clic répond et un clic droit épingle un chuchotement pour ne pas l'oublier.",
                    "Quatre réglages donnent sa forme à la liste : Icônes de classe, Lignes de la liste (de 5 à 100), Taille de la liste (de 80 à 150 %)"
                        .. " et Aspect de la liste (infobulle ou fenêtre).",
                    "Nouveau réglage dans Général, Déplacement : Fusionner les blocs posés ensemble."
                        .. " Décoché, un bloc posé contre un autre ne fusionne pas avec lui.",
                    "Figer ce bloc / groupe devient aussi un réglage du bloc (onglet Comportement), plus seulement dans le menu rapide.",
                    "Nouveau réglage dans Général, Déplacement : Aimanter à la grille. Décoché, la grille reste affichée et les blocs ne s'y aimantent pas.",
                    "Le bandeau de placement a les cases Aimanter les blocs entre eux, Fusionner les blocs posés ensemble et Aimanter à la grille.",
                },
            },
            {
                kind = "improved",
                en = {
                    "Block settings: the Content tab starts with a box named Only for this block (the block's own settings and what"
                        .. " its tooltip lists), then the standard settings every block has.",
                },
                fr = {
                    "Réglages d'un bloc : l'onglet Contenu commence par un cadre Propre à ce bloc (ses réglages à lui et ce que"
                        .. " liste son infobulle), puis les réglages standards que chaque bloc a.",
                },
            },
        },
    },
    {
        version = "1.5.1",
        date = "2026-11-15",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "Less memory, and no more short pauses when you move blocks or close the options.",
              fr = "Moins de mémoire, et plus de petites pauses quand tu déplaces des blocs ou fermes les options." },
        },
        sections = {
            { kind = "intro",
              en = {
                "Thank you to Ahlen and Malkkav on the FlareUI Discord. Ahlen's idea of a data panel under the minimap started"
                    .. " the talk where players tried Tessera, and Malkkav showed me how to measure performance."
                    .. " Players there also reported Tessera's memory use, which led to this version's change.",
                "Memory, in short. An addon manager counts live data plus garbage that Lua has not collected yet."
                    .. " Tessera makes garbage when it rebuilds blocks (a style change, a move, a merge) or draws the"
                    .. " options window. Lua's collector clears it in the background, so the figure rises and falls like a saw tooth.",
                "Some memory stays. The game never frees a frame an addon has created, so the options window and every block"
                    .. " you have shown stay allocated until you reload. Opening the options window once costs memory for the session.",
                "The figure depends on your blocks, the DataBroker sources you add, your other addons and what you did a moment ago.",
                "FPS. Memory use does not lower your frame rate by itself. You feel the pauses when Lua collects a lot of garbage"
                    .. " at once, and this version removes the main ones: the full cleaning after closing the options and the"
                    .. " redraw of a closed options window. With the blocks locked, Tessera does little work. To make it lighter,"
                    .. " hide the blocks that update often (coordinates, speed).",
                "Refresh rates. One timer wakes each block at its own pace, from four times a second (coordinates) to once a"
                    .. " minute (honor, Legacy). Blocks without a timer update only when the game sends an event. Hidden blocks"
                    .. " do not update. The README lists every block.",
              },
              fr = {
                "Merci à Ahlen et à Malkkav, du Discord de FlareUI. L'idée d'Ahlen d'un panneau de données sous la minimap a lancé"
                    .. " la discussion où des joueurs ont essayé Tessera, et Malkkav m'a montré comment mesurer les performances."
                    .. " Des joueurs y ont aussi signalé la mémoire utilisée par Tessera, ce qui a mené au changement de cette version.",
                "La mémoire, en bref. Un gestionnaire d'addons compte les données vivantes et les déchets que Lua n'a pas"
                    .. " encore ramassés. Tessera fabrique des déchets quand elle reconstruit des blocs (changement de style,"
                    .. " déplacement, fusion) ou dessine la fenêtre d'options. Le ramasse-miettes de Lua les vide en arrière-plan,"
                    .. " donc le chiffre monte et descend en dents de scie.",
                "Une partie reste. Le jeu ne libère jamais un cadre créé par un addon : la fenêtre d'options et chaque bloc"
                    .. " affiché restent alloués jusqu'au rechargement. Ouvrir la fenêtre d'options une fois coûte de la mémoire"
                    .. " pour la session.",
                "Le chiffre dépend de tes blocs, des sources DataBroker ajoutées, de tes autres addons et de ce que tu viens de faire.",
                "FPS. La mémoire utilisée ne fait pas baisser les FPS à elle seule. Tu sens les pauses quand Lua ramasse beaucoup"
                    .. " de déchets d'un coup, et cette version supprime les principales : le grand nettoyage après la fermeture des"
                    .. " options et le redessin d'une fenêtre d'options fermée. Blocs verrouillés, Tessera travaille peu. Pour"
                    .. " l'alléger, masque les blocs qui se mettent à jour souvent (coordonnées, vitesse).",
                "Rythmes de mise à jour. Un seul minuteur réveille chaque bloc à son rythme, de quatre fois par seconde"
                    .. " (coordonnées) à une fois par minute (honneur, Legacy). Les blocs sans minuteur se mettent à jour"
                    .. " seulement quand le jeu envoie un événement. Les blocs masqués ne se mettent pas à jour. Le README liste"
                    .. " chaque bloc.",
              },
            },
            { kind = "improved",
              en = {
                "Undo (Ctrl + Z) keeps its 30 steps, and each step now keeps only what changed since the step before."
                    .. " With many blocks it takes far less memory.",
                "The options window no longer redraws its settings while it is closed. Moving and locking blocks"
                    .. " feels lighter and uses less memory.",
                "Moving and merging blocks makes less temporary memory.",
                "Closing the options window or locking the blocks cleans memory in small steps, so the game no longer"
                    .. " pauses for a moment.",
              },
              fr = {
                "L'annulation (Ctrl + Z) garde ses 30 étapes, et chaque étape ne garde plus que ce qui a changé depuis la précédente."
                    .. " Avec beaucoup de blocs, elle prend bien moins de mémoire.",
                "La fenêtre d'options ne redessine plus ses réglages tant qu'elle est fermée. Déplacer et verrouiller"
                    .. " les blocs est plus léger et prend moins de mémoire.",
                "Déplacer et fusionner des blocs produit moins de mémoire temporaire.",
                "Fermer la fenêtre d'options ou verrouiller les blocs nettoie la mémoire par petits pas : le jeu ne se"
                    .. " fige plus un instant.",
              },
            },
          },
    },
    {
        version = "1.5.0",
        date = "2026-11-15",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "Choose the parts each tooltip shows (gold, bags, durability, guild...).",
              fr = "Choisis les parties de chaque infobulle (or, sacs, durabilité, guilde...).",
              show = { block = "gold", label = "GOLD_TIP_SESSION" } },
            { en = "Reset session: your gold, XP and reputation gains start again from zero.",
              fr = "Réinitialiser la session : tes gains d'or, d'XP et de réputation repartent de zéro." },
            { en = "Settings sit in boxes with a Reset button; the search says where a setting is.",
              fr = "Les réglages sont rangés en cadres avec un bouton Réinitialiser ; la recherche dit où se trouve un réglage." },
            { en = "Line a tooltip up with the left edge, the center or the right edge of its block.",
              fr = "Aligne une infobulle sur le bord gauche, le centre ou le bord droit de son bloc.",
              show = { block = "gold", label = "TOOLTIP_ALIGN" } },
        },
        sections = {
            { kind = "new",
              en = {
                "Gold: choose which parts of the tooltip show (session gain, gold per hour, history, characters)."
                    .. " The block can show the total of your characters of the same faction and realm."
                    .. " The history keeps 7, 14 or 30 days.",
                "Bags: count the profession bags, show the value of your junk in the block,"
                    .. " and choose which parts of the tooltip show (each bag, profession bags, junk value).",
                "Durability: show the repair cost in the block, list only the worn items (the most worn first),"
                    .. " and choose which parts of the tooltip show.",
                "XP: show the time to the next level and the XP of the quests you can hand in,"
                    .. " and choose which parts of the tooltip show.",
                "Reset session: a new choice for the Shift + click and middle click actions on Gold, XP, Reputation, Currencies,"
                    .. " XP per hour and Goal."
                    .. " Gains and rates per hour start again from now.",
                "Guild: the tooltip can show the message of the day, the members online out of the total,"
                    .. " and each member's rank and public note. Each line starts with the level, the rank is in gold"
                    .. " and the zone stays on the right. Sort the members (name, level, zone, rank),"
                    .. " put the top ranks, guild master and officers, above everyone else (they are not counted)"
                    .. " and choose how many members show: 5, 10, 20, 30, 50 or 100.",
                "Friends: choose which parts of the tooltip show, show the note you wrote on a friend,"
                    .. " sort the list by name, level or zone, and keep only the Battle.net friends who play WoW.",
                "Quests: sort the tooltip by level or finished first, list 10, 20 or all quests, show each zone or only the quests to hand in,"
                    .. " and set the alert on the free slots left in the quest log.",
                "Reputation: show the points left before the next standing and the reputation gained this session,"
                    .. " and choose which parts of the tooltip show. \"Reset session\" also restarts the reputation gain.",
                "Currencies: show any currency you own in the block, not only the three on your backpack."
                    .. " The tooltip can list your other currencies by category, the cap and the weekly limit, and what each gained this session."
                    .. " The block turns orange near a currency's cap, then red with the word \"max\" at the cap, and"
                    .. " \"Reset session\" starts the gains again.",
                "Goal: count a currency, see \"Reached\" in words with one flash when you get there,"
                    .. " and read the estimated time left in the tooltip (gold and level goals, at your session pace).",
                "XP per hour: it shares the session of Gold, XP and Reputation (\"Reset session\" restarts it)."
                    .. " Show the rate and the time together, and choose the tooltip parts, with the last 15 minutes.",
                "Reagents: choose which reagents show, show the ones you ran out of in gray,"
                    .. " and set the yellow and red stock levels (red makes \"Flash to alert\" react).",
                "Group: the tooltip shows roles (leader, assistant, master looter), the state (offline, dead, away)"
                    .. " and the level, each with its checkbox.",
                "Memory: list 5, 10, 20 or 30 addons, with each one's share of the total and a total line.",
                "Instances: sort the saves by nearest reset, choose which parts of the tooltip show, and let the block"
                    .. " turn yellow then red as a reset gets near (thresholds in hours).",
                "Item level: show the equipped level, the best available one or both, and list the weakest items first in the tooltip.",
                "Stats: a second stat next to the first.",
                "Weapon enchant and Long buffs: the yellow and red thresholds are now settings (in seconds)."
                    .. " Red now starts under one minute, so \"Flash to alert\" can warn you before the time runs out.",
              },
              fr = {
                "Or : choisis les parties de l'infobulle à afficher (gain de la session, or par heure, historique, personnages)."
                    .. " Le bloc peut afficher le total de tes personnages de la même faction et du même serveur."
                    .. " L'historique garde 7, 14 ou 30 jours.",
                "Sacs : compte les sacs de métier, affiche la valeur de ton bric-à-brac dans le bloc,"
                    .. " et choisis les parties de l'infobulle à afficher (chaque sac, sacs de métier, valeur du bric-à-brac).",
                "Durabilité : affiche le coût de réparation dans le bloc, liste seulement les pièces abîmées (les plus usées en premier),"
                    .. " et choisis les parties de l'infobulle à afficher.",
                "XP : affiche le temps avant le niveau suivant et l'XP des quêtes à rendre,"
                    .. " et choisis les parties de l'infobulle à afficher.",
                "Remise à zéro de la session : un nouveau choix pour les actions du Maj + clic et du clic milieu sur l'Or, l'XP,"
                    .. " la Réputation, les Monnaies, l'XP par heure et l'Objectif."
                    .. " Les gains et les rythmes par heure repartent de maintenant.",
                "Guilde : l'infobulle peut montrer le message du jour, les membres en ligne sur le total,"
                    .. " et le rang et la note publique de chaque membre. Chaque ligne commence par le niveau, le rang est en doré"
                    .. " et la zone reste à droite. Trie les membres (nom, niveau, zone, rang),"
                    .. " place les rangs les plus hauts, maître de guilde et officiers, au-dessus des autres (ils ne sont pas comptés)"
                    .. " et choisis combien de membres s'affichent : 5, 10, 20, 30, 50 ou 100.",
                "Amis : choisis les parties de l'infobulle à afficher, montre la note écrite sur un ami,"
                    .. " trie la liste par nom, niveau ou zone, et garde seulement les amis Battle.net qui jouent à WoW.",
                "Quêtes : trie l'infobulle par niveau ou les terminées d'abord, liste 10, 20 ou toutes les quêtes,"
                    .. " montre chaque zone ou seulement les quêtes à rendre, et règle l'alerte sur les places libres du journal.",
                "Réputation : affiche les points restants avant le rang suivant et la réputation gagnée pendant la session,"
                    .. " et choisis les parties de l'infobulle à afficher. « Remettre la session à zéro » relance aussi le gain de réputation.",
                "Monnaies : affiche n'importe quelle monnaie que tu possèdes dans le bloc, pas seulement les trois du sac à dos."
                    .. " L'infobulle peut lister tes autres monnaies par catégorie, le plafond et la limite hebdomadaire, et"
                    .. " le gain de chacune pendant la session."
                    .. " Le bloc passe à l'orange près du plafond d'une monnaie, puis au rouge avec le mot « max » au"
                    .. " plafond, et « Remettre la session à zéro » relance les gains.",
                "Objectif : compte une monnaie, affiche « Atteint » en toutes lettres avec un clignotement à l'arrivée,"
                    .. " et lis le temps restant estimé dans l'infobulle (objectifs d'or et de niveau, au rythme de ta session).",
                "XP par heure : elle partage la session de l'Or, de l'XP et de la Réputation (« Remettre la session à zéro » la relance)."
                    .. " Affiche le rythme et le temps ensemble, et choisis les parties de l'infobulle, avec les 15 dernières minutes.",
                "Composants : choisis lesquels afficher, montre en grisé ceux que tu n'as plus,"
                    .. " et règle les niveaux de stock jaune et rouge (le rouge fait réagir « Clignoter pour alerter »).",
                "Groupe : l'infobulle montre les rôles (chef, assistant, responsable du butin), l'état (hors ligne, mort, absent)"
                    .. " et le niveau, chacun avec sa case.",
                "Mémoire : liste 5, 10, 20 ou 30 addons, avec la part de chacun dans le total et une ligne de total.",
                "Instances : trie les sauvegardes par réinitialisation la plus proche, choisis les parties de l'infobulle à afficher,"
                    .. " et laisse le bloc passer au jaune puis au rouge quand une réinitialisation approche (seuils en heures).",
                "Niveau d'objet : affiche le niveau équipé, le meilleur disponible ou les deux, et liste d'abord les objets"
                    .. " les plus faibles dans l'infobulle.",
                "Stats : une deuxième statistique à côté de la première.",
                "Enchant d'arme et Buffs longs : les seuils jaune et rouge deviennent des réglages (en secondes)."
                    .. " Le rouge commence sous une minute, pour que « Clignoter pour alerter » te prévienne avant la fin.",
              },
            },
            { kind = "improved",
              en = {
                "The left tabs of the options window say what they hold: Blocks and groups, Style and layouts,"
                    .. " Placement and more, Profiles and sharing. \"Appearance\" now names only a block's own tab.",
                "Block settings: three tabs, Content (name, value, icon, style, its own settings and its tooltip),"
                    .. " Appearance (size, text, background, icon, border, separators, opacity and layer)"
                    .. " and Behaviour (when to show the block, hover, clicks, alerts and thresholds). You scroll less.",
                "Every tab of the options window sorts its settings into boxes. Each box has a Reset button"
                    .. " that puts its settings back to their defaults once you confirm."
                    .. " Two short settings share a line, and a setting that depends on another sits under it"
                    .. " and greys out while that one is off.",
                "The search shows where each setting sits, for example Blocks and groups › Guild › Content › Tooltip, and opens its tab.",
                "The options window opens 15 % larger (115 %) and a little taller, so text at 100 % fits with less scrolling.",
                "The \"What's new in 1.3\" button is gone from the Help tab. The Changelog in the About tab lists every change.",
                "The list on the left of the options window widens for a long tab name, so no name is cut.",
                "Block settings: choose how a block's tooltip lines up with it (left edge, centered, right edge). Automatic keeps the old behaviour.",
                "Tooltips: a blank line now separates the title, the information and the click help."
                    .. " \"Space between tooltip parts\" in Placement and more turns it off.",
                "FlareUI styles follow the font of FlareUI's XP bar. FlareUI 6 gave that bar its own font, apart from the action bar keybinds.",
                "German, Spanish (Spain and Mexico) and Brazilian Portuguese: every new or changed text is translated."
                    .. " Claude (an AI) translated them and nobody has reviewed them yet: corrections are welcome on GitHub.",
              },
              fr = {
                "Les onglets de gauche de la fenêtre d'options disent ce qu'ils contiennent : Blocs et groupes, Style et dispositions,"
                    .. " Placement et général, Profils et partage. « Apparence » ne nomme plus que l'onglet propre à un bloc.",
                "Réglages des blocs : trois onglets, Contenu (nom, valeur, icône, style, ses propres réglages et son infobulle),"
                    .. " Apparence (taille, texte, fond, icône, bordure, séparateurs, opacité et plan)"
                    .. " et Comportement (quand afficher le bloc, survol, clics, alertes et seuils). Moins de molette.",
                "Chaque onglet de la fenêtre d'options range ses réglages dans des cadres. Chaque cadre a un bouton Réinitialiser"
                    .. " qui remet ses réglages par défaut une fois que tu confirmes."
                    .. " Deux réglages courts partagent une ligne, et un réglage qui dépend d'un autre se place dessous"
                    .. " et se grise tant que l'autre est désactivé.",
                "La recherche indique où se trouve chaque réglage, par exemple Blocs et groupes › Guilde › Contenu › Infobulle, et ouvre son onglet.",
                "La fenêtre d'options s'ouvre 15 % plus grande (115 %) et un peu plus haute : le texte à 100 % tient avec moins de molette.",
                "Le bouton « Nouveautés de la 1.3 » disparaît de l'onglet Aide. Le Changelog de l'onglet À propos liste tous les changements.",
                "La liste à gauche de la fenêtre d'options s'élargit pour un nom d'onglet long : aucun nom n'est coupé.",
                "Réglages des blocs : choisis comment l'infobulle d'un bloc s'aligne sur lui (bord gauche, centrée, bord"
                    .. " droit). Automatique garde l'ancien comportement.",
                "Infobulles : une ligne vide sépare maintenant le titre, les informations et l'aide des clics."
                    .. " « Espaces dans les infobulles » dans Placement et général la retire.",
                "Les styles FlareUI suivent la police de la barre d'XP de FlareUI. FlareUI 6 a donné à cette barre sa propre police,"
                    .. " séparée de celle des raccourcis de la barre d'action.",
                "Allemand, espagnol (Espagne et Mexique) et portugais du Brésil : chaque texte nouveau ou changé est traduit."
                    .. " Claude (une IA) les a traduits et personne ne les a encore relus : les corrections sont les bienvenues sur GitHub.",
              },
            },
        },
    },
    {
        version = "1.4.0",
        date = "2026-11-14",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "Six fonts made for easier reading (low vision, dyslexia).",
              fr = "Six polices pour lire plus facilement (malvoyance, dyslexie).",
              show = { page = "PAGE_ACCESS", label = "FONT" } },
        },
        sections = {
            { kind = "new",
              en = {
                "Six fonts made for easier reading, in the font choice of every block: Atkinson Hyperlegible and Luciole (low vision),"
                    .. " OpenDyslexic (dyslexia), Lexend (reading flow), Andika (beginning readers) and Inclusive Sans (general legibility),"
                    .. " each in regular and bold."
                    .. " The menu shows in grey which alphabets each one covers."
                    .. " Other addons that use LibSharedMedia can pick them too.",
                "Accessibility tab: a Font setting for all blocks. It is the same setting as Font under \"All blocks\""
                    .. " in the Blocks tab, so each follows the other.",
                "About tab: a new Licenses chapter lists the credits and licenses of these fonts."
                    .. " A Licenses folder in the addon holds a copy of each license, and of Tessera's own.",
              },
              fr = {
                "Six polices pensées pour lire plus facilement, dans le choix de police de chaque bloc : Atkinson Hyperlegible et Luciole (malvoyance),"
                    .. " OpenDyslexic (dyslexie), Lexend (fluidité de lecture), Andika (lecteurs débutants) et Inclusive Sans (lisibilité générale),"
                    .. " chacune en normal et en gras."
                    .. " Le menu indique en gris les alphabets couverts par chacune."
                    .. " Les autres addons qui utilisent LibSharedMedia peuvent les choisir aussi.",
                "Onglet Accessibilité : un réglage Police pour tous les blocs. C'est le même réglage que Police sous « Tous les blocs »"
                    .. " dans l'onglet Blocs : l'un suit l'autre.",
                "Onglet À propos : un nouveau chapitre Licences donne les crédits et les licences de ces polices."
                    .. " Un dossier Licenses dans l'addon contient une copie de chaque licence, et celle de Tessera.",
              },
            },
            { kind = "improved",
              en = {
                "Optimizations under the hood: Tessera does less work in the background."
                    .. " Blocks that follow only you ignore the events of other units, a block update no longer creates"
                    .. " new functions each time, and the fade check stops at once when no block fades.",
              },
              fr = {
                "Optimisations sous le capot : Tessera travaille moins en arrière-plan."
                    .. " Les blocs qui ne suivent que toi ignorent les événements des autres unités, une mise à jour de bloc"
                    .. " ne crée plus de nouvelles fonctions à chaque fois, et la vérification des fondus s'arrête aussitôt quand aucun bloc ne s'estompe.",
              },
            },
            { kind = "fixed",
              en = {
                "A block no longer loses its text when you change its font."
                    .. " Tessera measures every block again a moment after the change.",
              },
              fr = {
                "Un bloc ne perd plus son texte quand tu changes sa police."
                    .. " Tessera mesure chaque bloc une nouvelle fois un instant après le changement.",
              },
            },
        },
    },
    {
        version = "1.3.2",
        date = "2026-11-14",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "Aurora style, for DaylightUI.",
              fr = "Style Aurora, pour DaylightUI.",
              show = { page = "PAGE_LOOK", label = "THEME" } },
        },
        sections = {
            { kind = "new",
              en = {
                "New style: Aurora, for DaylightUI. With DaylightUI installed, DaylightUI draws the frame of each block"
                    .. " (rounded border, shadow, background) and the blocks use its font."
                    .. " Aurora also works without DaylightUI, as a plain imitation."
                    .. " With only DaylightUI installed, new profiles start with Aurora."
                    .. " A profile on another style keeps it, and Tessera offers the new one.",
                "Placement: Tessera knows the frames of DaylightUI (unit frames, buffs, quest tracker, chat, info panel)"
                    .. " and warns when a block covers one.",
                "DataBroker tab: with DaylightUI installed, a note explains how to show Tessera's blocks in its panels,"
                    .. " next to Tessera's own blocks (sharing) or instead of them (DataBroker mode).",
              },
              fr = {
                "Nouveau style : Aurore, pour DaylightUI. Avec DaylightUI installé, DaylightUI dessine le cadre de chaque bloc"
                    .. " (bord arrondi, ombre, fond) et les blocs prennent sa police."
                    .. " Aurore marche aussi sans DaylightUI, en simple imitation."
                    .. " Avec DaylightUI seul installé, les nouveaux profils commencent avec Aurore."
                    .. " Un profil sur un autre style le garde, et Tessera te propose le nouveau.",
                "Placement : Tessera connaît les cadres de DaylightUI (unités, buffs, suivi de quêtes, discussion, panneau d'infos)"
                    .. " et prévient quand un bloc en recouvre un.",
                "Onglet DataBroker : avec DaylightUI installé, une note explique comment afficher les blocs de Tessera dans ses panneaux,"
                    .. " à côté de ceux de Tessera (partage) ou à leur place (mode DataBroker).",
              },
            },
            { kind = "improved",
              en = {
                "Tessera waits for another interface addon's setup guide or tour to close before it shows its welcome,"
                    .. " news, DataBroker mode notice and style offer, then follows two seconds later.",
              },
              fr = {
                "Tessera attend la fermeture du guide d'installation ou de la visite d'une autre interface avant d'afficher"
                    .. " sa bienvenue, ses nouveautés, l'avis du mode DataBroker et sa proposition de style, puis enchaîne deux secondes après.",
              },
            },
        },
    },
    {
        version = "1.3.1",
        date = "2026-11-12",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "Bronze and gold style, after FlareUI 6's settings window.",
              fr = "Style Bronze et or, d'après la fenêtre de réglages de FlareUI 6.",
              show = { page = "PAGE_LOOK", label = "THEME" } },
            { en = "Automatic style: your blocks follow the interface you installed.",
              fr = "Style automatique : tes blocs suivent l'interface que tu as installée.",
              show = { page = "PAGE_LOOK", label = "THEME" } },
        },
        sections = {
            { kind = "new",
              en = {
                "Placement banners: an \"Empty blocks\" button (or the V key) shows or hides, while you place,"
                    .. " the blocks set to \"Hide when empty\". Hide them to see the real bar.",
                "New style: Bronze and gold, after the settings window of FlareUI 6. Bronze edges like its frames and gold text;"
                    .. " on the options window, a rock background and gold rows under the mouse."
                    .. " With FlareUI 6 installed, new profiles start with it."
                    .. " A profile on Bronze keeps its style, and Tessera offers the new one.",
              },
              fr = {
                "Bandeaux de placement : un bouton « Blocs vides » (ou la touche V) montre ou cache, pendant le placement,"
                    .. " les blocs réglés sur « Masquer si vide ». Cache-les pour voir la vraie barre.",
                "Nouveau style : Bronze et or, d'après la fenêtre de réglages de FlareUI 6. Bords bronze comme ses cadres et texte or ;"
                    .. " sur la fenêtre d'options, un fond de roche et des lignes dorées sous la souris."
                    .. " Avec FlareUI 6 installé, les nouveaux profils commencent avec lui."
                    .. " Un profil en Bronze garde son style, et Tessera te propose le nouveau.",
              },
            },
            { kind = "improved",
              en = {
                "New \"Automatic\" choice at the top of the style list: it gives your blocks the style of the interface you have installed"
                    .. " and follows it if it goes missing. A style you pick yourself stays fixed.",
                "When the interface your automatic style follows goes missing, Tessera shows the Blizzard style for now"
                    .. " and says so in the chat. Your style comes back with the interface.",
                "Blocks tab, \"All blocks\" page: the style choice is greyed out. A button opens the Look tab,"
                    .. " which picks the style of every block and of the window.",
                "About tab: a thank-you to Malkkav for FlareUI, with a FlareUI button that copies the link of his addon.",
                "The styles that follow another interface get their own names: Bronze, Bronze (old) and Bronze square (FlareUI),"
                    .. " Elven (ElvUI) and Emerald (EllesmereUI). Your blocks look the same; only the name changes."
                    .. " Without its addon, a style says which one it lacks: \"Elven (without ElvUI)\"."
                    .. " Bronze (old), the FlareUI 1.x style, is back in the list.",
              },
              fr = {
                "Nouveau choix « Automatique » en haut de la liste des styles : il donne à tes blocs le style de l'interface que tu as installée"
                    .. " et la suit si elle disparaît. Un style que tu choisis toi-même reste fixe.",
                "Quand l'interface que suit ton style automatique disparaît, Tessera affiche le style Blizzard pour l'instant"
                    .. " et le dit dans la discussion. Ton style revient avec l'interface.",
                "Onglet Blocs, page « Tous les blocs » : le choix du style est grisé. Un bouton ouvre l'onglet Apparence,"
                    .. " qui choisit le style de tous les blocs et de la fenêtre.",
                "Onglet À propos : un merci à Malkkav pour FlareUI, avec un bouton FlareUI qui copie le lien de son addon.",
                "Les styles qui suivent une autre interface prennent leur propre nom : Bronze, Bronze ancien et Bronze carré (FlareUI),"
                    .. " Elfique (ElvUI) et Émeraude (EllesmereUI). Tes blocs ne changent pas ; seul le nom change."
                    .. " Sans son addon, un style dit lequel lui manque : « Elfique (sans ElvUI) »."
                    .. " Bronze ancien, le style de FlareUI 1.x, revient dans la liste.",
              },
            },
        },
    },
    {
        version = "1.3.0",
        date = "2026-11-11",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "Accessibility tab: high contrast, minimum text size, fewer animations.",
              fr = "Onglet Accessibilité : contraste élevé, taille de texte minimale, moins d'animations.",
              show = { page = "PAGE_ACCESS", label = "HIGH_CONTRAST" } },
            { en = "Place by pixel: move a group with the arrow keys.",
              fr = "Placer au pixel : déplace un groupe avec les flèches du clavier.",
              show = { block = "gold", widget = "placeButton" } },
            { en = "A new options window: search, help panel, one setting per row.",
              fr = "Nouvelle fenêtre d'options : recherche, panneau d'aide, un réglage par ligne." },
        },
        sections = {
            { kind = "new",
              en = {
                "Icon size goes up to 200 pixels. The block grows with its icon.",
                "Blocks tab: give a style to one block, to its group or to every block. Ctrl + Z undoes it.",
                "New Accessibility tab: threshold colors, high contrast, minimum text size, and fewer animations.",
                "Fewer animations: blocks fade at once, and a block that wants your attention lights up without flashing.",
                "\"Place by pixel\" (Blocks tab or placement banner): move a block's group pixel by pixel with the arrow keys (Shift: 10 pixels),"
                    .. " the arrows of the banner, or by typing X and Y. Click another block to place it instead."
                    .. " Enter (or \"Keep\") keeps the place, Escape puts the group back. Saved places keep working in older versions.",
                "Placement banner: change the grid size with its arrows, or press G.",
                "\"What's new in 1.3\": after the update, a window lists the big changes,"
                    .. " each with a button that opens the right place and makes the setting blink. It stays in the Help tab.",
              },
              fr = {
                "La taille de l'icône monte jusqu'à 200 pixels. Le bloc grandit avec son icône.",
                "Onglet Blocs : donnez un style à un bloc, à son groupe ou à tous les blocs. Ctrl + Z l'annule.",
                "Nouvel onglet Accessibilité : couleurs des seuils, contraste renforcé, taille minimale du texte, et moins d'animations.",
                "Moins d'animations : les blocs s'estompent d'un coup, et un bloc qui veut votre attention s'éclaire sans clignoter.",
                "« Placer au pixel » (onglet Blocs ou bandeau de placement) : déplacez le groupe d'un bloc pixel par pixel"
                    .. " avec les flèches du clavier (Maj : 10 pixels),"
                    .. " les flèches du bandeau, ou en tapant X et Y. Cliquez sur un autre bloc pour le placer à son tour."
                    .. " Entrée (ou « Garder ») garde la place, Échap remet le groupe où il était."
                    .. " Les places enregistrées marchent aussi dans les anciennes versions.",
                "Bandeau de placement : changez la taille de la grille avec ses flèches, ou appuyez sur G.",
                "« Nouveautés de la 1.3 » : après la mise à jour, une fenêtre liste les grands changements,"
                    .. " chacun avec un bouton qui ouvre le bon endroit et fait clignoter le réglage. Elle reste dans l'onglet Aide.",
              },
            },
            { kind = "improved",
              en = {
                "Streamer mode block: \"Hide when empty\" is off by default, so the block stays on screen to switch the mode on.",
                "Welcome window and quick tour: they follow the new options window (\"On screen\", placing to the pixel, search, help, Accessibility).",
                "\"Place by pixel\" is wider and its text is gold, so it is easy to find.",
                "A bar you placed no longer re-centers itself when a block grows or shrinks (a whisper arriving, for one):"
                    .. " it stays where you put it, and grows to the right.",
                "Export, import and report windows open in front of the options, in the middle of the screen.",
                "The options window opens in the middle of the screen each time, and comes back there when a window that pushed it aside is closed.",
                "Help tab: topics in groups that go together (getting started, placing, the settings tabs, other addons, help),"
                    .. " with thin lines between the groups and between the chapters of a topic.",
                "\"Remove\" replaces \"Hide\": a block you remove leaves its group, and the blocks around it close the gap.",
                "A removed block keeps its settings. Turn on its \"On screen\" switch (the old \"Show\") and it appears next to the options window.",
                "Your profiles keep working. Blocks you had hidden lose the invisible place they kept in a bar.",
                "Texts exported from older versions still import.",
                "The arrow of the Corpse block is 1.5 times bigger.",
                "Options window: one setting per row, its name on the left and its control on the right. Long names wrap instead of being cut.",
                "Lists with a few choices get arrows on each side, like the game's settings."
                    .. " Check boxes are the game's own: click anywhere on the row to tick one.",
                "Pages taller than the window scroll with the mouse wheel.",
                "Search a setting from the top of the options window: Enter or a click opens its page and makes it blink. Old names work too.",
                "A help panel on the right of the options window explains the setting under the mouse, in place of its tooltip.",
                "The arrow next to the cross folds the options window to its top bar."
                    .. " Shift + mouse wheel changes its size (70 to 130 %), shown at the top; Tessera's other windows follow."
                    .. " Their help tooltips are bigger and follow it too.",
                "About tab: the links sit in boxes, ready to copy (the game opens no browser).",
                "Blocks tab: one page in place of five sub-tabs. The \"On screen\" switch sits left of the block's name.",
                "The essentials and the block's own settings come first; its look, when to show it, and its name and clicks fold into sections.",
                "The block list shows the blocks on your screen first, then those available.",
                "Ctrl + Z also undoes while the options window is open (taking blocks off, a style...).",
              },
              fr = {
                "Fenêtre de bienvenue et visite rapide : elles suivent la nouvelle fenêtre d'options"
                    .. " (« Sur l'écran », placement au pixel, recherche, aide, Accessibilité).",
                "« Placer au pixel » est plus large et son texte est doré : on le trouve plus vite.",
                "Une barre que vous avez placée ne se recentre plus quand un bloc s'élargit ou rétrécit (un chuchotement qui arrive,"
                    .. " par exemple) : elle reste où vous l'avez mise, et s'agrandit vers la droite.",
                "Les fenêtres d'export, d'import et de rapport s'ouvrent devant les options, au milieu de l'écran.",
                "La fenêtre d'options s'ouvre chaque fois au milieu de l'écran, et y revient quand une fenêtre qui l'avait poussée se ferme.",
                "Onglet Aide : sujets rangés en groupes qui vont ensemble (prise en main, placement, onglets de réglages,"
                    .. " autres addons, aide), avec de fins traits entre les groupes et entre les chapitres d'un sujet.",
                "Bloc Mode streamer : « Masquer si vide » est désactivé au départ, le bloc reste à l'écran pour activer le mode.",
                "« Retirer » remplace « Masquer » : un bloc que vous retirez sort de son groupe, et ses voisins se resserrent.",
                "Un bloc retiré garde ses réglages. Allumez son interrupteur « Sur l'écran » (l'ancien « Afficher ») et il apparaît à côté des options.",
                "Vos profils continuent de fonctionner. Les blocs masqués perdent la place invisible qu'ils gardaient dans une barre.",
                "Les textes exportés d'anciennes versions s'importent toujours.",
                "La flèche du bloc Cadavre est 1,5 fois plus grande.",
                "Fenêtre d'options : un réglage par ligne, son nom à gauche et sa commande à droite."
                    .. " Les noms longs passent à la ligne au lieu d'être coupés.",
                "Les listes de quelques choix ont une flèche de chaque côté, comme les réglages du jeu."
                    .. " Les cases à cocher sont celles du jeu : cliquez n'importe où sur la ligne pour cocher.",
                "Les pages plus hautes que la fenêtre défilent à la molette.",
                "Cherchez un réglage en haut de la fenêtre d'options : Entrée ou un clic ouvre sa page et le fait clignoter."
                    .. " Les anciens noms marchent aussi.",
                "Un panneau d'aide, à droite de la fenêtre d'options, explique le réglage sous la souris, à la place de son infobulle.",
                "La flèche à côté de la croix réduit la fenêtre d'options à sa barre du haut."
                    .. " Maj + molette change sa taille (de 70 à 130 %), affichée en haut ; les autres fenêtres de Tessera suivent."
                    .. " Leurs bulles d'aide sont plus grandes et suivent aussi.",
                "Onglet À propos : les liens sont dans des cases, prêts à copier (le jeu n'ouvre pas de navigateur).",
                "Onglet Blocs : une seule page au lieu de cinq sous-onglets. L'interrupteur « Sur l'écran » se trouve à gauche du nom du bloc.",
                "L'essentiel et les réglages propres au bloc viennent d'abord ; son apparence, quand l'afficher, son nom et"
                    .. " ses clics se replient en sections.",
                "La liste des blocs montre d'abord ceux sur votre écran, puis ceux disponibles.",
                "Ctrl + Z annule aussi quand la fenêtre d'options est ouverte (blocs retirés, un style...).",
              },
            },
            { kind = "fixed",
              en = {
                "Camping block: near a campfire it shows the campfire instead of \"None\".",
              },
              fr = {
                "Bloc Camping : près d'un feu de camp, il affiche le feu au lieu de « Aucun ».",
              },
            },
        },
    },
    {
        version = "1.2.1",
        date = "2026-11-10",
        sections = {
            { kind = "improved",
              en = {
                "Show only on hover: blocks fade in and out without visible steps.",
              },
              fr = {
                "Afficher seulement au survol : les blocs apparaissent et disparaissent sans à-coups.",
              },
            },
            { kind = "fixed",
              en = {
                "A group you stick to a screen edge gets no separator line along that edge.",
                "A group you place in the middle of the screen stays centered when its blocks get wider or narrower.",
                "A group stuck to the left or right edge of the screen keeps that edge when a block gets wider, so its columns no longer overlap.",
                "A spacer in a column draws the separator line under it, like the blocks around it.",
              },
              fr = {
                "Un groupe que vous collez à un bord de l'écran n'a plus de ligne de séparation contre ce bord.",
                "Un groupe que vous placez au milieu de l'écran reste centré quand ses blocs s'élargissent ou rétrécissent.",
                "Un groupe collé au bord gauche ou droit de l'écran garde ce bord quand un bloc s'élargit : ses colonnes ne se chevauchent plus.",
                "Un espace dans une colonne trace la ligne de séparation en dessous de lui, comme les blocs voisins.",
              },
            },
        },
    },
    {
        version = "1.2.0",
        date = "2026-11-07",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "Style a whole bar of merged blocks at once.",
              fr = "Donne un style à toute une barre de blocs d'un coup." },
            { en = "Friends: the count takes your status color; Battle.net friends join the tooltip.",
              fr = "Amis : le compte prend la couleur de ton statut ; les amis Battle.net arrivent dans l'infobulle." },
        },
        sections = {
            { kind = "new",
              en = {
                "Style a whole group at once: each bar of merged blocks has its entry in the Blocks tab list, "
                    .. "named after its first block, and every setting then applies to the bar and the rows below it. "
                    .. "\"Copy style to group\" (next to \"Copy style to all\", and in the quick menu) gives one "
                    .. "block's look to the rest of its group. You can undo either copy (Ctrl + Z in placement mode).",
              },
              fr = {
                "Régler tout un groupe d'un coup : chaque barre de blocs fusionnés a son entrée dans la liste de "
                    .. "l'onglet Blocs, nommée d'après son premier bloc, et chaque réglage s'applique alors à la barre "
                    .. "et aux rangées en dessous. « Copier sur le groupe » (à côté de « Copier sur tous », et dans le "
                    .. "menu rapide) donne l'apparence d'un bloc au reste de son groupe. Tu peux annuler l'une ou "
                    .. "l'autre copie (Ctrl + Z en mode placement).",
              } },
            { kind = "improved",
              en = {
                "Weapon skills becomes Skills: show your main-hand weapon's skill, follow the fight (your "
                    .. "ranged weapon's while you shoot), or a skill you pick (This block).",
                "Friends: the count takes the color of your status (available, away, busy, appear offline), "
                    .. "and the tooltip lists your Battle.net friends online too, with their character in WoW.",
              },
              fr = {
                "Compétences d'armes devient Compétences : affiche la compétence de l'arme en main, suit le "
                    .. "combat (celle de l'arme à distance pendant que tu tires), ou une compétence que tu choisis (Ce bloc).",
                "Amis : le chiffre prend la couleur de ton statut (disponible, absence, ne pas déranger, apparaître "
                    .. "hors ligne), et l'infobulle liste aussi tes amis Battle.net en ligne, avec leur personnage dans WoW.",
              } },
        },
    },
    {
        version = "1.1.2",
        date = "2026-11-07",
        sections = {
            { kind = "improved",
              en = {
                "FlareUI styles follow FlareUI 4.0's text shadow, and its font, outline and shadow by themselves: "
                    .. "a change made in FlareUI reaches the blocks at the next /reload, with no need to apply the "
                    .. "style again. A font you set on a block stays. Tessera also knows FlareUI's new frames (party, "
                    .. "raid, boss, target of target) when it places blocks around them.",
              },
              fr = {
                "Les styles FlareUI suivent l'ombre du texte de FlareUI 4.0, et sa police, son contour et son ombre "
                    .. "tout seuls : un changement fait dans FlareUI arrive sur les blocs au /reload suivant, sans "
                    .. "réappliquer le style. Une police que tu as choisie pour un bloc reste. Tessera connaît aussi les "
                    .. "nouveaux cadres de FlareUI (groupe, raid, boss, cible de la cible) quand il place les blocs autour.",
              } },
            { kind = "fixed",
              en = {
                "Shift + click to copy a value into the chat, and replying to a whisper, use the game's "
                    .. "current chat functions: they keep working when Blizzard removes the old ones.",
                "XP: Forever's max level is read from the game, so the block knows when you reach it.",
              },
              fr = {
                "Maj + clic pour copier une valeur dans la discussion, et la réponse à un chuchotement, "
                    .. "utilisent les fonctions de discussion actuelles du jeu : elles marcheront encore quand "
                    .. "Blizzard retirera les anciennes.",
                "XP : le niveau maximum de Forever est lu dans le jeu, le bloc sait quand tu l'atteins.",
              } },
        },
    },
    {
        version = "1.1.1",
        date = "2026-11-06",
        sections = {
            { kind = "fixed",
              en = {
                "\"Replace with...\" a hidden block could break a bar apart, when that block still sat in "
                    .. "the bar among other hidden blocks. Ctrl + Z undid it; now it no longer happens.",
              },
              fr = {
                "« Remplacer par... » un bloc masqué pouvait casser une barre, quand ce bloc était encore "
                    .. "placé dans la barre parmi d'autres blocs masqués. Ctrl + Z l'annulait ; ça n'arrive plus.",
              } },
        },
    },
    {
        version = "1.1.0",
        date = "2026-11-06",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "7 new blocks, among them the micro-menu, the hunter pet and the way back to your corpse.",
              fr = "7 nouveaux blocs, dont le micro-menu, le familier du chasseur et le chemin vers ton corps." },
            { en = "Pin a tooltip next to its block.",
              fr = "Épingle une infobulle à côté de son bloc." },
            { en = "Give any block a name of your own.",
              fr = "Donne à n'importe quel bloc un nom à toi.",
              show = { block = "gold", label = "CUSTOM_NAME" } },
        },
        sections = {
            { kind = "intro",
              en = {
                "Your first big Tessera update on WoW Forever: 7 new blocks, a choice of display on 14 more, pinned tooltips "
                    .. "and names of your own.",
              },
              fr = {
                "La première grosse mise à jour de Tessera sur WoW Forever : 7 nouveaux blocs, un choix "
                    .. "d'affichage sur 14 autres, des infobulles épinglées et des noms à toi.",
              } },
            { kind = "new",
              en = {
                "Micro-menu: Blizzard's micro menu in one block. Its tooltip lists the menus (character, spellbook, "
                    .. "talents, professions, quests, guild, Legacy...); a click opens the list. A menu you have not "
                    .. "unlocked yet stays grey until you reach it.",
                "Hunter pet: your pet's happiness, with its damage and loyalty; a warning when it loses loyalty.",
                "Weapon enchant: time left on your poisons, sharpening stones or shaman imbues.",
                "Long buffs: Well Fed, elixirs and world buffs of 10 minutes or more, the shortest first.",
                "XP per hour, or the time to your next level at your pace.",
                "Gold this session: what you earned or spent since you logged in, and per hour.",
                "Corpse: while you are a ghost, the distance and an arrow toward your body; click for a map pin.",
                "Pin a tooltip: it stays open next to its block and updates every second (quick menu, or a "
                    .. "Shift / middle click).",
                "Custom name: rename any block, for example a launcher that shows \"SomeAddonMinimapButton\".",
                "Goal: a new \"Item\" type counts up to 3 items in your bags (\"47 / 100\"); drop an item on the block to add it.",
              },
              fr = {
                "Micro-menu : le micro-menu de Blizzard en un seul bloc. Son infobulle liste les menus (personnage, "
                    .. "grimoire, talents, métiers, quêtes, guilde, Héritage...) ; un clic ouvre la liste. Un menu pas "
                    .. "encore débloqué reste gris jusqu'à ce que tu l'atteignes.",
                "Familier du chasseur : l'humeur de ton familier, avec ses dégâts et sa fidélité ; une alerte "
                    .. "quand il perd de la fidélité.",
                "Enchantement d'arme : temps restant de tes poisons, pierres à aiguiser ou imprégnations du chaman.",
                "Buffs longs : Bien nourri, élixirs et buffs mondiaux de 10 minutes ou plus, le plus court en premier.",
                "XP par heure, ou le temps avant ton niveau suivant à ton rythme.",
                "Or de la session : ce que tu as gagné ou dépensé depuis ta connexion, et par heure.",
                "Corps : quand tu es un fantôme, la distance et une flèche vers ton corps ; clic pour un repère "
                    .. "sur la carte.",
                "Épingle une infobulle : elle reste ouverte à côté de son bloc et se met à jour chaque seconde "
                    .. "(menu rapide, ou Maj + clic / clic milieu).",
                "Nom personnalisé : renomme n'importe quel bloc, par exemple un lanceur qui affiche "
                    .. "« SomeAddonMinimapButton ».",
                "Objectif : un nouveau type « Objet » compte jusqu'à 3 objets de tes sacs (« 47 / 100 ») ; lâche un objet sur le bloc pour l'ajouter.",
              } },
            { kind = "improved",
              en = {
                "Pick what a block shows (\"This block\" tab, \"Value shown\"): played time this level, in total or this "
                    .. "session; zone with its subzone; completed quests; one tracked currency; honor out of its cap "
                    .. "or in percent; the next Legacy reward; Comprehension scrolls; rested XP in bubbles; daily or "
                    .. "weekly reset; the last whisper's name; speed in meters per second; Tessera's own memory.",
                "Volume: choose the volume the block shows and your mouse wheel changes (music, effects...).",
                "Friends: you can leave out your Battle.net friends.",
                "Text: a shadow under the text, with or without the outline (Text tab).",
                "Any block can show its icon alone (Display, \"Show the value\"); the tooltip and the clicks stay.",
                "Options window: a list of pages on the left, a short hint on each page, more room, and a first "
                    .. "\"This block\" tab with everything a block has of its own (right-click a block to open it). "
                    .. "Nothing was removed: settings only moved.",
                "Tessera's windows no longer cover each other: the tour and the text windows open beside the options.",
                "Translations now live on GitHub: send yours as a pull request or a \"Translation\" issue.",
                "Quick tour: two new steps, a block's own settings and the quick menu. Demo mode: \"Keep this style\".",
                "Weapon enchant: watch both hands, the main hand or the off hand. Micro-menu: its count can stay on.",
                "Bags: the tooltip lists profession bags (herb bag...) apart. Durability: the tooltip also lists "
                    .. "worn items in your bags, under their own title.",
                "Comprehension reads your skill directly and shows its description; Honor shows yesterday's kills "
                    .. "and honor when the game gives them.",
                "The demo mode shows the new blocks.",
              },
              fr = {
                "Choisis ce que montre un bloc (onglet « Ce bloc », « Valeur affichée ») : temps de jeu à ce niveau, "
                    .. "au total ou cette session ; zone avec sa sous-zone ; quêtes terminées ; une seule monnaie "
                    .. "suivie ; honneur sur son plafond ou en pourcentage ; prochaine récompense d'Héritage ; "
                    .. "parchemins de Compréhension ; XP de repos en bulles ; réinitialisation quotidienne ou "
                    .. "hebdomadaire ; nom du dernier chuchotement ; vitesse en mètres par seconde ; mémoire de "
                    .. "Tessera seul.",
                "Volume : choisis le volume que le bloc affiche et que ta molette change (musique, effets...).",
                "Amis : tu peux laisser de côté tes amis Battle.net.",
                "Texte : une ombre sous le texte, avec ou sans le contour (onglet Texte).",
                "Chaque bloc peut n'afficher que son icône (Affichage, « Afficher la valeur ») ; l'infobulle et les clics restent.",
                "Fenêtre des options : la liste des pages à gauche, une courte aide sur chaque page, plus d'air, "
                    .. "et un premier onglet « Ce bloc » avec tout ce qui est propre à un bloc (clic droit sur un "
                    .. "bloc pour l'ouvrir). Rien n'a été retiré : les réglages ont seulement changé de place.",
                "Les fenêtres de Tessera ne se recouvrent plus : la visite guidée et les fenêtres de texte s'ouvrent à côté des options.",
                "Les traductions passent sur GitHub : envoie la tienne en pull request ou dans une issue « Translation ».",
                "Visite guidée : deux nouvelles étapes, les réglages d'un bloc et le menu rapide. Mode démo : « Garder ce style ».",
                "Enchantement d'arme : surveille les deux mains, la main droite ou la main gauche. Micro-menu : son compteur peut rester affiché.",
                "Sacs : l'infobulle liste les sacs de métier (sac d'herbes...) à part. Durabilité : l'infobulle "
                    .. "liste aussi les pièces abîmées de tes sacs, sous leur propre titre.",
                "Compréhension lit ta compétence directement et montre sa description ; Honneur montre les "
                    .. "victoires et l'honneur d'hier quand le jeu les donne.",
                "Le mode démo montre les nouveaux blocs.",
              } },
            { kind = "fixed",
              en = {
                "\"Add a launcher block\" no longer lists map pins (Questie's numbered frames), nor a status "
                    .. "text in place of an addon's name.",
                "The War Within and Midnight styles: the placement banner and small windows take a plain frame "
                    .. "in the style's colors (the large art frame crowded their text), and the game's texts no longer "
                    .. "show through the options window.",
                "The Talent points block shows your unspent points on WoW Forever (it never appeared).",
                "The Weapon skills block shows the skill of the weapon you hold: a two-handed sword no "
                    .. "longer shows your one-handed sword skill (same for axes and maces).",
              },
              fr = {
                "« Ajouter un bloc lanceur » ne liste plus les repères de carte (cadres numérotés de Questie), "
                    .. "ni un texte d'état à la place du nom d'un addon.",
                "Styles The War Within et Midnight : le bandeau de placement et les petites fenêtres prennent un "
                    .. "cadre simple aux couleurs du style (le grand cadre décoré serrait leur texte), et les textes du "
                    .. "jeu ne se voient plus à travers la fenêtre d'options.",
                "Le bloc Points de talent affiche tes points non dépensés sur WoW Forever (il n'apparaissait jamais).",
                "Le bloc Compétences d'armes affiche la compétence de l'arme que tu tiens : une épée à deux "
                    .. "mains n'affiche plus ta compétence d'épée à une main (pareil pour les haches et les masses).",
              } },
        },
    },
    {
        version = "1.0.4",
        date = "2026-11-05",
        sections = {
            { kind = "fixed",
              en = {
                "The Bags block no longer counts the free slots of profession bags (herb bag, for one), "
                    .. "which only take their own items. The tooltip still lists every bag.",
              },
              fr = {
                "Le bloc Sacs ne compte plus les places libres des sacs de métier (sac d'herbes, par exemple), "
                    .. "qui ne prennent que leurs propres objets. La bulle montre toujours chaque sac.",
              } },
        },
    },
    {
        version = "1.0.3",
        date = "2026-11-05",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "New styles: Tessera, The War Within, Midnight and Blizzard Forever.",
              fr = "Nouveaux styles : Tessera, The War Within, Midnight et Blizzard Forever.",
              show = { page = "PAGE_LOOK", label = "THEME" } },
        },
        sections = {
            { kind = "new",
              en = {
                "New Tessera style, in the addon's own colors: turquoise on dark slate, with the game's "
                    .. "tooltip border. The default style does not change. The options window's background now "
                    .. "reaches its border in every style.",
                "New The War Within and Midnight styles: the frames Blizzard draws for these expansions on "
                    .. "the options window, and their colors on the blocks.",
                "Blizzard styles named after the games: Blizzard Retail (silver, formerly Blizzard modern), "
                    .. "the new Blizzard Forever (gold) and Blizzard Classic (formerly Blizzard classic), each with "
                    .. "its square version, and the same color on WoW Forever and on Retail. Your look does not "
                    .. "change: a profile that showed gold (Blizzard modern on WoW Forever, Blizzard modern square "
                    .. "everywhere) moves to Blizzard Forever or Blizzard Forever square.",
              },
              fr = {
                "Nouveau style Tessera, aux couleurs de l'addon : turquoise sur ardoise sombre, avec la "
                    .. "bordure des infobulles du jeu. Le style par défaut ne change pas. Le fond de la fenêtre "
                    .. "d'options touche maintenant sa bordure, dans tous les styles.",
                "Nouveaux styles The War Within et Midnight : les cadres que Blizzard dessine pour ces "
                    .. "extensions sur la fenêtre d'options, et leurs couleurs sur les blocs.",
                "Les styles Blizzard portent le nom des jeux : Blizzard Retail (argenté, ancien Blizzard "
                    .. "moderne), le nouveau Blizzard Forever (doré) et Blizzard Classic (ancien Blizzard "
                    .. "classique), chacun avec sa version carrée, et la même couleur sur WoW Forever et sur "
                    .. "Retail. Ton allure ne change pas : un profil qui s'affichait en doré (Blizzard moderne "
                    .. "sur WoW Forever, Blizzard moderne carré partout) passe à Blizzard Forever ou Blizzard "
                    .. "Forever carré.",
              } },
            { kind = "fixed",
              en = {
                "The Tessera icon sits in the middle of its minimap button's ring.",
                "A click on a gathering profession block (Herbalism, for one) opens that profession's page, "
                    .. "not the last profession you opened, and a second click closes it.",
              },
              fr = {
                "L'icône de Tessera est centrée dans l'anneau de son bouton de la minicarte.",
                "Un clic sur le bloc d'un métier de récolte (Herboristerie, par exemple) ouvre la page de ce "
                    .. "métier, et non le dernier métier ouvert ; un deuxième clic la ferme.",
              } },
        },
    },
    {
        version = "1.0.2",
        date = "2026-11-05",
        sections = {
            { kind = "fixed",
              en = {
                "A block that hides itself when empty (Mail, for one) no longer leaves the block above it as "
                    .. "wide as it was, even after a reload.",
              },
              fr = {
                "Un bloc qui se masque quand il est vide (Courrier, par exemple) ne laisse plus le bloc "
                    .. "au-dessus de lui aussi large qu'avant, même après un rechargement.",
              } },
        },
    },
    {
        version = "1.0.1",
        date = "2026-11-05",
        sections = {
            { kind = "fixed",
              en = {
                "The First Aid block shows your skill on WoW Forever (it stayed on \"None\"), and First "
                    .. "Aid no longer takes the place of a second primary profession.",
              },
              fr = {
                "Le bloc Secourisme affiche ta compétence sur WoW Forever (il restait sur « Aucun »), et le "
                    .. "secourisme ne prend plus la place d'un deuxième métier principal.",
              } },
        },
    },
    {
        version = "1.0.0",
        date = "2026-11-04",
        -- "What's new": one short line per new thing (About tab, update popup), with where to see it
        highlights = {
            { en = "More than 40 blocks, launchers and DataBroker, made for WoW Forever.",
              fr = "Plus de 40 blocs, des lanceurs et DataBroker, faits pour WoW Forever." },
            { en = "Blocks dropped together merge like the tiles of a mosaic.",
              fr = "Les blocs posés ensemble s'assemblent comme les tesselles d'une mosaïque." },
        },
        sections = {
            { kind = "intro",
              en = {
                "First stable version of Tessera, made for WoW Forever. New here? Type /tessera: the quick tour "
                    .. "shows the essentials, and the demo mode (Help tab) shows every block and every style.",
                "In short: more than 40 information blocks (gold, bags, durability, FPS, latency, clocks, date, "
                    .. "XP, quests, professions, reputation, mail, WoW Forever's own systems...), launcher blocks "
                    .. "for minimap and addon buttons, and DataBroker both ways.",
                "Blocks dropped against each other merge like the tiles of a mosaic: bars, columns, corners. "
                    .. "Screen edges, ready-made layouts, 19 styles, profiles and sharing as text.",
              },
              fr = {
                "Première version stable de Tessera, faite pour WoW Forever. Tu découvres Tessera ? Tape /tessera : "
                    .. "la visite rapide montre l'essentiel, et le mode démo (onglet Aide) montre tous les blocs et "
                    .. "tous les styles.",
                "En bref : plus de 40 blocs d'informations (or, sacs, durabilité, FPS, latence, horloges, date, XP, "
                    .. "quêtes, métiers, réputation, courrier, systèmes propres à WoW Forever...), des blocs lanceurs "
                    .. "pour les boutons de la minicarte et des addons, et DataBroker dans les deux sens.",
                "Les blocs posés l'un contre l'autre s'assemblent comme les tesselles d'une mosaïque : barres, "
                    .. "colonnes, coins. Bords de l'écran, dispositions toutes prêtes, 19 styles, profils et partage "
                    .. "en texte.",
              } },
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
                "The Bags block shows used slots out of the total in new profiles (your saved setting does "
                    .. "not change; Text tab, Slots shown).",
                "The About tab thanks Funkeh, whose StatBlock Core gave me the idea of Tessera's "
                    .. "free-floating blocks.",
              },
              fr = {
                "Nouvelle icône : un T et une tesselle dorée sur fond turquoise, plus facile à repérer dans "
                    .. "la liste des addons et sur le bouton de la minicarte.",
                "Le bloc Sacs affiche les places utilisées sur le total dans les nouveaux profils (ton réglage "
                    .. "enregistré ne change pas ; onglet Texte, Places affichées).",
                "L'onglet À propos remercie Funkeh, dont l'addon StatBlock Core m'a donné l'idée des blocs "
                    .. "libres de Tessera.",
              } },
            { kind = "fixed",
              en = {
                "The coin icons of the Gold block no longer spill over the next block.",
                "Each character's data (its own profile, its gold and gold history) is now saved under its "
                    .. "full name, as WoW Forever has no realms: it no longer depends on the server's name, which "
                    .. "may change. Your settings carry over on their own at your next login.",
                "Arcana, ChocolateBar's new name, now switches Tessera to DataBroker mode like ChocolateBar "
                    .. "did, and the help names it.",
              },
              fr = {
                "Les icônes de pièces du bloc Or ne débordent plus sur le bloc voisin.",
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
