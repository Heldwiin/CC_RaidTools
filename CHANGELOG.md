# Changelog

## 1.2.7

### Nouveau module : Raid Groups

- Ajout du module **Raid Groups** : organisation des 8 groupes de raid par glisser-déposer, directement depuis `/ccrt`.
- Tri automatique configurable (icône ⚙️) : groupes concernés par le tri, nombre de parts (2 à 8) et règle de split consécutive (`1,2,3 vs 4,5,6`) ou alternée (`1,3,5 vs 2,4,6`). Les groupes exclus du tri conservent leurs occupants actuels.
- Presets de composition nommés : sauvegarde, chargement et suppression, persistants après `/reload`.
- Partage en jeu de la composition active à tout le raid/groupe via message d'addon, ainsi qu'export/import sous forme de texte copiable (utilisable hors raid). Dans les deux cas, la composition reçue est toujours enregistrée comme un nouveau preset, jamais appliquée automatiquement, et reprend le nom du preset actif chez l'expéditeur.
- Bouton **Appliquer** : déplace réellement les joueurs dans les groupes du raid (chef de raid ou assistant uniquement, bloqué en combat), avec déplacement direct si le groupe cible a de la place ou échange sinon.

### Ready Check — durabilité de l'équipement

- Ajout d'une colonne **Durabilité** dans le Ready Check, affichant le pourcentage moyen de durabilité de chaque membre du raid/groupe, coloré selon le seuil (vert / orange / rouge).
- La durabilité est diffusée aux autres membres dès le déclenchement du Ready Check, y compris pour un joueur ayant désactivé sa propre fenêtre de Ready Check.

## 1.2.6

### Raid Inspect — stabilité et combat

- Correction définitive du blocage de Raid Inspect lorsque la fenêtre est fermée pendant une inspection.
- Annulation propre de la file et des timers d'inspection lors de la fermeture de la fenêtre.
- Blocage complet du lancement d'une inspection pendant le combat.
- Arrêt immédiat d'une inspection en cours lors de l'entrée en combat.
- Le bouton **Inspecter le raid** reste désactivé pendant le combat et est réactivé à la sortie de combat.
- Stabilisation des résultats lorsque les données Blizzard arrivent en plusieurs étapes.
- Les résultats `...` ne remplacent plus inutilement des données plus complètes déjà obtenues.
- Correction des faux états `manquant(s)` / `...` / `OK` liés aux données d'inspection encore incomplètes.
- Conservation des résultats les plus fiables lorsqu'une seconde passe fournit moins d'informations que la première.

## 1.2.5

### Raid Inspect — stabilité et fiabilité

- Stabilisation complète de l'inspection du raid après les problèmes de freeze introduits depuis la 1.2.3.
- L'inspection Raid Inspect reste entièrement déclenchée à la demande.
- Correction de la gestion de la file d'inspection afin d'éviter les blocages et les états d'inspection persistants.
- Fermeture de la fenêtre Raid Inspect pendant un scan : l'inspection et ses timers sont maintenant annulés proprement.
- Gestion des changements de roster pendant une inspection sans réinitialiser inutilement les résultats déjà obtenus.
- Conservation des résultats par GUID plutôt que par unit token.
- Correction de la détection des enchantements et des états de tooltip incomplets.
- Ajout de l'emplacement **Jambières** dans les emplacements inspectés pour les enchantements.
- Correction de la détection des sockets de gemmes, avec distinction entre sockets remplies, vides et données encore indisponibles.
- Correction des faux résultats `OK` lorsque les données d'inspection ne sont pas encore suffisamment disponibles.
- Conservation et fiabilisation des tooltips indiquant les emplacements exacts des enchants et gemmes manquants.
- Renforcement des protections autour des résultats d'inspection Blizzard asynchrones et des données de tooltip.

### Nettoyage

- Suppression des restes de l'ancien mécanisme de retry devenu inutilisé.
- Simplification de la gestion des timers d'inspection.

## 1.2.4

### Performance / Focus

- Correction d'un freeze important à la sortie de combat.
- Le binding Focus n'effectue plus un scan complet de toutes les frames WoW à chaque `PLAYER_REGEN_ENABLED`.
- Le parcours des unit frames reste réservé aux moments où la configuration des bindings doit réellement être appliquée.

### Raid Inspect

- Correction du comptage des sockets gemmes lorsque certaines sockets sont remplies et d'autres vides.
- Les sockets sont maintenant évaluées individuellement afin d'éviter les faux résultats.
- Protection renforcée autour de l'état d'inspection Blizzard natif.

### AutoLog

- Récupération de l'ownership du combat log après `/reload` lorsque le log est déjà actif dans une instance ciblée.

### Base de données

- Suppression de l'ancienne migration `AutoPromoteDB` → `CCRaidToolsDB`.
- `CCRaidToolsDB` est désormais la seule SavedVariable utilisée par l'addon.

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
- Le throttle est appliqué directement dans `MarksBar.lua` dès la création de la barre.
- Suppression du fichier `MarksBarPerformance.lua`, devenu inutile après intégration du correctif dans le module principal.

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
- Support des boutons configurés sur les unit frames sans casser leurs actions sécurisées.
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
