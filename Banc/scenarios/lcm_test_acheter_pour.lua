-- « Acheter pour… » (31 octobre 2026) : etal ouvert, l'addon cherche les
-- joueurs a cote (Equilibrage.marchands.rayonOffrir) ; on peut alors acheter
-- avec SES sous et ranger l'objet dans le sac de l'autre.
--
-- Ce qu'on verifie :
--   * l'etal ouvert lance le scan, et le choix « Acheter pour » n'apparait
--     que si quelqu'un est a portee ;
--   * on ne paie qu'une fois que l'autre a accepte et range ; un refus ou une
--     absence de reponse ne coutent rien, et le stock repart au vendeur ;
--   * chez le destinataire : la question, et l'objet range s'il accepte ;
--   * repondre au scan : seulement si l'on est assez pres.
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

local HERBE, PAIN = "ressources/herbe_offerte", "ressources/pain_offert"
LCM.Brouillons.Set("ressources", { id = "herbe_offerte", label = "Herbe offerte" })
LCM.Brouillons.Set("ressources", { id = "pain_offert", label = "Pain offert" })
LCM.Brouillons.Set("sacs", { id = "sac_offrir", label = "Sac témoin", places = 12 })
LCM.Brouillons.Set("devises", { id = "piece_offrir", label = "Pièce témoin" })
LCM.Brouillons.Set("points", {
    id = "etal_offrir", label = "Étal témoin", nature = "vendeur", deviseDefaut = "piece_offrir",
    onglets = { { id = "o1", label = "Articles", offres = {
        { id = "herbe", entree = HERBE, quantite = 1, prix = 3, devise = "piece_offrir",
          stock = { limite = 2, unites = 0, minutes = 0 } },
        { id = "pain", entree = PAIN, quantite = 2, prix = 1, devise = "piece_offrir" },
    } } },
})

__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
LCM.Inventaire.Poser(moi, "sacs", 1, "sac_offrir", true)
LCM.Bourse.Crediter(moi, "piece_offrir", 20)
local MOI = LCM.PlayerId()
__groupe({ MOI, "Syn-Apertus", "Claydenn-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")

local M, MJ = LCM.Marchands, LCM.MarchandsMJ
local S = M.SUJETS
local function Bourse() return LCM.Bourse.Solde(moi, "piece_offrir") end
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
-- Le dernier envoi d'un sujet (messages courts : un seul morceau).
local function DernierEnvoi(sujet, depuis)
    for i = #__envois, (depuis or 0) + 1, -1 do
        local e = __envois[i]
        local corps = e.message:match("^%d+:1:1:(.*)$")
        if corps and corps:sub(1, #sujet + 1) == sujet .. "|" then
            return e, LCM.Reseau.Decoder(corps:sub(#sujet + 2))
        end
    end
end
local function Recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end

-- Le marchand pose, et l'acheteur devant lui.
__position(10, 10, 0)
MJ.Placer("etal_offrir")
__position(12, 11, 0)
__avancer(0.3)

dire("== l'etal ouvert cherche qui est a cote")
local avant = #__envois
LCM.UI.Marchand.bouton:Click()
local etal = LCM.UI.Marchand.frame
attendu("l'etal s'ouvre", etal:IsShown(), true)
local scan, demande = DernierEnvoi(S.proches, avant)
attendu("le scan part", scan ~= nil, true)
attendu("avec le rayon de l'equilibrage", demande and tonumber(demande.r), LCM.Equilibrage.marchands.rayonOffrir)
attendu("personne a cote : pas de choix « Acheter pour »", etal.pour:IsShown(), false)
attendu("le bouton dit « Acheter »", LCM.UI.Marchand.lignes[2].action.label:GetText(), "Acheter")

Recevoir("Syn-Apertus", S.present, { d = 2.5, p = "Synestra" })
attendu("Syn repond : le choix apparait", etal.pour:IsShown(), true)
etal.pour.choisir("Syn-Apertus")
attendu("le bouton devient « Offrir »", LCM.UI.Marchand.lignes[2].action.label:GetText(), "Offrir")

dire("== offrir : on ne paie qu'a l'acceptation")
avant = #__envois
LCM.UI.Marchand.lignes[2].action:Click()
local offre, contenu = DernierEnvoi(S.offrir, avant)
attendu("l'offre part a Syn", offre and offre.cible, "Syn-Apertus")
attendu("avec l'objet et la quantite", contenu and (contenu.e .. " x" .. contenu.q), PAIN .. " x2")
attendu("rien n'est encore paye", Bourse(), 20)
attendu("rien dans mon sac", Combien(PAIN), 0)
Recevoir("Syn-Apertus", S.accepter, { i = contenu.i, ok = 1 })
attendu("Syn accepte : je paie", Bourse(), 19)
attendu("et je n'ai toujours rien dans mon sac", Combien(PAIN), 0)

dire("== un refus ne coute rien, et le stock revient")
attendu("deux herbes en stock", LCM.UI.Marchand.lignes[1].stock:GetText(), "2 / 2")
avant = #__envois
LCM.UI.Marchand.lignes[1].action:Click()
local _, offreHerbe = DernierEnvoi(S.offrir, avant)
attendu("l'unite est reservee pendant l'attente", MJ.EnAttente("etal_offrir", "herbe"), 1)
Recevoir("Syn-Apertus", S.accepter, { i = offreHerbe.i, n = "refusé." })
attendu("pas paye", Bourse(), 19)
attendu("l'herbe revient au vendeur", LCM.UI.Marchand.lignes[1].stock:GetText(), "2 / 2")
attendu("plus rien de reserve", MJ.EnAttente("etal_offrir", "herbe"), 0)

dire("== pas de reponse : rien n'est paye")
avant = #__envois
LCM.UI.Marchand.lignes[2].action:Click()
attendu("une offre en attente", next(M.cadeaux) ~= nil, true)
__avancer(31)
attendu("au bout du delai, l'offre tombe", next(M.cadeaux), nil)
attendu("et rien n'est paye", Bourse(), 19)
etal:Hide()

dire("== chez le destinataire : la question, puis le sac")
avant = #__envois
Recevoir("Claydenn-Apertus", S.offrir, { i = "77", e = PAIN, q = 2, l = "Pain offert", m = "Étal témoin" })
local question = LCM.UI.Marchand.cadeau
attendu("on me demande si j'accepte", question and question:IsShown(), true)
attendu("en nommant qui offre", (question.texte:GetText() or ""):find("Claydenn", 1, true) ~= nil, true)
question.oui:Click()
attendu("accepte : c'est range dans mon sac", Combien(PAIN), 2)
local reponse, r = DernierEnvoi(S.accepter, avant)
attendu("je reponds oui a Claydenn", reponse and reponse.cible .. "/" .. tostring(r.ok), "Claydenn-Apertus/1")
avant = #__envois
Recevoir("Claydenn-Apertus", S.offrir, { i = "78", e = PAIN, q = 2, l = "Pain offert", m = "Étal témoin" })
question.non:Click()
attendu("refuse : rien de plus dans mon sac", Combien(PAIN), 2)
local _, r2 = DernierEnvoi(S.accepter, avant)
attendu("et je reponds non", r2 and r2.ok, nil)

dire("== repondre au scan : seulement d'assez pres")
avant = #__envois
Recevoir("Claydenn-Apertus", S.proches, { x = 13, y = 12, z = 0, s = "monde", r = 5 })
local present, p = DernierEnvoi(S.present, avant)
attendu("a 1,4 yard : je reponds", present and present.cible, "Claydenn-Apertus")
avant = #__envois
Recevoir("Claydenn-Apertus", S.proches, { x = 40, y = 40, z = 0, s = "monde", r = 5 })
attendu("a 40 yards : je me tais", DernierEnvoi(S.present, avant), nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
