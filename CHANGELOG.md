# Changelog

All notable changes to Tessera. The in-game **About** tab (Changelog topic) shows the same list
(from `Changelog.lua`), in English or French depending on the game language.

## 1.0.0-rc6 — 

- Release candidate 6, the last one before 1.0.0 (November 4): everything planned for 1.0.0 is in. New here? Type /tessera: the quick tour shows the essentials, and the demo mode (Help tab) shows every block and every style.

### New

- Date block (hidden by default, add it from the Blocks tab): short or long, numbers in several orders, local or server date; click: calendar. The Rampart Walk layout shows it next to the clock.
- Demo mode: after the styles, the switcher shows "Mixed styles", each column in its own style, to compare them side by side.
- Gold block: a character you deleted or renamed can be removed from the tooltip (Alt + right-click on the block, "Forget a character").
- Ready-made layout "Rampart Walk": a bar stuck to the top of the screen over its whole width, the WoW Forever blocks in the center and system information (FPS, latency, clock, date) on the right.
- Blocks over Blizzard's frames (action bars, minimap, buffs): you choose whether they stay in front or behind. In placement mode (and in Blizzard's Edit Mode, under its window, where it glows until you hover it) a button switches every block for a while to see what is underneath; when you are done, Tessera asks which to keep. Look tab: all blocks in front or behind.

### Improvements

- "Around the gryphons" layout: two neat rectangles, the date and the clock in the corner on the right (pick the layout again to get it).
- Look tab: "Frame of all blocks..." and "Text of all blocks..." lead straight to those settings (Blocks tab, All blocks).
- FlareUI style: bronze lines between merged blocks and, when its addon is installed, progress bars with a grained texture (pick the style again to get them).
- Threshold colors (General tab, Accessibility): automatic, bright, soft or colorblind. Automatic gives the soft colors with the FlareUI style.

### Fixes

- The top bar follows FlareUI's XP bar also when FlareUI or its XP bar is turned on after Tessera (it stayed at the top of the screen, under the XP bar), and keeps its width when the XP bar changes size.
- A second row ("Double bar", the rows of blocks that hide when empty) dropped right against its bar keeps its place and its full width: it merged into the bar and shrank, its names cut short.
- Applying a ready-made layout keeps your style (it went back to the automatic one).
- After a loading screen (boat, portal, instance), the durability and other blocks no longer stay on "n/a": they are read again once the game is ready.
- WoW Forever characters with the same first name (Ellen Kemp, Ellen Sept) no longer share their gold line and their profile: each one is recognized by its full name and its ruleset, and the FlareUI styles find FlareUI's font for it again.

## 1.0.0-rc5 — 2026-10-15

- Demo mode (Help tab, welcome window, /tessera demo): every block at once, sorted by category, with sample values. Its banner switches the styles and can hide the game's interface, for screenshots. Your layout comes back when you leave.
- Placement mode made easier: a cross on the hovered block hides it, arrows replace it with another block in the exact same place, and a right-click opens the quick menu. What you can do with the hovered block shows in a panel under the banner.
- Replacing blocks: a hidden block takes the place, a shown block swaps places, and the spacers of the ready-made layouts can be replaced by blocks. New help topic "Replacing blocks".
- Nine new styles: Runestone (text only, black and white), Grimoire, Parchment and Arcane, and five made of the game's own frames: Royal Seal, Ironforge, Runeblade, Ember and Sylvan.
- The FlareUI, ElvUI and EllesmereUI styles can be picked without that addon: they are then an imitation, and the chat says what differs. ElvUI and EllesmereUI no longer look alike. The FlareUI styles use the font of FlareUI's XP bar (pick the style again to get it).
- "Value shown" (Blocks tab, Text): gold (coin icons or letters, gold and silver, rounding, thousands separator), bags, XP, durability, FPS, latency, seconds on the clocks, coordinates, friends and guild, reputation.
- New ready-made layout "Double bar": the top bar and a second bar of WoW Forever blocks. The quick tour lets you try every layout on your screen.
- Placement: a single block slips in between two merged blocks, a second row put back against its bar stays centered under it, and the names under the blocks no longer overlap.
- Group loot block: the game's official names for the loot methods. WoW Forever blocks show nothing rather than an error if the game changes.
- Help completed, and split into short texts that are easier to translate on CurseForge.

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
