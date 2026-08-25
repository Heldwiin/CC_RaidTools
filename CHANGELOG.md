# Changelog

## 1.3.9

Correctif faux positif main secondaire (casters/tanks/heals).

- Les enchants de main secondaire ne concernent que les vraies armes tenues en main gauche (cac corps-à-corps en double maniement) — pas les orbes/tomes/objets "tenus en main secondaire" des casters, tanks et heals, qui ne sont tout simplement pas enchantables. Le module vérifie désormais le `classID` de l'objet (`Enum.ItemClass.Weapon`) avant de compter la main secondaire comme un enchant potentiellement manquant ; si ce n'est pas une arme, l'emplacement est ignoré au lieu d'être signalé à tort.

## 1.3.8

Icône de menu simplifiée + tooltip de diagnostic par emplacement.

- Icône de menu Raid Inspect recadrée plus serrée et contraste/saturation accentués : la silhouette ressort nettement mieux du fond bleu à 30px.
- Ajout d'un tooltip au survol des colonnes Enchants/Gemmes du Raid Inspect, indiquant précisément quel(s) emplacement(s) sont détectés comme manquants (ex. "Anneau 2"), au lieu d'un simple nombre. Objectif : permettre de vérifier directement en jeu au lieu de deviner depuis une capture d'écran, et faciliter le diagnostic si un faux positif réapparaît.

## 1.3.7

Icône de menu Raid Inspect optimisée pour les petites tailles.

- L'icône complète (loupe + presse-papier + fond) reste nette à 72px (en-tête de module) mais devenait illisible à 30px (icône du menu de gauche) — trop de détails fins pour cette taille. Ajout de `TexturesGUI/RaidInspectMenu.png`, un recadrage plus serré centré uniquement sur la loupe, utilisé spécifiquement pour l'icône du menu. L'icône d'en-tête (72px) reste inchangée.

## 1.3.6

Fusion des correctifs + ajustements layout/plancher fenêtre Raid Inspect.

- Fusion de la passe de compatibilité (protection "valeurs secrètes" Midnight 12.x, `TooltipUtil.SurfaceArgs`, garde-fous anti race-condition sur la file d'inspection, `CanInspect(unit, true)`) avec les correctifs précédents qui n'avaient pas été livrés : point d'accroche `C.RequestResize()` (manquant dans ce zip, ce qui empêchait la fenêtre de se redimensionner après le chargement initial de l'onglet — cause du bouton qui dépassait), plancher de fenêtre remonté à 300px (7 onglets), atténuation du watermark de guilde sur Raid Inspect.
- Watermark encore plus atténué sur Raid Inspect (alpha 0.07 au lieu de 0.12).
- Colonnes Nom/Ilvl/Enchants/Gemmes resserrées et ascenseur explicitement repoussé de 26px sur la droite, dans la marge libre du panneau.
- Icône `TexturesGUI/RaidInspect.png` restaurée (absente de ce zip).
- Message de chargement en chat restauré (`C.L.addonLoaded`), qui affichait un ancien numéro de version codé en dur.

## 1.3.4

Correctifs Raid Inspect / Midnight.

- Correction des emplacements d'enchantement pour Midnight : casque, épaules, anneaux, torse, pieds et armes.
- Lecture des tooltips via `C_TooltipInfo.GetInventoryItem` avec `TooltipUtil.SurfaceArgs` avant inspection des lignes (avec garde de compatibilité pour les clients où les champs sont déjà surfacés).
- Protection contre les valeurs secrètes lors de la lecture des textes de tooltip et de l'ilvl inspecté.
- Protection de la file contre les `INSPECT_READY` tardifs après un timeout afin qu'une ancienne réponse ne fasse pas avancer la mauvaise inspection.
- Nettoyage explicite de l'inspection Blizzard en cas de timeout pour éviter de laisser une inspection précédente active.
- Vérification de `CanInspect` avec le paramètre d'affichage d'erreur utilisé par Blizzard.
- Localisation FR/EN du nouveau module Raid Inspect.
- Icône Raid Inspect intégrée au menu et aux en-têtes de module.
- Watermark de guilde atténué sur l'onglet Raid Inspect pour conserver la lisibilité du tableau.

## 1.2.0

### Raid Inspect

- Ajout du module **Raid Inspect**.
- Inspection séquentielle des membres du groupe ou du raid via les APIs Blizzard d'inspection.
