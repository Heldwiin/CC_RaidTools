# Changelog

## 1.3.6

Fusion des correctifs + ajustements layout/plancher fenêtre Raid Inspect.

- Fusion de la passe de compatibilité Midnight : protection des valeurs secrètes, `TooltipUtil.SurfaceArgs`, garde-fous anti race-condition sur la file d'inspection et `CanInspect(unit, true)`.
- Ajout du point d'accroche `C.RequestResize()` pour le redimensionnement après chargement du module.
- Plancher de fenêtre remonté à 300 px.
- Watermark de guilde atténué sur Raid Inspect.
- Colonnes Nom/Ilvl/Enchants/Gemmes resserrées et ascenseur repoussé dans la marge libre.
- Icône Raid Inspect et message de chargement restaurés.

## 1.3.4

Correctifs Raid Inspect / Midnight.

- Correction des emplacements d'enchantement pour Midnight : casque, épaules, anneaux, torse, pieds et armes.
- Lecture des tooltips via `C_TooltipInfo.GetInventoryItem` avec `TooltipUtil.SurfaceArgs`.
- Protection contre les valeurs secrètes lors de la lecture des textes de tooltip et de l'ilvl inspecté.
- Protection de la file contre les `INSPECT_READY` tardifs après timeout.
- Nettoyage explicite de l'inspection Blizzard en cas de timeout.
- Vérification de `CanInspect` avec le paramètre d'affichage d'erreur utilisé par Blizzard.
- Localisation FR/EN, icône et intégration du module Raid Inspect.

## 1.2.0

### Raid Inspect

- Ajout du module **Raid Inspect**.
- Inspection séquentielle des membres du groupe ou du raid via les APIs Blizzard d'inspection.
- Affichage de l'ilvl inspecté, des enchants manquants et des sockets de gemmes vides.
- Gestion des joueurs hors de portée et des inspections sans réponse avec timeout.
