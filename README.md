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

**1.1.5**

### v1.1.5 — Interface & branding

- Nouvelles icônes HD personnalisées pour les six modules.
- Menu des modules modernisé avec icônes, sélection et survol plus lisibles.
- Icône du module affichée en haut à droite de chaque panneau.
- Watermark Caelestis Concilium repositionné pour éviter les chevauchements avec les icônes de module.
- Correction du spam de messages AutoLog lors des rafraîchissements/reloads.
- Version Ready Check synchronisée sur 1.1.5.

### v1.1.4 — Fiabilité & sécurité

- AutoLog couvre tous les donjons Mythique et Mythique+.
- Focus n'altère plus les frames sécurisées externes.
- Synchronisation des versions affichées.
- Watermark de guilde plus discret.

### v1.1.2 — Release packaging & clean-up

- Synchronisation de toutes les chaînes de version sur 1.1.2.
- Génération automatique de l'archive de release via GitHub Actions.
- L'archive distribuée contient uniquement les fichiers nécessaires à l'addon.
- Les fichiers de développement et de documentation (`AGENTS.md`, `README.md`, `CHANGELOG.md`, `.github/`, etc.) ne sont pas inclus dans le ZIP WoWUp.
- Nettoyage général du processus de publication.

### v1.1.1 — Fixes & Performance

- Correction du défilement du Ready Check pour les raids jusqu'à 40 joueurs.
- Optimisation du scan des auras avec un cache par joueur et des mises à jour via `UNIT_AURA`.
- Sécurisation supplémentaire de l'accès aux champs d'auras potentiellement protégés.
- Correction du mode Test du Ready Check pour utiliser le cycle normal.
- Correction du défilement de la liste Auto Promote.
- Restauration des identifiants Vantus manquants.
- Correction du mapping des World Markers et des tooltips `/wm`.
- Améliorations générales de stabilité.

### v1.1.0 — Clean-up & stabilité

- Nettoyage général de l'architecture et des commandes.
- Sécurisation des éléments protégés et des actions en combat.
- Ready Check corrigé et optimisé.
- AutoLog fiabilisé, y compris après `/reload`.
- Marks Bar mieux protégée contre les modifications pendant le combat.
- SavedVariables initialisées de manière défensive.
- Interface et branding nettoyés.
- Documentation et règles de développement mises à jour.
