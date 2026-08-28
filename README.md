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
- Marks Bar avec marques de raid et marqueurs au sol.
- Barre configurable en horizontal ou vertical, avec position sauvegardée et affichage au mouseover.
- Focus configurable avec modificateur et bouton de souris, avec possibilité d'activer ou désactiver la fonction.
- Support du Focus sur les unit frames sécurisées, notamment Target et Boss Frames.
- Invite Tool avec invitation sur mot-clé reçu en chuchotement.
- Utilisation de la mécanique native Blizzard **Suggest Invite** lorsqu'un membre non-leader reçoit une demande d'invitation.
- **Raid Inspect** : inspection du groupe/raid avec ilvl moyen, enchants manquants et gemmes non serties.
- Interface personnalisée sombre/transparente avec bordures pixel et branding Caelestis Concilium.
- Configuration persistante après `/reload`.

## Commande

- `/ccrt` : ouvre la configuration de CC RaidTools.

## Version

1.2.2

## v1.2.2

### Raid Inspect

- Correction de la détection des gemmes manquantes.
- Comptage fiable des sockets vides à partir des données structurées Blizzard (`GemSocket` / `GemSocketEnchantment`).
- Réduction des faux positifs liés aux données de tooltip.
- Conservation de la détection des enchantements via l'item link, avec fallback structuré/textuel.

### Focus

- Correction du Focus avec Shift + clic sur les unit frames sécurisées, notamment la Target et les Boss Frames.
- Support des boutons configurés sur les unit frames sans casser leurs actions sécurisées existantes.
- Restauration des attributs d'origine lors de la désactivation ou du changement de configuration.

### Invite Tool

- Lorsqu'un joueur envoie le mot-clé d'invitation à un membre qui n'est pas leader, la demande utilise désormais la mécanique native Blizzard **Suggest Invite**.
- Le comportement est identique à l'action **Suggérer une invitation** du menu contextuel de WoW.
- Suppression du système de popup/communication maison pour ce cas.
