# Changelog

## 1.1.16

Ready Check : fermeture fiable après 2 secondes.

- Correction de la fermeture automatique du Ready Check : un seul délai de fermeture peut maintenant être programmé par Ready Check.
- Suppression du problème où le ticker de rafraîchissement reprogrammait continuellement le délai de 2 secondes.
- Lorsque tout le monde a répondu, la fenêtre se ferme **2 secondes plus tard**.
- Lorsque le timer arrive à zéro sans que tout le monde soit prêt, la fenêtre se ferme également **2 secondes plus tard**.
- Le chemin de fin naturelle du Ready Check passe lui aussi par le délai de 2 secondes.
- Réinitialisation propre de l'état de fermeture à chaque nouveau Ready Check et lors de la fermeture de la fenêtre.
- Conservation du timer fluide et de la durée réelle fournie par Blizzard.

## 1.1.15

AutoLog et Ready Check.

- Correction de la migration du réglage unifié **Donjons (M0 / M+)** : la migration des anciens réglages est effectuée dès le chargement de l'addon et ne dépend plus de l'ouverture de l'onglet AutoLog.
- Consolidation de la logique Ready Check : les réponses individuelles sont maintenant enregistrées dans le suivi interne dès `READY_CHECK_CONFIRM`.
- Conservation de la fermeture automatique rapide lorsque tout le monde a répondu, en groupe comme en raid.
- Conservation du fallback `READY_CHECK_FINISHED` pour la fin normale du Ready Check ou l'expiration du timer.
- Validation des APIs concernées avec la source UI Blizzard de WoW et maintien de la gestion des Secret Values pour les auras et les messages de chat.

## 1.1.14

Focus activable/désactivable.

- Ajout d'une option **Activer le Focus** dans le module Focus.
- Le Focus est activé par défaut afin de conserver le comportement existant.
- Désactivation du Focus : suppression du binding sécurisé associé.
- Réactivation du Focus : restauration automatique du binding choisi.
- Conservation du choix de modificateur et de bouton souris.
- Case d'activation harmonisée visuellement avec les autres cases à cocher de CC RaidTools.

## 1.1.13

Release Ready Check stabilisée.

- Versionnement synchronisé pour la release 1.1.13.
- Consolidation de la version Ready Check validée en groupe et en raid.
- Timer basé sur la durée réelle fournie par Blizzard au lancement du Ready Check.
- Barre de compte à rebours fluide.
- Fermeture fiable environ 2 secondes après que tout le monde est prêt.
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
