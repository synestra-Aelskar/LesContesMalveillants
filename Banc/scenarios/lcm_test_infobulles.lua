-- Couverture des textes d'aide sur les champs visibles de la fiche.
local manquants = {}
LCM.Schema.EachField(function(field)
    if not field.masque and (not field.note or field.note == "") then
        manquants[#manquants + 1] = field.id .. " | " .. field.label .. " | " .. field.kind
    end
end)
for _, ligne in ipairs(manquants) do print(ligne) end
assert(#manquants == 0, #manquants .. " champ(s) visible(s) sans infobulle")
print("TOUT PASSE : chaque champ visible de la fiche a une description")
