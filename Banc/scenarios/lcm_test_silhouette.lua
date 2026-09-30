local function dire(...) print(table.concat({...}, " ")) end
__declencher("PLAYER_LOGIN")
local boss = LCM.Entities.Create("chose", "La Chose", "npc")
LCM.Entities.Set_Value(boss, "morphologie", "aberration")
LCM.Entities.Set_Value(boss, "pv_max_override", 400)
local f = LCM.UI.Fiche.Fenetre()
f:Montrer(boss)
local ligne
for _, l in ipairs(f.pages.general.lignes) do if l.silhouette then ligne = l end end
local n = 0
for _, p in ipairs(ligne.silhouette.parties) do if p:IsShown() then n = n + 1 end end
dire("parties dessinees :", n)
dire("total :", ligne.total:GetText())
local rangees = {}
for _, p in ipairs(ligne.silhouette.parties) do
  if p:IsShown() then
    local r = p.donnees.part.row
    rangees[r] = (rangees[r] or 0) + 1
  end
end
for r = 1, 4 do if rangees[r] then dire("  rangee " .. r .. " :", rangees[r], "parties") end end
