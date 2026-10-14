-- Les marchands poses sur la carte (13 octobre 2026) : la meme procedure
-- reseau que les points de recolte. Le MJ pose un vendeur ; un joueur devant
-- lui ouvre son etal. Le stock est arbitre par le MJ present (reserve EN
-- ATTENTE, puis confirme ou rendu) ; un achat fait en son absence lui est
-- signale apres coup. Revendre ne touche a aucun stock.
--
-- Contenu TEMOIN : ressources, sac, devise et vendeur d'essai.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local HERBE, PAIN = "ressources/herbe_temoin", "ressources/pain_temoin"
LCM.Brouillons.Set("ressources", { id = "herbe_temoin", label = "Herbe témoin" })
LCM.Brouillons.Set("ressources", { id = "pain_temoin", label = "Pain témoin" })
LCM.Brouillons.Set("sacs", { id = "sac_temoin", label = "Sac témoin", places = 12 })
LCM.Brouillons.Set("devises", { id = "piece_temoin", label = "Pièce témoin" })
LCM.Brouillons.Set("points", {
    id = "etal_temoin", label = "Étal témoin", nature = "vendeur", deviseDefaut = "piece_temoin",
    onglets = { { id = "o1", label = "Articles", offres = {
        { id = "herbe", entree = HERBE, quantite = 1, prix = 3, devise = "piece_temoin",
          stock = { limite = 2, unites = 0, minutes = 0 } },
        { id = "pain", entree = PAIN, quantite = 2, prix = 1, devise = "piece_temoin" },
    } } },
    rachats = { { id = "r1", label = "Rachats", offres = {
        { id = "rachat_herbe", entree = HERBE, prix = 2, devise = "piece_temoin" },
    } } },
})

__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
LCM.Inventaire.Poser(moi, "sacs", 1, "sac_temoin", true)
LCM.Bourse.Crediter(moi, "piece_temoin", 20)
local MOI = LCM.PlayerId()
__groupe({ MOI, "Syn-Apertus", "Claydenn-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")

local M, MJ = LCM.Marchands, LCM.MarchandsMJ
local S = M.SUJETS

dire("== un objet vendu voyage avec sa definition")
LCM.Objets.Add({ id = "baton_vendu_test", label = "Bâton vendu", categorie = "arme",
    icone = "inv_staff_01", etat = { courant = 18, max = 18 }, bonus = { force = 2 } })
local paquetObjet = M.Paquet({ id = "etal_objet_test", label = "Marchand d'essai",
    offres = { { id = "baton", entree = "objets/baton_vendu_test", label = "Bâton vendu" } }, rachats = {} }, {})
paquetObjet = LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquetObjet))
LCM.Objets.Retirer("baton_vendu_test")
local marchandLu = M.Lire(paquetObjet)
attendu("l'offre transporte la definition", paquetObjet.o[1].x and paquetObjet.o[1].x.label, "Bâton vendu")
attendu("le joueur importe l'objet du marchand", LCM.Objets.Get("baton_vendu_test").label, "Bâton vendu")
attendu("ses statistiques sont importées", LCM.Objets.Get("baton_vendu_test").bonus.force, 2)
attendu("l'offre reste exploitable", marchandLu.offres[1].entree, "objets/baton_vendu_test")

local function Bourse() return LCM.Bourse.Solde(moi, "piece_temoin") end
local function Combien(ref)
    local n = 0
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for index = 1, LCM.Inventaire.Capacite(categorie.id) do
            local e = LCM.Inventaire.Emplacement(moi, categorie.id, index)
            if e then
                for case = 1, LCM.Inventaire.Cases(e) do
                    local c = LCM.Inventaire.Case(e, case)
                    if c and c.ref == ref then n = n + (tonumber(c.quantite) or 1) end
                end
            end
        end
    end
    return n
end
-- Le dernier envoi d'un sujet, RECOLLE : un vendeur et ses articles partent
-- en plusieurs morceaux, et le premier seul n'en dit qu'une partie.
local function DernierEnvoi(sujet, depuis)
    for i = #__envois, (depuis or 0) + 1, -1 do
        local e = __envois[i]
        local id, rang, total, corps = e.message:match("^(%d+):(%d+):(%d+):(.*)$")
        if corps and rang == "1" and corps:sub(1, #sujet + 1) == sujet .. "|" then
            local morceaux = { corps }
            for j = i + 1, #__envois do
                local id2, rang2, _, suite = __envois[j].message:match("^(%d+):(%d+):(%d+):(.*)$")
                if id2 == id and __envois[j].cible == e.cible then morceaux[tonumber(rang2)] = suite end
            end
            if #morceaux == tonumber(total) then
                local charge = table.concat(morceaux)
                return e, LCM.Reseau.Decoder(charge:sub(#sujet + 2))
            end
        end
    end
end
local function Recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end

dire("== l'entrée « Vendeur » du menu : création et placement")
LCM.UI.Menu.Trouver("vendeur").onClick()
local f = LCM.UI.MarchandsMJ.frame
attendu("la fenêtre s'ouvre", f and f:IsShown(), true)
f:Choisir("etal_temoin")
attendu("les articles sont listés", f.creation.lignes[1] and f.creation.lignes[1]:GetText():find("Herbe témoin", 1, true) ~= nil, true)
attendu("  avec leur stock", f.creation.lignes[1]:GetText():find("stock 2 / 2", 1, true) ~= nil, true)
f.modifier:Click()
local ed = LCM.UI.Points.Editeur("vendeur")
attendu("« Modifier » ouvre le constructeur", ed:IsShown(), true)
ed:Hide()

dire("== poser le marchand")
f:Onglet("placement")
__position(10, 10, 0)
local avant = #__envois
f.placement.poser:Click()
attendu("un emplacement", MJ.Compte("etal_temoin"), 1)
attendu("  listé", f.placement.compte:GetText(), "1 emplacement(s)")
local envoi, paquet = DernierEnvoi(S.definition, avant)
attendu("diffusé au groupe tout de suite", envoi and envoi.canal, "PARTY")
attendu("  avec ses deux articles", paquet and paquet.o and paquet.o[2] ~= nil, true)
attendu("  et son rachat", paquet and paquet.b and paquet.b[1] and paquet.b[1].e, HERBE)
attendu("  jamais au-delà de 255 octets", __plusGrosEnvoi() <= 255, true)

dire("== devant l'étal : « Commercer »")
__position(0, 0, 0)
__avancer(0.3)
local bouton = LCM.UI.Marchand.bouton
attendu("loin, rien", bouton == nil or not bouton:IsShown(), true)
__position(12, 11, 0)
__avancer(0.3)
bouton = LCM.UI.Marchand.bouton
attendu("devant, le bouton", bouton and bouton:IsShown(), true)
attendu("  au nom du marchand", bouton and bouton.nom:GetText(), "Étal témoin")
bouton:Click()
local etal = LCM.UI.Marchand.frame
attendu("l'étal s'ouvre", etal and etal:IsShown(), true)
local l1 = LCM.UI.Marchand.lignes[1]
attendu("l'herbe à 3 pièces", l1.prix:GetText(), "3 Pièce témoin")
attendu("  2 en stock", l1.stock:GetText(), "2 / 2")
attendu("le pain sans stock limité", LCM.UI.Marchand.lignes[2].stock:GetText(), "")

dire("== acheter chez soi (le MJ arbitre)")
l1.action:Click()
attendu("une herbe dans le sac", Combien(HERBE), 1)
attendu("payée", Bourse(), 17)
attendu("le stock baisse", l1.stock:GetText(), "1 / 2")
attendu("rien n'est resté réservé", MJ.EnAttente("etal_temoin", "herbe"), 0)
l1.action:Click()
attendu("épuisé", l1.stock:GetText(), "0 / 2")
attendu("  le bouton se grise", l1.action:IsEnabled(), false)
local ok, raison = M.Acheter("etal_temoin", "herbe")
attendu("plus rien : refusé", raison, "il n'y en a plus.")
attendu("  pas payé", Bourse(), 14)
LCM.UI.Marchand.lignes[2].action:Click()
attendu("le pain s'achète par deux", Combien(PAIN), 2)

dire("== revendre : sans stock, sans réseau")
etal.revendre:Click()
avant = #__envois
LCM.UI.Marchand.lignes[1].action:Click()
attendu("l'herbe quitte le sac", Combien(HERBE), 1)
attendu("le marchand paie", Bourse(), 15)
attendu("rien ne part sur le réseau", #__envois, avant)

dire("== s'éloigner referme l'étal")
__position(100, 100, 0)
__avancer(0.3)
attendu("l'étal se ferme", etal:IsShown(), false)
attendu("le bouton s'efface", bouton:IsShown(), false)

dire("== côté MJ : un joueur achète, le MJ réserve puis attend")
LCM.Stock.Rendre("etal_temoin/herbe", 2)
avant = #__envois
Recevoir("Claydenn-Apertus", S.acheter, { v = "etal_temoin", o = "herbe" })
envoi, paquet = DernierEnvoi(S.reponse, avant)
attendu("accordé au joueur", envoi and envoi.cible, "Claydenn-Apertus")
attendu("  oui", paquet and paquet.ok, "1")
attendu("  et il en reste un", paquet and paquet.r, "1")
attendu("l'unité est en attente", MJ.EnAttente("etal_temoin", "herbe"), 1)
local _, stock = DernierEnvoi(S.stock, avant)
attendu("le groupe apprend le stock", stock and stock.r, "1")
f:Onglet("creation")
attendu("le constructeur montre l'attente", f.creation.lignes[1]:GetText():find("1 en attente", 1, true) ~= nil, true)
Recevoir("Syn-Apertus", S.confirmer, { v = "etal_temoin", o = "herbe" })
attendu("un autre ne confirme pas", MJ.EnAttente("etal_temoin", "herbe"), 1)
Recevoir("Claydenn-Apertus", S.rendre, { v = "etal_temoin", o = "herbe" })
attendu("rendue : plus d'attente", MJ.EnAttente("etal_temoin", "herbe"), 0)
attendu("  et le stock revient", LCM.Stock.Restant("etal_temoin/herbe"), 2)
Recevoir("Claydenn-Apertus", S.acheter, { v = "etal_temoin", o = "herbe" })
Recevoir("Claydenn-Apertus", S.confirmer, { v = "etal_temoin", o = "herbe" })
attendu("confirmée : vendue", LCM.Stock.Restant("etal_temoin/herbe"), 1)
attendu("  plus d'attente", MJ.EnAttente("etal_temoin", "herbe"), 0)

dire("== côté MJ : achats faits sans lui, signalés après")
avant = #__envois
Recevoir("Claydenn-Apertus", S.signaler, { l = "etal_temoin/herbe:5,inconnu/x:1" })
attendu("le stock est entamé, sans descendre sous zéro", LCM.Stock.Restant("etal_temoin/herbe"), 0)
envoi, paquet = DernierEnvoi(S.accuse, avant)
attendu("on accuse réception", envoi and envoi.cible, "Claydenn-Apertus")
attendu("  de tout ce qu'il a cité", paquet and paquet.l, "etal_temoin/herbe:5,inconnu/x:1")

dire("== côté joueur : le marchand d'un autre MJ")
Recevoir("Syn-Apertus", S.definition, M.Paquet({
    id = "etal_syn", label = "Échoppe", offres = {
        { id = "herbe", entree = HERBE, quantite = 1, prix = 1, devise = "piece_temoin", limite = 5, restant = 5 },
    }, rachats = {},
}, { { id = "ms1", x = 300, y = 300, source = "monde", carte = LCM.Recolte.Carte() } }))
attendu("reçu", M.definitions.etal_syn and M.definitions.etal_syn.auteur, "Syn-Apertus")
attendu("  gardé dans la sauvegarde", LCM.db.marche.definitions.etal_syn ~= nil, true)
__position(301, 300, 0)
__avancer(0.3)
attendu("le bouton le nomme", bouton:IsShown() and bouton.nom:GetText(), "Échoppe")
local herbes = Combien(HERBE)
avant = #__envois
ok = M.Acheter("etal_syn", "herbe")
envoi, paquet = DernierEnvoi(S.acheter, avant)
attendu("son MJ est là : on lui demande", envoi and envoi.cible, "Syn-Apertus")
attendu("  rien livré avant sa réponse", Combien(HERBE), herbes)
Recevoir("Syn-Apertus", S.reponse, { v = "etal_syn", o = "herbe", ok = 1, r = 4 })
attendu("livré", Combien(HERBE), herbes + 1)
attendu("  le stock suit le MJ", M.Offre("etal_syn", "herbe").restant, 4)
envoi = DernierEnvoi(S.confirmer, avant)
attendu("  et on confirme", envoi and envoi.cible, "Syn-Apertus")

dire("== côté joueur : son MJ est absent, on achète quand même")
UnitIsConnected = function(unite) return (UnitName(unite)) ~= "Syn" end
local solde = Bourse()
avant = #__envois
ok = M.Acheter("etal_syn", "herbe")
attendu("acheté", ok, true)
attendu("rien ne part vers un MJ absent", DernierEnvoi(S.acheter, avant), nil)
attendu("livré tout de suite", Combien(HERBE), herbes + 2)
attendu("payé", Bourse(), solde - 1)
attendu("l'achat est en attente", M.attente["etal_syn/herbe"] and M.attente["etal_syn/herbe"].n, 1)
attendu("  sauvegardé", LCM.db.marche.attente["etal_syn/herbe"] ~= nil, true)
attendu("le stock vu d'ici en tient compte", M.Disponible("etal_syn", M.Offre("etal_syn", "herbe")), 3)

dire("== son MJ revient : on le lui dit")
UnitIsConnected = nil
avant = #__envois
Recevoir("Syn-Apertus", S.definition, M.Paquet({
    id = "etal_syn", label = "Échoppe", offres = {
        { id = "herbe", entree = HERBE, quantite = 1, prix = 1, devise = "piece_temoin", limite = 5, restant = 4 },
    }, rachats = {},
}, { { id = "ms1", x = 300, y = 300, source = "monde", carte = LCM.Recolte.Carte() } }))
envoi, paquet = DernierEnvoi(S.signaler, avant)
attendu("signalé à son MJ", envoi and envoi.cible, "Syn-Apertus")
attendu("  l'achat et son nombre", paquet and paquet.l, "etal_syn/herbe:1")
Recevoir("Claydenn-Apertus", S.accuse, { l = "etal_syn/herbe:1" })
attendu("un autre n'efface rien", M.attente["etal_syn/herbe"] ~= nil, true)
Recevoir("Syn-Apertus", S.accuse, { l = "etal_syn/herbe:1" })
attendu("son MJ, si", M.attente["etal_syn/herbe"], nil)

dire("== un joueur demande ou arrive : servi")
avant = #__envois
Recevoir("Claydenn-Apertus", S.demande, {})
envoi = DernierEnvoi(S.definition, avant)
attendu("le vendeur posé lui part", envoi and envoi.cible, "Claydenn-Apertus")
avant = #__envois
__groupe({ MOI, "Syn-Apertus", "Claydenn-Apertus", "Nytherah-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")
envoi = DernierEnvoi(S.definition, avant)
attendu("le nouveau venu le reçoit", envoi and envoi.cible, "Nytherah-Apertus")

dire("== retirer l'emplacement")
f:Onglet("placement")
f.placement.lignes[1].retirer:Click()
attendu("plus d'emplacement", MJ.Compte("etal_temoin"), 0)
attendu("plus de marchand chez soi", (function()
    for _, p in pairs(M.points) do if p.def == "etal_temoin" then return false end end
    return true
end)(), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
