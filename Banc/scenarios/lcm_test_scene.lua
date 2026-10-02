-- Les PNJ en scene : le MJ les met en jeu, les joueurs les ciblent.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end
local function dernier(sujet)
    for i = #__envois, 1, -1 do
        if __envois[i].message:find(":" .. sujet .. "|", 1, true) then return __envois[i] end
    end
end
local function maitre(oui)
    LCM._masterCompanion = oui
    __addonsCharges["LesContesMalveillants_MJ"] = oui
end

__declencher("PLAYER_LOGIN")
local S, I, A = LCM.Scene, LCM.Incarnation, LCM.Actions
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })

dire("== chez le MJ : la scene, ce sont ses PNJ en jeu")
attendu("vide au depart", #S.Liste(), 0)
local garde = I.Instancier(LCM.PNJ.list[1].id, "Garde")
attendu("mettre en jeu l'ajoute", #S.Liste(), 1)
local envoi = dernier("scene")
attendu("et la diffuse au groupe", envoi and envoi.canal, "PARTY")
attendu("avec le PNJ", envoi and envoi.message:find("Garde", 1, true) ~= nil, true)
local _, pnj = A.Cibles()
attendu("le MJ peut le cibler, sans combat", #pnj == 1 and pnj[1].id, garde.id)
attendu("et le resout chez lui", pnj[1].mj, LCM.PlayerId())
I.Oublier(garde.id)
attendu("le retirer le retire", #S.Liste(), 0)
attendu("et rediffuse", dernier("scene").message:find("Garde", 1, true), nil)

dire("== un joueur demande la scene : le MJ lui repond en prive")
garde = I.Instancier(LCM.PNJ.list[1].id, "Garde")
recevoir("Nytherah-Apertus", "scene?", {})
local r = dernier("scene")
attendu("en chuchotant", r and (r.canal .. " " .. r.cible), "WHISPER Nytherah-Apertus")

dire("== chez un joueur : la scene vient du MJ")
maitre(false)
attendu("rien avant", #S.Liste(), 0)
recevoir("Nytherah-Apertus", "scene", { nb = 2, i1 = "pnj:loup", n1 = "Loup", ic1 = "Ability_Hunter_Pet_Wolf",
                                       i2 = "pnj:ours", n2 = "Ours" })
attendu("deux PNJ", #S.Liste(), 2)
_, pnj = A.Cibles()
attendu("ciblables", #pnj, 2)
attendu("ils renvoient a leur MJ", pnj[1].mj, "Nytherah-Apertus")
recevoir("Etranger-Apertus", "scene", { nb = 1, i1 = "pnj:faux", n1 = "Faux" })
attendu("un etranger au groupe ne change rien", #S.Liste(), 2)

dire("== cibler un PNJ de la scene : l'action part au MJ")
local ctx = { entity = LCM.Entities.Self(), vars = {}, journal = {}, nom = "Attaque",
              declaration = { nature = "Attaque", valeurs = { ["Total Normal"] = "5" }, ordre = {} } }
local n = #__envois
-- La declaration envoie aux PNJ choisis (Core/Actions.lua, Envoyer).
A.Etape({ type = "declare", id = "d", nature = "Attaque", declareTags = "Total Normal=5" },
    setmetatable(ctx, nil), function() end)
attendu("le choix des cibles s'ouvre", LCM.UI.Resolution.cibles:IsShown(), true)
local C = LCM.UI.Resolution.cibles
attendu("les PNJ de la scene y sont", C.pnj.nombre, 2)
C.pnj.lignes[1]:Click()
C.declarer:Click()
local act = dernier("act")
attendu("l'action part au MJ", act and act.cible, "Nytherah-Apertus")
attendu("en visant le loup", act and act.message:find("p=pnj:loup", 1, true) ~= nil, true)

dire("== combat et scene : un PNJ n'apparait qu'une fois")
LCM.Combat.etat = { s = "x", mj = "Nytherah-Apertus", c = 1, t = 1, r = 1, rm = 3,
                    entrees = { { id = "pnj:loup", nom = "Loup", v = 3, pnj = true } } }
_, pnj = A.Cibles()
attendu("pas de doublon", #pnj, 2)
LCM.Combat.etat = nil

dire("== la scene arrive pendant qu'on choisit : la liste suit, sans decocher")
A.Etape({ type = "declare", id = "d2", nature = "Attaque", declareTags = "Total Normal=5" },
    { entity = LCM.Entities.Self(), vars = {}, journal = {}, nom = "Attaque" }, function() end)
C.pnj.lignes[2]:Click()
recevoir("Nytherah-Apertus", "scene", { nb = 3, i1 = "pnj:loup", n1 = "Loup", i2 = "pnj:ours", n2 = "Ours",
                                       i3 = "pnj:corbeau", n3 = "Corbeau" })
attendu("le nouveau PNJ apparait", C.pnj.nombre, 3)
attendu("l'ours reste coche", C.pnj.lignes[2]:EstCochee(), true)
C.annuler:Click()

dire("== le MJ quitte le groupe : sa scene s'en va")
__groupe({ "Reika-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")
attendu("plus de PNJ", #S.Liste(), 0)
maitre(true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
