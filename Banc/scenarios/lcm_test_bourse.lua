-- La bourse : devises de base, soldes, credits et debits, fenetre.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
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
attendu("l'onglet Devises a ete retire", LCM.Inventaire.Get("devises"), nil)
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
-- 13 octobre 2026 : plus de boutons + et - ; le MJ clique sur le solde et
-- tape le nouveau. Le joueur ne peut pas.
attendu("le MJ peut ajuster", f.lignes[1].saisie:IsShown(), true)
attendu("plus de bouton +", f.lignes[1].plus, nil)
f.lignes[1].saisie:Click()
local d = LCM_Demande
attendu("on demande le solde", d:IsShown(), true)
d.saisie:SetText("250")
d.valider:Click()
attendu("le solde est pose", B.Solde(moi, "ecus"), 250)
attendu("et affiche", f.lignes[1].solde:GetText(), "250")
f.lignes[1].saisie:Click()
d.saisie:SetText("-3")
d.valider:Click()
attendu("negatif : refus dit", (d.message:GetText() or ""):find("illisible", 1, true) ~= nil, true)
attendu("rien n'a bouge", B.Solde(moi, "ecus"), 250)
d.saisie:SetText("20")
d.valider:Click()
attendu("on redescend", B.Solde(moi, "ecus"), 20)
attendu("a zero, le solde s'efface", (function() B.Definir(moi, "credits", 0) return moi.bourse.credits end)(), nil)

dire("== clic droit sur une devise : Échanger, Jeter (13 octobre 2026)")
local menu = LCM.UI.MenuContexte()
local function libelles()
    local t = {}
    for _, l in ipairs(menu.lignes) do if l:IsShown() then t[#t + 1] = l.texte:GetText() end end
    return table.concat(t, ",")
end
local function cliquer(libelle)
    for _, l in ipairs(menu.lignes) do
        if l:IsShown() and l.texte:GetText() == libelle then l:Click() return true end
    end
    return false
end
f.lignes[1]:Click("RightButton")
attendu("le menu", libelles(), "Échanger,Jeter")
cliquer("Jeter")
attendu("on demande combien", d:IsShown(), true)
d.saisie:SetText("21")
d.valider:Click()
attendu("pas plus qu'on n'a", (d.message:GetText() or ""):find("que 20", 1, true) ~= nil, true)
d.saisie:SetText("5")
d.valider:Click()
local conf
for _, cadre in ipairs({ UIParent:GetChildren() }) do
    if cadre.oui and cadre.non and cadre:IsShown() then conf = cadre end
end
attendu("puis on confirme", conf ~= nil, true)
conf.non:Click()
attendu("annule : rien de perdu", B.Solde(moi, "ecus"), 20)
f.lignes[1]:Click("RightButton")
cliquer("Jeter")
d.saisie:SetText("5")
d.valider:Click()
conf.oui:Click()
attendu("jetes", B.Solde(moi, "ecus"), 15)
attendu("et affiche", f.lignes[1].solde:GetText(), "15")
-- Clic droit sur le montant lui-meme : le meme menu.
f.lignes[1].saisie:Click("RightButton")
attendu("le montant garde le menu", libelles(), "Échanger,Jeter")
menu:Hide()

__groupe({ "Nytherah-Apertus" })
f.lignes[1]:Click("RightButton")
attendu("en groupe : a qui", libelles(), "Échanger >,Jeter")
cliquer("Échanger >")
menu.sousLignes[1]:Click()
d.saisie:SetText("4")
d.valider:Click()
attendu("l'echange est propose", LCM.Echange.courant and LCM.Echange.courant.qui, "Nytherah-Apertus")
attendu("la somme attend la reponse", LCM.Echange.courant.attente and LCM.Echange.courant.attente.combien, 4)
attendu("rien n'est debite avant", B.Solde(moi, "ecus"), 15)
-- L'autre accepte : la somme se pose, et quitte la bourse (mise en gage).
LCM.Reseau.Recevoir("Nytherah-Apertus", "1:1:1:ECH_OUI|" .. LCM.Reseau.Encoder({}))
attendu("l'echange s'ouvre", LCM.Echange.courant and LCM.Echange.courant.ouverte, true)
attendu("posee dans l'echange", LCM.Echange.courant.mien.devises.ecus, 4)
attendu("et mise en gage", B.Solde(moi, "ecus"), 11)
LCM.Echange.Annuler("essai", true)
__groupe({})
B.Definir(moi, "ecus", 20)
f:Afficher()

dire("== le joueur lit, il ne se sert pas")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Afficher()
attendu("le solde ne se clique pas", f.lignes[1].saisie:IsShown(), false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== l'entree du menu")
attendu("liee", LCM.UI.Menu.EstLiee("bourse"), true)
f:Hide()
SlashCmdList.LCM("bourse")
attendu("la commande ouvre la bourse", LCM.UI.Bourse.frame:IsShown(), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
