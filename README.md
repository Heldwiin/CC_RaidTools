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

**1.3.9**

### v1.3.9 — Correctif faux positif main secondaire (casters/tanks/heals)

- Les enchants de main secondaire ne concernent que les vraies armes (double maniement melee) — pas les orbes/tomes tenus en main secondaire par les casters, tanks et heals, qui ne sont pas enchantables. Vérification du `classID` (`Enum.ItemClass.Weapon`) ajoutée avant de compter cet emplacement.

### v1.3.8 — Icône de menu simplifiée + tooltip de diagnostic par emplacement

- Icône de menu recadrée plus serrée (silhouette seule) avec contraste/saturation accentués, nettement plus lisible à 30px.
- Survoler "manquant(s)" dans les colonnes Enchants/Gemmes affiche désormais un tooltip listant précisément quel(s) emplacement(s) sont en cause (ex. "Anneau 2"), pour vérifier directement en jeu plutôt que de deviner.

### v1.3.7 — Icône de menu Raid Inspect optimisée

- L'icône Raid Inspect devenait illisible à la taille du menu de gauche (30px) à cause de sa composition riche en détails, alors qu'elle restait nette à 72px (en-tête de module). Ajout d'un recadrage dédié, plus serré sur la loupe seule, utilisé uniquement pour l'icône de menu.

### v1.3.6 — Fusion des correctifs + ajustements layout/plancher fenêtre Raid Inspect

- Fusion de la passe de compatibilité Midnight (valeurs secrètes, `TooltipUtil.SurfaceArgs`, garde-fous file d'inspection, `CanInspect(unit, true)`) avec les correctifs de redimensionnement dynamique qui manquaient dans ce zip : `C.RequestResize()` (son absence empêchait la fenêtre de grandir après le chargement initial, d'où le bouton qui dépassait), plancher de fenêtre à 300px, watermark atténué (0.07) sur Raid Inspect.
- Colonnes resserrées et ascenseur repoussé de 26px vers la droite.
- Icône `RaidInspect.png` et message de chargement en chat restaurés (absents/obsolètes dans ce zip).

### v1.3.4 — Correctifs Raid Inspect / Midnight

- Correction des emplacements d'enchantement pour Midnight : casque, épaules, anneaux, torse, pieds et armes.
- Lecture des tooltips via `C_TooltipInfo.GetInventoryItem` avec `TooltipUtil.SurfaceArgs` avant inspection des lignes.
- Protection contre les valeurs secrètes lors de la lecture des textes de tooltip et de l'ilvl inspecté.
- Protection de la file contre les `INSPECT_READY` tardifs après un timeout afin qu'une ancienne réponse ne fasse pas avancer la mauvaise inspection.
- Localisation FR/EN du nouveau module Raid Inspect.
- Icône Raid Inspect intégrée au menu et aux en-têtes de module.
- Watermark de guilde atténué sur l'onglet Raid Inspect pour conserver la lisibilité du tableau.

### v1.2.0 — Raid Inspect

- Ajout du module **Raid Inspect**.
- Inspection séquentielle des membres du groupe ou du raid via les APIs Blizzard d'inspection.
- Affichage de l'ilvl inspecté pour chaque joueur.
- Détection des enchants manquants sur les emplacements enchantables de Midnight.
- Détection des sockets de gemmes vides.
- Gestion des joueurs hors de portée et des inspections sans réponse avec timeout.
- File d'inspection temporisée afin de limiter les appels simultanés et les résultats incohérents.
- Utilisation de `C_TooltipInfo` avec `TooltipUtil.SurfaceArgs` avant lecture des données structurées des tooltips.
- Protection contre les `INSPECT_READY` tardifs après un timeout afin d'éviter de perturber la file d'inspection.
- Ajout de l'icône et de l'entrée **Raid Inspect** dans le menu principal.

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
- Conservation du fallback `READY_CHECK_FINISHED`.
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
