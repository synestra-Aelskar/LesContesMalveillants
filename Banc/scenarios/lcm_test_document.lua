-- La documentation en jeu : liste, page defilante, titres du modele.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")

dire("== ouverture")
SlashCmdList.LCM("doc")
local f = LCM.UI.Document.frame
attendu("ouverte", f:IsShown(), true)
attendu("titre du modele", f.titre:GetText(), "DOCUMENTATION")
attendu("un bouton par document", #f.liste.boutons, #LCM.Documents.Visibles())
attendu("le premier est choisi", f.liste.boutons[1].__selectionne, true)

dire("== la page")
attendu("la page defile et se rogne", f.zone:DoesClipChildren(), true)
local titre = f.page.blocs[1]
attendu("l'aide commence par le titre du jeu", titre:GetText(), "LES CONTES MALVEILLANTS")
local precedent, ordonne = 1, true
for index, fs in ipairs(f.page.blocs) do
    if fs:IsShown() then
        local _, _, _, _, y = fs:GetPoint(1)
        if index > 1 and y > precedent then ordonne = false end
        precedent = y
    end
end
attendu("les blocs se suivent sans remonter", ordonne, true)
attendu("hauteur mesuree", f.hauteur > 0, true)

dire("== changer de document")
f.liste.boutons[2]:Click()
attendu("second document", f.documentId, LCM.Documents.Visibles()[2].id)
attendu("son bouton est choisi", f.liste.boutons[2].__selectionne, true)
attendu("l'autre ne l'est plus", f.liste.boutons[1].__selectionne, false)

SlashCmdList.LCM("doc")
attendu("fermee", f:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
