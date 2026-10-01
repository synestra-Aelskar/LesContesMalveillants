-- Stock partage : repousse deterministe, fusion de deux copies, reseau.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local S = LCM.Stock
__temps(10000)

dire("== un filon neuf est plein")
S.Declarer("herbe", { limite = 5, unites = 1, minutes = 10 })
attendu("limite", S.Limite("herbe"), 5)
attendu("plein", S.Restant("herbe"), 5)
attendu("et rien n'est encore ecrit", LCM.db.stock, nil)

dire("== prendre")
attendu("pris", (S.Consommer("herbe", 2)), true)
attendu("il reste", S.Restant("herbe"), 3)
attendu("prendre plus qu'il n'y a : refuse", (S.Consommer("herbe", 99)), false)
attendu("et rien n'a bouge", S.Restant("herbe"), 3)

dire("== la repousse se deduit du temps, elle ne s'attend pas")
__avancerTemps(9 * 60)
attendu("avant la premiere periode", S.Restant("herbe"), 3)
__avancerTemps(60)
attendu("une periode : une unite", S.Restant("herbe"), 4)
__avancerTemps(30 * 60)
attendu("elle plafonne a la limite", S.Restant("herbe"), 5)

dire("== lire ne salit pas la sauvegarde")
S.Declarer("minerai", { limite = 4, unites = 1, minutes = 5 })
attendu("plein sans etre ecrit", S.Restant("minerai"), 4)
attendu("rien en sauvegarde pour lui", LCM.db.stock.minerai, nil)

dire("== la fusion : la prise la plus recente gagne")
__temps(20000)
S.Declarer("filon", { limite = 10, unites = 0, minutes = 0 })
S.Consommer("filon", 1, true)              -- chez moi : 9, pris a 20000
attendu("chez moi", S.Restant("filon"), 9)
-- L'autre a pris deux unites plus tard : c'est lui qui fait foi.
attendu("fusion acceptee", S.Fusionner("filon", { r = 7, t = 20000, u = 20050 }), true)
attendu("on prend sa version", S.Restant("filon"), 7)
-- Un etat plus ANCIEN n'ecrase pas le notre.
attendu("une prise plus ancienne ne change rien",
    S.Fusionner("filon", { r = 9, t = 20000, u = 20000 }), false)
attendu("toujours", S.Restant("filon"), 7)

dire("== a egalite de prise, le plus bas gagne")
-- Deux joueurs qui n'ont jamais pris : on croit celui qui a le moins.
S.Declarer("baies", { limite = 8, unites = 0, minutes = 0 })
S.Fusionner("baies", { r = 8, t = 20000, u = 0 })
attendu("chez moi", S.Restant("baies"), 8)
S.Fusionner("baies", { r = 5, t = 20000, u = 0 })
attendu("on retient le moins", S.Restant("baies"), 5)
S.Fusionner("baies", { r = 7, t = 20000, u = 0 })
attendu("et on ne remonte pas", S.Restant("baies"), 5)

dire("== a egalite de prise, la repousse la plus recente")
S.Declarer("champignon", { limite = 6, unites = 0, minutes = 0 })
S.Fusionner("champignon", { r = 2, t = 20000, u = 100 })
S.Fusionner("champignon", { r = 6, t = 25000, u = 100 })
attendu("la repousse plus recente l'emporte", S.Restant("champignon"), 6)

dire("== le MJ remet du stock")
S.Rendre("filon", 3, true)
attendu("rendu", S.Restant("filon"), 10)
attendu("sans depasser la limite", S.Limite("filon"), 10)

dire("== ca passe par le reseau")
local avant = #__envois
S.Consommer("filon", 1)
attendu("la prise est annoncee", #__envois > avant, true)
local dernier = __envois[#__envois]
attendu("sur le canal du groupe", dernier.canal, "RAID")
attendu("sous la limite des 255 octets", dernier.taille <= LCM.Reseau.LIMITE, true)

dire("== ce qui arrive du reseau se fusionne")
LCM.Stock.onChange = function(cle) _G.__stockChange = cle end
LCM.Reseau.Recevoir("Autre-Royaume", "77:1:1:stock|cle=filon;r=2;t=20000;u=99999")
attendu("fusionne", S.Restant("filon"), 2)
attendu("et signale", _G.__stockChange, "filon")

dire("== demander l'etat en arrivant")
local avant2 = #__envois
S.Demander("filon")
attendu("la demande part", #__envois > avant2, true)

dire("== oublier un stock le nettoie")
S.Oublier("filon") S.Oublier("baies") S.Oublier("champignon")
S.Oublier("herbe") S.Oublier("minerai")
attendu("plus rien en sauvegarde", LCM.db.stock, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
