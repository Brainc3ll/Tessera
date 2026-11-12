# Plan T2 : placement au pixel (lot 5a, 11/11/2026, Opus 5.5)

**Statut (12/11) : fait, publié dans la 1.3.0.** L'échelle pixel perfect (lot 5b) est reportée.

Choix de Braincell1980 (11/11) : bouton « Placer » en tête de l'onglet Blocs ; blocs verrouillés déverrouillés le temps du placement puis reverrouillés ; X et Y modifiables, en vrais pixels depuis le coin bas-gauche de l'écran ; la souris reste active ; message de première fois = une ligne du bandeau + « Compris » ; zip test102 (pixel perfect : test103).

## Ce qui change dans les données
- `TesseraDB` (compte) : `placeNoticeSeen = true` après « Compris ». Booléen, ignoré par la 1.2.1.
- Profil, bloc tête du groupe déplacé : `cfg.point[3]` et `cfg.point[4]` peuvent avoir des décimales (arrondies au millième). Un pixel réel vaut souvent moins d'une unité de bloc ; la 1.2.1 et les exports lisent déjà des nombres (`IsNumber`, `SetPoint`). Rien d'autre de nouveau.
- Comme un glissé à la souris : le groupe déplacé perd `anchor`, `edges`, `stretch` (il n'est plus collé au bord ni à la disposition par défaut). C'est déjà le cas aujourd'hui avec la souris.

## Retour en arrière
- 1.2.1 ou ancien profil : les décimales sont acceptées ; `placeNoticeSeen` est ignoré. Rien à convertir, aucune conversion lancée au chargement.

## Annuler
- Au début : `ns:PushUndo()` une fois (instantané de départ). Les flèches ne poussent rien de plus ; un glissé à la souris pousse le sien.
- Échap : `ns:Undo()` jusqu'à retirer l'instantané de départ (retour exact au point de départ). Limite : plus de 30 glissés pendant le placement font sortir l'instantané de départ de la pile ; on revient alors au plus ancien gardé.
- Entrée ou ✓ : l'instantané reste (Ctrl + Z ensuite annule tout le placement) ; si rien n'a bougé, il est retiré sans rien appliquer.

## Ce qui pourrait se perdre
- Rien d'enregistré n'est effacé hors des champs de position du groupe déplacé, comme avec la souris. Groupe figé (`frozen`) : « Placer » refusé, comme le glissé.

## Combat
- Clavier coupé en combat (règle du jeu), le bandeau le dit ; avec « verrouiller en combat », le bandeau disparaît et revient après.
