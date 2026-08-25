# CC RaidTools

Addon World of Warcraft développé pour la guilde **Caelestis Concilium (CC)**.

## Fonctionnalités

- Auto Promote de joueurs configurés manuellement ou selon les rangs de guilde.
- AutoLog configurable pour LFR, Normal, Héroïque, Mythique et Donjons (M0 / M+).
- Fenêtre Ready Check automatique avec statuts dynamiques, consommables et buffs de raid.
- Ready Check groupe/raid avec largeur et hauteur dynamiques, timer fluide et fermeture 2 secondes après la fin.
- Marks Bar avec marques de raid et marqueurs au sol, orientation et position configurables.
- Focus configurable avec modificateur/bouton souris et possibilité d'activer ou désactiver la fonction.
- Invite Tool avec invitation sur mot-clé reçu en chuchotement.
- **Raid Inspect** : inspection séquentielle du groupe/raid avec ilvl, enchants manquants, gemmes non serties et gestion des joueurs hors portée / sans réponse.
- Interface personnalisée sombre/transparente avec branding Caelestis Concilium.
- Configuration persistante après `/reload`.

## Commande

- `/ccrt` : ouvre la configuration de CC RaidTools.

## Version

**1.3.6**

### v1.3.6 — Raid Inspect : compatibilité Midnight et ajustements UI

- Fusion des correctifs de compatibilité Midnight : valeurs secrètes, `TooltipUtil.SurfaceArgs`, garde-fous de file d'inspection et `CanInspect(unit, true)`.
- Protection contre les réponses `INSPECT_READY` tardives après timeout.
- Nettoyage explicite de l'inspection Blizzard après timeout.
- Redimensionnement dynamique via `C.RequestResize()` et plancher de fenêtre à 300 px.
- Colonnes Raid Inspect resserrées et ascenseur repoussé dans la marge libre.
- Watermark de guilde atténué sur Raid Inspect.
- Ajout de la localisation FR/EN et de l'icône Raid Inspect.

### v1.2.0 — Raid Inspect

- Ajout du module Raid Inspect.
- Inspection séquentielle des membres du groupe ou du raid via les APIs Blizzard d'inspection.
- Affichage de l'ilvl inspecté, des enchants manquants et des sockets de gemmes vides.
- Gestion des joueurs hors de portée et des inspections sans réponse avec timeout.
