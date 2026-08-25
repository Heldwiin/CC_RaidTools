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

**1.2.0**

### v1.2.0 — Raid Inspect

- Ajout du module **Raid Inspect**.
- Inspection séquentielle des membres du groupe ou du raid via les APIs Blizzard d'inspection.
- Affichage de l'ilvl inspecté, des enchants manquants et des sockets de gemmes vides.
- Gestion des joueurs hors de portée et des inspections sans réponse avec timeout.
- Compatibilité Midnight : slots d'enchantement adaptés, lecture des tooltips via `C_TooltipInfo` et `TooltipUtil.SurfaceArgs`, protection des valeurs secrètes et des réponses `INSPECT_READY` tardives.
- Nettoyage explicite de l'inspection Blizzard après timeout.
- Redimensionnement dynamique de la fenêtre et ajustements de l'interface Raid Inspect.
- Localisation FR/EN et icône dédiée Raid Inspect.
