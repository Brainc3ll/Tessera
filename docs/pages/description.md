# Tessera – Info Blocks That Snap Together for WoW Forever

**TL;DR:** Gold, bags, FPS, Legacy points… in small blocks that snap together like mosaic tiles. Made by a player who can't code and an AI that can't play (yet). So I test it a lot.

## What makes it different?

- **Blocks that snap together.** Drag a block against another and they merge into one bar. Build a top bar, a column, a corner cluster, or keep each block on its own.
- **Made for WoW Forever.** Legacy points (next reward, challenges per category), Comprehension (with the scrolls in your bags), Camping (buffs and kit), Honor, weapon skills.
- **One look for everything.** Every block shares the same tooltips and the same style: Blizzard's look, FlareUI, ElvUI, EllesmereUI, or fantasy styles built from the game's own frames. 20 styles in all.
- **In your language.** English and French from day one, plus German, Spanish and Brazilian Portuguese.
- **Looked after.** Each version is tested in game, and your layouts carry over from one version to the next.
- **DataBroker both ways.** Show your other addons' DataBroker objects as blocks, or share Tessera's blocks with Titan Panel, Bazooka or Arcana (formerly ChocolateBar).

40+ blocks in all, plus launchers for your minimap buttons. A ready-made bar shows up at first launch. Type **/tessera** for the options, or **/tessera demo** to see every block at once.

## Why make Tessera when addons like it already exist?

I love bars like Arcana (formerly ChocolateBar) and Bazooka. I used Broker_Everything a lot, and I spent hours building small bars with a single piece of info each, to put them in just the right spot on my interface. My favorite was StatBlock Core by Funkeh: free-floating blocks, one per piece of info, that I could put anywhere. It hasn't been updated since 2022. And tooltips didn't look the same from one broker addon to the next, French was often missing, and many of those addons were no longer maintained.

When the WoW Forever beta came out, I came back to WoW and found FlareUI: an interface with a fantasy look, not a futuristic one. Seeing what players were building with AI's help, I wanted to try something: a small thing just for me, that did exactly what I asked for.

That's how Tessera was born. It was never meant to be published. I wanted to learn how it works when you start a GitHub repo from scratch and release an addon. Then I put it through more testing than I gave the Forever beta itself, and the ideas kept coming. Some are in Tessera today. Others are on the way: accessibility for players with disabilities, and full gamepad support, something I have never seen in a panel or DataBroker addon.

So I decided to make it available to as many players as I could. That meant watching closely what the AI does: the right WoW words in every language, and code checked with the tools real addon developers use.

## How I look after it

- I play WoW Forever and test each version in game before I release it.
- Your layouts, styles and profiles carry over from one version to the next. If a change ever has to break them, Tessera warns you and converts them.
- On every change, GitHub runs automatic checks: static analysis, the API audit addon reviewers use, a check against WoW Forever's own function list, a full run of the addon in English and French, and a test of the Forever blocks against a changing game.
- WoW Forever's own systems are young and may change. If a game update breaks a block, tell me and I'll fix it.

I can't promise how many years I'll keep this up. Today, this is how I run it.

## Who writes what

I don't write code. Claude (an AI by Anthropic) writes all of it, from my instructions, along with the tests and most texts. I decide what Tessera does and how it looks, I test it, and I review the French. No human programmer reads the code line by line ([AI Code Rating](https://aicoderating.com): E4d). The code is open (MIT) on [GitHub](https://github.com/Brainc3ll/Tessera).

Claude translated the German, Spanish and Brazilian Portuguese texts, and nobody has reviewed them yet. You can correct them, or add your language, with CurseForge's localization tool, and your name will appear in the addon.

## Bugs and ideas

Type **/tessera bug**, copy the report and post it on [GitHub](https://github.com/Brainc3ll/Tessera/issues) or in the comments on CurseForge. Ideas are welcome, especially about WoW Forever systems Tessera could show.

## Every block and command

**All the blocks**: gold (with a 7-day history and your characters' gold; forget a deleted character from its menu), bags (with junk value), durability, FPS and latency (with graphs), local and server time, date, XP and rested XP, coordinates, zone and subzone, friends, guild, group, quests, reputation, currencies, one block per profession (plus cooking, first aid and fishing), talent points, hearthstone, mail, whispers, class reagents, ammo, item level, speed, volume, addon memory, instances, played time, a personal goal, mana regeneration, character stats, group loot... plus the WoW Forever blocks above.

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

---

# Tessera – Des blocs d'infos qui s'emboîtent, pour WoW Forever (français)

**TL;DR :** Or, sacs, FPS, points d'héritage… dans de petits blocs qui s'emboîtent comme les pièces d'une mosaïque. Fait par un joueur qui ne sait pas coder et une IA qui ne sait pas jouer (pour le moment). Alors je teste beaucoup.

## Qu'est-ce qui le rend différent ?

- **Des blocs qui s'emboîtent.** Pose un bloc contre un autre : ils forment une seule barre. Une barre en haut, une colonne, un groupe dans un coin, ou chaque bloc tout seul.
- **Pensé pour WoW Forever.** Points d'héritage (prochaine récompense, défis par catégorie), Compréhension (avec les parchemins de tes sacs), Camping (bonus et kit), Honneur, compétences d'armes.
- **Une seule allure pour tout.** Tous les blocs ont les mêmes infobulles et le même style : celui de Blizzard, de FlareUI, d'ElvUI, d'EllesmereUI, ou des styles fantasy faits avec les fenêtres du jeu. 20 styles en tout.
- **Dans ta langue.** Anglais et français depuis le premier jour, plus l'allemand, l'espagnol et le portugais du Brésil.
- **Suivi.** Chaque version est testée en jeu, et tes dispositions passent d'une version à l'autre.
- **DataBroker dans les deux sens.** Affiche les objets DataBroker de tes autres addons comme des blocs, ou partage les blocs de Tessera avec Titan Panel, Bazooka ou Arcana (anciennement ChocolateBar).

Plus de 40 blocs, et des lanceurs pour les boutons de ta minicarte. Une barre toute prête s'affiche au premier lancement. Tape **/tessera** pour les options, ou **/tessera demo** pour voir tous les blocs d'un coup.

## Pourquoi Tessera, alors que des addons du genre existent déjà ?

J'aime bien les barres comme Arcana (anciennement ChocolateBar) ou Bazooka. J'utilisais beaucoup Broker_Everything, et je passais de longs moments à créer de petites barres avec une seule info, pour les poser aux endroits pertinents de mon interface. Mon préféré, c'était StatBlock Core de Funkeh : des blocs libres, une info par bloc, à poser où je voulais. Il n'est plus mis à jour depuis 2022. Et les infobulles changeaient d'un addon broker à l'autre, le français manquait souvent, et beaucoup de ces addons n'étaient plus maintenus.

À la sortie de la bêta de WoW Forever, j'ai repris WoW et je suis tombé sur FlareUI : une interface typée fantasy, pas futuriste. En voyant ce que des joueurs construisaient avec l'aide de l'IA, j'ai voulu tester un petit truc pour moi, qui réponde à mes demandes précises.

Voilà comment Tessera est né. Il ne devait pas du tout être publié : je voulais savoir comment ça marche quand on crée un dépôt GitHub de zéro et qu'on publie un addon. Ensuite, je l'ai plus mis à l'épreuve que la bêta de Forever elle-même, et les idées sont venues. Certaines sont déjà là. D'autres arrivent : l'accessibilité pour les personnes en situation de handicap, et un support manette complet, ce que je n'ai encore jamais vu dans un addon de barre ou DataBroker.

Alors j'ai voulu qu'il soit disponible pour plein de gens. Ça voulait dire surveiller de près ce que fait l'IA : le bon jargon de WoW dans chaque langue, et un code vérifié avec les outils qu'utilisent les vrais développeurs d'addons.

## Comment je suis Tessera

- Je joue à WoW Forever et je teste chaque version en jeu avant de la publier.
- Tes dispositions, styles et profils passent d'une version à l'autre. Si un changement doit un jour les casser, Tessera te prévient et les convertit.
- À chaque modification, GitHub lance des vérifications automatiques : analyse du code, l'audit qu'utilisent les relecteurs d'addons, une vérification avec la liste des fonctions de WoW Forever, un lancement complet de l'addon en anglais et en français, et un test des blocs Forever face à un jeu qui change.
- Les systèmes propres à WoW Forever sont jeunes et peuvent changer. Si une mise à jour du jeu casse un bloc, dis-le-moi et je le corrige.

Je ne peux pas promettre combien d'années je tiendrai ce rythme. Aujourd'hui, c'est comme ça que je m'en occupe.

## Qui écrit quoi

Je ne code pas. Claude (une IA d'Anthropic) écrit tout le code à partir de mes consignes, ainsi que les tests et la plupart des textes. Je décide de ce que fait Tessera et de son allure, je le teste et je relis le français. Aucun programmeur humain ne relit le code ligne par ligne ([AI Code Rating](https://aicoderating.com) : E4d). Le code est ouvert (MIT) sur [GitHub](https://github.com/Brainc3ll/Tessera).

Claude a traduit l'allemand, l'espagnol et le portugais du Brésil, et personne ne les a encore relus. Tu peux les corriger, ou ajouter ta langue, avec l'outil de traduction de CurseForge, et ton nom apparaîtra dans l'addon.

## Bugs et idées

Tape **/tessera bug**, copie le rapport et poste-le sur [GitHub](https://github.com/Brainc3ll/Tessera/issues) ou dans les commentaires sur CurseForge. Les idées sont les bienvenues, surtout sur les systèmes de WoW Forever que Tessera pourrait afficher.

## Tous les blocs et commandes

**Tous les blocs** : or (avec l'historique sur 7 jours et l'or de tes personnages ; un personnage supprimé s'oublie depuis son menu), sacs (avec la valeur des objets gris), durabilité, FPS et latence (avec graphiques), heure locale, heure du serveur, date, XP et XP de repos, coordonnées, zone et sous-zone, amis, guilde, groupe, quêtes, réputation, monnaies, un bloc par métier (plus cuisine, secourisme et pêche), points de talent, pierre de foyer, courrier, chuchotements, composants de classe, munitions, niveau d'objet, vitesse, volume, mémoire des addons, instances, temps de jeu, objectif personnel, régénération de mana, statistiques, butin du groupe... en plus des blocs WoW Forever ci-dessus.

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
