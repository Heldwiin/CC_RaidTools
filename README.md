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
- Fermeture automatique rapide lorsque tout le monde est prêt.
- Marks Bar avec marques de raid et marqueurs au sol.
- Barre configurable en horizontal ou vertical, avec position sauvegardée et affichage au mouseover.
- Focus configurable avec modificateur et bouton de souris, avec possibilité d'activer ou désactiver la fonction.
- Invite Tool avec invitation sur mot-clé reçu en chuchotement.
- Interface personnalisée sombre/transparente avec bordures pixel et branding Caelestis Concilium.
- Configuration persistante après `/reload`.

## Commande

- `/ccrt` : ouvre la configuration de CC RaidTools.

## Version

**1.1.14**

### v1.1.14 — Focus activable/désactivable

- Ajout d'une option **Activer le Focus** dans le module Focus.
- Le Focus est activé par défaut afin de conserver le comportement existant.
- Désactivation du Focus : suppression du binding sécurisé associé.
- Réactivation du Focus : restauration automatique du binding choisi.
- Conservation du choix de modificateur et de bouton souris.
- Case d'activation harmonisée visuellement avec les autres cases à cocher de CC RaidTools.

### v1.1.13 — Release Ready Check stabilisée

- Versionnement synchronisé pour la release 1.1.13.
- Consolidation de la version Ready Check validée en groupe et en raid.
- Timer basé sur la durée réelle fournie par Blizzard au lancement du Ready Check.
- Barre de compte à rebours fluide.
- Fermeture fiable environ 2 secondes après la fin du Ready Check lorsque tout le monde est prêt.
- Conservation du mode groupe dynamique et du buff Évocateur / Bronze.

### v1.1.11 — Ready Check : timer réel et fermeture fiable

- Correction de la fermeture automatique du Ready Check en groupe et en raid via la fin réelle du Ready Check Blizzard.
- Fermeture environ 2 secondes après que tout le monde est prêt.
- Utilisation de la durée réelle fournie au lancement du Ready Check au lieu d'une durée fixe de 30 secondes.
- Barre de compte à rebours rendue plus fluide.
- Conservation du mode groupe dynamique, du mode raid et du buff Évocateur / Bronze.

### v1.1.10 — Ready Check : largeur dynamique

- Optimisation du redimensionnement horizontal du Ready Check en groupe.
- Largeur calculée selon les buffs réellement disponibles dans le groupe.
- Mise à jour immédiate de la largeur lors des changements de composition.
- Réduction de la largeur fixe du mode raid à 640 px.
- Conservation du mode groupe sans Vantus et des buffs dynamiques par classe.
- Conservation du timer `atrocity.tga` et de la fermeture automatique.

### v1.1.9 — Ready Check Groupe & Buffs dynamiques

- Ajout du mode **groupe 5 joueurs** au Ready Check, en complément du mode raid.
- Suppression du check **Vantus** en groupe.
- Affichage dynamique des buffs selon les classes présentes dans le groupe.
- Ajout du buff **Évocateur / Bronze** dans les modes groupe et raid.
- Largeur de la fenêtre adaptée automatiquement au contenu du groupe.
- Repositionnement des icônes et colonnes pour conserver l'alignement du mode raid.
- Conservation du timer de fermeture avec `atrocity.tga`.
- Conservation de la fermeture automatique lorsque tout le monde est prêt.
