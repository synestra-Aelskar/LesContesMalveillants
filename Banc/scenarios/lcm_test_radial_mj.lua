local ko = 0
local function attendu(n, a, b)
    if a ~= b then ko = ko + 1 print('KO ' .. n .. ': ' .. tostring(a) .. ' attendu ' .. tostring(b)) end
end
__declencher('PLAYER_LOGIN')
__personnage()
__groupe({'Nytherah-Apertus'})
local R, M = LCM.UI.Radial, LCM.UI.Menu
R.Basculer('fenetres')
__avancer(1)
local f = R.Fenetre()
local function bouton(liste, id)
    for _, b in ipairs(liste) do if b.cible and b.cible.id == id then return b end end
end
bouton(f.couronnes.fenetres.boutonsCategorie, 'outils'):Click()
__avancer(1)
local panel = bouton(f.couronnes.fenetres.boutonsEntree, 'panneau_mj')
panel:Click('RightButton')
__avancer(1)
local mj = R.compagnonMJ.couronnes.mj
attendu('grimoire reste en fenetres', f.couronnes.fenetres.ouvert, true)
attendu('dossier Outils conserve', f.couronnes.fenetres.choisi, 'outils')
attendu('pas de mode MJ dans le grimoire', f.couronnes.mj, nil)
attendu('couronne MJ ouverte', mj.ouvert, true)
attendu('cinq branches', mj.nombreCategories, 5)
bouton(mj.boutonsCategorie, 'mj_etats'):Click()
local p = LCM.UI.PanneauMJ.Fenetre()
attendu('etats seuls', p.onglet, 'etats')
attendu('sans onglets', p.barre:IsShown(), false)
attendu('joueurs masques', p.pages.joueurs:IsShown(), false)
bouton(mj.boutonsCategorie, 'mj_outils'):Click()
__avancer(1)
attendu('quatre outils', mj.nombreEntrees, 4)
for _, id in ipairs({'mj_barres','mj_compteurs','mj_annonce','mj_notes'}) do
    bouton(mj.boutonsEntree, id):Click()
    attendu(id .. ' ouvre outils seuls', p.onglet, 'outils')
    attendu(id .. ' masque sous onglets', p.pages.outils.barre:IsShown(), false)
end
bouton(mj.boutonsCategorie, 'mj_regain'):Click()
attendu('regain ouvert', p.pages.joueurs.regainPanneau:IsShown(), true)
attendu('panel cache pour regain', p:IsShown(), false)
bouton(mj.boutonsCategorie, 'mj_joueurs'):Click()
attendu('joueurs seuls', p.onglet, 'joueurs')
bouton(mj.boutonsCategorie, 'mj_combat'):Click()
attendu('combat seul', p.onglet, 'combat')
M.Trouver('panneau_mj').onClick()
attendu('clic gauche restaure onglets', p.barre:IsShown(), true)
attendu('restaure outils', p.pages.outils.barre:IsShown(), true)
local master = LCM.IsMaster
LCM.IsMaster = function() return false end
R.Fermer('mj')
__avancer(1)
M.Trouver('panneau_mj').onRightClick()
attendu('interdit au joueur', mj.ouvert, false)
LCM.IsMaster = master
print(ko == 0 and 'TOUT PASSE' or (ko .. ' ECHEC(S)'))
