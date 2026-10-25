# Découper Tessera en modules optionnels (étude, 24 octobre 2026)

Idée de Braincell1980 : livrer dans le même zip une base et des modules de blocs, rangés par catégorie. Le joueur coche dans la liste des addons les catégories qu'il veut. Cas type : un joueur en mode DataBroker qui veut seulement Camping et Points d'héritage, sans charger tout Tessera.

**Statut : étude, rien n'est codé.** Les mesures viennent du simulateur (`tools/mock_run.lua`, Lua 5.1 comme le jeu) et de la lecture du code de la 1.0.0-rc9-hotfix. Ce que je ne sais pas est listé à la fin.

---

## 1. Ce qui reste dans la base, ce qui devient module

### La base (`Tessera`)

Tout ce dont un bloc a besoin pour exister, quelle que soit sa catégorie :

- le moteur : création des blocs, styles (`Themes.lua`), fusion (`Merge.lua`), placement, devant / derrière (`Layers.lua`), clics sécurisés (`SecureClicks.lua`) ;
- les options, les profils, l'export / import, les dispositions toutes prêtes, la visite rapide, le mode démo ;
- les traductions (voir plus bas : elles restent toutes dans la base) ;
- le mode DataBroker (publier et afficher) ;
- les trois familles de blocs qui ne sont pas des données du jeu : espaceurs, lanceurs, blocs DataBroker ;
- les outils communs aux blocs, aujourd'hui en tête de `Modules.lua` : seuils (`Threshold`), durées, `Try`, couleurs de classe, format de l'or (`FormatGold` sert aussi au bloc Objectif et aux exemples) ;
- un **catalogue** de tous les blocs connus : clé, nom, module qui le fournit (voir section 3).

**Recommandation :** garder aussi dans la base les 8 blocs de la barre par défaut (Or, Sacs, Durabilité, FPS, Latence, Guilde, Amis, Heure). Avec la base seule, un nouveau joueur a toujours une barre qui marche, et les dispositions toutes prêtes gardent leur première barre. Ces 8 blocs pèsent environ 25 Ko. L'autre choix (tout en modules, base vide) est plus pur mais casse l'expérience du premier lancement si un module manque.

### Les modules proposés

Les catégories du mode démo existent déjà et les joueurs les voient : je propose de les reprendre, pour que la liste des addons et la démo parlent la même langue. Noms de dossier en anglais (la liste des addons), titres traduits dans le `.toc` (`## Title-frFR:`).

| Module (dossier) | Titre français | Blocs | Poids mesuré |
|---|---|---|---|
| `Tessera_Forever` | Tessera : WoW Forever | Points d'héritage, Compréhension, Camping, Honneur, Compétences d'armes | ~10 Ko |
| `Tessera_Character` | Tessera : Personnage | XP, XP de repos, Statistiques, Régénération de mana, Vitesse, Points de talent, Niveau d'objet, Munitions, Composants de classe | ~22 Ko |
| `Tessera_World` | Tessera : Monde | Zone, Sous-zone, Coordonnées, Heure du serveur, Date, Pierre de foyer, Instances, Remise à zéro | ~16 Ko |
| `Tessera_Progress` | Tessera : Progression | Réputation, Monnaies, Quêtes, Objectif, Métiers 1 et 2, Cuisine, Secourisme, Pêche | ~21 Ko |
| `Tessera_Social` | Tessera : Social | Chuchotements, Courrier, Groupe, Butin du groupe | ~8 Ko |
| `Tessera_System` | Tessera : Système | Mémoire des addons, Volume, Temps de jeu | ~5 Ko |

Les 4 blocs validés pour la 1.1 iraient directement dans leur module : DPS et Corps dans `Tessera_Character` (ou un module `Tessera_Combat`), Mode de jeu dans `Tessera_Forever`, Météo dans `Tessera_World`.

Ça fait 7 entrées dans la liste des addons. C'est le prix du découpage ; voir « Ce que je ne sais pas » sur le regroupement dans la liste.

### Les modules ont besoin d'une porte d'entrée

Chaque addon de WoW reçoit sa propre table privée (`ns`) : un module ne voit pas celle de la base. La base devra exposer une porte d'entrée globale, par exemple `TesseraAPI` (`RegisterModule`, outils communs, traductions `L`, état du jeu). Aujourd'hui les blocs utilisent `ns` directement en beaucoup d'endroits (`ns.LEVEL_COLORS`, `ns.state`, `ns.sv` pour l'or des personnages, `ns:UpdateBlock`...). Le plus simple et le plus sûr : exposer la table `ns` elle-même sous ce nom global, documentée comme « réservée aux modules de Tessera ». Un autre addon pourrait y toucher : risque faible, mais à savoir.

### Ce qui cite des blocs précis dans la base (à adapter)

Relevé dans le code :
- `Core.lua` : les dispositions toutes prêtes (`BASE_ROW`, `SECOND_ROW`, `FOREVER_ROW`, coins des gryphons, Chemin de ronde), l'historique de l'or (`RecordMoney`, `goldHistory`), le style automatique (lit le bloc Or).
- `Placement.lua` : « Oublier un personnage » (bloc Or), la liste `FOREVER_KEYS` (vérification à l'import).
- `Options.lua` : les blocs d'exemple de la fenêtre « style proposé » (Or, FPS, Heure).
- `Demo.lua` : les catégories.

Les dispositions savent déjà sauter un bloc absent (c'est ce qui se passe sur un client sans les blocs Forever). L'historique de l'or reste dans la base si le bloc Or y reste.

### Les traductions restent dans la base

L'outil de CurseForge travaille par projet, avec un fichier de textes par langue. Le découper par module est possible (« namespaces » de CurseForge), mais ça changerait toute la chaîne de publication et le travail des traducteurs. Les textes d'un module désactivé restent chargés : environ 46 Ko pour l'anglais. Pas rentable de les découper.

---

## 2. L'affichage des blocs en module séparé ?

**Réponse courte : non, pas maintenant.** Le gain est petit et le chantier gros.

Ce que pèse l'affichage, au chargement (mesuré dans le simulateur) : `Themes` 20 Ko, `Merge` 5 Ko, `Placement` 6 Ko, `Layers` 5 Ko, `Spacers` 5 Ko, `Launchers` 3 Ko, `Demo` 3 Ko, `SecureClicks` 1 Ko, plus la moitié environ de `Core` et d'`Options`. En tout, **environ 0,1 Mo**.

Le chantier : `Core.lua` mélange données et affichage (`UpdateBlock` calcule la valeur et l'écrit dans le cadre ; la visibilité, les alertes et les seuils vivent au même endroit). Les séparer touche le cœur de l'addon, avec un vrai risque de régression.

**Mieux, et petit :** en mode DataBroker, Tessera crée quand même un cadre pour chaque bloc (61 cadres avec le Chemin de ronde), puis les cache. Ne pas les créer en mode DataBroker donne une bonne partie du gain, sans découpage. À faire dans la 1.1, module ou pas.

### Le gain réel en mémoire, sans exagérer

| Ce qui est chargé | Poids (Lua, au chargement) |
|---|---|
| Tout Tessera aujourd'hui | ~270 à 340 Ko |
| dont le code de tous les blocs (`Modules.lua`) | ~97 Ko |
| dont le changelog (`Changelog.lua`) | ~54 Ko |
| dont les textes anglais | ~46 Ko |
| Le cas type : base + Forever seulement | **~85 Ko de moins** |

En jeu, le bloc Mémoire des addons montre 3 à 4 Mo pour Tessera au repos. Le cas type économise donc **environ 2 à 3 %** de la mémoire de Tessera. Le processeur ne gagne presque rien : un bloc désactivé ne se met déjà jamais à jour.

**Ce qui pèse vraiment** (trouvé pendant l'étude) : **les profils**. Chaque bloc enregistre ses ~55 réglages, même ceux restés aux valeurs par défaut (la même cause que les exports trop lourds). Un profil comme le Chemin de ronde occupe **environ 200 Ko** en mémoire Lua, et WoW charge tous les profils au lancement, plus les copies de secours (démo, visite rapide, profil de donjon). Cinq profils, c'est environ 1 Mo, dix fois le gain des modules. Ne garder que ce qui diffère des valeurs par défaut (comme le fait AceDB, la bibliothèque de la plupart des gros addons) serait le vrai levier mémoire. C'est un chantier à part, délicat lui aussi pour la rétrocompatibilité (les sauvegardes actuelles, complètes, doivent rester lisibles).

**Conclusion honnête :** les modules ne se justifient pas par la mémoire. Leurs vrais avantages :
- le joueur choisit ce qu'il voit : listes de blocs plus courtes dans les options, le menu « Remplacer par... », la démo ;
- un code mieux rangé, un bloc ajouté va dans son dossier ;
- les blocs propres à un client (Forever) ont une place naturelle, utile si une version Retail revient un jour.

---

## 3. Rétrocompatibilité : un bloc dont le module est désactivé

Règle de Tessera : un profil ou une disposition qui contient un bloc d'un module désactivé reste valide. Tessera garde sa configuration et prévient le joueur.

### Ce qui se passe aujourd'hui (et casserait)

- **Au chargement d'un profil**, `PrepareProfile` ne touche pas aux blocs inconnus : leur configuration reste dans les variables sauvegardées. Bon point.
- **Mais aucun cadre n'est créé pour eux.** Les blocs rattachés à un bloc absent perdent leur point d'accroche : une barre se casse en morceaux (par exemple la Double barre, dont la troisième rangée pend sous le bloc Points d'héritage).
- **À l'import**, `SanitizeProfile` supprime tout bloc dont le module n'est pas chargé, et `CleanBlock` ne garde que les champs connus du module. Importer un profil avec des blocs Forever, module désactivé, les **effacerait**.

### Ce que je propose

1. **Un catalogue dans la base** : `clé du bloc → module, nom traduit`. Tessera connaît chaque bloc, même sans son module (pour le nommer dans un message, dans les options).
2. **Un « bloc fantôme »**, sur le modèle des blocs DataBroker dont l'addon manque (ça existe déjà dans `Broker.lua`) : pour un bloc du catalogue présent et activé dans le profil, module absent, la base crée un cadre avec un module de remplacement :
   - caché quand les blocs sont verrouillés, mais **il garde sa place** (largeur `slotW`, comme un bloc masqué depuis la rc8) : les voisins ne bougent pas, les rangées restent accrochées ;
   - en mode placement, il s'affiche en gris : « Camping (module Tessera_Forever désactivé) » ;
   - pas de mise à jour, pas d'événement, pas de publication DataBroker ;
   - absent du menu « Remplacer par... ».
3. **L'import garde les blocs du catalogue** : `SanitizeProfile` les accepte, et pour un module absent, `CleanBlock` garde les champs de type simple (texte, nombre, vrai / faux, couleur) après les vérifications de position habituelles. Pareil pour l'import d'une disposition et d'un style.
4. **L'export** les garde aussi (ils sont dans le profil) : un profil passe intact d'un joueur avec le module à un joueur sans, puis à un troisième avec.
5. **Prévenir le joueur**, une fois par chargement de profil : une ligne dans la discussion, « Ce profil utilise des blocs d'un module désactivé : Camping, Points d'héritage (Tessera : WoW Forever) », et dans les options les blocs concernés marqués « module désactivé », avec un bouton « Activer le module » (`C_AddOns.EnableAddOn`, puis rechargement de l'interface). La fonction existe dans l'API de Forever ; je ne l'ai pas testée.
6. **Bonus :** le même mécanisme règle un cas qui existe déjà : un profil Forever ouvert sur un client sans les blocs Forever.

Ce travail sur la base est utile même sans découpage. C'est par lui qu'il faut commencer.

### Variante plus tard : chargement à la demande

Les modules pourraient être marqués `## LoadOnDemand: 1` : la base chargerait elle-même (`C_AddOns.LoadAddOn`) seulement les modules dont le profil utilise un bloc. Le joueur n'aurait rien à cocher. Plus confortable, mais plus risqué : il faut savoir ajouter des blocs après la connexion (événements, cadres, profil), et je ne sais pas si le chargement est permis en combat sur Forever. À garder pour une deuxième étape.

---

## 4. Packaging et tests

### Zip, CurseForge, Wago

- Le packager de BigWigs (déjà utilisé par `release.yml`) sait mettre plusieurs dossiers dans un zip, avec `move-folders` dans `.pkgmeta`, par exemple `Tessera/Modules/Forever: Tessera_Forever`. C'est la méthode de DBM ou BigWigs.
- Un seul projet CurseForge, une seule page Wago, un seul zip avec 7 dossiers. L'appli CurseForge et WowUp / Wago App installent tous les dossiers.
- Chaque module a son `.toc` : `## Interface: 16001`, `## Dependencies: Tessera`, titre traduit, même version que la base. Sans la base, WoW refuse de charger le module et l'indique dans la liste des addons.
- Les modules n'ont pas de variables sauvegardées : tout reste dans `TesseraDB`. Aucune conversion des sauvegardes.
- **Pour les joueurs actuels :** à la mise à jour, les nouveaux dossiers arrivent activés. Ils gardent tous leurs blocs, rien ne change pour eux. Une installation à la main doit copier tous les dossiers : à écrire dans les descriptions.

### Ce qui change dans les outils

- `tools/mock_run.lua` lit `Tessera.toc` : il devra aussi charger les `.toc` des modules. Nouveau scénario : un module absent (Forever), avec un profil qui l'utilise (le texte `tools/fixtures/rc9-profile.txt` contient Points d'héritage, Camping, Compréhension) : configuration gardée, voisins immobiles, export intact, module réactivé, tout revient.
- `tools/fuzz_blocks.lua` : inchangé si tous les modules sont chargés.
- `tools/check_docs.lua` : version identique dans tous les `.toc`, fichiers de tous les `.toc` dans le tableau du README, blocs rangés par module dans le README et les descriptions.
- `make_test_zip.sh` (dépôt privé) : copier les dossiers des modules.
- `.luacheckrc` : la porte d'entrée globale (`TesseraAPI`).
- L'audit de l'API (`api_audit.py`) parcourt tous les fichiers : rien à changer, à vérifier.

---

## 5. Ampleur et moment

| Étape | Travail |
|---|---|
| 1. Base : catalogue, blocs fantômes, import qui garde les blocs inconnus, avertissement, tests | 2 à 3 soirées |
| 2. Outils communs dans la base, porte d'entrée `TesseraAPI` | 1 à 2 soirées |
| 3. Découper `Modules.lua` en dossiers et `.toc`, adapter dispositions, démo, options | 1 à 2 soirées |
| 4. Packaging, outils, docs, descriptions, publication d'essai (rc) | 1 à 2 soirées |
| Tests en jeu : chaque module activé / désactivé, anciens profils, mode DataBroker | 3 à 5 zips de test |

**Total : environ 6 à 9 soirées.** Un chantier moyen, moins gros que la manette, comparable à l'accessibilité.

**Moment (mis à jour le 24/10, feuille de route dans A-REPRENDRE) :** la décision de faire les modules reste à prendre (« bof » pour la mémoire, utile pour le confort). Si on les fait, c'est dans la 1.2, juste avant les 4 nouveaux blocs, pour qu'ils aillent directement dans leur module. La 1.1 (nettoyage et optimisation) prépare le terrain sans engager les modules : catalogue et blocs fantômes (étape 1), pas de cadres de blocs en mode DataBroker, profils allégés faits maison.

Ensuite, remettre la branche `accessibilite-manette` à jour depuis `main`, avant d'y commencer l'accessibilité. Les modules touchent surtout les blocs, les profils et les dispositions ; l'accessibilité, surtout l'affichage et les options : peu de conflits si on les fait l'un après l'autre.

---

## Risques

- **Une barre qui se casse** si un cas de bloc fantôme est oublié (rattachement, rangée suspendue, groupe figé, bord d'écran) : c'est le risque principal, d'où les tests avec de vrais profils.
- **La porte d'entrée globale** expose l'intérieur de Tessera à d'autres addons.
- **7 entrées dans la liste des addons** : certains joueurs trouveront ça encombrant.
- **Installations à la main incomplètes** (un seul dossier copié) : des blocs fantômes partout, et des questions sur Discord.
- **Le gain mémoire est petit** : si la motivation principale était la mémoire, ce chantier ne la sert pas. Les profils allégés, si.

## Ce que je ne sais pas (à vérifier, sans deviner)

- Si la liste des addons de WoW Forever sait regrouper un addon et ses modules (un champ du `.toc` comme `## Group:` existe peut-être sur le client moderne ; je ne l'ai pas vérifié).
- Si `C_AddOns.EnableAddOn` et `C_AddOns.LoadAddOn` marchent depuis un addon sur Forever, et s'ils sont bloqués en combat. Une sonde dans `TesseraDev.lua` le dira.
- Comment l'appli CurseForge et WowUp se comportent à la mise à jour quand un joueur a désactivé un module (WoW garde l'état par nom d'addon dans `AddOns.txt` ; je pense qu'une mise à jour ne le change pas, sans l'avoir vérifié).
- La part réelle des profils dans les 3 à 4 Mo vus en jeu : mes 200 Ko par profil viennent du simulateur. Le bloc Mémoire des addons, avant et après la suppression de quelques profils, le dirait.
- Les chiffres du simulateur sont ceux de Lua 5.1 hors du jeu ; ceux du jeu peuvent différer un peu, les proportions devraient tenir.
