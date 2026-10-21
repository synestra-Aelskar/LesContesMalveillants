-- banc: --sans-mj
-- Lancer avec --sans-mj : ni atelier, ni jeu d'equilibrage necessaire.
__declencher("PLAYER_LOGIN")
assert(not LCM.IsMaster())
local def={id="ic_public",label="Objet public IC",categorie="accessoire",forge="jeu_absent/rare",
    ic={version=1,palier="bleu",convertis=1,proprietes={
        {id="retiree",version=1,nom="Ancienne propriété",description="Donnée conservée",cout=2,
            parametres={actif=true,valeur=2}}}}}
local recu=LCM.Objets.Construire(LCM.Lien.Deserialiser(LCM.Lien.Serialiser(def)))
assert(recu.ic.proprietes[1].parametres.actif==true)
assert(LCM.IC.Bilan(recu.ic).restants==3)
local carte=LCM.Compendium.Carte(LCM.Compendium.Get("accessoires"),recu)
assert(carte.corps[1].texte:find("indisponible",1,true))
assert(next(LCM.IC.effets)==nil)
assert(LCM.Objets.Construire({id="ancien_ic",categorie="accessoire"}).ic==nil)
print("IC JOUEUR : TOUT PASSE")
