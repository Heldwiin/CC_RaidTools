# Changelog

## 1.2.0

Raid Inspect.

- Ajout du module **Raid Inspect**.
- Inspection séquentielle des membres du groupe ou du raid via les APIs Blizzard d'inspection.
- Affichage de l'ilvl inspecté, des enchants manquants et des sockets de gemmes vides.
- Gestion des joueurs hors de portée et des inspections sans réponse avec timeout.
- Compatibilité Midnight : slots d'enchantement adaptés au client 12.x.
- Lecture des tooltips via `C_TooltipInfo.GetInventoryItem` et `TooltipUtil.SurfaceArgs`.
- Protection des valeurs secrètes lors de la lecture des textes de tooltip et de l'ilvl inspecté.
- Protection de la file contre les réponses `INSPECT_READY` tardives après timeout.
- Nettoyage explicite de l'inspection Blizzard en cas de timeout.
- Vérification de `CanInspect(unit, true)` alignée sur l'usage Blizzard.
- Ajout du redimensionnement dynamique via `C.RequestResize()` et ajustements de l'interface Raid Inspect.
- Ajout de la localisation FR/EN et de l'icône Raid Inspect.

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
