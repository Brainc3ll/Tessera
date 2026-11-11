# Plan T2 : « Retirer » au lieu de « masquer » (lot 2 de la 1.3)

Rédigé le 11/11 (Fable 5.2), avant tout code. Procédure : skill tessera-gate2.

## Aujourd'hui (1.2.1)

- `cfg.enabled = false` masque le bloc, mais il garde sa place dans les données (`dock`, `point`, `anchor`).
- À l'affichage, les voisins sautent par-dessus un bloc masqué seulement quand la chaîne garde la même direction (`GetEffectiveDock`). Sinon il reste un trou : la « place fantôme ». Un bloc masqué en tête de groupe laisse aussi un trou.
- Réaffiché, le bloc revient à son ancienne place.
- Un bloc éteint continue de recevoir les événements du jeu (`UpdateBlock` tourne) : rien à changer pour « tourne en fond ».

## Après

1. Une seule fonction `ns:LeaveGroup(key)` (Core.lua), reprise du code qui existe déjà dans `ReplaceBlock` :
   - les blocs accrochés au bloc retiré s'accrochent à ce qu'il suivait ;
   - s'il était en tête de groupe, le premier bloc accroché devient la tête et reprend la place du groupe (`point`, `anchor`, `scale`, `frozen`, `edges`, `stretch`, `look`) ;
   - le bloc retiré perd `dock`, `anchor`, `point`, `edges`, `stretch`, `look`, `scale`, `frozen`. Il garde tout son style et ses réglages.
2. `HideBlock`, la case « Afficher » décochée, « Remplacer par » (le remplacé) passent par `LeaveGroup`.
3. Rangement des anciens profils (`PrepareProfile`, donc à la connexion et à chaque changement de profil) et des textes importés (`SanitizeProfile`) : tout bloc éteint qui a encore une place passe par la même logique, sur les données seules, clés triées (résultat identique d'une fois à l'autre). Sans message.
4. Un bloc remis à l'écran depuis les options arrive près de la fenêtre (`PlaceNearOptions`, qui existe déjà).
5. Textes : « masquer » devient « retirer », « Afficher » devient « Sur l'écran » (mêmes clés). Le réglage renommé est déclaré dans `tools/options_renames.txt`.

## Données enregistrées

- Aucun champ nouveau, aucun champ supprimé, format d'export inchangé. Seules des valeurs changent (place d'un bloc éteint mise à vide).
- Retour à la 1.2.1 : le profil rangé se lit sans erreur (un bloc éteint sans place est l'état par défaut).
- Export 1.3 importé en 1.2.1 : identique. Export ancien importé en 1.3 : rangé à l'import.
- Le rangement ne fait rien la seconde fois (un bloc éteint sans place et sans bloc accroché n'est plus touché).

## Ce qu'un joueur peut perdre

- La place d'un bloc éteint : s'il le rallume, il arrive près de la fenêtre d'options au lieu de son ancienne place. Voulu (décision du 6/11).
- Un groupe dont la tête était éteinte se décale de la largeur du bloc fantôme (le trou se ferme). Voulu.
- Ctrl + Z annule un retrait fait dans la session (l'annulation garde déjà `enabled` et toute la place).
- Rien d'autre : styles, profils, réglages par bloc, lanceurs et espaces restent tels quels.

## Tests

- Chaîne A-B-C, B retiré : C suit A. Tête retirée : l'héritier prend la place. Coude (B à droite de A, C sous B) : plus de trou.
- Profil ancien avec blocs éteints accrochés : rangé à la préparation ; seconde préparation sans effet.
- Fixtures rc9 (profil, disposition, style, variables enregistrées) : même résultat pour les blocs allumés.
- Import d'un ancien texte avec bloc éteint au milieu d'une barre.
- Ctrl + Z après un retrait.
- Démo, visite guidée et dispositions toutes faites : pas de bloc éteint avec une place après leur passage.

## Relecture

Agent indépendant, avec ce plan, le diff et la liste de contrôle de tessera-gate2.

## Après la relecture (11/11)

Corrigé : apparence gardée au retour (`keepLook`), confirmation pour plusieurs blocs, héritier à la place exacte, boucles abîmées, Ctrl + Z de l'action de clic. Limite acceptée : trois branches autour d'un bloc retiré peuvent se toucher.
