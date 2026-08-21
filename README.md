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
- Barre de fermeture avec compte à rebours et texture personnalisée Atrocity.
- Fermeture automatique rapide lorsque tout le monde est prêt.
- Marks Bar avec marques de raid et marqueurs au sol.
- Barre configurable en horizontal ou vertical, avec position sauvegardée et affichage au mouseover.
- Focus configurable avec modificateur et bouton de souris.
- Invite Tool avec invitation sur mot-clé reçu en chuchotement.
- Interface personnalisée sombre/transparente avec bordures pixel et branding Caelestis Concilium.
- Configuration persistante après `/reload`.

## Commande

- `/ccrt` : ouvre la configuration de CC RaidTools.

## Version

**1.1.9**

### v1.1.9 — Ready Check Groupe & Buffs dynamiques

- Ajout du mode **groupe 5 joueurs** au Ready Check, en complément du mode raid.
- Suppression du check **Vantus** en groupe.
- Affichage dynamique des buffs selon les classes présentes dans le groupe.
- Ajout du buff **Évocateur / Bronze** dans les modes groupe et raid.
- Largeur de la fenêtre adaptée automatiquement au contenu du groupe.
- Repositionnement des icônes et colonnes pour conserver l'alignement du mode raid.
- Conservation du timer de fermeture avec `atrocity.tga`.
- Conservation de la fermeture automatique lorsque tout le monde est prêt.

### v1.1.8 — AutoLog Donjons & Ready Check

- Fusion des options Donjons Mythique et Mythique+ en une seule option Donjons (M0 / M+).
- Correction du démarrage de l'AutoLog en Mythique+ avec `CHALLENGE_MODE_START` et délai d'une seconde.
- Alignement de la logique de démarrage des donjons sur le comportement validé avec Method Raid Tools.
- Fenêtre Ready Check redimensionnée automatiquement selon le nombre de joueurs.
- Suppression de l'ascenseur visible du Ready Check.
- Barre de fermeture utilisant `atrocity.tga`.
- Timer de fermeture démarré dès l'ouverture du Ready Check.
- Fermeture automatique environ 2 secondes après que tout le monde est prêt.
- Fusion des améliorations Ready Check dans `ReadyCheck.lua`.
- Version affichée dans la fenêtre Ready Check synchronisée avec la release.

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
