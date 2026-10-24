local ko = 0
local function attendu(n, a, b)
    if a ~= b then ko = ko + 1 print('KO ' .. n .. ': ' .. tostring(a) .. ' attendu ' .. tostring(b)) end
end
__declencher('PLAYER_LOGIN')
__personnage()
__groupe({ 'Nytherah-Apertus' })
local f = LCM.UI.PanneauMJ.Basculer()
for _, b in ipairs(f.barre.boutons) do if b.ongletId == 'etats' then b:Click() end end
local p = f.pages.etats
local moi = LCM.Entities.Personnage()
moi.etatsTemporaires, moi.etats = nil, nil
local def = { id = 'etat_panel_temoin', label = 'Etat temoin', categorie = 'etat', bonus = {} }
LCM.Etats.Add(def)
attendu('duree vide par defaut', p.duree:GetText(), '')
p:Appliquer(LCM.PlayerId(), def)
attendu('etat pose', #LCM.EtatsTemporaires.Liste(moi), 1)
attendu('sans expiration', moi.etatsTemporaires[1].restant, nil)
for i = 1, 20 do LCM.EtatsTemporaires.Round(moi) end
attendu('persiste apres 20 rounds', #LCM.EtatsTemporaires.Liste(moi), 1)
p:ChoisirJoueur(LCM.PlayerId())
attendu('affiche etat actif', p.lignesActifs[1].nom:GetText(), 'Etat temoin')
p.lignesActifs[1].retirer:Click()
attendu('croix retire vraiment', #LCM.EtatsTemporaires.Liste(moi), 0)
p.duree:SetText('2')
p:Appliquer(LCM.PlayerId(), def)
LCM.EtatsTemporaires.Round(moi)
attendu('duree finie decomptee', moi.etatsTemporaires[1].restant, 1)
LCM.EtatsTemporaires.Round(moi)
attendu('expire normalement', #LCM.EtatsTemporaires.Liste(moi), 0)
p.duree:SetText('0')
p:Appliquer(LCM.PlayerId(), def)
attendu('zero reste refuse', #LCM.EtatsTemporaires.Liste(moi), 0)
LCM.Etats.Placer(moi, def.id)
p:ChoisirJoueur(LCM.PlayerId())
attendu('etat catalogue affiche', p.lignesActifs[1].etat.catalogue, true)
p.lignesActifs[1].retirer:Click()
attendu('etat catalogue retire', LCM.Etats.Porte(moi, def.id), false)
local copie = { name = 'Autre', etatsTemporaires = { {nom = 'Distant', restant = 4} } }
local recue, demander, envoyer = LCM.Fiches.Recue, LCM.Fiches.Demander, LCM.EtatsTemporaires.EnvoyerRetrait
LCM.Fiches.Recue = function() return copie end
LCM.Fiches.Demander = function() return true end
local cible, nom
LCM.EtatsTemporaires.EnvoyerRetrait = function(j, n) cible, nom = j, n return true end
p:ChoisirJoueur('Nytherah-Apertus')
p.lignesActifs[1].retirer:Click()
attendu('adresse destinataire', cible, 'Nytherah-Apertus')
attendu('nom etat retire', nom, 'Distant')
attendu('ne modifie pas une copie distante', #copie.etatsTemporaires, 1)
LCM.Fiches.Recue, LCM.Fiches.Demander, LCM.EtatsTemporaires.EnvoyerRetrait = recue, demander, envoyer
print(ko == 0 and 'TOUT PASSE' or (ko .. ' ECHEC(S)'))
