# Réorganisation de la fenêtre d'options (1.5.0, branche `next`)

Validé par Braincell1980 le 14/11/2026 (maquette, Opus 5.5). À faire AVANT de reprendre la
modernisation des blocs (Progression, Monde, Système, Forever) : la révision des blocs est en pause.

## Pourquoi
Page d'un bloc trop longue (beaucoup de molette) et titres en double : « Réglages de ce bloc »,
« Ses propres réglages », « Ce bloc », deux fois « Affichage ». Modèle : la fenêtre de FlareUI 6.5.1
(MIT, Malkkav), `Settings/Panel.lua` et `Settings/Registry.lua`.

## Ce qu'on reprend de FlareUI
- En-tête de page : le bloc choisi (liste), « Sur l'écran », Remplacer, Placer au pixel.
- Onglets en haut de la page (FlareUI : `tabs = { settings, fonts }` par module).
- Chaque section dans son propre cadre (FlareUI : `SEC_X, SEC_TOP, SEC_BOTTOM, SEC_GAP` = 10, 2, 10, 10),
  titre du cadre à gauche, bouton Réinitialiser de la section à droite (confirmé).
- Lignes « half » : deux réglages par ligne (cases, petites listes en flèches ◄ ► plus étroites).
- Lignes enfants indentées (`parent`, INDENT 18) et grisées quand le parent est décoché.
- Pas de sections repliables dans une page : les onglets les remplacent.

## Page d'un bloc : 3 onglets
1. **Contenu** : cadre « Valeur » (nom, valeur, icône, style du bloc, réglages d'affichage propres au
   bloc) ; cadre « Infobulle » (options `section = "tooltip"` du bloc). Rien d'autre.
2. **Apparence** : Taille (auto, largeur, hauteur, icône, échelle du groupe) ; Texte ; Fond ; Icône ;
   Bordure ; Séparateurs ; Opacité et plan ; Couleur selon le seuil, barre de progression.
3. **Comportement** : Quand l'afficher (combat, instance, véhicule, repos...) ; Apparition au survol ;
   Clics ; Alertes et seuils (clignoter, seuils jaune/rouge).

Disparaissent : « Ce bloc », « Ses propres réglages », « Apparence de ce bloc » (repliable),
« Quand l'afficher » (repliable), les sous-titres en double.

## Tous les autres onglets (même lot)
Général, Accessibilité, Apparence, Lanceurs, DataBroker, Profils : sections encadrées, cases deux par
ligne, petites listes en flèches. Le contenu ne change pas, seulement le rangement.

## Règles à tenir
- Fenêtre à 115 % par défaut, un peu plus haute (fait, test133/134) ; tout tenir sans molette si possible.
- Rien n'est retiré (règle 1.0.0) ; les profils et réglages des joueurs restent valables (pas de
  nouvelle clé de sauvegarde nécessaire : seul l'affichage change ; l'onglet ouvert peut être retenu).
- Accessibilité et manette : ordre de focus gauche → droite puis ligne suivante, sélection visible,
  texte deux fois plus grand (les lignes « half » repassent en pleine largeur quand le texte ne tient pas),
  contraste élevé.
- Recherche : les résultats disent « Blocs › Guilde › Contenu › Infobulle ».
- Textes : nouvelles clés pour les noms d'onglets et de cadres (CONTENT, APPEARANCE, BEHAVIOUR...) ;
  les anciennes clés restent (ne jamais renommer ni réutiliser).
- Tests du mock : chevauchement, lignes dans leur cadre, ordre de focus, texte x2, recherche.

## Code (où)
- `OptionsBlocks.lua` : `BuildModuleOptions` et la page des blocs (sections lignes ~400-640).
- `OptionsWidgets.lua` : `CreateSection` / `CreateHeader` → nouveau `CreateBox` (cadre + titre + reset),
  `FitRow`, `ROW_PAD`.
- `OptionsPages.lua` : les autres onglets.
- `Options.lua` : constantes (COL_W, COL_X, FULL_W, SPACING, PANEL_H).
- Vérifier `tools/check_locals.py` avant d'ajouter des locales (scinder si besoin, skill tessera-refactor).
