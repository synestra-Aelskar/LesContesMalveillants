-- Les difficultes (2 novembre 2026) : un nombre range dans une couleur de
-- metier, ajoute en seance, et le coefficient d'XP qu'il vaut selon la
-- couleur du metier de celui qui recolte.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local D, R = LCM.Difficultes, LCM.Reglages

dire("== les couleurs sont celles des metiers")
local couleurs = D.Couleurs()
-- Plus le Noir, couleur de difficulte seulement (le MJ, 2 novembre 2026).
attendu("sept couleurs", #couleurs, 7)
attendu("Rose d'abord", couleurs[1].nom, "Rose")
attendu("Violet en sixième", couleurs[6].nom, "Violet")
attendu("Noir au bout", couleurs[7].nom, "Noir")
attendu("six couleurs de métier", #D.CouleursMetier(), 6)
attendu("une difficulté Noire se pose", (D.Definir(90, 7)), true)
attendu("  elle est au-dessus d'un Violet", select(2, D.Coefficient(6, 7)), "dessus")
D.Retirer(90)

dire("== ajouter en seance")
-- Le fichier part sans difficulte : la liste vient du MJ. On ne compte pas
-- ce que la campagne aurait deja publie, on compare a avant.
local avant = #D.Liste()
attendu("ajouter 12 en Vert", (D.Definir(12, 2)), true)
attendu("ajouter 1 en Rose", (D.Definir(1, 1)), true)
attendu("ajouter 5 en Rose", (D.Definir(5, 1)), true)
local liste = D.Liste()
attendu("trois de plus", #liste, avant + 3)
attendu("rangées en ordre croissant", D.Liste()[1].valeur <= D.Liste()[2].valeur, true)
attendu("12 est Vert", D.Get(12).nom, "Vert")
attendu("c'est un réglage à exporter", R.Surcharges()["difficultes.niveaux.12"], 2)
attendu("une couleur inconnue est refusée", (D.Definir(20, 9)), false)
attendu("un nombre non entier aussi", (D.Definir(2.5, 1)), false)
D.Definir(12, 3)
attendu("recolorer : 12 passe Bleu", D.Get(12).nom, "Bleu")

dire("== le coefficient d'XP")
-- Une case par couple de couleurs depuis le 2 novembre 2026 (le MJ : « Rose
-- qui mine du Vert 1,5, du Bleu 2 ; Rouge qui mine de l'Orange 0,5, du Bleu,
-- du Vert ou du Rose 0 »). Les trois relations d'avant (0,5 / 1 / 2) sont
-- remplacees : les nombres attendus suivent la grille par defaut.
attendu("Rose qui mine du Vert : 1,5", (D.Coefficient(1, 2)), 1.5)
attendu("Rose qui mine du Bleu : 2", (D.Coefficient(1, 3)), 2)
attendu("Rouge qui mine du Rouge : 1", (D.Coefficient(5, 5)), 1)
attendu("Rouge qui mine de l'Orange : 0,5", (D.Coefficient(5, 4)), 0.5)
attendu("Rouge qui mine du Bleu : 0", (D.Coefficient(5, 3)), 0)
attendu("Bleu sur du Bleu : 1", (D.Coefficient(3, 3)), 1)
attendu("la relation est dite", select(2, D.Coefficient(3, 1)), "dessous")
-- Les coefficients sont portes par la couleur du METIER.
R.Definir(D.CheminCoefficient(6, 1), 0.1)
attendu("une case se règle seule", (D.Coefficient(6, 1)), 0.1)
attendu("  sa voisine ne bouge pas", (D.Coefficient(2, 1)), 0.5)
R.Retirer(D.CheminCoefficient(6, 1))
local moi = LCM.Entities.Personnage()
LCM.Metiers.Gagner(moi, "bucheron", LCM.Metiers.XPPourNiveau(11) - LCM.Metiers.XP(moi, "bucheron"))
attendu("un bûcheron niveau 11 est Bleu", LCM.Metiers.Palier(moi, "bucheron").rangCouleur, 3)
attendu("sur un arbre Rose, deux couleurs sous lui : rien", (D.CoefficientPour(moi, "bucheron", 5)), 0)
attendu("sur un arbre Bleu, le plein", (D.CoefficientPour(moi, "bucheron", 12)), 1)

dire("== retirer")
attendu("retirer une difficulté ajoutée", (D.Retirer(5)), true)
attendu("elle disparaît", D.Get(5), nil)
attendu("  et ne reste pas à exporter", R.Surcharges()["difficultes.niveaux.5"], nil)

dire("== l'éditeur du Panel MJ")
local p = LCM.UI.PanneauMJ.Basculer()
p:Onglet("equilibrage")
local page = p.pages.equilibrage
page:Choisir("difficultes")
local ed = page.difficultes
attendu("l'éditeur remplace le tableau", ed:IsShown() and not page.zone:IsShown(), true)
attendu("il liste les difficultés", ed.nombre, #D.Liste())
ed.nouvelle:SetText("14")
ed.couleurNouvelle.choisir(1)
ed.couleurNouvelle:Definir(1)
ed.ajouter:Click()
attendu("Ajouter pose la difficulté", D.Get(14) and D.Get(14).nom, "Rose")
attendu("  le champ se vide", ed.nouvelle:GetText(), "")
-- Le nombre se modifie sur place (2 novembre 2026) : 14 devient 16, Rose garde.
local ligneA
for _, l in ipairs(ed.lignes) do if l:IsShown() and l.difficulte == 14 then ligneA = l end end
ligneA.valeur:SetText("16")
ligneA.valeur:GetScript("OnEnterPressed")(ligneA.valeur)
attendu("la valeur change", D.Get(16) and D.Get(16).nom, "Rose")
attendu("  l'ancienne disparaît", D.Get(14), nil)
attendu("un nombre déjà pris est refusé", (D.Renumeroter(16, 1)), false)
D.Renumeroter(16, 14)
local ligne14
for _, l in ipairs(ed.lignes) do if l:IsShown() and l.difficulte == 14 then ligne14 = l end end
ligne14.couleur:Definir(4)
ligne14.couleur.choisir(4)
attendu("changer sa couleur depuis la ligne", D.Get(14).nom, "Orange")
ligne14.retirer:Click()
attendu("× la retire", D.Get(14), nil)
-- Les coefficients d'XP sont dans le tableau des metiers, avec les paliers
-- (le MJ, 2 novembre 2026), dans les memes colonnes de couleur.
attendu("plus de coefficients avec les difficultés", ed.coefs, nil)
page:Choisir("metiers")
attendu("ils sont avec les paliers des métiers", page.paliers:IsShown() and not ed:IsShown(), true)
attendu("une rangée par couleur de difficulté, Noir compris", page.paliers.coefs[3][7] ~= nil, true)
local champ = page.paliers.coefs[3][5]
champ:SetText("3")
champ:GetScript("OnEnterPressed")(champ)
attendu("un coefficient se règle dans sa case", (D.Coefficient(3, 5)), 3)
R.Retirer(D.CheminCoefficient(3, 5))
page:Choisir("pv")
attendu("un autre groupe rend le tableau", page.zone:IsShown() and not ed:IsShown(), true)

dire("== une difficulté, partout : le libellé et le NF")
-- Les difficultes servent aux epreuves et aux jets, pas qu'aux filons (le MJ,
-- 2 novembre 2026). En couleur, juste « DD 15 » : la couleur dit le palier ;
-- en texte brut, « DD 15 · Rose ».
attendu("le libellé dit la couleur", D.Libelle(1, true), "DD 1 · Rose")
attendu("  en couleur, sans le nom", __sansCouleur(D.Libelle(1)), "DD 1")
attendu("un DD hors liste le dit", D.Libelle(13, true), "DD 13 (hors liste)")
attendu("la suivante de 1 est 12", D.Suivante(1).valeur, 12)
attendu("la plus haute n'a pas de suivante", D.Suivante(12), nil)
local options = D.Options({ id = 0, label = "Sans jet" })
attendu("les options commencent par l'entrée donnée", options[1].label, "Sans jet")

local ancienRandom = math.random
math.random = function(minimum) return minimum end
-- Une Vue a 10 : le de minimal laisse un total assez haut pour poser trois
-- difficultes en dessous de lui sans tomber sous zero.
local vueAvant = LCM.Entities.Get_Value(moi, "vue")
LCM.Entities.Set_Value(moi, "vue", 10)
local base = LCM.Roll.Field(moi, "vue").total
local fatigue = LCM.Entities.Gauge(moi, "fatigue")
LCM.Entities.SetGauge(moi, "fatigue", fatigue.max, fatigue.max)
-- La liste du test : base - 5, base - 1, base, base + 4. Le jet fait toujours
-- `base`. Le NF (le MJ, 2 novembre 2026) : ATTEINDRE la difficulte deux
-- paliers au-dessus du DD (DD 9, liste 9 / 11 / 15 : il faut 15). La premiere
-- regle (faire plus que la suivante) est remplacee.
local temoins = { base - 5, base - 1, base, base + 4 }
for _, v in ipairs(temoins) do D.Definir(v, 1) end
local r1 = LCM.Roll.ResoudreExpertise(moi, "vue", base - 5, 3)
attendu("atteindre deux paliers au-dessus : réussite totale", r1 and r1.issue, "Réussite totale")
attendu("  pas de fatigue", r1 and r1.perteFatigue, 0)
attendu("  le seuil NF est la seconde au-dessus", r1 and r1.seuilNF, base)
local r2 = LCM.Roll.ResoudreExpertise(moi, "vue", base - 1, 3)
attendu("deux paliers au-dessus non atteints : partielle", r2 and r2.issue, "Réussite partielle")
attendu("  la fatigue part", r2 and r2.perteFatigue, 3)
-- La liste porte aussi les difficultes posees plus haut dans ce scenario
-- (12) : le seuil se lit dans la liste, deux crans au-dessus du DD.
attendu("  le seuil NF est deux crans au-dessus", r2 and r2.seuilNF,
    D.Suivante(D.Suivante(base - 1).valeur).valeur)
local r3 = LCM.Roll.ResoudreExpertise(moi, "vue", base, 2)
attendu("pas deux paliers au-dessus : seul le critique épargne", r3 and r3.issue, "Réussite partielle")
math.random = ancienRandom
LCM.Entities.Set_Value(moi, "vue", vueAvant)

dire("== le menu du jet d'expertise")
local cible
LCM.Schema.EachField(function(champ)
    if champ.kind == "roll" and tostring(champ.label or "") == "Équilibre" then cible = champ end
end)
local vue = LCM.UI.Vues.Fenetre("expertise")
vue:Montrer(moi)
vue:Afficher("athletisme")
local jet
for _, pg in pairs(vue.pages or {}) do
    for _, bloc in ipairs(pg.blocs or {}) do
        for _, ligne in ipairs(bloc.lignes or {}) do
            if ligne.field and ligne.field.id == cible.id then jet = ligne end
        end
    end
end
jet.lancer:Click()
local saisie = jet.saisieExpertise
attendu("avec une liste, le DD se choisit", saisie.choixDD:IsShown(), true)
attendu("  le champ libre se cache", saisie.dd:IsShown(), false)
saisie.lancer:Click()
attendu("sans DD choisi, on ne lance pas", saisie:IsShown(), true)
saisie.choixDD.choisir(12)
attendu("choisir remplit le DD du jet", saisie.dd:GetText(), "12")
saisie:Hide()
vue:Hide()
for _, v in ipairs(temoins) do D.Retirer(v) end
LCM.Entities.SetGauge(moi, "fatigue", fatigue.max, fatigue.max)

dire("== la création de ressource : un DD et une fatigue par métier")
-- Metier · Bonus · DD · Fatigue · croix (le MJ, 2 novembre 2026) : le DD n'est
-- plus celui du point, c'est celui de chaque metier.
LCM.UI.Recoltes.Basculer()
local fr = LCM.UI.Recoltes.frame
fr:Nouveau()
local cr = fr.creation
attendu("le DD du point n'est plus à l'écran", cr.choixDD:IsShown() or cr.dd:IsShown(), false)
cr.metier:Click()
for _, ligne in ipairs(fr.choixMetier.lignes) do
    if ligne:IsShown() and ligne.choix == "bucheron" then ligne:Click() end
end
local lm = cr.lignesMetiers[1]
attendu("la ligne propose le DD en menu", lm.dd:IsShown() and not lm.ddLibre:IsShown(), true)
attendu("  elle part sans jet", lm.dd.label:GetText(), "Sans jet (DD 0)")
lm.dd.choisir(12)
attendu("choisir pose le DD de CE métier", fr.travail.recolte.metiers[1].dd, 12)
lm.fatigue:Saisir("3")
attendu("la fatigue se règle sur la ligne", fr.travail.recolte.metiers[1].fatigue, "3")
fr.travail.recolte.metiers[1].dd = 13
fr:AfficherMetiers()
attendu("un DD hors liste se garde et le dit", lm.dd.label:GetText(), "DD 13 (hors liste)")
fr:Hide()

dire("== les coffres : le DD de chaque méthode, en menu")
SlashCmdList.LCM("coffres")
local ed = LCM.UI.CoffresMJ.frame
ed:Nouveau()
ed.ajouterExpertise:Click()
for _, ligne in ipairs(ed.choixExpertise.lignes) do
    if ligne:IsShown() and ligne.choix == "vue" then ligne:Click() end
end
local lc = ed.lignesExpertises[1]
attendu("le DD se choisit dans la liste", lc.choixDD:IsShown() and not lc.dd:IsShown(), true)
lc.choixDD.choisir(12)
attendu("  il se pose sur la méthode", ed.travail.coffre.expertises[1].dd, 12)
attendu("  et le champ que la validation lit suit", lc.dd:GetText(), "12")
ed:Hide()

dire("== le jet de récolte lit la ligne")
local Rc = LCM.Recolte
local def = { id = "essai_diff", label = "Arbre témoin", dd = 99, metiers = {
    { id = "bucheron", bonus = true, dd = 1, fatigue = 2 },
} }
local jauge = LCM.Entities.Gauge(moi, "fatigue")
LCM.Entities.SetGauge(moi, "fatigue", 5, jauge.max)
local r = Rc.Jet(moi, def)
attendu("le DD est celui de la ligne, pas du point", r and r.dd, 1)
attendu("  la fatigue de la ligne se paie", LCM.Entities.Gauge(moi, "fatigue").current, 3)
LCM.Entities.SetGauge(moi, "fatigue", 1, jauge.max)
local refus, raison = Rc.Jet(moi, def)
attendu("sans assez de PF, la tentative est refusée", refus, nil)
attendu("  et on dit pourquoi", raison, "fatigue insuffisante : cette récolte coûte 2 PF.")
LCM.Entities.SetGauge(moi, "fatigue", jauge.max, jauge.max)
local ancien = { id = "essai_ancien", label = "Filon d'avant", dd = 7,
    metiers = { { id = "bucheron", bonus = true } } }
attendu("une ligne d'avant, sans DD, prend celui du point", Rc.Jet(moi, ancien).dd, 7)

D.Retirer(1)
D.Retirer(12)
LCM.Metiers.Gagner(moi, "bucheron", -LCM.Metiers.XP(moi, "bucheron"))
print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
