-- Deux MJ posent le MEME modele de filon et de vendeur (21 octobre 2026).
--
-- Comme pour les coffres (lcm_test_coffres_garde) : le proprietaire etait
-- celui du modele, et l'annonce de l'un remplacait tous les points du modele
-- par les siens. Chacun garde maintenant les siens, et un geste part chez
-- celui qui a pose le point devant lequel on se tient.
-- banc: --sans-mj
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__groupe({ "Syn-Apertus", "Zed-Apertus" })
__declencher("PLAYER_LOGIN")
__personnage()
local R, M = LCM.Recolte, LCM.Marchands
local CARTE = R.Carte()
local sequence = 0
local function Recevoir(expediteur, sujet, donnees)
    sequence = sequence + 1
    LCM.Reseau.Recevoir(expediteur, string.format("%d:1:1:%s|%s", 700 + sequence, sujet,
        LCM.Reseau.Encoder(donnees)), "CHANNEL")
end
local function DernierVers(sujet)
    for i = #__envois, 1, -1 do
        if __envois[i].message:find(":" .. sujet .. "|", 1, true) then return __envois[i].cible end
    end
end

dire("== un filon, posé par deux MJ")
local filon = { id = "filon_commun", label = "Filon commun", ressources = {
    { entree = "ressources/minerai_commun", min = 1, max = 1, chance = 100 } }, dd = 0, rayon = 3 }
Recevoir("Syn-Apertus", R.SUJETS.definition, R.Paquet(filon,
    { { id = "f_syn", x = 100, y = 100, z = 0, source = "monde", carte = CARTE } }))
Recevoir("Zed-Apertus", R.SUJETS.definition, R.Paquet(filon,
    { { id = "f_zed", x = 200, y = 200, z = 0, source = "monde", carte = CARTE } }))
attendu("celui de Syn est toujours là", R.points.f_syn ~= nil, true)
attendu("celui de Zed aussi", R.points.f_zed ~= nil, true)
attendu("  arbitré par Syn", R.Auteur(R.points.f_syn), "Syn-Apertus")
attendu("  arbitré par Zed", R.Auteur(R.points.f_zed), "Zed-Apertus")
attendu("la sauvegarde garde les deux", LCM.db.recolte.points.f_syn ~= nil
    and LCM.db.recolte.points.f_zed ~= nil, true)

dire("== la récolte part chez celui qui a posé le point")
__position(100, 100, 0)
__avancer(0.5)
R.Tenter("f_syn")
attendu("devant le filon de Syn : on demande à Syn", DernierVers(R.SUJETS.prendre), "Syn-Apertus")
__position(200, 200, 0)
__avancer(0.5)
R.Tenter("f_zed")
attendu("devant celui de Zed : à Zed", DernierVers(R.SUJETS.prendre), "Zed-Apertus")

dire("== un MJ retire SES points du modèle, pas ceux de l'autre")
Recevoir("Syn-Apertus", R.SUJETS.retrait, { d = "filon_commun" })
attendu("le point de Syn part", R.points.f_syn, nil)
attendu("celui de Zed reste", R.points.f_zed ~= nil, true)
attendu("le modèle reste connu", R.definitions.filon_commun ~= nil, true)
Recevoir("Syn-Apertus", R.SUJETS.retrait, { i = "f_zed" })
attendu("Syn ne retire pas le point de Zed", R.points.f_zed ~= nil, true)

dire("== une échoppe, posée par deux MJ")
local etal = { id = "etal_commun", label = "Échoppe commune", offres = {
    { id = "herbe", entree = "ressources/minerai_commun", quantite = 1, prix = 0, limite = 5, restant = 5 },
}, rachats = {} }
Recevoir("Syn-Apertus", M.SUJETS.definition, M.Paquet(etal,
    { { id = "e_syn", x = 300, y = 300, z = 0, source = "monde", carte = CARTE } }))
Recevoir("Zed-Apertus", M.SUJETS.definition, M.Paquet(etal,
    { { id = "e_zed", x = 400, y = 400, z = 0, source = "monde", carte = CARTE } }))
attendu("celle de Syn est toujours là", M.points.e_syn ~= nil, true)
attendu("celle de Zed aussi", M.points.e_zed ~= nil, true)

dire("== l'achat part chez celui qui a posé l'échoppe")
__position(300, 300, 0)
__avancer(0.5)
M.Acheter("etal_commun", "herbe")
attendu("devant celle de Syn : on demande à Syn", DernierVers(M.SUJETS.acheter), "Syn-Apertus")
-- Zed ne peut pas repondre a une demande faite a Syn.
local reste = M.Offre("etal_commun", "herbe").restant
Recevoir("Zed-Apertus", M.SUJETS.reponse, { v = "etal_commun", o = "herbe", ok = 1, r = 0 })
attendu("une réponse de Zed est ignorée", M.Offre("etal_commun", "herbe").restant, reste)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
