# Changelog

## 1.1.4

Correctifs de fiabilité et de sécurité.

- AutoLog couvre tous les donjons Mythique et Mythique+ sans filtrage arbitraire par carte.
- Focus n'altère plus les frames sécurisées créées par d'autres addons.
- Synchronisation de la version affichée dans le Ready Check.
- Watermark de guilde rendu plus discret.

## 1.1.2

Release packaging et nettoyage du processus de publication.

- Synchronisation de toutes les chaînes de version sur 1.1.2.
- Génération automatique du ZIP de release via GitHub Actions.
- Le ZIP distribué contient uniquement les fichiers nécessaires à l'addon.
- Les fichiers de développement et de documentation ne sont pas inclus dans l'archive WoWUp.
- Nettoyage général du processus de publication.

## 1.1.1

Correctifs, performances et nettoyage général.

- Correction du défilement du Ready Check pour les raids importants.
- Optimisation du rafraîchissement des auras du Ready Check avec cache par joueur.
- Correction du mode Test du Ready Check.
- Correction du défilement de la liste Auto Promote.
- Sécurisation des accès aux champs d'aura potentiellement secrets.
- Correction du mapping des World Markers et des tooltips `/wm`.
- Correction du matching des rangs Auto Promote pour les joueurs inter-royaumes et homonymes.
- Conservation des vérifications de combat pour les actions protégées.
- Nettoyage des fonctions globales inutilisées et sécurisation du module Focus.

## 1.1.0

Clean-up, stabilité et sécurisation de l'addon.

- Nettoyage général de l'architecture et des commandes.
- Sécurisation des actions protégées et des changements pendant le combat.
- Ready Check corrigé et optimisé.
- AutoLog fiabilisé, notamment après `/reload`.
- Marks Bar mieux protégée vis-à-vis du combat.
- SavedVariables initialisées de manière défensive.
- Interface et branding nettoyés.
- Documentation et règles de développement mises à jour.

## 1.0

Première version de référence de **CC RaidTools**.

- Auto Promote par joueur et par rang de guilde.
- Persistance des rangs sélectionnés.
- AutoLog par difficulté de raid.
- Ready Check automatique avec fermeture différée de 30 secondes.
- Statuts OK / KO / WAIT.
- Détection repas, flacon, rune et Vantus.
- Buffs de raid avec icônes grisées/colorées.
- Compteur dynamique prêts/total dans le Ready Check.
- Skin CC RaidTools sombre, transparent et pixel-perfect.
