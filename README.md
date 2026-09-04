# CC RaidTools

Addon World of Warcraft développé pour la guilde **Caelestis Concilium (CC)**.

## Fonctionnalités

- Auto Promote de joueurs configurés manuellement.
- Auto Promote selon les rangs de guilde sélectionnés.
- AutoLog configurable pour LFR, Normal, Héroïque, Mythique et Donjons (M0 / M+).
- Fenêtre Ready Check automatique lors d'un appel.
- Statut dynamique OK / KO / WAIT.
- Colonne **Durabilité** de l'équipement, partagée entre les membres du raid/groupe.
- Vérification des consommables : repas, flacon, rune et rune de Vantus.
- Affichage des buffs de raid Mage (Intel), Guerrier (PA), Druide, Prêtre (Endu), Chaman et Évocateur (Bronze).
- En groupe 5 joueurs, affichage dynamique uniquement des buffs correspondant aux classes présentes et suppression du check Vantus.
- Compteur dynamique des joueurs prêts dans l'en-tête du Ready Check (ex. 3/20).
- Fenêtre Ready Check redimensionnée automatiquement selon le nombre de joueurs, jusqu'à 40 joueurs sans ascenseur visible.
- Largeur du Ready Check ajustée dynamiquement au contenu en groupe et compacte en raid.
- Mise à jour immédiate de la largeur lors des changements de composition du groupe.
- Barre de fermeture avec compte à rebours et texture personnalisée Atrocity.
- Marks Bar avec marques de raid et marqueurs au sol.
- Barre configurable en horizontal ou vertical, avec position sauvegardée et affichage au mouseover.
- Focus configurable avec modificateur et bouton de souris, avec possibilité d'activer ou désactiver la fonction.
- Support du Focus sur les unit frames sécurisées, notamment Target et Boss Frames.
- Invite Tool avec invitation sur mot-clé reçu en chuchotement.
- Utilisation de la mécanique native Blizzard **Suggest Invite** lorsqu'un membre non-leader reçoit une demande d'invitation.
- **Raid Inspect** : inspection du groupe/raid avec ilvl moyen, enchants manquants et gemmes non serties.
- **Raid Groups** : organisation des 8 groupes de raid par glisser-déposer, tri automatique configurable, presets nommés, partage en jeu et export/import texte, application directe des groupes en jeu.
- Interface personnalisée sombre/transparente avec bordures pixel et branding Caelestis Concilium.
- Configuration persistante après `/reload`.

## Commande

- `/ccrt` : ouvre la configuration de CC RaidTools.

## Version

**1.2.7**

### v1.2.7

#### Raid Groups (nouveau module)

- Organisation des 8 groupes de raid par glisser-déposer.
- Tri automatique configurable : groupes concernés, nombre de splits (1 à 8), règle de split consécutive ou alternée.
- Presets de composition nommés, persistants après `/reload`.
- Partage en jeu et export/import texte, toujours enregistrés comme un nouveau preset côté réception.
- Bouton **Appliquer** pour déplacer réellement les joueurs dans les groupes du raid (chef de raid/assistant, bloqué en combat).

#### Ready Check

- Ajout d'une colonne **Durabilité** de l'équipement, colorée selon le seuil et partagée entre les membres du raid/groupe.

### v1.2.6

#### Raid Inspect

- Correction définitive du blocage de Raid Inspect lorsque la fenêtre est fermée pendant une inspection.
- Annulation propre de la file et des timers d'inspection lors de la fermeture de la fenêtre.
- Blocage complet du lancement d'une inspection pendant le combat.
- Arrêt immédiat d'une inspection en cours lors de l'entrée en combat.
- Le bouton **Inspecter le raid** reste désactivé pendant le combat et est réactivé à la sortie de combat.
- Stabilisation des résultats lorsque les données Blizzard arrivent en plusieurs étapes.
- Les résultats `...` ne remplacent plus inutilement des données plus complètes déjà obtenues.
- Évite les faux états `manquant(s)` / `...` / `OK` liés aux données d'inspection encore incomplètes.
- Conservation des résultats les plus fiables lorsqu'une seconde passe fournit moins d'informations que la première.

### v1.2.5

#### Raid Inspect

- Stabilisation complète de la file d'inspection et des inspections Blizzard.
- Correction de la détection des enchants et gemmes manquants.
- Ajout de l'emplacement **Jambières** dans les emplacements inspectés pour les enchantements.
- Gestion explicite des données d'inspection encore inconnues afin d'éviter les faux `OK`.
- Amélioration de la revalidation des données de tooltip pour les enchants et les gemmes.
- Conservation des résultats lors des changements de composition du groupe.
- Arrêt propre de l'inspection lorsque la fenêtre Raid Inspect est fermée.
- Correction des états d'inspection pouvant rester bloqués après fermeture de la fenêtre.
- Amélioration des tooltips affichant les emplacements d'enchants et de gemmes manquants ou encore non confirmés.

#### Stabilité

- Réduction des faux résultats liés aux données de tooltip Blizzard disponibles de façon asynchrone.
- Renforcement de la gestion des réponses d'inspection tardives et des états incomplets.

### v1.2.4

#### Performance / Focus

- Correction d'un freeze important à la sortie de combat.
- Le binding Focus n'effectue plus un scan complet de toutes les frames WoW à chaque `PLAYER_REGEN_ENABLED`.
- Le parcours des unit frames reste réservé aux moments où la configuration des bindings doit réellement être appliquée.

#### Raid Inspect

- Correction du comptage des sockets gemmes lorsque certaines sockets sont remplies et d'autres vides.
- Les sockets sont maintenant évaluées individuellement afin d'éviter les faux résultats.
- Protection renforcée autour de l'état d'inspection Blizzard natif.

#### AutoLog

- Récupération de l'ownership du combat log après `/reload` lorsque le log est déjà actif dans une instance ciblée.

#### Base de données

- Suppression de l'ancienne migration `AutoPromoteDB` → `CCRaidToolsDB`.
- `CCRaidToolsDB` est désormais la seule SavedVariable utilisée par l'addon.

### v1.2.3

#### Interface

- Suppression du message de bienvenue/version affiché dans le chat au chargement de l'addon.
- Affichage de la version directement dans la fenêtre `/ccrt`.
- La version affichée dans l'interface est maintenant récupérée automatiquement depuis le fichier `.toc`, évitant les numéros de version codés en dur.

#### Marks Bar

- Throttle de la vérification mouseover à 30 ms afin d'éviter un `IsMouseOver()` à chaque frame.
- Le throttle est appliqué directement dans `MarksBar.lua` dès la création de la barre.
- Suppression du fichier `MarksBarPerformance.lua`, devenu inutile après intégration du correctif dans le module principal.

#### Raid Inspect

- Correction du comptage des sockets et réduction des faux positifs.
- Les résultats d'inspection sont indexés par GUID afin d'éviter les données obsolètes après un changement de roster.
- Gestion des changements de composition du groupe pendant une inspection.

#### Focus

- Correction du Focus avec Shift + clic sur les unit frames sécurisées, notamment la Target et les Boss Frames.
- Support des boutons configurés sur les unit frames sans casser leurs actions sécurisées existantes.
- Restauration des attributs d'origine lors de la désactivation ou du changement de configuration.

#### Invite Tool

- Lorsqu'un joueur envoie le mot-clé d'invitation à un membre qui n'est pas leader, la demande utilise désormais la mécanique native Blizzard **Suggest Invite**.
- Le comportement est identique à l'action **Suggérer une invitation** du menu contextuel de WoW.

### v1.2.2

#### Raid Inspect

- Correction de la détection des gemmes manquantes.
- Comptage fiable des sockets vides à partir des données structurées Blizzard (`GemSocket` / `GemSocketEnchantment`).
- Réduction des faux positifs liés aux données de tooltip.
- Conservation de la détection des enchantements via l'item link, avec fallback structuré/textuel.

#### Focus

- Correction du Focus avec Shift + clic sur les unit frames sécurisées, notamment la Target et les Boss Frames.
- Support des boutons configurés sur les unit frames sans casser leurs actions sécurisées.
- Restauration des attributs d'origine lors de la désactivation ou du changement de configuration.

#### Invite Tool

- Utilisation de la mécanique native Blizzard **Suggest Invite** lorsqu'un membre non-leader reçoit une demande d'invitation.

### v1.2.1 — Raid Inspect

- Correction de la détection des enchantements sur les équipements inspectés.
- Détection native des enchantements permanents via les données structurées des tooltips Blizzard, avec fallback textuel pour les états/API où le type structuré n'est pas disponible.
- Correction des faux positifs où un joueur correctement enchanté pouvait être signalé comme non enchanté.
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
- Mise à jour immédiate lors des changements de composition.
- Réduction de la largeur du mode raid à 640 px.

### v1.1.9 — Ready Check Groupe & Buffs dynamiques

- Ajout du mode **groupe 5 joueurs**.
- Suppression du check **Vantus** en groupe.
- Affichage dynamique des buffs selon les classes présentes.
- Ajout du buff **Évocateur / Bronze**.
- Largeur de la fenêtre adaptée automatiquement au contenu du groupe.
