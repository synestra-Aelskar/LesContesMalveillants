-- Le regain du panneau MJ : remplir, vider, donner ou RETIRER un nombre de
-- points (le negatif est demande par le MJ le 23 octobre 2026).
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function contient(libelle, texte, morceau)
    local ok = tostring(texte or ""):find(morceau, 1, true) ~= nil
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(texte), ok and "" or ("(attendu « " .. morceau .. " »)"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM._masterCompanion = true
local R, E = LCM.Regain, LCM.Entities
local moi = E.Self()
local function PA() return E.Gauge(moi, "pa") end
local maximum = PA().max
attendu("les PA ont un maximum", maximum > 2, true)

dire("== donner")
E.SetGauge(moi, "pa", 1)
local r = R.Appliquer(moi, { pa = true }, "exact", 1)
attendu("+1 PA", PA().current, 2)
attendu("le texte dit le gain", R.Texte(r), "Vous gagnez 1 PA.")

dire("== retirer")
r = R.Appliquer(moi, { pa = true }, "exact", -1)
attendu("-1 PA", PA().current, 1)
attendu("le texte dit la perte", R.Texte(r), "Vous perdez 1 PA.")
r = R.Appliquer(moi, { pa = true }, "exact", -50)
attendu("on ne descend pas sous zero", PA().current, 0)
attendu("la perte dite est celle reellement retiree", R.Texte(r), "Vous perdez 1 PA.")
R.Appliquer(moi, { pa = true }, "exact", 999)
attendu("ni au-dessus du maximum", PA().current, maximum)
local rien, raison = R.Appliquer(moi, { pa = true }, "exact", 0)
attendu("zero est refuse", rien, nil)
contient("     raison", raison, "positif ou négatif")

dire("== les PV aussi")
R.Appliquer(moi, { pv_buste = true }, "max")
local avant = R.Etat(moi, "pv_buste").current
-- Le personnage nu du banc n'a que 2 PV par zone : on en retire un.
attendu("le torse a des PV a retirer", avant >= 2, true)
R.Appliquer(moi, { pv_buste = true }, "exact", -1)
attendu("-1 PV au torse", R.Etat(moi, "pv_buste").current, avant - 1)

dire("== envoyer un retrait")
local ok = R.Envoyer("Nytherah-Apertus", { pa = true }, "exact", -3)
attendu("le MJ peut envoyer un negatif", ok, true)
attendu("le paquet porte le signe", __envois[#__envois].message:find("m=-3", 1, true) ~= nil, true)

dire("== le panneau accepte le signe moins")
__groupe({ "Nytherah-Apertus" })
local p = LCM.UI.PanneauMJ.Basculer()
p.pages.joueurs.regainBouton:Click()
local rg = p.pages.joueurs.regainPanneau
rg.modes.exact:Click()
rg.montant:Saisir("-2")
attendu("le champ garde le signe", rg.montant:GetText(), "-2")
rg.casesRessources.pa:Click()
E.SetGauge(moi, "pa", 3)
for rang = 1, rg.nombre do
    local l = rg.lignes[rang]
    if l.joueur == LCM.PlayerId() then l.case:Click() end
end
rg.envoyer:Click()
attendu("le MJ se retire 2 PA", PA().current, 1)
rg:Ouvrir()
rg.modes.exact:Click()
rg.montant:Saisir("abc")
rg.casesRessources.pa:Click()
for rang = 1, rg.nombre do rg.lignes[rang].case:Click() end
rg.envoyer:Click()
contient("une saisie qui n'est pas un nombre est refusee", __sansCouleur(__sorties[#__sorties] or ""), "nombre entier")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
