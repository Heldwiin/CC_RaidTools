# CC RaidTools

Addon World of Warcraft développé pour la guilde **Caelestis Concilium (CC)**.

## Fonctionnalités

- Auto Promote de joueurs configurés manuellement.
- Auto Promote selon les rangs de guilde sélectionnés.
- AutoLog configurable pour LFR, Normal, Héroïque, Mythique et Donjons (M0 / M+).
- Fenêtre Ready Check automatique lors d'un appel.
- Statut dynamique OK / KO / WAIT.
- Vérification des consommables : repas, flacon, rune et rune de Vantus.
- Affichage des buffs de raid Mage (Intel), Guerrier (PA), Druide, Prêtre (Endu), Chaman et Évocateur (Bronze).
- En groupe 5 joueurs, affichage dynamique uniquement des buffs correspondant aux classes présentes et suppression du check Vantus.
- Compteur dynamique des joueurs prêts dans l'en-tête du Ready Check (ex. 3/20).
- Fenêtre Ready Check redimensionnée automatiquement selon le nombre de joueurs, jusqu'à 40 joueurs sans ascenseur visible.
- Largeur du Ready Check ajustée dynamiquement au contenu en groupe et compacte en raid.
- Mise à jour immédiate de la largeur lors des changements de composition du groupe.
- Barre de fermeture avec compte à rebours et texture personnalisée Atrocity.
- Fermeture automatique **2 secondes après la fin du Ready Check**, que tout le monde soit prêt ou que le timer arrive à expiration.
- Marks Bar avec marques de raid et marqueurs au sol.
- Barre configurable en horizontal ou vertical, avec position sauvegardée et affichage au mouseover.
- Focus configurable avec modificateur et bouton de souris, avec possibilité d'activer ou désactiver la fonction.
- Invite Tool avec invitation sur mot-clé reçu en chuchotement.
- **Raid Inspect** : inspection du groupe/raid avec ilvl moyen, enchants manquants et gemmes non serties.
- Interface personnalisée sombre/transparente avec bordures pixel et branding Caelestis Concilium.
- Configuration persistante après `/reload`.

## Commande

- `/ccrt` : ouvre la configuration de CC RaidTools.

## Version

**1.2.1**

### v1.2.1 — Raid Inspect

- Correction de la détection des enchantements sur les équipements inspectés.
- Détection native des enchantements permanents via les données structurées des tooltips Blizzard, avec fallback textuel pour les états/API où le type structuré n'est pas disponible.
- Suppression des faux positifs où un joueur correctement enchanté pouvait être signalé comme non enchanté.
- Conservation de la file d'inspection temporisée et des protections contre les inspections sans réponse et les événements `INSPECT_READY` tardifs.

### v1.2.0 — Raid Inspect

- Ajout du module **Raid Inspect**.
- Inspection séquentielle des membres du groupe ou du raid via les APIs Blizzard d'inspection.
- Affichage de l'ilvl inspecté pour chaque joueur.
- Détection des enchants manquants sur les emplacements enchantables de Midnight.
- Détection des sockets de gemmes vides.
- Gestion des joueurs hors de portée et des inspections sans réponse avec timeout.
- File d'inspection temporisée afin de limiter les appels simultanés et les résultats incohérents.
- Utilisation de `C_TooltipInfo` avec `TooltipUtil.SurfaceArgs` avant lecture des données structurées des tooltips.
- Protection contre les valeurs secrètes lors de la lecture des données d'inspection.
- Protection contre les `INSPECT_READY` tardifs après un timeout afin d'éviter de perturber la file d'inspection.
- Vérification de `CanInspect` avant chaque inspection.
- Correctifs de redimensionnement et de présentation du module Raid Inspect.
- Ajout des icônes Raid Inspect au menu et à l'en-tête du module.

### v1.1.16 — Ready Check : fermeture fiable après 2 secondes

- Correction de la fermeture automatique du Ready Check : un seul délai de fermeture peut maintenant être programmé par Ready Check.
- Suppression du problème où le ticker de rafraîchissement reprogrammait continuellement le délai de 2 secondes.
- Lorsque tout le monde a répondu, la fenêtre se ferme **2 secondes plus tard**.
- Lorsque le timer arrive à zéro sans que tout le monde soit prêt, la fenêtre se ferme également **2 secondes plus tard**.
- Le chemin de fin naturelle du Ready Check passe lui aussi par le délai de 2 secondes.
- Réinitialisation propre de l'état de fermeture à chaque nouveau Ready Check et lors de la fermeture de la fenêtre.
- Conservation du timer fluide et de la durée réelle fournie par Blizzard.

### v1.1.15 — AutoLog et Ready Check

- Correction de la migration du réglage unifié **Donjons (M0 / M+)** dès le chargement de l'addon.
- Consolidation du suivi des réponses `READY_CHECK_CONFIRM`.
- Conservation de la fermeture automatique rapide en groupe comme en raid.
- Validation des APIs concernées avec la source UI Blizzard de WoW.

### v1.1.14 — Focus activable/désactivable

- Ajout d'une option **Activer le Focus**.
- Désactivation du Focus : suppression du binding sécurisé associé.
- Réactivation du Focus : restauration automatique du binding choisi.

### v1.1.13 — Ready Check stabilisée

- Versionnement synchronisé.
- Timer basé sur la durée réelle fournie par Blizzard.
- Barre de compte à rebours fluide.
- Fermeture fiable environ 2 secondes après que tout le monde est prêt.

### v1.1.11 — Ready Check : timer réel et fermeture fiable

- Correction de la fermeture automatique du Ready Check en groupe et en raid via la fin réelle du Ready Check Blizzard.
- Utilisation de la durée réelle fournie au lancement du Ready Check.
- Barre de compte à rebours rendue plus fluide.

### v1.1.10 — Ready Check : largeur dynamique

- Largeur calculée selon les buffs réellement disponibles en groupe.
- Mise à jour immédiate de la largeur lors des changements de composition.
- Réduction de la largeur du mode raid à 640 px.

### v1.1.9 — Ready Check Groupe & Buffs dynamiques

- Ajout du mode **groupe 5 joueurs**.
- Suppression du check **Vantus** en groupe.
- Affichage dynamique des buffs selon les classes présentes.
- Ajout du buff **Évocateur / Bronze**.
- Largeur de la fenêtre adaptée automatiquement au contenu du groupe.
