-- Chaque ligne consultable de creation dispose d'une explication.
local manquants = {}
for _, categorie in ipairs({ "primaires", "secondaires", "expertises", "mecaniques", "penetration", "resistance" }) do
    for _, ligne in ipairs(LCM.Creation.Lignes(categorie)) do
        local note = ligne.note or LCM.Creation.Note(categorie, ligne.id)
        if not note or note == "" then manquants[#manquants + 1] = categorie .. "/" .. ligne.id end
    end
end
assert(#manquants == 0, "Survols manquants : " .. table.concat(manquants, ", "))
print("TOUT PASSE : chaque ligne de repartition a une description")
