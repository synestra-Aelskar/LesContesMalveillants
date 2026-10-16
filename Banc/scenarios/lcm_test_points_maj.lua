-- Un point modifie se met a jour la ou il est pose (16 octobre 2026) : « si tu
-- mets a jour la monnaie d'un marchand deja pose, tu dois supprimer le point
-- et le replacer. Non : ca doit etre mis a jour automatiquement. » Le renvoi
-- passe par l'enregistrement lui-meme (MJ/Brouillons.lua, SurPoint) : en
-- seance, depuis n'importe quelle fenetre, et a la reception de l'autre MJ.
--
-- Contenu TEMOIN : devises, ressource, vendeur, recolte et coffre d'essai.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local HERBE = "ressources/herbe_maj"
LCM.Brouillons.Set("ressources", { id = "herbe_maj", label = "Herbe" })
LCM.Brouillons.Set("devises", { id = "piece_maj", label = "Pièce" })
LCM.Brouillons.Set("devises", { id = "ecu_maj", label = "Écu" })

__declencher("PLAYER_LOGIN")
__personnage()
local MOI = LCM.PlayerId()
__groupe({ MOI, "Syn-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")

-- Le dernier envoi d'un sujet, RECOLLE (copie de lcm_test_marchands).
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
local function Vendeur(devise, label)
    return { id = "etal_maj", label = label or "Étal", nature = "vendeur", deviseDefaut = devise,
        onglets = { { id = "o1", label = "Articles", offres = {
            { id = "herbe", entree = HERBE, quantite = 1, prix = 3 } } } } }
end

dire("== un vendeur pose change de monnaie")
local ok, raison = LCM.Brouillons.Enregistrer("points", Vendeur("piece_maj"), true)
attendu("vendeur enregistre", ok, true)
if not ok then dire("raison :", tostring(raison)) end
local SM = LCM.Marchands.SUJETS
local avant = #__envois
LCM.Brouillons.Enregistrer("points", Vendeur("piece_maj"), false)
attendu("pas encore pose : rien ne part", DernierEnvoi(SM.definition, avant) == nil, true)
__position(10, 10, 0)
LCM.MarchandsMJ.Placer("etal_maj")
attendu("pose", LCM.MarchandsMJ.Compte("etal_maj"), 1)
avant = #__envois
LCM.Brouillons.Enregistrer("points", Vendeur("ecu_maj"), false)
local envoi, paquet = DernierEnvoi(SM.definition, avant)
attendu("rediffuse sans le reposer", envoi and envoi.canal, "PARTY")
attendu("  dans la nouvelle monnaie", paquet and paquet.o[1].f, "3*devises/ecu_maj")
attendu("  toujours a la meme place", LCM.MarchandsMJ.Compte("etal_maj"), 1)
attendu("le prix lu chez soi suit aussi",
    LCM.Prix.Texte(LCM.Points.Offre("etal_maj", "herbe").formules), "3 Écu")

dire("== modifie par l'autre MJ")
avant = #__envois
LCM.Reseau.Recevoir("Syn-Apertus", "1:1:1:brouillon|" .. LCM.Reseau.Encoder({
    f = "points", e = Vendeur("ecu_maj", "Étal de Syn") }))
envoi, paquet = DernierEnvoi(SM.definition, avant)
attendu("mon etal repart aussi", paquet and paquet.n, "Étal de Syn")

dire("== un vendeur pose est supprime")
avant = #__envois
LCM.Brouillons.Supprimer("points", "etal_maj")
envoi, paquet = DernierEnvoi(SM.retrait, avant)
attendu("les joueurs l'oublient", paquet and paquet.d, "etal_maj")

dire("== une recolte posee")
local function Recolte(label)
    return { id = "filon_maj", label = label, nature = "ressource",
        recolte = { ressources = { { entree = HERBE, min = 1, max = 1, chance = 100 } } } }
end
ok, raison = LCM.Brouillons.Enregistrer("points", Recolte("Filon"), true)
attendu("recolte enregistree", ok, true)
if not ok then dire("raison :", tostring(raison)) end
LCM.Recoltes.Placer("filon_maj")
local SR = LCM.Recolte.SUJETS
avant = #__envois
LCM.Brouillons.Enregistrer("points", Recolte("Filon riche"), false)
envoi, paquet = DernierEnvoi(SR.definition, avant)
attendu("rediffusee", paquet and paquet.n, "Filon riche")
avant = #__envois
LCM.Brouillons.Supprimer("points", "filon_maj")
envoi, paquet = DernierEnvoi(SR.retrait, avant)
attendu("supprimee : oubliee", paquet and paquet.d, "filon_maj")

dire("== un coffre pose")
local function Coffre(label)
    return { id = "coffre_maj", label = label, nature = "coffre",
        coffre = { places = 2, rayon = 7, verrous = 0, reset = false, objets = {} } }
end
ok, raison = LCM.Brouillons.Enregistrer("points", Coffre("Coffre"), true)
attendu("coffre enregistre", ok, true)
if not ok then dire("raison :", tostring(raison)) end
local idCoffre = LCM.CoffresMJ.Placer("coffre_maj")
local SC = LCM.Coffres.SUJETS
avant = #__envois
LCM.Brouillons.Enregistrer("points", Coffre("Coffre ferré"), false)
envoi, paquet = DernierEnvoi(SC.definition, avant)
attendu("rediffuse", paquet ~= nil, true)
attendu("  sous son nouveau nom", LCM.Coffres.definitions["coffre_maj"]
    and LCM.Coffres.definitions["coffre_maj"].label, "Coffre ferré")
avant = #__envois
LCM.Brouillons.Supprimer("points", "coffre_maj")
envoi, paquet = DernierEnvoi(SC.retrait, avant)
attendu("supprime : le point est oublie", paquet and paquet.i, idCoffre)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
