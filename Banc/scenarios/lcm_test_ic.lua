-- Fixtures propres : aucun objet ni bareme de campagne.
__declencher("PLAYER_LOGIN")
local IC,F,B,U=LCM.IC,LCM.Forge,LCM.Brouillons,LCM.UI.Forge
assert(#IC.ordre==0,"le catalogue livré doit rester vide")
local budgets={0,3,6,10,15,21,50}
for i,id in ipairs(LCM.Equilibrage.ic.ordre) do assert(IC.Pool(id)==budgets[i],id) end
assert(IC.Lire(nil)==nil,"pas de migration ecrite a la lecture")
assert(IC.Description(nil)=="","aucune propriete fictive")
assert(IC.Palier({id="rare",couleur="FF0000"})=="bleu","couleur non mecanique")
assert(IC.Palier({id="custom",couleur="4D8CFF"})==nil,"pas de deduction par couleur")
local jeu={id="ic_temoin",label="IC témoin",categorie="armes",raretes={
    {id="rare",label="Bleu",couleur="4D8CFF",points=4},
    {id="custom",label="Autre",couleur="FFFFFF",points=2,palierIC="vert"},
    {id="commun",label="Rose",couleur="FF8CB8",points=1}},champs={}}
assert(B.Enregistrer("jeux",jeu,true))
jeu=F.Get(jeu.id)
assert(jeu.raretes[1].palierIC=="bleu","palier explicite dans le registre")
local ic=IC.Nouveau("bleu"); ic.convertis=3
assert(not IC.Verifier(ic,nil,{id="sans_palier"}),"une rarete personnalisee exige un palier explicite")
local ancien=F.Bilan(jeu,"rare",{force=-100},2,40)
local neuf=F.Bilan(jeu,"rare",{force=-100},2,40,ic)
assert(neuf.pool==ancien.pool+0.75,"conversion apres multiplicateur")
assert(neuf.creditRetenu==ancien.creditRetenu,"plafond des malus inchange")
assert(IC.Bilan(ic).total==6 and IC.Bilan(ic).restants==3)
local function Objet(id)
    return {id=id,label="Objet IC témoin",categorie="arme",forge="ic_temoin/rare",taille=1,
        bonus={},etat={courant=40,max=40,version=2},ic=LCM.Copie(ic)}
end
local def=Objet("ic_objet")
assert(B.Enregistrer("objets",def,true))
assert(LCM.Objets.Get(def.id).ic.convertis==3)
local partage=LCM.Echange.DefinitionPartagee("objets/"..def.id)
assert(partage.ic.convertis==3,"l'echange conserve les choix IC")
assert(LCM.Lien.Deserialiser(partage.icSerialise).convertis==3,"corps IC type")
partage.ic.convertis=0
assert(LCM.Objets.Get(def.id).ic.convertis==3,"partage sans alias vers le catalogue")
assert(LCM.Echange.ImporterPartage({ref="objets/"..def.id,definition=partage}))
assert(LCM.Objets.Get(def.id).ic.convertis==3,"corps type prioritaire en reception")
local revert=LCM.Copie(def); revert.ic.convertis=2
assert(not B.Enregistrer("objets",revert),"conversion irreversible au point d'enregistrement")
revert.ic=nil
assert(not B.Enregistrer("objets",revert),"supprimer le bloc IC ne rembourse pas")
local trop=Objet("ic_trop"); trop.ic.convertis=7
assert(not B.Enregistrer("objets",trop,true),"depassement refuse")
local fraction=Objet("ic_fraction"); fraction.ic.convertis=0.5
assert(not B.Enregistrer("objets",fraction,true),"IC convertis entiers")
local code=Objet("ic_code"); code.ic.code=function() end
assert(not B.Enregistrer("objets",code,true),"aucun code embarque dans les donnees")
local bas=LCM.Copie(def); bas.forge="ic_temoin/commun"; bas.ic.palier="rose"
assert(not B.Enregistrer("objets",bas),"diminution rarete refusee sans rabotage")
assert(LCM.Objets.Get(def.id).ic.convertis==3)
local legacy=Objet("ic_ancien"); legacy.ic=nil
assert(B.Enregistrer("objets",legacy,true))
assert(LCM.Objets.Get(legacy.id).ic==nil)
local wire=LCM.Reseau.Decoder(LCM.Reseau.Encoder(def))
local recu=LCM.Objets.Construire(wire)
assert(recu.ic.convertis==3 and #recu.ic.proprietes==0,"reseau conserve aussi les listes vides")

print("== Forge : panneau, conversion, annulation, sauvegarde")
assert(U.OuvrirEdition(LCM.Compendium.Get("armes"),LCM.Objets.Get(def.id)))
local f=U.frame
assert(f.panelIC:IsShown() and f:GetWidth()==890)
assert(not f.panelIC.moins:IsEnabled(),"plancher apres sauvegarde")
f.panelIC.plus:Click()
assert(U.Definition().ic.convertis==4)
f.panelIC.moins:Click()
assert(U.Definition().ic.convertis==3,"annulation de la conversion non enregistree")
f.panelIC.plus:Click(); f:Hide()
assert(LCM.Objets.Get(def.id).ic.convertis==3,"fermer ne sauvegarde rien")
assert(U.OuvrirEdition(LCM.Compendium.Get("armes"),LCM.Objets.Get(def.id)))
f.panelIC.plus:Click()
assert(U.Creer())
f:Rafraichir()
assert(LCM.Objets.Get(def.id).ic.convertis==4 and not f.panelIC.moins:IsEnabled())
local rendu
assert(U.OuvrirPourBonus("armes",{},"ic_temoin/rare",function(bonus,forge,etat,choix) rendu=choix end,1,{max=40},LCM.Objets.Get(def.id).ic))
f.panelIC.plus:Click(); f:Creer()
assert(rendu and rendu.convertis==5,"aller retour atelier")
-- Revenir a la forge depuis un formulaire non enregistre n'engage pas ses IC.
assert(U.OuvrirPourBonus("armes",{},"ic_temoin/rare",function() end,1,{max=40},rendu,4))
f.panelIC.moins:Click()
assert(U.ChoixIC(jeu.raretes[1]).convertis==4,"atelier : annuler une conversion encore non enregistree")
local largeurEcran=UIParent:GetWidth()
UIParent:SetWidth(800); f:Rafraichir()
assert(f:GetWidth()*f:GetScale()<=800,"forge entiere reste dans un petit ecran")
UIParent:SetWidth(largeurEcran); f:Rafraichir()

print("== Propriete temoin locale, jamais livree dans Data")
IC.Declarer({id="test",nom="Témoin",description="Description témoin",categorie="Essais",type="actif",
    version=1,coutBase=1,frequence={type="combat",nombre=1},duree={type="instantanee"},instantane=true,
    coutsFrequence={["combat:1"]=1},coutsDuree={instantanee=0},effet="test_inactif",
    valider=function(p) return p.parametres==nil,"aucun paramètre autorisé" end})
local choix=assert(IC.Selection("test")); assert(choix.cout==2)
assert(U.OuvrirEdition(LCM.Compendium.Get("armes"),LCM.Objets.Get(def.id)))
f.panelIC.ajouter:Click()
for _,b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix=="test" then b:Click() end end
assert(#U.courant.ic.proprietes==1,"catalogue classe par categorie utilisable sans refaire la forge")
assert(IC.Bilan(U.courant.ic).restants==0)
f.panelIC.retirer:Click()
for _,b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix==1 then b:Click() end end
assert(#U.courant.ic.proprietes==0,"retrait d'une selection")
local avec=Objet("ic_propriete"); avec.ic.convertis=0; avec.ic.proprietes={choix}
assert(B.Enregistrer("objets",avec,true))
local carte=LCM.Compendium.Carte(LCM.Compendium.Get("armes"),LCM.Objets.Get(avec.id))
assert(carte.corps[1].titre=="Propriétés IC" and carte.corps[1].texte:find("Témoin",1,true))
local recuAvec=LCM.Objets.Construire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(avec)))
assert(recuAvec.ic.proprietes[1].cout==2)
IC.catalogue.test.coutBase=50
assert(B.Enregistrer("objets",LCM.Copie(avec)),"pas de repricing silencieux")
IC.catalogue.test=nil
assert(B.Enregistrer("objets",LCM.Copie(avec)),"catalogue retire : donnees preservees")
assert(IC.Description(avec.ic):find("indisponible",1,true))
local fausse=LCM.Copie(avec); fausse.id="ic_inconnue"
assert(not B.Enregistrer("objets",fausse,true),"nouvel achat inconnu refuse")
fausse.ic.proprietes[1].parametres={actif=true,valeur=2,texte="002"}
LCM.Reseau.Recevoir("Autre-Apertus","9001:1:1:brouillon|"..LCM.Reseau.Encoder({f="objets",e=fausse,
    ic=LCM.Lien.Serialiser(fausse.ic),s="ic_reception_temoin"}))
local distante=assert(LCM.Objets.Get(fausse.id),"une propriete retiree reste transmissible entre MJ")
assert(distante.ic.proprietes[1].parametres.actif==true and distante.ic.proprietes[1].parametres.valeur==2)
assert(distante.ic.proprietes[1].parametres.texte=="002","types preserves par la synchro MJ")
assert(next(IC.effets)==nil,"aucun effet executable active")
print("IC : TOUT PASSE")
