-- Identite : qui est le joueur, vu des autres.
--
-- Reprise de Necronicon (GetTRP3IconPath, GetPlayerDisplayProfile) : si Total
-- RP 3 est la, le nom RP (prenom + nom) et l'icone de son profil l'emportent ;
-- sinon, le nom du personnage WoW. C'est cette identite que Necronicon mettait
-- sur le bouton du menu, dans l'initiative, la presence et les messages de
-- combat (attackerRp, resolu cote emetteur : le recepteur l'affiche tel quel).
--
-- TRP3 est lu, jamais ecrit, et toujours sous pcall : son API peut manquer ou
-- changer, l'addon ne doit pas tomber avec.

local _, LCM = ...

local Identite = {}
LCM.Identite = Identite

local function Nettoyer(valeur)
    return (tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Les caracteristiques du profil TRP3 du joueur, ou nil.
function Identite.ProfilTRP()
    local api = TRP3_API
    if not (type(api) == "table" and type(api.profile) == "table" and type(api.profile.getData) == "function") then
        return nil
    end
    local ok, data = pcall(api.profile.getData, "player")
    if not (ok and type(data) == "table" and type(data.characteristics) == "table") then return nil end
    return data.characteristics
end

-- Le nom RP TRP3 (« Prenom Nom »), ou nil.
function Identite.NomTRP()
    local c = Identite.ProfilTRP()
    if not c then return nil end
    local prenom, nom = Nettoyer(c.FN), Nettoyer(c.LN)
    local complet = Nettoyer(prenom .. (nom ~= "" and (" " .. nom) or ""))
    return complet ~= "" and complet or nil
end

-- L'icone du profil TRP3 (chemin complet), ou nil.
function Identite.IconeTRP()
    local c = Identite.ProfilTRP()
    local icone = c and Nettoyer(c.IC) or ""
    if icone == "" then return nil end
    return "Interface\\Icons\\" .. icone
end

-- { joueur, nom, icone } : l'identite a afficher ou a envoyer. L'icone vaut
-- nil sans TRP3 — a l'appelant de choisir son repli.
function Identite.Joueur()
    return {
        joueur = LCM.PlayerId(),
        nom = Identite.NomTRP() or tostring((UnitName and UnitName("player")) or "Inconnu"),
        icone = Identite.IconeTRP(),
    }
end

-- TRP3 peut se charger apres nous : on previent qui affiche l'identite.
Identite.abonnes = {}
function Identite.AuChangement(fonction)
    Identite.abonnes[#Identite.abonnes + 1] = fonction
end

local function Prevenir()
    for _, fonction in ipairs(Identite.abonnes) do pcall(fonction) end
end

LCM.On("ADDON_LOADED", function(nom)
    if nom == "totalRP3" or nom == "TotalRP3" or nom == "TRP3" then Prevenir() end
end)
