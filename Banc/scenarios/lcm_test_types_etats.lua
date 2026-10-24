local ko = 0
local function attendu(n, a, b)
    if a ~= b then ko = ko + 1 print('KO ' .. n .. ': ' .. tostring(a) .. ' attendu ' .. tostring(b)) end
end
__declencher('PLAYER_LOGIN')
__personnage()
local C = LCM.Compendium
attendu('liste visible', C.Get('liste_type_etats').label, 'Liste-Type-Etats')
attendu('seul champ supplementaire', #C.Get('liste_type_etats').champs, 1)
attendu('trois destinations', #C.Options({source='conteneurs_etats'}), 3)
local moi = LCM.Entities.Personnage()
local panel = LCM.UI.PanneauMJ.Fenetre()
local p = panel.pages.etats
for _, destination in ipairs({'etat', 'maladie', 'intangible'}) do
    local typeId = 'type_test_' .. destination
    LCM.Listes.Add({id=typeId, label='Type ' .. destination, liste='type_etats', conteneur=destination})
    local def = {id='test_' .. destination, label='Test ' .. destination, categorie='etat', type=typeId}
    local e = LCM.Etats.Construire(def)
    attendu('destination construite ' .. destination, e.categorie, destination)
    LCM.Etats.Add(def)
    -- Sans duree, l'etat rejoint les etats PORTES (le MJ, 24 octobre 2026),
    -- dans l'emplacement que son TYPE designe.
    p.duree:SetText('')
    p:Appliquer(LCM.PlayerId(), e)
    attendu('pose locale ' .. destination, LCM.Etats.Porte(moi, def.id), true)
    local ids = LCM.Etats.Ids(moi, destination)
    attendu('dans son conteneur ' .. destination, ids[#ids], def.id)
    attendu('et pas en temporaire ' .. destination, #LCM.EtatsTemporaires.Liste(moi), 0)
end
for _, id in ipairs({'etats', 'maladies'}) do
    local source
    for _, champ in ipairs(C.Champs(C.Get(id))) do if champ.cle == 'type' then source = champ.source end end
    attendu('source forge ' .. id, source, 'listes:type_etats')
end
local ancien = LCM.Etats.Construire({id='ancien', categorie='maladie', type='ancien_type_arme'})
local FU = LCM.UI.Forge
LCM.Forge.Add({id='jeu_etats_test', label='Jeu etats test', categorie='etats',
    raretes={{id='commun', label='Commun', points=10, couleur='FF8CB8'}}, champs={}})
FU.Ouvrir('etats')
FU.courant.jeuId, FU.courant.rareteId = 'jeu_etats_test', 'commun'
FU.courant.nom, FU.courant.type = 'Forge temoin', 'type_test_maladie'
local definition, raison = FU.Definition()
attendu('forge produit une definition ' .. tostring(raison), definition ~= nil, true)
attendu('forge enregistre destination du type', definition and definition.categorie, 'maladie')
attendu('forge conserve reference du type', definition and definition.type, 'type_test_maladie')
attendu('ancien preserve', ancien.categorie, 'maladie')
local tardif = LCM.Etats.Construire({id='tardif', categorie='etat', type='type_tardif'})
LCM.Listes.Add({id='type_tardif', label='Arrive ensuite', liste='type_etats', conteneur='intangible'})
attendu('type arrive apres etat', LCM.Etats.Conteneur(tardif), 'intangible')
local ok = pcall(function() LCM.Listes.Construire({id='invalide', liste='type_etats', conteneur='armes'}) end)
attendu('destination invalide refusee', ok, false)
__groupe({'Nytherah-Apertus'})
__reseauBoucle(true, 'Nytherah-Apertus')
-- Il est deja porte depuis la boucle plus haut : on le rend, sinon la pose
-- serait refusee pour doublon et ce n'est pas ce qu'on teste ici.
LCM.Etats.Enlever(moi, 'test_maladie')
LCM.EtatsTemporaires.Envoyer('Nytherah-Apertus', 'test_maladie', nil)
__avancer(LCM.Reseau.FileEnvoi() * LCM.Reseau.CADENCE + 1)
-- Sans duree, l'etat recu du MJ rejoint lui aussi les etats PORTES.
local maladies = LCM.Etats.Ids(moi, 'maladie')
attendu('pose reseau destination', maladies[#maladies], 'test_maladie')
print(ko == 0 and 'TOUT PASSE' or (ko .. ' ECHEC(S)'))
