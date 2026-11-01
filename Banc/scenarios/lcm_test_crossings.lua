-- Crossings : l'outil des lieux, repris d'Omega Hub (31 octobre 2026).
--
-- Il remplace l'ancien outil Lieux de LCM. Ce qu'on verifie ici, c'est ce
-- que l'adaptation a pu casser, pas le module lui-meme (il a ses tests chez
-- Omega) :
--   * AUCUN nom d'Omega ne fuit : Omega_Hub peut etre charge a cote, et deux
--     modules sur la meme table, la meme sauvegarde ou le meme prefixe
--     s'ecraseraient ;
--   * un franchissement se detecte et affiche sa banniere, dans les deux sens ;
--   * sur une carte d'instance (UnitPosition muet), la position vient de la
--     source serveur de LCM, dans le MEME repere ;
--   * une commande serveur passe par le chemin de `.gps` ;
--   * les fenetres sont des fenetres LCM, ouvertes par la branche Lieux du
--     radial ; la touche de la carte ouvre la carte des regions.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- La touche de la carte du jeu, comme chez un joueur ordinaire : Crossings
-- la surcharge a la connexion.
__raccourcis.M = "TOGGLEWORLDMAP"
__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local ZG = LCM.Crossings

dire("== aucun nom d'Omega ne fuit")
attendu("le moteur est la", ZG ~= nil, true)
attendu("sous son nom LCM", _G.LCMCrossings == ZG, true)
attendu("pas de table ZoneGate", _G.ZoneGate, nil)
attendu("pas de sauvegarde ZoneGateDB", _G.ZoneGateDB, nil)
attendu("pas de sauvegarde ZoneGateCharDB", _G.ZoneGateCharDB, nil)
attendu("la sauvegarde est la notre", type(_G.LCM_Crossings), "table")
attendu("pas de commande /crossings", SlashCmdList.OZONEGATE, nil)
attendu("le prefixe est le notre", C_ChatInfo.IsAddonMessagePrefixRegistered("LCMCrossings"), true)
attendu("pas celui d'Omega", C_ChatInfo.IsAddonMessagePrefixRegistered("OmegaZoneGate"), false)
local canal = false
for _, nom in ipairs(__canaux) do if nom == "LCMCrossings" then canal = true end end
attendu("le canal global est le notre", canal, true)
attendu("l'ancien outil Lieux est parti", LCM.Lieux, nil)
attendu("et ses bannieres", LCM.Bannieres, nil)

dire("== un passage droit, franchi dans les deux sens")
-- Les bannieres, interceptees : c'est l'effet visible d'un franchissement.
local vues = {}
local montrer = ZG.ShowBanner
function ZG:ShowBanner(titre, sous, theme)
    vues[#vues + 1] = { titre = titre, sous = sous }
    return montrer(self, titre, sous, theme)
end
local function derniere() return vues[#vues] or {} end
local function battre() __avancer(0.3) end

__position(0, 0, 0)
__cap(0)
local region = ZG:CreateZone("Les Marches Grises")
attendu("la region existe", region ~= nil, true)
local village = ZG:CreatePlace(region.id, "Le village")
local foret = ZG:CreatePlace(region.id, "La foret")
local porte = ZG:CreateSubZone(region.id, "Porte du village", village.id)
attendu("le passage est pose", porte ~= nil, true)
ZG:SetPassagePlace(porte.id, "leave", foret.id)

-- Quel cote est « devant » ? On le demande au passage plutot que de deviner
-- la convention du cap : c'est elle qui decide, pas le test.
local devant, derriere
for _, essai in ipairs({ { 0, 4 }, { 4, 0 }, { 0, -4 }, { -4, 0 } }) do
    __position(essai[1], essai[2], 0)
    local dans, sens = ZG:GetCheckpointStatus(porte)
    if dans and sens == "forward" and not devant then devant = essai end
    if dans and sens == "backward" and not derriere then derriere = essai end
end
attendu("le passage a un devant", devant ~= nil, true)
attendu("et un derriere", derriere ~= nil, true)

__position(derriere[1], derriere[2], 0)
battre()
local avant = #vues
__position(devant[1], devant[2], 0)
battre()
attendu("en entrant : une banniere", #vues, avant + 1)
attendu("celle du lieu d'entree", derniere().sous, "Le village")
attendu("sous le nom de la region", derniere().titre, "Les Marches Grises")
attendu("on est au village", ZG:IsInPlace(village.id), true)

__position(derriere[1], derriere[2], 0)
battre()
attendu("en ressortant : la foret", derniere().sous, "La foret")
attendu("on a quitte le village", ZG:IsInPlace(village.id), false)

dire("== sur une carte d'instance, la position serveur de LCM")
__position(12, 34, 5)
local x1, y1 = ZG:GetPlayerPose()
-- UnitPosition se tait (carte de campagne) ; Epsilon repond dans le meme
-- repere que lui.
__positionMonde(false)
C_Epsilon = { GetPosition = function() return 12, 34, 5, 585 end }
local x2, y2, _, carte = ZG:GetPlayerPose()
attendu("la position ne manque pas", x2 ~= nil, true)
attendu("meme x que UnitPosition", x2, x1)
attendu("meme y que UnitPosition", y2, y1)
attendu("et la carte serveur sert d'instance", carte, 585)
C_Epsilon = nil
__positionMonde(true)

dire("== une commande serveur passe par le chemin de .gps")
__groupe({ "Nytherah-Apertus" })
local avantChats = #__chats
ZG.ServerCommand("12345", "apply")
attendu("une ligne part", #__chats, avantChats + 1)
attendu("l'ID nu devient .aura", (__chats[#__chats] or {}).texte, ".aura 12345")
ZG.ServerCommand("12345", "remove")
attendu("et .unaura au depart", (__chats[#__chats] or {}).texte, ".unaura 12345")

dire("== la touche de la carte ouvre la carte des regions")
attendu("M est surchargee", GetBindingAction("M"), "CLICK LCMCrossingsMapToggle:LeftButton")
attendu("les raccourcis du joueur ne bougent pas", __raccourcis.M, "TOGGLEWORLDMAP")
LCMCrossingsMapToggle:Click()
attendu("la carte s'ouvre", LCMCrossingsRegionMap:IsShown(), true)
attendu("dans une fenetre LCM", LCMCrossingsRegionMap.fenetre ~= nil, true)
LCMCrossingsRegionMap:Hide()

dire("== les fenetres sont des fenetres LCM")
local panneau = LCMCrossingsPanel
local fenetre = panneau.fenetre
attendu("le panneau vit dans une UI.Fenetre", fenetre ~= nil and fenetre.cle == "crossings_panneau", true)
attendu("avec le cadre A'hell'Raz'kah", fenetre and fenetre.decor ~= nil, true)
attendu("et le titre couronne", fenetre and __sansCouleur(fenetre.titre:GetText()), "CROSSINGS")
attendu("la branche Lieux du radial est liee", LCM.UI.Menu.EstLiee("lieux"), true)
LCM.UI.Menu.Trouver("lieux").onClick()
attendu("elle ouvre le panneau", panneau:IsShown(), true)
attendu("c'est la fenetre LCM qui s'ouvre", fenetre:IsShown(), true)
-- Un bouton de Crossings est un bouton du Kit : il porte l'habillage du
-- modele (UI.AelBoutonNet).
local boutonKit
local function Chercher(cadre)
    for _, enfant in ipairs({ cadre:GetChildren() }) do
        if enfant.aelCadre and enfant.accent then boutonKit = enfant return end
        Chercher(enfant)
        if boutonKit then return end
    end
end
Chercher(panneau)
attendu("ses boutons sont ceux du Kit", boutonKit ~= nil, true)
panneau:Hide()
attendu("et elle se referme", fenetre:IsShown(), false)

LCMCrossingsThemePanel:Toggle()
attendu("l'atelier des bannieres aussi", LCMCrossingsThemePanel.fenetre ~= nil and LCMCrossingsThemePanel.fenetre:IsShown(), true)
LCMCrossingsThemePanel:Hide()

ZG:ToggleKnowledge()
attendu("les Connaissances aussi", LCMCrossingsKnowledge and LCMCrossingsKnowledge.fenetre ~= nil, true)
if LCMCrossingsKnowledge then LCMCrossingsKnowledge:Hide() end

dire("== une promenade dans chaque ecran ne casse rien")
-- Les ecrans ont ete repris tels quels puis habilles : chacun doit s'ouvrir
-- et se rafraichir sans erreur, onglet par onglet. Une erreur arrete le
-- scenario, et c'est ce qu'on veut voir.
local function essai(libelle, fn)
    local ok, err = pcall(fn)
    attendu(libelle, ok and "ok" or tostring(err), "ok")
end
ZG:CreateCountry("Le Royaume")
local perimetre = ZG:CreateSubZone(region.id, "Le bois", foret.id)
ZG:SetSubZoneShape(perimetre.id, "polygon")
for _, p in ipairs({ { 0, 0 }, { 30, 0 }, { 30, 30 }, { 0, 30 } }) do
    __position(p[1], p[2], 0)
    ZG:AddRegionPoint(perimetre.id)
end
ZG:FinishRegion(perimetre.id)
attendu("le perimetre est ferme", perimetre.regionReady, true)

panneau:Toggle()
-- Les onglets de la region, remanies le 1er novembre 2026 : « passages »
-- s'est scinde, la carte est passee en tete, et les zones se reglent
-- desormais dans la fiche de leur lieu — la region n'en a plus l'onglet.
for _, onglet in ipairs({ "carte", "places", "doors", "settings" }) do
    essai("region, onglet " .. onglet, function()
        panneau.mode, panneau.zoneId, panneau.zoneTab = "zone", region.id, onglet
        panneau.passageId = porte.id
        panneau:RefreshAll()
    end)
end
for _, onglet in ipairs({ "zone", "aura", "banner", "effects", "arcanum", "discovery" }) do
    essai("lieu, onglet " .. onglet, function()
        panneau.mode, panneau.placeId, panneau.zoneId, panneau.placeTab = "place", village.id, region.id, onglet
        panneau:RefreshAll()
    end)
end
essai("le trace en direct", function()
    panneau.mode, panneau.zoneId, panneau.zoneTab, panneau.passageId = "zone", region.id, "doors", porte.id
    panneau:EnterTrace(porte.id)
    __avancer(0.5)
    panneau:ExitTrace()
end)
essai("les auras d'un passage", function()
    panneau.mode, panneau.zoneId, panneau.zoneTab, panneau.passageId = "zone", region.id, "doors", porte.id
    panneau:OpenPassageAuras()
    LCMCrossingsAuraManager:Hide()
end)
panneau:Hide()

essai("un brouillon de theme, de la galerie a la bibliotheque", function()
    LCMCrossingsThemePanel:Toggle()
    LCMCrossingsThemePanel:BeginDraft(ZG.StudioPresets[1])
    __avancer(0.5)
    LCMCrossingsThemePanel.createThemeButton:Click()
    LCMCrossingsThemePanel:Hide()
end)
attendu("le theme est cree", #ZG:GetThemeList() > 0, true)

-- « Purger les modèles » : Omega ne l'offrait que par /crossings clean, absent
-- de LCM ; le bouton est revenu dans l'atelier (31 octobre 2026). Deux clics :
-- le premier compte et arme, le second supprime les thèmes de la galerie.
local purge = LCMCrossingsThemePanel.studioControls.cleanBtn
LCMCrossingsThemePanel:Toggle()
attendu("le bouton de purge est visible", purge:IsVisible(), true)
local avantPurge = #ZG:GetThemeList()
purge:Click()
attendu("le premier clic ne supprime rien", #ZG:GetThemeList(), avantPurge)
attendu("il demande confirmation", (purge:GetText() or ""):match("^Confirmer") ~= nil, true)
purge:Click()
attendu("le second supprime le modele de galerie", #ZG:GetThemeList(), avantPurge - 1)
LCMCrossingsThemePanel:Hide()

essai("la carte d'une region", function()
    ZG:ShowRegionMap()
    LCMCrossingsRegionMap:Hide()
end)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
