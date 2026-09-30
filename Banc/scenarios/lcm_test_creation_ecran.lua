-- L'ecran de creation, organise comme la Creation du template : sept onglets,
-- textes, grilles de repartition, refus visibles.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function dernierMessage() return __sansCouleur(__sorties[#__sorties] or "") end
local function compteur(page, champ)
    for _, c in ipairs(page.compteurs) do if c.champ == champ then return c end end
end
local function budget(page, categorie)
    for _, b in ipairs(page.budgets) do if b.categorie == categorie then return b end end
end

__declencher("PLAYER_LOGIN")

dire("== le bouton + du carrousel ouvre la creation")
local carrousel = LCM.UI.Personnages.Ouvrir()
carrousel.creer:Click()
local f = LCM.UI.Creation.frame
attendu("fenetre ouverte", f:IsShown(), true)
local noms = {}
for _, b in ipairs(f.barre.boutons) do noms[#noms + 1] = b.label:GetText() end
attendu("les onglets du template", table.concat(noms, ", "),
    "Bienvenue, Générale, Statistiques, Expertises, Pénétrations, Résistances, Traits")
attendu("on demarre sur Bienvenue", f.etape, "bienvenue")
attendu("brouillon neuf", f.brouillon.nom, "")
attendu("les textes du template", f.pages.bienvenue.blocs[1].paragraphe:GetText():find("Syn ou Talyah") ~= nil, true)
local finRangee = 0
for _, b in ipairs(f.barre.boutons) do
    local _, _, _, x = b:GetPoint(1)
    finRangee = math.max(finRangee, (x or 0) + b:GetWidth())
end
attendu("aucun onglet ne deborde", finRangee <= f.barre:GetWidth() + 0.5, true)

dire("== Generale : identite, race, niveau, points")
f.barre.boutons[2]:Click()
local g = f.pages.generale
attendu("niveau de depart affiche", g.niveau.valeur, 5)
attendu("une race proposee", #g.races, 1)
attendu("nom du bouton de race", g.races[1].label:GetText(), "Humain")
attendu("creation bloquee", f.valider:IsEnabled(), false)
attendu("et on dit pourquoi", f.probleme:GetText(), "il faut un nom.")
g.nom:Saisir("Ysolde")
attendu("nom retenu", f.brouillon.nom, "Ysolde")
attendu("il manque encore la race", f.probleme:GetText(), "il faut choisir une race.")
g.races[1]:Click()
attendu("race retenue", f.brouillon.race, "humain")
attendu("creation possible", f.valider:IsEnabled(), true)
g.age:Saisir("28")
attendu("age retenu", f.brouillon.valeurs.age, 28)
g.poids:Saisir("64")
attendu("poids retenu", f.brouillon.valeurs.poids, 64)
g.sexes[1]:Click()
attendu("sexe retenu", f.brouillon.valeurs.sexe, "Féminin")
-- 17 + 3 x 5 ; 12 + 4 x 5 ; 8 + 2 x 5
attendu("points de statistiques", g.infos[1].valeur:GetText(), "32")
attendu("points secondaires", g.infos[2].valeur:GetText(), "32")
attendu("points d'expertises", g.infos[3].valeur:GetText(), "18")

dire("== Statistiques : primaires")
f.barre.boutons[3]:Click()
local st = f.pages.statistiques
attendu("page affichee", f.etape, "statistiques")
local force = compteur(st, "force")
attendu("plafond lu du moteur (5 + 4)", force.plafond, 9)
for _ = 1, 9 do force.plus:Click() end
attendu("neuf clics, neuf points", f.brouillon.valeurs.force, 9)
attendu("budget dans le titre du bloc", budget(st, "primaires").budget:GetText(), "23 / 32")
force.plus:Click()
attendu("le dixieme est refuse", f.brouillon.valeurs.force, 9)
attendu("et il est explique", dernierMessage():find("plafond") ~= nil, true)
force.moins:Click()
attendu("on peut redescendre", f.brouillon.valeurs.force, 8)
force.remise:Click()
attendu("R remet la ligne a zero", f.brouillon.valeurs.force, nil)
local adresse = compteur(st, "adresse")
attendu("plafond de l'adresse (5 + 2)", adresse.plafond, 7)
adresse.maximum:Click()
attendu("M monte au plafond", LCM.Creation.Valeur(f.brouillon, "adresse"), 7)
attendu("deux points le cran", LCM.Creation.Depense(f.brouillon, "primaires"), 14)
budget(st, "primaires").remise:Click()
attendu("le R du bloc vide la categorie", LCM.Creation.Depense(f.brouillon, "primaires"), 0)
for _ = 1, 8 do force.plus:Click() end

dire("== Statistiques : l'apercu suit la repartition")
local constitution = compteur(st, "constitution")
for _ = 1, 4 do constitution.plus:Click() end
-- PV : 2 + 7,5 + 0 + 4 x (2 + 4 x 0,25) = 21,5 -> 21 ; Fatigue : 15 + 10 + 0 + 8 + 1 = 34
attendu("points de vie", st.pv.valeur:GetText(), "21")
attendu("fatigue", st.fatigue.valeur:GetText(), "34")
for _ = 1, 4 do constitution.moins:Click() end

dire("== Statistiques : secondaires et leur cout")
local pa = compteur(st, "sec_pa")
pa.plus:Click()
attendu("un point d'action pris", f.brouillon.valeurs.sec_pa, 1)
attendu("huit points depenses", LCM.Creation.Depense(f.brouillon, "secondaires"), 8)
attendu("budget secondaire", budget(st, "secondaires").budget:GetText(), "24 / 32")
local sec = compteur(st, "sec_expertises")
for _ = 1, 3 do sec.plus:Click() end
attendu("expertises : deux points le cran (template)", LCM.Creation.Depense(f.brouillon, "secondaires"), 14)

dire("== Expertises et mecaniques")
f.barre.boutons[4]:Click()
local ex = f.pages.expertises
attendu("page expertises", f.etape, "expertises")
local n = 0
for _, c in ipairs(ex.compteurs) do if c.categorie == "expertises" then n = n + 1 end end
attendu("25 expertises", n, 25)
attendu("budget 18 + 3 x 2", budget(ex, "expertises").budget:GetText(), "24 / 24")
local soin = compteur(ex, "meca_soin")
attendu("les mecaniques dans le meme onglet", soin ~= nil, true)
attendu("plafond d'une mecanique", soin.plafond, 10)
for _ = 1, 4 do soin.plus:Click() end
attendu("quatre points de soin", f.brouillon.valeurs.meca_soin, 4)

dire("== Penetrations")
f.barre.boutons[5]:Click()
local pen = f.pages.penetrations
attendu("15 types", #pen.compteurs, 15)
local tranchant = compteur(pen, "pen_tranchant")
-- force 8 -> 8 / 1,75 = 4, plus la base de 3.
attendu("plafond suivant la force investie", tranchant.plafond, 7)
for _ = 1, 7 do tranchant.plus:Click() end
attendu("sept points poses", f.brouillon.valeurs.pen_tranchant, 7)

dire("== Resistances")
f.barre.boutons[6]:Click()
local res = f.pages.resistances
attendu("15 types", #res.compteurs, 15)
attendu("plafond 3 + Constitution / 0,25 (sans constitution)", compteur(res, "resi_feu").plafond, 3)

dire("== baisser la force fait apparaitre le debordement")
f.barre.boutons[3]:Click()
for _ = 1, 8 do compteur(st, "force").moins:Click() end
attendu("la creation est bloquee", f.valider:IsEnabled(), false)
attendu("le debordement est nomme", f.probleme:GetText():find("Tranchant") ~= nil, true)
f.barre.boutons[5]:Click()
attendu("la ligne est marquee", tranchant.valeur > tranchant.plafond, true)

dire("== Traits : des emplacements, pas de liste a prendre ou laisser")
f.barre.boutons[7]:Click()
local tr = f.pages.traits
attendu("traits totaux : 2 + 5/5", budget(tr, "traits").budget:GetText(), "3 / 3")
attendu("plus de liste de traits", tr.traits, nil)
attendu("une case libre", #tr.emplacements, 1)
attendu("vide : Emplacement", tr.emplacements[1].nom:GetText(), "Emplacement")
LCM.Creation.AjouterTrait(f.brouillon, LCM.Traits.list[1].id)
f:Actualiser()
attendu("un trait pris occupe une case", tr.emplacements[1].nom:GetText(), LCM.Traits.list[1].label)
attendu("et une case libre suit", tr.emplacements[2]:IsShown() and tr.emplacements[2].nom:GetText(), "Emplacement")
LCM.Creation.RetirerTrait(f.brouillon, LCM.Traits.list[1].id)
f:Actualiser()
attendu("retire : une seule case", tr.emplacements[2]:IsShown(), false)

dire("== la page defile quand elle depasse")
attendu("la zone rogne", f.zone:DoesClipChildren(), true)
f.barre.boutons[4]:Click()
attendu("la page expertises est longue", ex.hauteur > 400, true)
attendu("et la zone le sait", f.zone.hauteurContenu, ex.hauteur)

dire("== tout remettre a zero, avec confirmation")
f.barre.boutons[3]:Click()
for _ = 1, 3 do compteur(st, "force").plus:Click() end
attendu("des points depenses", LCM.Creation.Depense(f.brouillon, "primaires"), 3)
f.remiseTotale:Click()
attendu("on demande confirmation", f.confirmation:IsShown(), true)
attendu("rien n'a bouge", LCM.Creation.Depense(f.brouillon, "primaires"), 3)
f.confirmation.non:Click()
attendu("annuler ne touche a rien", LCM.Creation.Depense(f.brouillon, "primaires"), 3)
f.remiseTotale:Click()
f.confirmation.oui:Click()
attendu("confirme : tout est rendu", LCM.Creation.Depense(f.brouillon, "primaires"), 0)
attendu("le nom est conserve", f.brouillon.nom, "Ysolde")
attendu("la race aussi", f.brouillon.race, "humain")

dire("== creer le personnage")
attendu("plus de debordement", #LCM.Creation.Debordements(f.brouillon), 0)
attendu("creation possible", f.valider:IsEnabled(), true)
f.valider:Click()
attendu("la fenetre se ferme", f:IsShown(), false)
attendu("le personnage existe", LCM.Personnages.Compte(), 1)
attendu("et il est joue", LCM.Entities.Self().name, "Ysolde")
attendu("sa fiche s'ouvre", LCM.UI.Fiche.frame:IsShown(), true)

dire("== rouvrir repart d'un brouillon neuf")
LCM.UI.Creation.Ouvrir()
attendu("nom vide", f.brouillon.nom, "")
attendu("aucune valeur", next(f.brouillon.valeurs), nil)
attendu("sur Bienvenue", f.etape, "bienvenue")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
