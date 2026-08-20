# Changelog

## 1.1.9

Ready Check groupe et buffs dynamiques.

- Ajout du mode **groupe 5 joueurs** au Ready Check, en plus du mode raid.
- Suppression du check **Vantus** en groupe.
- Affichage dynamique des buffs selon les classes présentes dans le groupe.
- Ajout du buff **Évocateur / Bronze** dans les modes groupe et raid.
- Largeur de la fenêtre adaptée automatiquement au contenu du groupe.
- Repositionnement des icônes et colonnes pour conserver l'alignement du mode raid.
- Conservation du timer de fermeture avec `atrocity.tga`.
- Conservation de la fermeture automatique lorsque tout le monde est prêt.

## 1.1.8

Correctif AutoLog Donjons et optimisation du Ready Check.

- Fusion des options **Donjons Mythique** et **Mythique+** en une seule option **Donjons (M0 / M+)**.
- Correction du démarrage de l'AutoLog en Mythique+ avec `CHALLENGE_MODE_START` et délai d'une seconde.
- Alignement de la logique de démarrage des donjons sur le comportement validé avec Method Raid Tools.
- Optimisation du Ready Check avec une fenêtre dont la hauteur s'adapte automatiquement au nombre de joueurs du raid.
- Suppression de l'ascenseur visible du Ready Check : tous les joueurs sont affichés directement jusqu'à 40 joueurs.
- Ajout d'une barre de progression de fermeture utilisant la texture `atrocity.tga`.
- Le timer de fermeture démarre dès l'ouverture du Ready Check.
- Affichage du compte à rebours jusqu'à 30 secondes.
- Fermeture automatique environ 2 secondes après que tout le monde est prêt.
- Fusion de toutes les améliorations Ready Check dans `ReadyCheck.lua` et suppression de `ReadyCheckEnhancements.lua`.
- Version affichée dans la fenêtre Ready Check synchronisée avec la release.

## 1.1.7

Correctif AutoLog Mythique+.

- Correction du démarrage de l'enregistrement des combats en Mythique+.
- Détection du lancement de clé via `CHALLENGE_MODE_START` avec délai de 1 seconde, suivant le comportement validé de Method Raid Tools.
- Suppression des interrogations répétées de `LoggingCombat()` qui pouvaient perturber le démarrage du log.
- Conservation de la propriété du logging pour que CC RaidTools n'arrête jamais un combat log lancé manuellement.

## 1.1.6

Correctif Ready Check et synchronisation de release.

- Restauration complète du cycle Ready Check après le nettoyage de la version précédente.
- Restauration du bouton Test et des événements READY_CHECK, READY_CHECK_CONFIRM et READY_CHECK_FINISHED.
- Conservation du cache d'auras, du throttling UNIT_AURA et du défilement jusqu'à 40 joueurs.
- Synchronisation des chaînes de version sur 1.1.6.

## 1.1.5

Interface, branding et stabilité.

- Nouvelles icônes HD personnalisées pour les six modules.
- Menu des modules modernisé avec icônes, sélection et survol plus lisibles.
- Icône du module affichée en haut à droite de chaque panneau.
- Watermark Caelestis Concilium repositionné pour éviter les chevauchements avec les icônes de module.
- Correction du spam de messages AutoLog lors des rafraîchissements/reloads.
- Version Ready Check synchronisée sur 1.1.5.

## 1.1.4

Correctifs de fiabilité et de sécurité.

- AutoLog couvre tous les donjons Mythique et Mythique+ sans filtrage arbitraire par carte.
- Focus n'altère plus les frames sécurisées créées par d'autres addons.
- Synchronisation de la version affichée dans le Ready Check.
- Watermark de guilde rendu plus discret.

## 1.1.2

Release packaging et nettoyage du processus de publication.

- Synchronisation de toutes les chaînes de version sur 1.1.2.
- Génération automatique du ZIP de release via GitHub Actions.
- Le ZIP distribué contient uniquement les fichiers nécessaires à l'addon.
- Les fichiers de développement et de documentation ne sont pas inclus dans l'archive WoWUp.
- Nettoyage général du processus de publication.

## 1.1.1

Correctifs, performances et nettoyage général.

- Correction du défilement du Ready Check pour les raids importants.
- Optimisation du rafraîchissement des auras du Ready Check avec cache par joueur.
- Correction du mode Test du Ready Check.
- Correction du défilement de la liste Auto Promote.
- Sécurisation des accès aux champs d'aura potentiellement secrets.
- Correction du mapping des World Markers et des tooltips `/wm`.
- Correction du matching des rangs Auto Promote pour les joueurs inter-royaumes et homonymes.
- Conservation des vérifications de combat pour les actions protégées.
- Nettoyage des fonctions globales inutilisées et sécurisation du module Focus.

## 1.1.0

Clean-up, stabilité et sécurisation de l'addon.

- Nettoyage général de l'architecture et des commandes.
- Sécurisation des actions protégées et des changements pendant le combat.
- Ready Check corrigé et optimisé.
- AutoLog fiabilisé, notamment après `/reload`.
- Marks Bar mieux protégée vis-à-vis du combat.
- SavedVariables initialisées de manière défensive.
- Interface et branding nettoyés.
- Documentation et règles de développement mises à jour.

## 1.0

Première version de référence de **CC RaidTools**.

- Auto Promote par joueur et par rang de guilde.
- Persistance des rangs sélectionnés.
- AutoLog par difficulté de raid.
- Ready Check automatique avec fermeture différée de 30 secondes.
- Statuts OK / KO / WAIT.
- Détection repas, flacon, rune et Vantus.
- Buffs de raid avec icônes grisées/colorées.
- Compteur dynamique prêts/total dans le Ready Check.
- Skin CC RaidTools sombre, transparent et pixel-perfect.
