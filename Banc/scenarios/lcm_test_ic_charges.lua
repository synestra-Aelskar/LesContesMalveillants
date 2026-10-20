__declencher("PLAYER_LOGIN")
local C = LCM.IC.Charges
local a, b = C.Nouveau("exemplaire-a", "objets/temoin"), C.Nouveau("exemplaire-b", "objets/temoin")
local jour = {type="heures24", nombre=1}
local ctx = {maintenant=100000, combat="combat-a", tour=1}
assert(C.Restants(a,"protection",jour,ctx)==1)
assert(next(a.usages)==nil, "une lecture ne cree rien")
assert(C.Consommer(a,"protection",jour,ctx,"action-a"))
assert(C.Restants(a,"protection",jour,ctx)==0)
assert(C.Restants(b,"protection",jour,ctx)==1, "charges par exemplaire")
assert(not C.Consommer(a,"protection",jour,ctx,"action-a"), "rejeu refuse")
local copie = LCM.Copie(a)
assert(C.Restants(copie,"protection",jour,ctx)==0, "transfert conserve les usages")
ctx.maintenant=186399
assert(C.Restants(copie,"protection",jour,ctx)==0)
ctx.maintenant=186400
assert(C.Restants(copie,"protection",jour,ctx)==1, "24 heures glissantes")
local combat = {type="combat",nombre=2}
assert(C.Consommer(a,"renforce",combat,ctx,"b"))
assert(C.Consommer(a,"renforce",combat,ctx,"c"))
assert(not C.Consommer(a,"renforce",combat,ctx,"d"))
ctx.combat="combat-b"
assert(C.Restants(a,"renforce",combat,ctx)==2)
local tour = {type="tour",nombre=1}
assert(C.Consommer(a,"armure",tour,ctx,"e"))
assert(C.Restants(a,"armure",tour,ctx)==0)
ctx.tour=2
assert(C.Restants(a,"armure",tour,ctx)==1)
assert(C.Restants(a,"armure",tour,{maintenant=1})==nil, "pas de recharge hors combat")
assert(C.Restants(a,"armure",{type="inconnu",nombre=1},ctx)==nil)
assert(C.Restants(a,"armure",{type="sans_limite"},ctx)==math.huge)
print("TOUT PASSE — charges IC par exemplaire")
