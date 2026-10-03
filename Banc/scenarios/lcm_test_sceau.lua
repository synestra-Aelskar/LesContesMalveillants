-- Le sceau se glisse a la main : il reste sous le point saisi meme pour un
-- geste vif, un petit tremblement reste un clic, et sa place est retenue.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = obtenu == voulu
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()   -- sans personnage, le clic ouvre la creation, pas le menu
local f = LCM.UI.Radial.Fenetre()
LCM.UI.Radial.Placer()
local x0, y0 = f:GetCenter()

local function Appuyer(x, y)
    __curseur = { x, y }
    __souris.LeftButton = true
    f.sceau:GetScript("OnMouseDown")(f.sceau, "LeftButton")
end
local function Aller(x, y)
    __curseur = { x, y }
    __avancer(0.02, 0.02)
end

dire("== Un geste vif : le sceau reste sous le point saisi")
-- Saisi 10 px a droite et 5 px au-dessus de son centre.
Appuyer(x0 + 10, y0 + 5)
Aller(x0 + 600, y0 + 300)   -- d'un coup, loin hors du sceau
local x, y = f:GetCenter()
attendu("suit en x", math.floor(x + 0.5), math.floor(x0 + 590 + 0.5))
attendu("suit en y", math.floor(y + 0.5), math.floor(y0 + 295 + 0.5))
attendu("c'est un glisser", f.glisse, true)
Aller(x0 - 300, y0 + 100)
x, y = f:GetCenter()
attendu("suit encore", math.floor(x + 0.5), math.floor(x0 - 310 + 0.5))

dire("== Relache hors du sceau : le glisser s'arrete et la place est retenue")
__souris.LeftButton = false
Aller(x0 - 300, y0 + 100)
attendu("plus de suivi", f.glisseur:GetScript("OnUpdate"), nil)
Aller(x0 + 50, y0 + 50)
x, y = f:GetCenter()
attendu("ne bouge plus", math.floor(x + 0.5), math.floor(x0 - 310 + 0.5))
local cx, cy = UIParent:GetCenter()
attendu("place retenue (x)", math.floor(LCM.db.settings.radial.x + 0.5), math.floor(x0 - 310 - cx + 0.5))
attendu("place retenue (y)", math.floor(LCM.db.settings.radial.y + 0.5), math.floor(y0 + 95 - cy + 0.5))

-- Le clic qui termine un glisser n'ouvre pas le menu.
f.sceau:Click("LeftButton")
attendu("fin de glisser avalee", f.couronnes.fenetres.orbite:IsShown(), false)

dire("== Un tremblement reste un clic")
LCM.UI.Radial.Placer()
local px, py = f:GetCenter()
attendu("replace a sa place retenue", math.floor(px + 0.5), math.floor(x0 - 310 + 0.5))
Appuyer(px, py)
Aller(px + 2, py + 1)
attendu("pas un glisser", f.glisse, false)
local qx = f:GetCenter()
attendu("pas bouge", math.floor(qx + 0.5), math.floor(px + 0.5))
__souris.LeftButton = false
f.sceau:GetScript("OnMouseUp")(f.sceau, "LeftButton")
f.sceau:Click("LeftButton")
attendu("le clic ouvre le menu", f.couronnes.fenetres.orbite:IsShown(), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
