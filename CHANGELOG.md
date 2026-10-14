# Changelog

All notable changes to Tessera. The in-game **About** tab (Changelog topic) shows the same list
(from `Changelog.lua`), in English or French depending on the game language.

## 1.0.0-rc5 — 

- Placement mode, easier without knowing the shortcuts: a cross on the hovered block hides it, and arrows replace it with another block in the exact same place. A plain right-click opens the quick menu (Alt + right-click still works). What can be done with the hovered block shows in a panel under the placement banner (draggable with it), no longer in a tooltip covering the block.
- Replacing blocks: the list shows the hidden blocks (they take the place) apart from the shown ones (they swap places). A spacer can now be replaced by a block, to fill the room the ready-made layouts leave in their bars (Ctrl + Z brings it back). A bar's first block can be replaced without the bar losing its screen edge or its width. New help topic "Replacing blocks".
- Four new fantasy styles (Look tab), with the game's fonts: Runestone (text only, black and white, silver edges), Grimoire (dark leather and gold), Parchment (parchment and brown ink), Arcane (deep violet, pale blue letters).
- The styles of FlareUI, ElvUI and EllesmereUI can be picked without that addon: they are then an imitation, marked in the list, and the chat says what differs.
- More choices for how blocks show their value (Text tab, "Value shown"): gold (coin icons or colored letters, gold and silver format, rounding, thousands separator), bags (free, used or free / total), XP (percent, values or XP to go, rested XP or not), durability (most worn item or average), FPS and latency (with or without the unit, home, world or both latencies), clocks (seconds), coordinates (0 to 2 decimals), friends and guild (online or online / total), reputation (standing, faction name, percent).
- Blocks tab: how a block shows its value (gold format, clock, decimals, stat shown...) is now in the Text sub-tab, under "Value shown"; Behaviour keeps the rest (goal, thresholds, hiding, clicks).
- Styles: Parchment is easier to read (darker ink, colors in the values darkened); ElvUI shows the values in its value color (blue by default) and EllesmereUI has its green accent between merged blocks, so they no longer look alike. FlareUI 1.x is only listed with FlareUI 1.x installed (profiles using it keep it).
- Quick tour: a new step to try the ready-made layouts one after the other with arrows, right on the screen; keep one, or yours comes back.
- Placement mode: the names under the blocks no longer overlap each other nor go off screen (Compact and Left column layouts); when room is short, a name is shortened to its block's width.
- New ready-made layout "Double bar" (Look tab): the top bar with the basics, and a second bar always shown with WoW Forever's blocks (Legacy, Comprehension, Camping, Honor, weapon skills).
- Placement: a single block dropped against a side already taken slips in between (the block that was there moves along), so a block taken out of a bar can be put back in its place. Nothing docks any more on the side of a bar where its second row hangs (that mixed both groups). A second row dragged and dropped back against its bar keeps hanging there, centered and full width.
- Blocks made for WoW Forever's own systems are more robust: if the game changes at release, they show nothing rather than an error.
- Help: where to find the blocks hidden at first, tooltips while holding Alt, /roll on the group loot block, the stat shown on the stats block; /tessera help is in the chat command list.
- Help split into small texts: easier to translate with CurseForge's tool, and a change to one line no longer asks translators to redo the whole help.
- FlareUI styles (2.x, 1.x and Square): the font of FlareUI's XP bar, Arial Narrow by default, or the one picked in FlareUI's settings. Blocks already in a FlareUI style keep their font: pick the style again in the Look tab to get it.
- Development commands removed from released versions: only the commands useful to players remain.
- Code checked with Ketho's WoW API annotations (the tool addon reviewers use): no deprecated function, no unknown global; old fallbacks for other game versions removed.

## 1.0.0-rc4 — 2026-10-13

- Three new blocks (hidden by default, add them from the Blocks tab): Mana regeneration (per 5 seconds, the value while casting in combat), Character stats (the stat of your choice on the block, all of them in the tooltip) and Group loot (loot method, threshold, master looter; click: /roll).
- Durability tooltip: the repair cost of your equipment.
- General tab, new Tooltips section: tooltip size, and tooltips only while holding Alt.
- New logo, drawn in high definition: sharp in the addon list, on the minimap button and on large screens.
- About tab: a fuller account of how Tessera is made, what the author does and what the AI does.

## 1.0.0-rc3 — 2026-10-11

- New ready-made layout "Around the gryphons": two groups in the bottom corners of the screen, on both sides of the action bars, WoW Forever blocks included. Ready-made layouts are now picked in a list (Look tab), with a description of each one.
- New "Replace with..." (quick menu, or next to the block list in the Blocks tab): puts another block exactly in a block's place, with its look, without moving the others; or swaps two shown blocks.
- Screen edges: drop a group against an edge and Tessera offers to stick it there (no border on that side, stays put on any screen). Along the top or bottom, a bar can be stretched over the whole width: spacer blocks fill the room (blocks on the left, center, right or spread) and the blocks keep their size. Setting in the Look tab (ask, always, never).
- New ready-made layouts in the spirit of desktop taskbars and menu bars: Stormwind Stained Glass, Cathedral Rose Window, Tirisfal Orchard and Gnomeregan, with the clock, FPS, latency and volume where you expect them.
- New "Add a spacer" (quick menu): an empty block on the left, right, above or below a block, slipped in between if another block is already there; in a stretched bar it takes room from the other spacers.
- New styles "FlareUI Square", "Blizzard Modern Square" and "Blizzard Classic Square": square corners, a plain dark background, a thin border and a thin line between merged blocks. The line is also an option of every style (Frame tab, Separators), on by default in the layouts showing the WoW Forever blocks.
- New Look tab: the style of the blocks, how groups look, screen edges, ready-made layouts and sharing are now in one place (they were spread over the General and Profiles tabs). The options window is larger and roomier, and shrinks on small screens so blocks still fit on both sides of it.
- Group look (Look tab): fused (one bar, one border, as before), tiles (each block keeps its frame, with a small adjustable joint, like a mosaic) or separate (each block keeps its whole frame and blocks no longer merge; replaces the "Merge blocks" option). A single group can have its own look: quick menu, Group look. Existing profiles keep their look.
- Share only a style (the look) or only a layout (the placement) as text, from the Look tab. One import window reads a style, a layout or a whole profile, and first lists what is missing on this computer (another addon's blocks, LibSharedMedia fonts or frames, the interface a style matches, WoW Forever blocks): those parts are skipped or replaced by the default font or frame.
- Quick tour: seven short steps on first launch, and again from the Help tab. The help was reviewed for the new tab, and the placement banner and the tooltip of unlocked blocks now mention what the quick menu offers (add a spacer, replace with..., group look).
- Round minimap button: click for the options, right-click to lock or unlock the blocks, drag it around the minimap. With FlareUI, Tessera stays in FlareUI's addon bag instead (no duplicate). /tessera minimap still hides or shows it.
- Blizzard's Edit Mode: when a Tessera bar stuck to the top or bottom covers Blizzard frames (action bars, menu, minimap...), Tessera offers a copy of your Edit Mode layout, "My layout (Tessera 1)", where only those frames move, and activates it. Your layout is never changed. "Back to my layout" and "Delete the copies" (only Tessera's unchanged copies, never a layout of yours) are in the Look tab. Tested on Blizzard's interface (Modern, Classic) and FlareUI unchanged; with FlareUI, its own frames go back to their default place in the copy (Tessera warns before). With another interface, results may be unexpected.
- New blocks and ready-made layouts are drawn above Blizzard's action bars (layer "High"), so a bar along the bottom passes in front of the gryphons; the layer can still be changed (Blocks tab, Display). Existing blocks keep their layer.
- The Broker tab becomes the DataBroker tab, in two parts: "Plugins as blocks" (other addons' DataBroker plugins as Tessera blocks, moved from the Launchers tab) and "Sharing and mode" (sharing Tessera's blocks with Titan Panel, Bazooka..., DataBroker mode). The Launchers tab keeps the minimap buttons.
- Help rewritten with one topic per tab (Blocks, Look, Blizzard's Edit Mode, General, Launchers, DataBroker, Profiles, Help and About), tooltips updated, and /tessera preview forever (the WoW Forever blocks with sample values) added to the help and the command list. Button texts too long for their button (in any language) are made smaller instead of spilling out.
- Fix: choosing a ready-made layout showed the "reset everything" message in the chat; it now says which layout was applied.
- Fix: switching to another layout or profile could raise a Lua error ("Cannot anchor to a region dependent on it") when two blocks swapped places.
- Fix: a column stuck to the bottom of the screen piled up its blocks; the whole column now stays visible above the edge.
- Fix: spacers did not follow the layer (strata), opacity or hide options chosen for all blocks, and could stay hidden behind the action bars.
- Releases: the English and French strings are sent to CurseForge's localization tool automatically, and community translations are added to the addon.

## 1.0.0-rc2 — 2026-10-11

- When an interface with a matching style is installed (FlareUI 1.x or 2.x, ElvUI, EllesmereUI), a window shows that style on sample blocks and offers it. Tessera no longer changes the style of your blocks on its own.
- DataBroker mode: turning it off now only applies to the display addon detected at that moment (another one installed later offers the mode again, with its explanation window). The Broker tab shows the current state and can go back to the automatic choice.
- Opening Blizzard's Edit Mode also unlocks the blocks (option in the General tab).
- New "Bring blocks back on screen" button and /tessera recover command, for groups that stick out of the screen.
- Icons (Frame tab): the same size for every block, a square or round frame with a thin border (the color you want), and black and white, for Tessera's blocks, launchers and DataBroker blocks. The Transparent style uses square icons of the same size by default.
- After an update, a window offers to read what's new.
- The Help tab is now split into topics: a short summary first, then pick a topic on the left. Several tooltips were updated.
- The Version tab becomes About, laid out like the Help tab: an About topic (version, author, translators, license, source code) and a Changelog topic.
- Key bindings now have their own Tessera category in the game's key bindings, like other addons.
- New WoW Forever blocks: Comprehension (scroll-reading skill and the scrolls in your bags), Camping (camp buffs and campfire kit cooldown, a click lights a campfire) and Honor. The Legacy points tooltip now shows your challenges completed per category. Like every block, they can be shared with DataBroker display addons. WoW Forever is in beta: these systems may change.
- Reset everything (Profiles tab, Blizzard's AddOns settings or /tessera reset) now really erases all of Tessera's saved data and reloads the interface, as on a first install.
- Ready for community translations with CurseForge's localization tool.
- Blocks shown from the options are now placed evenly on both sides of the window, and never over Blizzard's action bars, minimap or chat.
- The placement banner steps aside while the options window is open, and remembers where it is dragged; it is not shown while Blizzard's Edit Mode is open.
- Professions: a click on a gathering profession (herbalism, mining, skinning) opens the professions book on WoW Forever; the talents block opens the talents with Blizzard's own button. The weapon skills block now works on WoW Forever.
- New Legacy points block (WoW Forever): your points, the next reward and every reward of the track in the tooltip, a progress bar toward the next reward, and a click opens the Legacy panel.
- Fix: hiding all blocks with the key binding during combat left their invisible click buttons active; the blocks are now hidden when combat ends.

## 1.0.0-rc1 — 2026-10-10

- First public version (release candidate).
- More than 35 information blocks: gold (with history), bags, durability, FPS, latency, time, XP, coordinates, friends, guild, group, quests, reputation, currencies, professions, weapon skills, talents, mail, whispers, reagents, ammo, instances, played time, goal and more.
- Launcher blocks made from minimap buttons and addon compartment entries.
- DataBroker: add other addons' DataBroker objects as blocks, share Tessera's blocks with Titan Panel, ChocolateBar, Bazooka and others, and a DataBroker mode used automatically when such an addon is installed, explained on first use and easy to turn off.
- Blocks merge like mosaic tiles in every direction; spacers (empty, line or text), undo, alignment guides, snapping to Blizzard frames, frozen groups, global and group scale.
- Blocks with nothing to show hide themselves, in a second row under the main bar.
- Styles matching FlareUI (2.x and 1.x looks), ElvUI, EllesmereUI and Blizzard, plus Clean and Transparent; per-block text, frame, opacity, progress bar, thresholds, show on hover, alerts and click actions.
- Profiles with export / import, ready-made layouts and an automatic dungeon / raid profile; accessibility options; English and French.
