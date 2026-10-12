# À reprendre (état au 11 octobre 2026, soir)

Reprise prévue le mardi 13 octobre 2026 (voir avec Braincell1980).

## Versions
- **1.0.0-rc3** : publiée (GitHub + CurseForge), traductions envoyées.
- **1.0.0-rc4** : en préparation sur `main`, non publiée (nouveau logo HD, texte « À propos » à la première personne). Publier seulement sur « on publie ».
- **1.1.0-alpha1** (autres versions du jeu : Classic Era, BC Classic, MoP Classic, jeu actuel ; pas Forever) : branche `multi-versions`, zip de test donné, en attente des tests de Braincell1980. Publication en Alpha seulement pour les versions testées. Si un jour elle est fusionnée dans `main` : retirer le suffixe « -forever » du nom du zip (voulu par Braincell1980 tant que l'addon est Forever seul).

## Prochaines étapes proposées (ordre validé à confirmer)
1. Publier la rc4, en ajoutant Wago : projet créé (lié au GitHub), identifiant `ANz7wj64` → ajouter `## X-Wago-ID: ANz7wj64` dans le .toc et `WAGO_API_TOKEN` (secret GitHub, mis par Braincell1980) dans release.yml. Vérifier que le lien GitHub de Wago n'importe pas aussi les releases (doublon).
2. Nettoyage / allègement du code, seul, sans changement de comportement, compatibilité des profils intacte (outils de dev vers la version debug, regroupements, mesure mémoire avant/après).
3. Styles pour tout le monde (vraies images si l'interface est installée, version approchante sinon) + nouveaux styles d'interface (TukUI, GW2 UI, NDui, KkthnxUI, SpartanUI…).

## En attente de Braincell1980
- Captures d'écran en jeu → GIF de défilement pour la description CurseForge.
- Tests de l'alpha multi-versions ; tests en instance (profil donjon, masquer en instance, clics en combat).

## Idées notées (docs/IDEES-FUTUR.md et conversation)
- Icônes nettes en 4K (Masque, icônes HD du jeu, option « icône nette », jeu d'icônes maison).
- Réactifs de classe affichés à 0 en rouge, seuil réglable, liste complétée.
- Bannière à refaire avec le nouveau logo et le titre « Tessera – Mosaic Info Bars & Data Blocks ».
- WoWInterface dans la publication automatique (Wago : prévu avec la rc4).
- Cadres décoratifs autour des groupes.
