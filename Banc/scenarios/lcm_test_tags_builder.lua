local function verifier(condition, message)
    if not condition then error(message, 0) end
end

__declencher("PLAYER_LOGIN")
__personnage()

-- Les tags de la campagne ecartes (3 novembre 2026) : le menu des parents
-- se mesure sur les deux tags du test, pas sur ceux de la seance.
for _, t in ipairs(LCM.Etiquettes.Liste()) do LCM.Listes.Retirer(t.id) end
local origine = LCM.Listes.Add({ id = "origine_builder_test", liste = "origines", label = "Origine du test" })
local autreOrigine = LCM.Listes.Add({ id = "autre_origine_builder_test", liste = "origines", label = "Autre origine" })
local compendium = LCM.UI.Compendium.Ouvrir("liste_tags")
local fenetre = LCM.UI.Compendium.frame or compendium
verifier(fenetre.nouveauTag:IsShown(), "bouton Nouveau Tag + absent")
verifier(not fenetre.nouvelle:IsShown(), "ancien bouton de creation visible dans Tags")
fenetre.nouveauTag:Click()

local editeur = LCM.TagsUI and LCM.TagsUI.frame
verifier(editeur and editeur:IsShown(), "constructeur de tag absent")
verifier(editeur.nom and editeur.origine and editeur.parent and editeur.description,
    "champs du constructeur absents")
editeur.nom:SetText("Tag de test")
editeur.description:SetText("Description du tag")
editeur.travail.icone = "INV_Sword_05"
editeur.origine:Click()
for _, ligne in ipairs(editeur.choixOrigine.cases) do
    if ligne:IsShown() and (ligne.id == origine.id or ligne.id == autreOrigine.id) then ligne:Click() end
end
editeur.choixOrigine.valider:Click()
verifier(#editeur.travail.origines == 2, "Liste origine ne permet pas plusieurs choix")
editeur:Valider()

local tag
for _, entree in ipairs(LCM.Etiquettes.Liste()) do
    if entree.label == "Tag de test" then tag = entree break end
end
verifier(tag and #LCM.Etiquettes.Origines(tag) == 2, "origines du tag non enregistrees")
verifier(tag.description == "Description du tag", "description du tag non enregistree")
verifier(tag.icone == "Interface\\Icons\\INV_Sword_05", "icone du tag non enregistree")

fenetre.nouveauTag:Click()
editeur.nom:SetText("Enfant de test")
editeur.parent:Click()
local ancrage, relatif = editeur.choixParent:GetPoint()
verifier(ancrage == "TOPLEFT" and relatif == editeur.parent,
    "le menu parent n'est pas ancre sous le champ")
verifier(editeur.choixParent:GetHeight() <= 70, "menu parent trop haut pour deux choix")
for _, ligne in ipairs(editeur.choixParent.lignes) do
    if ligne:IsShown() and ligne.choix == tag.id then ligne:Click() break end
end
verifier(editeur.travail.parent == tag.id, "le tag parent n'est pas proposé")
editeur.origine:Click()
for _, ligne in ipairs(editeur.choixOrigine.cases) do
    if ligne:IsShown() and ligne.id == autreOrigine.id then ligne:Click() break end
end
editeur.choixOrigine.valider:Click()
editeur:Valider()
local enfant
for _, entree in ipairs(LCM.Etiquettes.Liste()) do
    if entree.label == "Enfant de test" then enfant = entree break end
end
verifier(enfant and enfant.parent == tag.id, "parent du tag non enregistre")
verifier(LCM.Etiquettes.Origine(enfant) == origine.id, "origine non heritee")
verifier(#LCM.Etiquettes.Origines(enfant) == 1, "le sous-tag n'a pas perdu l'autre origine")
local groupes = LCM.Etiquettes.Groupes()
local vu = {}
for _, groupe in ipairs(groupes) do
    for _, ligne in ipairs(groupe.tags) do
        if ligne.tag.id == enfant.id then vu[groupe.id] = true end
    end
end
verifier(vu[origine.id] and not vu[autreOrigine.id], "le sous-tag apparait dans la mauvaise origine")
local horsParent = LCM.Brouillons.Enregistrer("listes", {
    id = enfant.id, liste = "tags", label = enfant.label, parent = tag.id,
    origines = { "origine_hors_parent" },
}, false)
verifier(not horsParent, "origine absente acceptee")

local ok = LCM.Brouillons.Enregistrer("listes", {
    id = tag.id, liste = "tags", label = tag.label, parent = enfant.id,
}, false)
verifier(not ok, "cycle parent-enfant accepte")
print("TOUT PASSE")
