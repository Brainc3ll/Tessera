# À reprendre (état au 13 octobre 2026, soir)

Reprise prévue le mardi 13 octobre 2026 (voir avec Braincell1980).

## Versions
- **1.0.0-rc3** : publiée (GitHub + CurseForge), traductions envoyées.
- **1.0.0-rc4** : publiée le 13/10 (GitHub, CurseForge, Wago) : logo HD, « À propos » à la première personne, section Infobulles (taille, Alt), coût de réparation, blocs Régénération de mana / Statistiques / Butin du groupe. À vérifier en jeu par Braincell1980 : coût de réparation, hâte/toucher, butin en groupe.
- **1.1.0-alpha1** (autres versions du jeu : Classic Era, BC Classic, MoP Classic, jeu actuel ; pas Forever) : branche `multi-versions`, zip de test donné, en attente des tests de Braincell1980. Publication en Alpha seulement pour les versions testées. Si un jour elle est fusionnée dans `main` : retirer le suffixe « -forever » du nom du zip (voulu par Braincell1980 tant que l'addon est Forever seul).

## Prochaines étapes proposées (ordre validé à confirmer)
1. Corriger les deux bugs d'étiquettes ci-dessous (version suivante). Wago est branché (X-Wago-ID dans le .toc, WAGO_API_TOKEN dans release.yml).
2. Nettoyage / allègement du code, seul, sans changement de comportement, compatibilité des profils intacte (outils de dev vers la version debug, regroupements, mesure mémoire avant/après).
3. Styles pour tout le monde (vraies images si l'interface est installée, version approchante sinon) + nouveaux styles d'interface (TukUI, GW2 UI, NDui, KkthnxUI, SpartanUI…).

## Bugs à corriger (version suivante, pas dans la rc4)
- Disposition « Compacte », mode placement : les étiquettes sous les blocs se chevauchent (blocs compacts plus étroits que leur étiquette, ex. « Monnaies » / « Composants de classe » / « Munitions », « Instances » sur « 2 verrouillée(s) »).
- Disposition « Colonne à gauche », mode placement : les étiquettes sortent de l'écran à gauche (on ne voit que leur fin).
- Les 26 captures FR sont dans cette session (uploads du 13/10) : refaire ici les visuels si besoin.

## Visibilité (échanges du 12/10 dans une autre conversation)
- Tessera est sur Wago (projet ANz7wj64, description = docs/wago-description.md). Fin de liste normale pour un addon récent.
- Pistes : Reddit (r/WoWUI, subreddit Forever), Discords Forever (MP à Malkkav envoyé pour demander s'il accepte un message sur son Discord), WoWInterface (pas de section Forever : catégorie la plus proche en précisant « WoW Forever »), pic de promotion vers le 4 novembre (sortie de Forever).
- Images faites dans l'autre conversation à partir de ~26 captures FR : barre du haut zoomée, collage et GIF des 4 styles, GIF des dispositions (chat flouté), groupe libre + infobulle Honneur. Pas présentes ici : les redemander si besoin.
- À faire : GIF de 5-10 s du mode placement (glisser/fusionner), 2-3 captures en client anglais, masquer « Issue Reporter » et la notification GNOME, description de page et post Reddit en anglais.

## En attente de Braincell1980
- Captures d'écran en jeu → GIF de défilement pour la description CurseForge.
- Tests de l'alpha multi-versions ; tests en instance (profil donjon, masquer en instance, clics en combat).

## Idées notées (docs/IDEES-FUTUR.md et conversation)
- Icônes nettes en 4K (Masque, icônes HD du jeu, option « icône nette », jeu d'icônes maison).
- Réactifs de classe affichés à 0 en rouge, seuil réglable, liste complétée.
- Bannière à refaire avec le nouveau logo et le titre « Tessera – Mosaic Info Bars & Data Blocks ».
- WoWInterface dans la publication automatique (Wago : prévu avec la rc4).
- Cadres décoratifs autour des groupes.
