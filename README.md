# CC RaidTools

Addon World of Warcraft développé pour la guilde **Caelestis Concilium (CC)**.

## Fonctionnalités

- Auto Promote de joueurs configurés manuellement.
- Auto Promote selon les rangs de guilde sélectionnés.
- AutoLog configurable pour LFR, Normal, Héroïque, Mythique, Donjon Mythique et Mythique+.
- Fenêtre Ready Check automatique lors d'un appel.
- Statut dynamique OK / KO / WAIT.
- Vérification des consommables : repas, flacon, rune et rune de Vantus.
- Affichage des buffs de raid Mage (Intel), Guerrier (PA), Druide, Prêtre (Endu) et Chaman.
- Compteur dynamique des joueurs prêts dans l'en-tête du Ready Check (ex. 3/20).
- Marks Bar avec marques de raid et marqueurs au sol.
- Barre configurable en horizontal ou vertical, avec position sauvegardée et affichage au mouseover.
- Focus configurable avec modificateur et bouton de souris.
- Invite Tool avec invitation sur mot-clé reçu en chuchotement.
- Interface personnalisée sombre/transparente avec bordures pixel et branding Caelestis Concilium.
- Configuration persistante après `/reload`.

## Commande

- `/ccrt` : ouvre la configuration de CC RaidTools.

## Version

**1.1.1**

### v1.1.1 — Fixes & Performance

- Correction de l'affichage et du défilement du Ready Check pour les gros raids.
- Optimisation du rafraîchissement des auras du Ready Check avec throttling.
- Sécurisation supplémentaire de l'accès aux champs d'auras potentiellement protégés.
- Correction du mode Test du Ready Check pour utiliser le cycle normal.
- Correction du défilement de la liste Auto Promote.
- Mise à jour de l'affichage de version du Ready Check.
- Restauration des identifiants Vantus manquants et suppression du doublon.
- Centralisation du mapping des marqueurs au sol.
- Corrections générales de stabilité.
