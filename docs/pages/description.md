# Tessera: little info blocks you put anywhere

Gold, bags, FPS, Legacy points... each in its own little block. Put a block anywhere on your screen, or drop it against another one and they stick together into a bar. A bar shows up at first launch, so you can start from there.

Made by a player who can't code and an AI that can't play (yet). So I test it a lot.

I made it for WoW Forever, so you also get blocks for Forever's own stuff: Legacy points and the next reward, Comprehension and the scrolls in your bags, camping buffs and your campfire kit, honor, weapon skills. Since 1.1 there's also your hunter pet's mood, poisons and sharpening stones, Well Fed and other long buffs, XP per hour, an arrow to your corpse when you die, and Blizzard's micro menu in one block (the menus you haven't unlocked yet stay grey).

Most blocks let you choose what they show: played time this level or in total, honor out of its cap, completed quests, and so on.

Other things you might like:

- 27 styles, so the blocks match your UI: Blizzard, Bronze and Bronze and gold (FlareUI), Elven (ElvUI), Emerald (EllesmereUI), Aurora (DaylightUI), or fantasy looks made from the game's own frames.
- Streamer mode hides other players' names, your other characters, your guild and your gold.
- DataBroker works both ways: your other addons' Data Broker plugins become blocks, or Tessera's blocks go into Titan Panel, Bazooka or Arcana (formerly ChocolateBar).
- Pin a block's tooltip so it stays open, and give any block a name of your own.
- Style a whole bar at once: pick its group in the options, or copy one block's look to the rest of the bar.
- Place a bar to the exact pixel with the arrow keys, or type where it goes.
- An options window with a search, a help panel for each setting and an Accessibility tab: high contrast, fewer animations, a minimum text size.
- English and French, plus German, Spanish and Brazilian Portuguese.

Over 50 blocks, plus launchers for your minimap buttons. Type **/tessera** for the options, or **/tessera demo** to see every block at once.

## Why make Tessera when addons like it already exist?

I love bars like Arcana (formerly ChocolateBar) and Bazooka. I used Broker_Everything a lot, and I spent hours building small bars with a single piece of info each, to put them in just the right spot on my interface. My favorite was StatBlock Core (StatBlockCore) by Funkeh: free-floating blocks, one per piece of info, that I could put anywhere. It hasn't been updated since 2022. And tooltips didn't look the same from one broker addon to the next, French was often missing, and many of those addons were no longer maintained. The options window takes its look from [FlareUI](https://www.curseforge.com/wow/addons/flareui) by Malkkav (MIT license).

When the WoW Forever beta came out, I came back to WoW and found FlareUI: an interface with a fantasy look, not a futuristic one. Seeing what players were building with AI's help, I wanted to try something: a small thing just for me, that did exactly what I asked for.

That's how Tessera was born. It was never meant to be published. I wanted to learn how it works when you start a GitHub repo from scratch and release an addon. Then I put it through more testing than I gave the Forever beta itself, and the ideas kept coming. Some are in Tessera today. Others are on the way: accessibility for players with disabilities, and full gamepad support, something I have never seen in a panel or DataBroker addon.

So I put it out there. That meant keeping an eye on what the AI writes: the right WoW words in each language, and code checked with the same tools addon developers use.

## How I look after it

I play WoW Forever and test each version in game before I release it. Your layouts and profiles carry over between versions; if a change ever has to break them, Tessera tells you and converts them. GitHub also runs a set of automatic checks on every change (the API audit addon reviewers use, a check against Forever's own function list, a full run of the addon in each language).

Forever's own systems are still young. If a game update breaks a block, tell me and I'll fix it.

Tessera is free and open source (MIT). No premium version, no paid extras.

## Who writes what

I don't write code. Claude (an AI by Anthropic) writes all of it, from my instructions, along with the tests and most texts. I decide what Tessera does and how it looks, I test it, and I review the French. No human programmer reads the code line by line ([AI Code Rating](https://aicoderating.com): E4d). The code is open (MIT) on [GitHub](https://github.com/Brainc3ll/Tessera).

Claude translated the German, Spanish and Brazilian Portuguese texts, and nobody has reviewed them yet. You can correct them, or add your language, on [GitHub](https://github.com/Brainc3ll/Tessera/blob/main/docs/TRANSLATING.md): a pull request, or an issue with your lines. Your name will appear in the addon.

## Bugs and ideas

Type **/tessera bug**, copy the report and post it on [GitHub](https://github.com/Brainc3ll/Tessera/issues) or in the comments on CurseForge. Ideas are welcome, especially about WoW Forever systems Tessera could show.

## Every block and command

**All the blocks**: gold (with a 7-day history and your characters' gold; forget a deleted character from its menu), bags (with junk value), durability, FPS and latency (with graphs), local and server time, date, XP and rested XP, coordinates, zone and subzone, friends, guild, group, quests, reputation, currencies, one block per profession (plus cooking, first aid and fishing), talent points, hearthstone, mail, whispers, class reagents, ammo, item level, speed, volume, addon memory, instances, daily and weekly reset, played time, a personal goal, mana regeneration, character stats, group loot, streamer mode, micro-menu, hunter pet, weapon enchant, long buffs, XP per hour, gold this session, corpse... plus the WoW Forever blocks above.

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

# Tessera : des petits blocs d'infos à placer où tu veux (français)

Or, sacs, FPS, points d'Héritage... chacun dans son petit bloc. Pose un bloc où tu veux sur ton écran, ou colle-le contre un autre : ils forment une barre. Une barre s'affiche au premier lancement, tu peux partir de là.

Fait par un joueur qui ne sait pas coder et une IA qui ne sait pas jouer (pour le moment). Alors je teste beaucoup.

Je l'ai fait pour WoW Forever, donc tu as aussi des blocs pour ses systèmes à lui : points d'Héritage et prochaine récompense, Compréhension et les parchemins de tes sacs, Camping (bonus et kit de feu de camp), honneur, compétences d'armes. Depuis la 1.1, il y a aussi l'humeur de ton familier de chasseur, les poisons et pierres à aiguiser, Bien nourri et les autres buffs longs, l'XP par heure, une flèche vers ton corps quand tu meurs, et le micro-menu de Blizzard en un seul bloc (les menus pas encore débloqués restent gris).

La plupart des blocs te laissent choisir ce qu'ils affichent : temps de jeu à ce niveau ou au total, honneur sur son plafond, quêtes terminées, etc.

D'autres choses qui pourraient te plaire :

- 27 styles, pour que les blocs collent à ton interface : Blizzard, Bronze et Bronze et or (FlareUI), Elfique (ElvUI), Émeraude (EllesmereUI), Aurore (DaylightUI), ou des allures fantasy faites avec les fenêtres du jeu.
- Le mode streamer cache les noms des autres joueurs, tes autres personnages, ta guilde et ton or.
- DataBroker dans les deux sens : les objets Data Broker de tes autres addons deviennent des blocs, ou les blocs de Tessera vont dans Titan Panel, Bazooka ou Arcana (anciennement ChocolateBar).
- Épingle l'infobulle d'un bloc pour qu'elle reste ouverte, et donne à n'importe quel bloc le nom que tu veux.
- Règle toute une barre d'un coup : choisis son groupe dans les options, ou copie l'apparence d'un bloc sur le reste de la barre.
- Place une barre au pixel près avec les flèches du clavier, ou tape où elle va.
- Une fenêtre d'options avec une recherche, un panneau d'aide pour chaque réglage et un onglet Accessibilité : contraste élevé, moins d'animations, une taille minimale du texte.
- Anglais et français, plus l'allemand, l'espagnol et le portugais du Brésil.

Plus de 50 blocs, et des lanceurs pour les boutons de ta minicarte. Tape **/tessera** pour les options, ou **/tessera demo** pour voir tous les blocs d'un coup.

## Pourquoi Tessera, alors que des addons du genre existent déjà ?

J'aime bien les barres comme Arcana (anciennement ChocolateBar) ou Bazooka. J'utilisais beaucoup Broker_Everything, et je passais des heures à créer de petites barres avec une seule info, pour les poser au bon endroit de mon interface. Mon préféré, c'était StatBlock Core (StatBlockCore) de Funkeh : des blocs libres, une info par bloc, à poser où je voulais. Il n'est plus mis à jour depuis 2022. En plus, les infobulles changeaient d'un addon broker à l'autre, le français manquait souvent, et beaucoup de ces addons n'étaient plus maintenus. La fenêtre d'options s'inspire de [FlareUI](https://www.curseforge.com/wow/addons/flareui) de Malkkav (licence MIT).

À la sortie de la bêta de WoW Forever, je suis revenu sur WoW et je suis tombé sur FlareUI : une interface à l'allure fantasy, pas futuriste. En voyant ce que des joueurs construisaient avec l'aide de l'IA, j'ai voulu tester un petit truc rien que pour moi, qui fasse exactement ce que je demandais.

Voilà comment Tessera est né. Il ne devait pas être publié : je voulais savoir comment ça marche quand on crée un dépôt GitHub de zéro et qu'on publie un addon. Puis je l'ai plus mis à l'épreuve que la bêta de Forever elle-même, et les idées sont arrivées. Certaines sont dans Tessera aujourd'hui. D'autres arrivent : l'accessibilité pour les personnes en situation de handicap, et un vrai support manette, ce que je n'ai jamais vu dans un addon de barre ou DataBroker.

Alors je l'ai partagé. Ça voulait dire surveiller ce que l'IA écrit : les bons mots de WoW dans chaque langue, et un code vérifié avec les outils qu'utilisent les développeurs d'addons.

## Comment je m'en occupe

Je joue à WoW Forever et je teste chaque version en jeu avant de la publier. Tes dispositions et tes profils passent d'une version à l'autre ; si un changement doit un jour les casser, Tessera te prévient et les convertit. GitHub lance aussi des vérifications automatiques à chaque modification (l'audit qu'utilisent les relecteurs d'addons, une vérification avec la liste des fonctions de Forever, un lancement complet de l'addon dans chaque langue).

Les systèmes propres à Forever sont encore jeunes. Si une mise à jour du jeu casse un bloc, dis-le-moi et je le corrige.

Tessera est gratuit et open source (MIT). Pas de version premium, rien de payant.

## Qui écrit quoi

Je ne code pas. Claude (une IA d'Anthropic) écrit tout le code à partir de mes consignes, ainsi que les tests et la plupart des textes. Je décide de ce que fait Tessera et de son allure, je le teste et je relis le français. Aucun programmeur humain ne relit le code ligne par ligne ([AI Code Rating](https://aicoderating.com) : E4d). Le code est ouvert (MIT) sur [GitHub](https://github.com/Brainc3ll/Tessera).

Claude a traduit l'allemand, l'espagnol et le portugais du Brésil, et personne ne les a encore relus. Tu peux les corriger, ou ajouter ta langue, sur [GitHub](https://github.com/Brainc3ll/Tessera/blob/main/docs/TRANSLATING.md) : une pull request, ou une issue avec tes lignes. Ton nom apparaîtra dans l'addon.

## Bugs et idées

Tape **/tessera bug**, copie le rapport et poste-le sur [GitHub](https://github.com/Brainc3ll/Tessera/issues) ou dans les commentaires sur CurseForge. Les idées sont les bienvenues, surtout sur les systèmes de WoW Forever que Tessera pourrait afficher.

## Tous les blocs et commandes

**Tous les blocs** : or (avec l'historique sur 7 jours et l'or de tes personnages ; un personnage supprimé s'oublie depuis son menu), sacs (avec la valeur des objets gris), durabilité, FPS et latence (avec graphiques), heure locale, heure du serveur, date, XP et XP de repos, coordonnées, zone et sous-zone, amis, guilde, groupe, quêtes, réputation, monnaies, un bloc par métier (plus cuisine, secourisme et pêche), points de talent, pierre de foyer, courrier, chuchotements, composants de classe, munitions, niveau d'objet, vitesse, volume, mémoire des addons, instances, réinitialisation quotidienne et hebdomadaire, temps de jeu, objectif personnel, régénération de mana, statistiques, butin du groupe, mode streamer, micro-menu, familier du chasseur, enchantement d'arme, buffs longs, XP par heure, or de la session, corps... en plus des blocs WoW Forever ci-dessus.

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
