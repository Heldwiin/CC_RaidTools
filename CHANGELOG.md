# Changelog

## 1.2.3

### Interface / versioning

- Suppression du message de bienvenue/version affiché dans le chat au chargement de l'addon.
- Affichage de la version directement dans la fenêtre `/ccrt`.
- La version affichée dans l'interface est maintenant récupérée automatiquement depuis le fichier `.toc`, évitant les numéros de version codés en dur.
- Renommage de la SavedVariable principale en `CCRaidToolsDB`, avec migration automatique des installations existantes utilisant `AutoPromoteDB`.
- `AutoPromoteDB` reste temporairement déclaré dans le `.toc` pendant la période de migration afin de préserver les données des utilisateurs existants.

### Raid Inspect — fiabilité

- Correction du comptage des sockets : `GemSocket.gemIcon` est utilisé pour déterminer directement si chaque socket est vide, sans double comptage des lignes `GemSocketEnchantment`.
- Les résultats d'inspection sont maintenant indexés par GUID plutôt que par unit token (`raid5`, `party2`, etc.), évitant d'afficher les données d'un ancien joueur sur un nouveau membre après un changement de roster.
- Ajout de la gestion de `GROUP_ROSTER_UPDATE` afin d'arrêter et réinitialiser proprement une inspection lorsque la composition du groupe change.
- Protection de `ClearInspectPlayer()` afin de ne pas interrompre une inspection Blizzard active dans l'interface native.

### Marks Bar

- Throttle de la vérification mouseover à 30 ms afin d'éviter un `IsMouseOver()` à chaque frame.
- Le throttle est appliqué dès le chargement de l'addon et ne dépend plus de l'ouverture de `/ccrt`.

### Architecture / maintenance

- Ajout d'un système de hooks UI propre pour les éléments de décoration de la fenêtre `/ccrt`.
- Suppression des monkey-patches de `ToggleUI` utilisés par les modules de branding/icônes.
- Découplage de `ModuleIcons` de `ReadyCheck`.
- AutoLog utilise désormais un état d'ownership en mémoire pour le suivi du combat log démarré par l'addon.
- Nettoyage et sécurisation de plusieurs chemins d'intégration UI sans modification du comportement utilisateur validé.

### Focus

- Correction du Focus avec Shift + clic sur les unit frames sécurisées, notamment la Target et les Boss Frames.
- Support des boutons configurés sur les unit frames sans casser leurs actions sécurisées existantes.
- Restauration des attributs d'origine lors de la désactivation ou du changement de configuration, sans écraser une modification effectuée entre-temps par un autre addon.

### AutoPromote

- Utilisation de `C_PartyInfo.PromoteToAssistant()` pour l'appel de promotion.
- Validation conservée avant toute promotion.

### Invite Tool

- Lorsqu'un joueur envoie le mot-clé d'invitation à un membre qui n'est pas leader, la demande utilise désormais la mécanique native Blizzard **Suggest Invite**.
- Le comportement est identique à l'action **Suggérer une invitation** du menu contextuel de WoW.
- Suppression du système de popup/communication maison pour ce cas.

## 1.2.2

### Raid Inspect

- Correction de la détection des gemmes manquantes.
- Comptage fiable des sockets vides à partir des données structurées Blizzard (`GemSocket` / `GemSocketEnchantment`).
- Réduction des faux positifs liés aux données de tooltip.
- Conservation de la détection des enchantements via l'item link, avec fallback structuré/textuel.

### Focus

- Correction du Focus avec Shift + clic sur les unit frames sécurisées, notamment la Target et les Boss Frames.
- Support des boutons configurés sur les unit frames sans casser leurs actions sécurisées existantes.
- Restauration des attributs d'origine lors de la désactivation ou du changement de configuration.

### Invite Tool

- Lorsqu'un joueur envoie le mot-clé d'invitation à un membre qui n'est pas leader, la demande utilise désormais la mécanique native Blizzard **Suggest Invite**.
- Le comportement est identique à l'action **Suggérer une invitation** du menu contextuel de WoW.
- Suppression du système de popup/communication maison pour ce cas.

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
