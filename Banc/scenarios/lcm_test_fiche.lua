-- La Fiche, organisee comme celle du template : onglets Statistiques,
-- Facultes, Traits ; blocs, lignes, en-tete, defilement.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")

local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "humain")
LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.Set_Value(moi, "constitution", 6)
LCM.Entities.Set_Value(moi, "sec_vitalite", 4)
LCM.Entities.Set_Value(moi, "force", 4)
LCM.Entities.Set_Value(moi, "adresse", 3)

dire("== ouverture")
SlashCmdList.LCM("fiche")
local f = LCM.UI.Fiche.frame
attendu("la fenetre existe", f ~= nil, true)
attendu("elle est affichee", f:IsShown(), true)
attendu("elle porte le nom de l entite", f.nom:GetText(), "Reika")
attendu("titre en capitales", f.titre:GetText(), "FICHE")
-- Le nom vit dans l'en-tete : entre le titre et le filet d'or, pas dessus.
local _, _, _, _, yTitre = f.titre:GetPoint(1)
local _, _, _, _, yNom = f.sousTitre:GetPoint(1)
local _, _, _, _, yRegle = f.regle:GetPoint(1)
attendu("le nom est sous le titre", yNom < yTitre, true)
-- Le bas du texte, pas son centre, et mesure sur sa police : un « 7 » en dur
-- ne veut plus rien dire des qu'une fenetre change de largeur.
local hautNom = select(2, f.sousTitre:GetFont()) / 2
attendu("et au-dessus du filet", yNom - hautNom > yRegle, true)

dire("== les onglets du template")
local noms = {}
for _, b in ipairs(f.barre.boutons) do noms[#noms + 1] = b.label:GetText() end
attendu("trois onglets", table.concat(noms, ", "), "Statistiques, Facultés, Traits")
attendu("le premier est actif", f.barre.actif, "statistiques")
attendu("sa page est visible", f.pages.statistiques:IsShown(), true)
attendu("les autres non", f.pages.facultes:IsShown(), false)
local largeurBandeau = f.barre:GetWidth()
local finRangee = 0
for _, b in ipairs(f.barre.boutons) do
    local _, _, _, x = b:GetPoint(1)
    finRangee = math.max(finRangee, (x or 0) + b:GetWidth())
end
attendu("aucun onglet ne deborde", finRangee <= largeurBandeau + 0.5, true)
attendu("onglet actif dore", select(1, f.barre.boutons[1].label:GetTextColor()) > 0.95, true)

dire("== Statistiques : les blocs du template, dans l'ordre")
local page = f.pages.statistiques
local titres = {}
for _, bloc in ipairs(page.blocs) do titres[#titres + 1] = bloc.titre and bloc.titre:GetText() or "?" end
attendu("blocs", table.concat(titres, ", "), "GÉNÉRALE, STATISTIQUES, CARACTÉRISTIQUES, DÉPLACEMENT")
local generale = {}
for _, l in ipairs(page.blocs[1].lignes) do generale[#generale + 1] = l.field.id end
attendu("Generale", table.concat(generale, ","), "corps,armure,fatigue,pa")
local corps = page.blocs[1].lignes[1]
attendu("les PV seuls (les zones sont dans Sante)", #corps.zones, 0)
attendu("jauge des PV", corps.total.barre.label:GetText(), "42 / 42")
attendu("six statistiques", #page.blocs[2].lignes, 6)

dire("== rien ne traine a droite d'une ligne")
-- Le gabarit arrete sa derniere colonne a 762 unites sur 786 ; reportees
-- telles quelles, ces 24 unites laissaient une bande vide entre le dernier
-- bouton et le bord. Les colonnes de droite se calent donc sur le bord.
local L = LCM.Vues.Get("fiche").largeur - 24 - 2 * LCM.UI.Fiche.MARGE_BLOC
local col = LCM.UI.AelColonnes(L)
attendu("le dernier bouton finit au bord", col.boutons[3] + col.boutonL, L)
attendu("le bouton d'action aussi", col.action + col.actionLargeur, L)
attendu("et la jauge s'arrete juste avant les boutons", col.barreFin < col.boutons[1], true)

dire("== une icone n'ecrase pas son libelle")
-- `Fiche.Nom` a deux colonnes : avec icone et sans. Oublier de dire laquelle
-- pose le texte a l'interieur de l'icone — c'est arrive sur les trois types de
-- ligne a la fois le 1er octobre 2026.
local function nomApresIcone(ligne)
    if not ligne.icone then return true end
    local _, _, _, xIcone = ligne.icone:GetPoint(1)
    local _, _, _, xNom = ligne.nom:GetPoint(1)
    return (xNom or 0) >= (xIcone or 0) + (ligne.icone:GetWidth() or 0)
end
local chevauche, avecIcone = 0, 0
for _, bloc in ipairs(page.blocs) do
    for _, ligne in ipairs(bloc.lignes) do
        if ligne.icone and ligne.nom then
            avecIcone = avecIcone + 1
            if not nomApresIcone(ligne) then chevauche = chevauche + 1 end
        end
    end
end
attendu("des lignes portent une icone", avecIcone > 0, true)
attendu("aucun libelle sous son icone", chevauche, 0)
attendu("initiative", page.blocs[3].lignes[1].field.id, "initiative")
attendu("deplacement", #page.blocs[4].lignes, 2)

dire("== Facultes (formules du template)")
f.barre.boutons[2]:Click()
local fac = f.pages.facultes
attendu("bloc Physiques", fac.blocs[1].titre:GetText(), "PHYSIQUES")
local valeurs = {}
for _, l in ipairs(fac.lignes) do valeurs[l.field.id] = l.valeur:GetText() end
-- 5 + 5 x 4 = 25 ; 4/2 + 3/3 = 3 ; 4/2 + 3/4 = 2,75
attendu("poids soulevable", valeurs.poids_soulevable, "25")
attendu("saut horizontal", valeurs.saut_horizontal, "3")
attendu("saut vertical", valeurs.saut_vertical, "2.75")

dire("== Traits")
f.barre.boutons[3]:Click()
attendu("la liste des traits", f.pages.traits.lignes[1].field.id, "traits_portes")

dire("== ce qui depasse reste dans la fenetre")
f.barre.boutons[1]:Click()
local zone = f.zone
attendu("la zone rogne ce qui depasse", zone:DoesClipChildren(), true)
zone:SetHeight(300)
zone:Regler(page.hauteur)
attendu("la page est plus haute que la zone", page.hauteur > 300, true)
attendu("la barre apparait", zone.barre:IsShown(), true)
zone:GetScript("OnMouseWheel")(zone, -1)
attendu("la molette descend", zone.decalage > 0, true)
for _ = 1, 100 do zone:GetScript("OnMouseWheel")(zone, -1) end
attendu("sans depasser le bas", zone.decalage, zone.debord)
zone:Aller(-50)
attendu("ni le haut", zone.decalage, 0)
zone:Regler(100)
attendu("contenu court : pas de barre", zone.barre:IsShown(), false)

dire("== fermeture")
SlashCmdList.LCM("fiche")
attendu("la fenetre se referme", f:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
