-- La bourse : devises de base, soldes, credits et debits, fenetre.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local B = LCM.Bourse
local moi = LCM.Entities.Self()

dire("== les devises viennent du compendium, pas d'une liste a part")
attendu("ecus", LCM.Devises.Get("ecus").label, "Écus")
attendu("credits domiens", LCM.Devises.Get("credits").label, "Crédits")
attendu("essences stellaires", LCM.Devises.Get("essence_stelaire") ~= nil, true)
attendu("le MJ peut en proposer d'autres", #B.Catalogue() >= 3, true)

dire("== les trois de base sont toujours visibles, meme a zero")
local liste = B.Liste(moi)
attendu("trois lignes", #liste, 3)
attendu("la premiere", liste[1].id, "ecus")
attendu("a zero", liste[1].solde, 0)
attendu("rien n'est ecrit tant qu'on n'a rien", moi.bourse, nil)

dire("== crediter")
attendu("credite", (B.Crediter(moi, "ecus", 25)), true)
attendu("solde", B.Solde(moi, "ecus"), 25)
attendu("un second credit s'ajoute", (B.Crediter(moi, "ecus", 5)), true)
attendu("cumule", B.Solde(moi, "ecus"), 30)
attendu("une devise inconnue : refus", (B.Crediter(moi, "berlingots", 5)), false)
attendu("un montant nul : refus", (B.Crediter(moi, "ecus", 0)), false)

dire("== la bourse tient ses propres soldes")
-- L'onglet Devises du template n'a qu'UN emplacement : il ne peut pas loger
-- trois monnaies, donc la bourse ne passe pas par lui.
attendu("l'onglet Devises n'a qu'une place", LCM.Inventaire.Capacite("devises"), 1)
attendu("la bourse est ailleurs", moi.bourse.ecus, 30)
attendu("et n'a rien pose dans l'inventaire", moi.inventaire, nil)

dire("== debiter")
attendu("debite", (B.Debiter(moi, "ecus", 10)), true)
attendu("solde", B.Solde(moi, "ecus"), 20)
local ok, raison = B.Debiter(moi, "ecus", 999)
attendu("plus que ce qu'on a : refus", ok, false)
attendu("et on dit combien il reste", raison:find("20") ~= nil, true)
attendu("le solde n'a pas bouge", B.Solde(moi, "ecus"), 20)
attendu("de quoi payer ?", B.Peut(moi, "ecus", 20), true)
attendu("et 21 ?", B.Peut(moi, "ecus", 21), false)

dire("== une devise hors des trois n'apparait que si on en a")
attendu("le Temps existe au compendium", LCM.Devises.Get("temps") ~= nil, true)
attendu("mais pas dans la bourse", #B.Liste(moi), 3)
B.Crediter(moi, "temps", 7)
attendu("une fois qu'on en a, si", #B.Liste(moi), 4)
attendu("en dernier", B.Liste(moi)[4].id, "temps")

dire("== un solde a zero ne reste pas en sauvegarde")
B.Debiter(moi, "temps", B.Solde(moi, "temps"))
attendu("le Temps a disparu des soldes", moi.bourse.temps, nil)
attendu("et il quitte la bourse", #B.Liste(moi), 3)
B.Crediter(moi, "temps", 7)

dire("== la fenetre")
local f = LCM.UI.Bourse.Basculer()
attendu("ouverte", f:IsShown(), true)
attendu("quatre lignes", f.nombreAffiche, 4)
attendu("la premiere nomme la devise", f.lignes[1].nom:GetText(), "Écus")
attendu("et son solde", f.lignes[1].solde:GetText(), "20")
attendu("le MJ peut ajuster", f.lignes[1].plus:IsShown(), true)
f.lignes[1].plus:Click()
attendu("le + credite", B.Solde(moi, "ecus"), 21)
f.lignes[1].moins:Click()
attendu("le - debite", B.Solde(moi, "ecus"), 20)

dire("== le joueur lit, il ne se sert pas")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Afficher()
attendu("pas de bouton +", f.lignes[1].plus:IsShown(), false)
attendu("pas de bouton -", f.lignes[1].moins:IsShown(), false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== l'entree du menu")
attendu("liee", LCM.UI.Menu.EstLiee("bourse"), true)
f:Hide()
SlashCmdList.LCM("bourse")
attendu("la commande ouvre la bourse", LCM.UI.Bourse.frame:IsShown(), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
