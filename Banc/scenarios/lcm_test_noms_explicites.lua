__declencher('PLAYER_LOGIN')
local p=__personnage();LCM.Personnages.Actif=function() return p end
LCM._masterCompanion=true;LCM.db.settings.modeJoueur=true
local Z=LCM.Crossings
local c=Z:CreateCountry('Pays inconnu');local z=Z:CreateZone('Region inconnue');z.countryId=c.id
local l=Z:CreatePlace(z.id,'Lieu inconnu')
Z:PreparerBrouillard(999)
local data=LCM_CrossingsChar.parPerso[p.id]
data.playerKnowledge={learnedCountries={[c.id]=true},learnedZones={[z.id]=true},learnedSubZones={[l.id]=true}}
Z:TriggerCrossing({},nil,l.id)
assert(not Z:HasLearnedCountryName(c.id) and not Z:HasLearnedZoneName(z.id) and not Z:KnowsPlaceName(l),'passage revele les noms')
Z:MarkLearnedZoneName(z.id,true)
assert(Z:HasLearnedZoneName(z.id) and not Z:HasLearnedCountryName(c.id),'region revele pays')
Z:MarkLearnedCountryName(c.id,true)
assert(Z:HasLearnedCountryName(c.id) and not Z:KnowsPlaceName(l),'pays revele lieux')
assert(data.playerKnowledge.learnedCountries[c.id],'archive perdue')
print('TOUT PASSE : franchissement ne revele rien, acquisitions independantes, archives conservees')
