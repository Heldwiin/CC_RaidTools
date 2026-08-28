-- CC RaidTools - Localization
-- Fallback language is French (frFR). English (enUS/enGB) overrides are applied
-- automatically based on the client's game locale (GetLocale()).
local ADDON_NAME, CCRT = ...
CCRT = CCRT or {}
_G.CCRT = CCRT

local L = {}
CCRT.L = L

-- ===== French (default / fallback) =====
local frFR = {
    -- Tabs / module names
    tabAutoPromote = "Auto Promote",
    tabAutoLog = "AutoLog",
    tabReadyCheck = "Ready Check",
    tabInviteTool = "Invite Tool",
    tabFocus = "Focus",
    tabMarksBar = "Marks Bar",

    -- Chat prefix / generic
    addonLoaded = "|cff33ff99[CC RaidTools]|r v%s chargé",
    chatPrefix = "|cff33ff99[CC RaidTools]|r ",

    -- AutoPromote
    apPromotedSuffix = " promu(e) assistant de raid.",
    apAddPlayersLabel = "Ajouter des joueurs (un par ligne, format Nom-Royaume) :",
    apAddButton = "Ajouter",
    apPlayersListLabel = "Joueurs Auto Promote :",
    apNoGuildLabel = "Pas de guilde, ou liste des rangs en cours de chargement...",
    apGuildRankLabel = "Rang à Auto Promote :",

    -- AutoLog
    autoLogLabel = "AutoLog :",
    autoLogDungeons = "Donjons (M0 / M+)",
    autoLogHeroic = "Héroïque",
    autoLogLFR = "LFR",
    autoLogMythic = "Mythique",
    autoLogNormal = "Normal",
    autoLogStopped = "Enregistrement des combats arrêté.",
    autoLogStarted = "Enregistrement des combats démarré.",

    -- ReadyCheck
    rcColBronze = "Bronze",
    rcColDruid = "Druid",
    rcColStam = "Endu",
    rcColIntel = "Intel",
    rcColAP = "PA",
    rcColReady = "Prêt",
    rcColFood = "Repas",
    rcColFlask = "Flacon",
    rcColRune = "Rune",
    rcColSham = "Sham",
    rcColVantus = "Vantus",
    rcCheckBuffsLabel = "Check Buffs /appel",
    rcClosingIn = "Fermeture dans %ds",
    rcClosingIn30 = "Fermeture dans 30s",
    rcWindowTitle = "CC RaidTools - Ready Check",
    rcLabel = "Ready Check :",
    rcFinished = "Ready check terminé",
    rcTestButton = "Test",
    rcEveryoneReady = "Tout le monde est prêt !",
    rcNeedGroup = "Le Ready Check nécessite d'être dans un groupe ou un raid.",

    -- InviteTool
    itCombatBlocked = "Invitation impossible pendant le combat.",
    itLabel = "Invite Tool :",
    itKeywordsLabel = "Mots-clés :",
    itLeaderWhisper = "|cff33ff99[CC RaidTools]|r %s demande une invitation.",
    itInviteRequest = "CC RaidTools : %s demande une invitation.",
    itInviteButton = "Inviter",
    itInviteIgnore = "Ignorer",

    -- Focus
    focusEnable = "Activer le Focus",
    focusMouseClick = "Clic souris",
    focusLabel = "Focus :",
    focusKey = "Touche",
    mouseLeft = "Gauche",
    mouseRight = "Droit",
    mouseMiddle = "Milieu",
    mouse4 = "Souris 4",
    mouse5 = "Souris 5",

    -- MarksBar
    mbHelpRaidMarks = "Clic gauche : poser   |   Clic droit : retirer",
    mbHelpWorldMarks = "Clic gauche : placer   |   Clic droit : retirer",
    mbEnableBar = "Activer la barre",
    mbMouseoverOnly = "Afficher uniquement au mouseover",
    mbWorldCommand = "Commande monde : /wm ",
    mbTooltip = "Ligne 1 : marques de raid.\nLigne 2 : marqueurs au sol.\nClic droit : retirer.\nLa barre est déplaçable tant qu'elle n'est pas verrouillée.",
    mbLabel = "Marks Bar :",
    mbRaidMark = "Marque de raid ",
    mbWorldMarker = "Marqueur au sol ",
    mbOrientation = "Orientation",
    mbRecenter = "Recentrer la barre",
    mbLock = "Verrouiller la position",
    mbHorizontal = "Horizontal",
    mbVertical = "Vertical",

    -- ModuleIcons
    miTestButton = "Tester",

    -- RaidInspect
    riTabName = "Raid Inspect",
    riWindowTitle = "CC RaidTools - Raid Inspect",
    riLabel = "Raid Inspect :",
    riInspectButton = "Inspecter le raid",
    riInspectingButton = "Inspection...",
    riColName = "Nom",
    riColIlvl = "Ilvl",
    riColEnchants = "Enchants",
    riColGems = "Gemmes",
    riColSpec = "Spé",
    riStatusWaiting = "...",
    riStatusOutOfRange = "N/A",
    riStatusTimeout = "Timeout",
    riStatusOK = "OK",
    riMissingCount = "%d manquant(s)",
    riNeedGroup = "Le Raid Inspect nécessite d'être dans un groupe ou un raid.",
    riDone = "Inspection terminée : %d/%d joueurs inspectés.",
    riSlotHead = "Casque",
    riSlotShoulder = "Épaulières",
    riSlotChest = "Torse",
    riSlotFeet = "Pieds",
    riSlotFinger1 = "Anneau 1",
    riSlotFinger2 = "Anneau 2",
    riSlotMainHand = "Arme principale",
    riSlotOffHand = "Arme secondaire",
    riSlotNeck = "Cou",
    riSlotWaist = "Ceinture",
    riSlotWrist = "Poignets",
    riSlotHands = "Mains",
    riSlotLegs = "Jambes",
    riSlotBack = "Dos",
    riSlotTrinket1 = "Babiole 1",
    riSlotTrinket2 = "Babiole 2",
    riMissingEnchantTooltip = "Enchant manquant sur :",
    riMissingGemTooltip = "Socket(s) vide(s) sur :",
}

-- ===== English overrides =====
local enUS = {
    tabAutoPromote = "Auto Promote",
    tabAutoLog = "AutoLog",
    tabReadyCheck = "Ready Check",
    tabInviteTool = "Invite Tool",
    tabFocus = "Focus",
    tabMarksBar = "Marks Bar",

    addonLoaded = "|cff33ff99[CC RaidTools]|r v%s loaded",
    chatPrefix = "|cff33ff99[CC RaidTools]|r ",

    apPromotedSuffix = " promoted to raid assistant.",
    apAddPlayersLabel = "Add players (one per line, Name-Realm format):",
    apAddButton = "Add",
    apPlayersListLabel = "Auto Promote players:",
    apNoGuildLabel = "No guild, or rank list still loading...",
    apGuildRankLabel = "Rank to Auto Promote:",

    autoLogLabel = "AutoLog:",
    autoLogDungeons = "Dungeons (M0 / M+)",
    autoLogHeroic = "Heroic",
    autoLogLFR = "LFR",
    autoLogMythic = "Mythic",
    autoLogNormal = "Normal",
    autoLogStopped = "Combat logging stopped.",
    autoLogStarted = "Combat logging started.",

    rcColBronze = "Bronze",
    rcColDruid = "Druid",
    rcColStam = "Stam",
    rcColIntel = "Intel",
    rcColAP = "AP",
    rcColReady = "Ready",
    rcColFood = "Food",
    rcColFlask = "Flask",
    rcColRune = "Rune",
    rcColSham = "Sham",
    rcColVantus = "Vantus",
    rcCheckBuffsLabel = "Check Buffs /roll call",
    rcClosingIn = "Closing in %ds",
    rcClosingIn30 = "Closing in 30s",
    rcWindowTitle = "CC RaidTools - Ready Check",
    rcLabel = "Ready Check:",
    rcFinished = "Ready check finished",
    rcTestButton = "Test",
    rcEveryoneReady = "Everyone is ready!",
    rcNeedGroup = "Ready Check requires being in a party or raid.",

    itCombatBlocked = "Cannot invite while in combat.",
    itLabel = "Invite Tool:",
    itKeywordsLabel = "Keywords:",
    itLeaderWhisper = "|cff33ff99[CC RaidTools]|r %s is requesting an invite.",
    itInviteRequest = "CC RaidTools: %s is requesting an invite.",
    itInviteButton = "Invite",
    itInviteIgnore = "Ignore",

    focusEnable = "Enable Focus",
    focusMouseClick = "Mouse click",
    focusLabel = "Focus:",
    focusKey = "Key",
    mouseLeft = "Left",
    mouseRight = "Right",
    mouseMiddle = "Middle",
    mouse4 = "Mouse 4",
    mouse5 = "Mouse 5",

    mbHelpRaidMarks = "Left click: place   |   Right click: remove",
    mbEnableBar = "Enable bar",
    mbMouseoverOnly = "Show on mouseover only",
    mbHelpWorldMarks = "Left click: place   |   Right click: remove",
    mbWorldCommand = "World command: /wm ",
    mbTooltip = "Row 1: raid marks.\nRow 2: world markers.\nRight click: remove.\nThe bar can be moved while unlocked.",
    mbLabel = "Marks Bar:",
    mbRaidMark = "Raid mark ",
    mbWorldMarker = "World marker ",
    mbOrientation = "Orientation",
    mbRecenter = "Recenter bar",
    mbLock = "Lock position",
    mbHorizontal = "Horizontal",
    mbVertical = "Vertical",

    miTestButton = "Test",

    riTabName = "Raid Inspect",
    riWindowTitle = "CC RaidTools - Raid Inspect",
    riLabel = "Raid Inspect:",
    riInspectButton = "Inspect raid",
    riInspectingButton = "Inspecting...",
    riColName = "Name",
    riColIlvl = "Ilvl",
    riColEnchants = "Enchants",
    riColGems = "Gems",
    riColSpec = "Spec",
    riStatusWaiting = "...",
    riStatusOutOfRange = "N/A",
    riStatusTimeout = "Timeout",
    riStatusOK = "OK",
    riMissingCount = "%d missing",
    riNeedGroup = "Raid Inspect requires being in a party or raid.",
    riDone = "Inspection finished: %d/%d players inspected.",
    riSlotHead = "Head",
    riSlotShoulder = "Shoulders",
    riSlotChest = "Chest",
    riSlotFeet = "Feet",
    riSlotFinger1 = "Ring 1",
    riSlotFinger2 = "Ring 2",
    riSlotMainHand = "Main Hand",
    riSlotOffHand = "Off Hand",
    riSlotNeck = "Neck",
    riSlotWaist = "Waist",
    riSlotWrist = "Wrist",
    riSlotHands = "Hands",
    riSlotLegs = "Legs",
    riSlotBack = "Back",
    riSlotTrinket1 = "Trinket 1",
    riSlotTrinket2 = "Trinket 2",
    riMissingEnchantTooltip = "Missing enchant on:",
    riMissingGemTooltip = "Empty socket(s) on:",
}

for k, v in pairs(frFR) do
    L[k] = v
end

local locale = GetLocale()
if locale == "enUS" or locale == "enGB" then
    for k, v in pairs(enUS) do
        L[k] = v
    end
end
