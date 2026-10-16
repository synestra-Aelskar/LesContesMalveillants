-- Verifie la marge radiale de chaque cercle apres les animations,
-- sur toutes les categories des deux couronnes et les sous-menus.
__declencher("PLAYER_LOGIN")
__personnage()
local R = LCM.UI.Radial
local total = 0
local function Verifier(c)
    local lien = c.lienPourpre
    assert(lien.nombreCibles == c.nombreEntrees, "Le flux ne suit pas le nombre d'icones")
    assert(lien.nombreGrains == c.nombreEntrees * 12, "Densite incorrecte")
    local _, _, _, ox, oy = c.orbite:GetPoint(1)
    -- Les cibles du sous-menu sont exprimees dans le repere de sa couronne.
    if c.def then ox, oy = 0, 0 end
    for _, cible in ipairs(lien.cibles) do
        local trouve = false
        for i = 1, c.nombreEntrees do
            local b = c.boutonsEntree[i]
            if math.abs(cible.x - ox - b.rx) < 0.001 and math.abs(cible.y - oy - b.ry) < 0.001 then trouve = true end
        end
        assert(trouve, "Une branche de poussiere ne vise aucune icone")
    end
    for i = 1, c.nombreEntrees or 0 do
        local b = c.boutonsEntree[i]
        local _, _, _, x, y = b:GetPoint(1)
        local rayon = math.sqrt(x*x + y*y)
        local dedans = rayon - R.FOND * R.BANDE_INTERIEURE
        local dehors = R.FOND * R.BANDE_EXTERIEURE - rayon
        assert(math.abs(dedans - dehors) < 0.001, "Cercle decentre : " .. b.cible.id)
        total = total + 1
    end
end
for _, id in ipairs({ "fenetres", "actions" }) do
    R.Basculer(id)
    __avancer(1)
    local c = R.frame.couronnes[id]
    for i = 1, c.nombreCategories do
        local bouton = c.boutonsCategorie[i]
        local _, _, _, x, y = bouton:GetPoint(1)
        local rayon = math.sqrt(x*x + y*y)
        local dedans = rayon - R.FOND * R.COURONNE_INTERIEURE
        local dehors = R.FOND * R.COURONNE_EXTERIEURE - rayon
        assert(math.abs(dedans - dehors) < 0.001, "Categorie decentree : " .. bouton.cible.id)
        total = total + 1
        if #c.def.Entrees(bouton.cible) > 0 then
            bouton:Click("LeftButton")
            __avancer(1)
            Verifier(c)
            assert(c.lienPourpre and c.lienPourpre:IsShown(), "Lien principal absent")
            assert(c.lienPourpre:GetFrameLevel() < c.secteur:GetFrameLevel(), "Lien devant le cuir")
            assert(math.abs(c.lienPourpre.departX - bouton.rx) < 0.001, "Mauvais bouton source")
            local phase = c.lienPourpre.grains[1].phase
            __avancer(0.1)
            assert(c.lienPourpre.grains[1].phase ~= phase, "Particules immobiles")
            for j = 1, c.nombreEntrees do
                local entree = c.boutonsEntree[j]
                if entree.cible.enfants then
                    entree:Click("LeftButton")
                    __avancer(1)
                    Verifier(c.sousMenu)
                    local lien = c.sousMenu.lienPourpre
                    assert(lien and lien:IsShown(), "Lien sous-menu absent")
                    assert(lien:GetFrameLevel() < c.sousMenu.secteur:GetFrameLevel(), "Lien devant le sous-menu")
                    assert(math.abs(lien.departX - entree.rx) < 0.001, "Mauvais parent du sous-menu")
                end
            end
        end
    end
    R.Fermer(id)
    __avancer(1)
    assert(not c.lienPourpre:IsShown(), "Lien principal persistant")
    assert(c.lienPourpre:GetScript("OnUpdate") == nil, "Animation principale non arretee")
    if c.sousMenu and c.sousMenu.lienPourpre then
        assert(not c.sousMenu.lienPourpre:IsShown(), "Lien sous-menu persistant")
        assert(c.sousMenu.lienPourpre:GetScript("OnUpdate") == nil, "Animation sous-menu non arretee")
    end
end
assert(total > 20, "Pas assez de branches verifiees")
print("TOUT PASSE : " .. total .. " cercles centres dans leurs couronnes et eventails")
