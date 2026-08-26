# Changelog

## 1.2.1

### Raid Inspect

- Correction de la détection des enchantements sur les équipements inspectés.
- Détection native des enchantements permanents via les données structurées des tooltips Blizzard, avec fallback textuel pour les états/API où le type structuré n'est pas disponible.
- Correction des faux positifs où un joueur correctement enchanté pouvait être signalé comme non enchanté.
- Conservation de la file d'inspection temporisée et des protections contre les inspections sans réponse et les événements `INSPECT_READY` tardifs.

## 1.2.0

### Raid Inspect

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
- Correction de la détection de l'enchant de main gauche : les objets tenus en main secondaire qui ne sont pas des armes ne sont plus signalés à tort.
- Ajout d'un tooltip indiquant les emplacements exacts concernés par les enchants ou gemmes manquants.
- Icône de menu Raid Inspect optimisée pour rester lisible à petite taille.

### v1.1.16 — Ready Check

- Fermeture fiable 2 secondes après que tout le monde a répondu.
- Fermeture 2 secondes après l'expiration du timer.
- Un seul délai de fermeture peut être programmé par Ready Check, empêchant le ticker de repousser continuellement la fermeture.
- Réinitialisation propre de l'état de fermeture à chaque nouveau Ready Check.

### v1.1.15 — AutoLog et Ready Check

- Migration du réglage unifié Donjons (M0 / M+) dès le chargement de l'addon.
- Consolidation du suivi des réponses `READY_CHECK_CONFIRM`.
- Conservation de la fermeture automatique rapide en groupe comme en raid.
- Validation des APIs concernées avec la source UI Blizzard de WoW.

### v1.1.14 — Focus activable/désactivable

- Ajout de l'option **Activer le Focus**.
- Désactivation et réactivation propre du binding sécurisé associé.

### v1.1.13 — Ready Check stabilisée

- Timer basé sur la durée réelle fournie par Blizzard.
- Barre de compte à rebours fluide.
- Fermeture fiable environ 2 secondes après que tout le monde est prêt.

### v1.1.11 — Ready Check

- Correction de la fermeture automatique en groupe et en raid via la fin réelle du Ready Check Blizzard.
- Utilisation de la durée réelle fournie au lancement du Ready Check.
- Barre de compte à rebours rendue plus fluide.

### v1.1.10 — Ready Check : largeur dynamique

- Largeur calculée selon les buffs réellement disponibles en groupe.
- Mise à jour immédiate lors des changements de composition.
- Réduction de la largeur du mode raid à 640 px.

### v1.1.9 — Ready Check Groupe & Buffs dynamiques

- Ajout du mode groupe 5 joueurs.
- Suppression du check Vantus en groupe.
- Affichage dynamique des buffs selon les classes présentes.
- Ajout du buff Évocateur / Bronze.
