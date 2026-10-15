-- Interface aventurier des coffres, sans l'addon MJ.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
__groupe({ LCM.PlayerId(), "Syn-Apertus" })
__position(50, 60, 0)

local REF = "objets/coffre_joueur_temoin"
LCM.Objets.Add({ id = "coffre_joueur_temoin", label = "Potion du coffre", categorie = "accessoire",
    icone = "inv_potion_01", etat = { courant = 1, max = 1 }, pileMax = 10 })
local C = LCM.Coffres
local definition = { id = "coffre_externe", label = "Coffre partagé", auteur = "Syn-Apertus",
    coffre = { places = 3, verrous = 0, reset = false,
        objets = { { entree = REF, quantite = 2 } }, expertises = {}, outils = {} } }
local point = { id = "coffre_externe_1", x = 50, y = 60, source = "monde", carte = LCM.Recolte.Carte() }
local paquet = C.Paquet(definition, { point })
paquet = LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet))
LCM.Objets.Retirer("coffre_joueur_temoin")
local def, points = C.Lire(paquet)
C.Connaitre(def, points, "Syn-Apertus")

attendu("définition de coffre reçue sans MJ", C.definitions.coffre_externe.label, "Coffre partagé")
attendu("objet importé sans compendium local préalable",
    LCM.Compendium.Resoudre(REF) and LCM.Compendium.Resoudre(REF).label, "Potion du coffre")
attendu("point sur la carte reconnu", C.Proche() and C.Proche().id, point.id)

C.Ouvrir(point.id)
attendu("fenêtre de consultation ouverte", LCM.UI.Coffre.frame and LCM.UI.Coffre.frame:IsShown(), true)
local envoi
for i = #__envois, 1, -1 do
    if __envois[i].message:find("cof!", 1, true) then envoi = __envois[i]; break end
end
attendu("demande transmise au MJ propriétaire", envoi and envoi.cible, "Syn-Apertus")
attendu("addon MJ absent", LCM.CoffresMJ == nil, true)

if ko > 0 then error(tostring(ko) .. " vérification(s) en échec") end
dire("TOUT PASSE")
