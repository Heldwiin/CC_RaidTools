# Changelog

## 1.1.13

Release Ready Check stabilisée.

- Versionnement synchronisé pour la release 1.1.13.
- Consolidation de la version Ready Check validée en groupe et en raid.
- Timer basé sur la durée réelle fournie par Blizzard au lancement du Ready Check.
- Barre de compte à rebours fluide.
- Fermeture fiable environ 2 secondes après la fin du Ready Check lorsque tout le monde est prêt.
- Conservation du mode groupe dynamique et du buff **Évocateur / Bronze**.

## 1.1.11

Ready Check : timer réel et fermeture fiable.

- Correction de la fermeture automatique du Ready Check en groupe et en raid via la fin réelle du Ready Check Blizzard.
- Fermeture environ 2 secondes après que tout le monde est prêt.
- Utilisation de la durée réelle fournie au lancement du Ready Check au lieu d'une durée fixe de 30 secondes.
- Barre de compte à rebours rendue plus fluide.
- Conservation du mode groupe dynamique, du mode raid et du buff **Évocateur / Bronze**.

## 1.1.10

Optimisation du redimensionnement du Ready Check.

- Largeur du Ready Check calculée dynamiquement selon les buffs réellement disponibles en groupe.
- Mise à jour immédiate de la largeur lors des changements de composition du groupe.
- Réduction de la largeur du mode raid à **640 px** pour supprimer l'espace inutile à droite.
- Conservation du mode groupe sans Vantus et des buffs dynamiques par classe.
- Conservation du buff **Évocateur / Bronze** dans les modes groupe et raid.
- Conservation du timer de fermeture avec `atrocity.tga`.
- Conservation de la fermeture automatique lorsque tout le monde est prêt.

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
