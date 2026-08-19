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

**1.1.7**

### v1.1.7 — Correctif AutoLog Mythique+

- Correction du démarrage de l'enregistrement des combats en Mythique+.
- Détection du lancement de clé via `CHALLENGE_MODE_START` avec délai de 1 seconde, suivant le comportement validé de Method Raid Tools.
- Suppression des interrogations répétées de `LoggingCombat()` qui pouvaient perturber le démarrage du log.
- Conservation de la propriété du logging pour que CC RaidTools n'arrête jamais un combat log lancé manuellement.

### v1.1.6 — Ready Check & stabilité

- Restauration complète du cycle Ready Check après le nettoyage de la version précédente.
- Restauration du bouton Test et des événements READY_CHECK, READY_CHECK_CONFIRM et READY_CHECK_FINISHED.
- Conservation du cache d'auras, du throttling UNIT_AURA et du défilement jusqu'à 40 joueurs.
- Synchronisation de toutes les chaînes de version sur 1.1.6.