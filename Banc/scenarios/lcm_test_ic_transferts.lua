__declencher("PLAYER_LOGIN")
__personnage()
local I, X, O, C = LCM.Inventaire, LCM.Exemplaires, LCM.Objets, LCM.IC.Charges
LCM.Sacs.Add({id="ic_sac",label="Sac témoin",places=8})
O.Add({id="ic_transfert",label="Objet témoin",categorie="arme",taille=1,pileMax=4,bonus={}})
local moi=LCM.Entities.Self()
moi.inventaire=nil; moi.equipement=nil; moi.exemplairesEquipes=nil
assert(I.Poser(moi,"sacs",1,"ic_sac",true))
local ref="objets/ic_transfert"
local function Case(n) return I.Case(I.Emplacement(moi,"sacs",1),n) end
assert(I.Ranger(moi,"sacs",1,1,ref,3))
local a,b,c=unpack(Case(1).exemplaires)
assert(a.id~=b.id and b.id~=c.id)
local frequence={type="heures24",nombre=1}
local ctx={maintenant=100000}
assert(C.Consommer(a,"critique",frequence,ctx,"attaque"))
assert(I.Scinder(moi,"sacs",1,1,1,{onglet="sacs",index=1,case=2}))
assert(Case(2).exemplaires[1].id==a.id)
assert(C.Restants(Case(2).exemplaires[1],"critique",frequence,ctx)==0)
assert(Case(1).exemplaires[1].id==b.id)
assert(I.Empiler(moi,"sacs",1,2,"sacs",1,1))
assert(Case(1).exemplaires[3].id==a.id)
assert(Case(2)==nil)
local ok, instance=I.Prendre(moi,ref)
assert(ok and instance.id==b.id)
assert(I.Deposer(moi,ref,1,{instance}))
assert(Case(1).exemplaires[3].id==b.id)
local avant=Case(1).exemplaires[1].id
assert(O.Equiper(moi,"ic_transfert"))
assert(moi.exemplairesEquipes.arme[1].id==avant)
assert(O.Desequiper(moi,"ic_transfert"))
assert(Case(1).exemplaires[3].id==avant)
local copie=LCM.Lien.Deserialiser(LCM.Lien.Serialiser(moi))
assert(copie.inventaire.sacs[1].cases[1].exemplaires[1].id==a.id, "reload")
assert(C.Restants(copie.inventaire.sacs[1].cases[1].exemplaires[1],"critique",frequence,ctx)==0)
assert(not I.Deposer(moi,ref,2,{a,a}),"doublons refuses")
assert(Case(1).quantite==3,"refus atomique")
local malforme=LCM.Copie(a); malforme.usages.critique[1].date=0/0
assert(not I.Deposer(moi,ref,1,{malforme}))
assert(I.Poser(moi,"sacs",2,"ic_sac",true))
local liste=LCM.Copie(Case(1).exemplaires)
I.Vider(moi,"sacs",1,1)
assert(I.Transvaser(moi,"sacs",2,ref,3,liste))
local ailleurs=I.Case(I.Emplacement(moi,"sacs",2),1)
assert(ailleurs.exemplaires[1].id==a.id)
assert(C.Restants(ailleurs.exemplaires[1],"critique",frequence,ctx)==0)
local emplacement, contenu=I.Lacher(moi,"sacs",2)
assert(contenu.objets[1].exemplaires[1].id==a.id,"sac complet")
assert(I.Poser(moi,"sacs",2,"ic_sac",true))
assert(#I.RemplirSac(moi,"sacs",2,contenu.objets)==0)
assert(I.Case(I.Emplacement(moi,"sacs",2),1).exemplaires[1].id==a.id)
local E=LCM.Echange
local pris, transmis=I.Prendre(moi,ref)
assert(pris and transmis.id==a.id)
E.courant={qui="Temoin",ouverte=true,mien={objets={},devises={}},sien={objets={},devises={}}}
assert(E.Offrir({ref=ref,quantite=1,exemplaires={transmis},origine={temoin=true}}))
local paquet=E.Contenu()
local reception=LCM.Reseau.Decoder and LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet)) or paquet
-- Le corps d'exemplaires est une chaine : son typage survit a l'aplatissement.
assert(type(paquet.objets[1].exemplairesSerialises)=="string")
E.courant.sien.objets=reception.objets
assert(E.Place())
assert(E.Conclure())
local trouve
for index=1,2 do
for _, case in pairs(I.Emplacement(moi,"sacs",index).cases or {}) do
    for _, ex in ipairs(case.exemplaires or {}) do if ex.id==a.id then trouve=ex end end
end
end
assert(trouve and C.Restants(trouve,"critique",frequence,ctx)==0,"echange conserve les charges")
local doublon={}
assert(O.Placer(doublon,"ic_transfert",a))
assert(O.Placer(doublon,"ic_transfert",b))
local retire, premier=O.Enlever(doublon,"ic_transfert",a.id)
assert(retire and premier.id==a.id)
assert(#doublon.equipement.arme==1 and doublon.exemplairesEquipes.arme[1].id==b.id,
    "retirer le premier exemplaire ne retire pas le second")
print("TOUT PASSE — piles, équipement et rechargement des exemplaires")
