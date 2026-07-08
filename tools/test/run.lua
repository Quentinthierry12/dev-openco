-- tools/test/run.lua
-- Suite de tests hors-jeu (Lua 5.3 standard). Exécuter depuis n'importe où :
--   lua5.3 tools/test/run.lua
-- Couvre : SHA-256/HMAC, réseau privé (netsec), sérialisation, rôles, comptes, auth, routeur.

-- Rend require("shared/x") etc. utilisable quel que soit le répertoire courant.
local here = debug.getinfo(1, "S").source:sub(2)
local root = here:gsub("tools/test/run%.lua$", "")
if root == "" then root = "./" end
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path

local sha2 = require("shared/sha2")
local netsec = require("shared/netsec")
local util = require("shared/util")
local roles = require("shared/roles")
local protocol = require("shared/protocol")
local accountsSvc = require("server/services/accounts")
local logsSvc = require("server/services/logs")
local authSvc = require("server/services/auth")
local doorsSvc = require("server/services/doors")
local radarSvc = require("server/services/radar")
local nodesSvc = require("server/services/nodes")
local messagingSvc = require("server/services/messaging")
local situationSvc = require("server/services/situation")
local protocolsSvc = require("server/services/protocols")
local powerSvc = require("server/services/power")
local defenseSvc = require("server/services/defense")
local settingsSvc = require("server/services/settings")
local router = require("server/router")
local REQ = protocol.REQ

-- Mini-framework -------------------------------------------------------------
local passed, failed = 0, 0
local function ok(cond, name)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print("  ✗ FAIL: " .. name)
  end
end
local function eq(a, b, name)
  ok(a == b, (name or "") .. " (attendu " .. tostring(b) .. ", obtenu " .. tostring(a) .. ")")
end
local function section(s) print("• " .. s) end

-- 1. SHA-256 / HMAC (vecteurs standard) --------------------------------------
section("SHA-256 & HMAC")
eq(sha2.sha256(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "sha256 vide")
eq(sha2.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "sha256 abc")
-- RFC 4231, test case 1
eq(sha2.hmac(string.rep("\x0b", 20), "Hi There"),
  "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7", "hmac RFC4231 #1")

-- 2. Sérialisation -----------------------------------------------------------
section("Sérialisation")
local orig = { a = 1, b = "x\"y", c = true, nested = { 1, 2, 3, k = "v" } }
local round = util.deserialize(util.serialize(orig))
eq(round.a, 1, "serialize number")
eq(round.b, 'x"y', "serialize string échappée")
eq(round.c, true, "serialize bool")
eq(round.nested.k, "v", "serialize nested")
eq(round.nested[2], 2, "serialize array")

-- 3. Réseau privé ------------------------------------------------------------
section("Réseau privé (netsec)")
netsec.setSecret("test-secret-123")
local wire = netsec.encode({ t = "ping", id = "abc" })
local decoded = netsec.decode(wire)
ok(decoded and decoded.t == "ping" and decoded.id == "abc", "encode/decode round-trip")

-- Message falsifié -> rejeté
local env = netsec.wrap("payload")
env.b = env.b .. "x" -- altère le corps sans re-signer
ok(netsec.unwrap(env) == nil, "message falsifié rejeté (bad_mac)")

-- Nœud sans le bon secret -> ne peut pas être décodé
netsec.setSecret("autre-secret")
ok(netsec.decode(wire) == nil, "message d'un secret différent rejeté")
netsec.setSecret("test-secret-123")

-- Liste blanche
netsec.setWhitelist({ ["good-addr"] = true })
ok(netsec.isAllowed("good-addr") == true, "whitelist autorise adresse connue")
ok(netsec.isAllowed("evil-addr") == false, "whitelist rejette adresse inconnue")
netsec.setWhitelist(nil)

-- 4. Rôles -------------------------------------------------------------------
section("Rôles & permissions")
ok(roles.can("admin", "manage_accounts"), "admin: manage_accounts")
ok(roles.can("admin", "door:silo"), "admin: door:silo")
ok(roles.can("agent", "door:A"), "agent: door:A (joker door:*)")
ok(not roles.can("agent", "door:silo"), "agent: door:silo REFUSÉ (restreint admin)")
ok(roles.can("agent", "view_logs"), "agent: view_logs")
ok(not roles.can("agent", "manage_accounts"), "agent: manage_accounts REFUSÉ")
ok(roles.can("invite", "door:lobby"), "invite: door:lobby")
ok(not roles.can("invite", "door:A"), "invite: door:A REFUSÉ")

-- 5. Comptes -----------------------------------------------------------------
section("Comptes")
local accounts = accountsSvc.new()
local adminV = accounts:create({ name = "admin", role = "admin", password = "secret" })
ok(adminV and adminV.hasPassword, "création admin avec mot de passe")
local agentV = accounts:create({ name = "bob", role = "agent", cardId = "CARD-123" })
ok(agentV and agentV.hasCard, "création agent avec carte")
ok(accounts:byCardId("CARD-123") ~= nil, "résolution par carte")
ok(accounts:byCardId("NOPE") == nil, "carte inconnue -> nil")
ok(accounts:verifyPassword("admin", "secret") ~= nil, "mot de passe correct")
ok(accounts:verifyPassword("admin", "faux") == nil, "mot de passe incorrect")
local _, e1 = accounts:create({ name = "admin", role = "agent", password = "x" })
eq(e1, "name_taken", "nom déjà pris")
local _, e2 = accounts:create({ name = "carol", role = "agent", cardId = "CARD-123" })
eq(e2, "card_taken", "carte déjà prise")
local _, e3 = accounts:create({ name = "dave", role = "wizard", password = "x" })
eq(e3, "bad_role", "rôle invalide")
local _, e4 = accounts:create({ name = "eve", role = "agent" })
eq(e4, "need_card_or_password", "ni carte ni mot de passe")
ok(adminV.salt == nil and adminV.passwordHash == nil, "vue publique sans secrets")

-- 6. Auth --------------------------------------------------------------------
section("Auth & sessions")
local logs = logsSvc.new()
local auth = authSvc.new(accounts, logs)
local sAdmin = auth:loginPassword("admin", "secret", "term-1")
ok(sAdmin and sAdmin.role == "admin", "login mot de passe -> session admin")
ok(auth:loginPassword("admin", "faux") == nil, "login mot de passe erroné refusé")
local sBob = auth:loginCard("CARD-123", "term-2")
ok(sBob and sBob.role == "agent", "login carte -> session agent")
ok(auth:loginCard("NOPE") == nil, "login carte inconnue refusé")
ok(auth:check(sAdmin.token) ~= nil, "session valide")
ok(auth:authorize(sAdmin.token, "manage_accounts") ~= nil, "admin autorisé manage_accounts")
local sForbidden = auth:authorize(sBob.token, "manage_accounts")
ok(sForbidden == nil, "agent: authorize refuse manage_accounts (session nil)")
auth:logout(sAdmin.token)
ok(auth:check(sAdmin.token) == nil, "logout invalide la session")

-- 7. Routeur -----------------------------------------------------------------
section("Routeur")
local ctx = { accounts = accounts, auth = auth, logs = logs }
local function req(t, p) p = p or {}; p.t = t; return p end

local rPing = router.handle(ctx, req(protocol.REQ.PING))
ok(rPing.ok and rPing.data.pong, "PING")

local rLogin = router.handle(ctx, req(protocol.REQ.AUTH_PASSWORD, { name = "admin", password = "secret" }))
ok(rLogin.ok and rLogin.data.token, "AUTH_PASSWORD ok")
local adminTok = rLogin.data.token

local rBad = router.handle(ctx, req(protocol.REQ.AUTH_PASSWORD, { name = "admin", password = "x" }))
ok(not rBad.ok and rBad.error == "bad_credentials", "AUTH_PASSWORD mauvais mdp")

local rCardLogin = router.handle(ctx, req(protocol.REQ.AUTH_CARD, { cardId = "CARD-123" }), { from = "term-2" })
ok(rCardLogin.ok, "AUTH_CARD ok")
local agentTok = rCardLogin.data.token

local rCreate = router.handle(ctx, req(protocol.REQ.ACCOUNT_CREATE,
  { token = adminTok, name = "frank", role = "invite", password = "pw" }))
ok(rCreate.ok and rCreate.data.account.name == "frank", "ACCOUNT_CREATE par admin")

local rForbidden = router.handle(ctx, req(protocol.REQ.ACCOUNT_LIST, { token = agentTok }))
ok(not rForbidden.ok and rForbidden.error == "forbidden", "ACCOUNT_LIST refusé à l'agent")

local rNoTok = router.handle(ctx, req(protocol.REQ.ACCOUNT_LIST, { token = "invalide" }))
ok(not rNoTok.ok and rNoTok.error == "unauthorized", "token invalide -> unauthorized")

local rLogs = router.handle(ctx, req(protocol.REQ.LOG_QUERY, { token = adminTok, limit = 5 }))
ok(rLogs.ok and type(rLogs.data.entries) == "table", "LOG_QUERY par admin")

local rUnknown = router.handle(ctx, req("n.existe.pas"))
ok(not rUnknown.ok and rUnknown.error == "unknown_type", "type inconnu")

local rId = router.handle(ctx, { t = protocol.REQ.PING, id = "xyz" })
eq(rId.id, "xyz", "id de corrélation renvoyé")

-- 8. Portes typées -----------------------------------------------------------
section("Portes typées")
local recDriver = { writes = {} }
function recDriver:write(door, key, on)
  self.writes[#self.writes + 1] = { id = door.id, key = key, on = on }
end
local dsvc = doorsSvc.new(recDriver, logsSvc.new())
local dOpen = dsvc:set("lobby", true, "tester")
ok(dOpen and dOpen.open == true, "porte simple ouverte")
local aIn = dsvc:airlock("airlock_A", "inner", true, "t")
ok(aIn and aIn.open, "sas: battant intérieur ouvert")
local aOut, aReason = dsvc:airlock("airlock_A", "outer", true, "t")
ok(aOut == nil and aReason == "interlock", "sas interlock: extérieur refusé si intérieur ouvert")
dsvc:airlock("airlock_A", "inner", false, "t")
local aOut2 = dsvc:airlock("airlock_A", "outer", true, "t")
ok(aOut2 and aOut2.open, "sas: extérieur s'ouvre après fermeture intérieur")
dsvc:lockdown("t")
ok(dsvc:isLocked(), "lockdown actif")
local lSet, lReason = dsvc:set("lobby", true, "t")
ok(lSet == nil and lReason == "locked", "ouverture refusée sous lockdown")
ok(dsvc.state.airlock_A.outer == false, "lockdown a fermé le sas")
dsvc:release("t")
ok(not dsvc:isLocked(), "release du lockdown")
ok(#recDriver.writes > 0, "le driver a reçu des ordres physiques")

-- 9. Radar / DEFCON ----------------------------------------------------------
section("Radar / DEFCON")
local ev = { alarm = {}, broadcast = {}, lockdown = 0, release = 0 }
local mockDoors = { locked = false }
function mockDoors:lockdown() self.locked = true; ev.lockdown = ev.lockdown + 1 end
function mockDoors:release() self.locked = false; ev.release = ev.release + 1 end
local rsvc = radarSvc.new({
  doors = mockDoors,
  logs = logsSvc.new(),
  alarm = function(on) ev.alarm[#ev.alarm + 1] = on end,
  broadcast = function(e) ev.broadcast[#ev.broadcast + 1] = e.evt end,
})
eq(rsvc:update({ missiles = 0, signal = 0 }).defcon, 5, "calme -> DEFCON 5")
local esc = rsvc:update({ missiles = 1, contacts = { { x = 1 } } })
eq(esc.defcon, 2, "1 missile -> DEFCON 2")
ok(esc.alert, "alerte active")
eq(ev.lockdown, 1, "lockdown déclenché une fois")
eq(ev.alarm[#ev.alarm], true, "sirène activée à l'escalade")
eq(ev.broadcast[#ev.broadcast], "alert", "broadcast 'alert'")
rsvc:update({ missiles = 1 })
eq(ev.lockdown, 1, "pas de re-lockdown tant qu'en alerte")
rsvc:update({ missiles = 0, signal = 0 })
eq(ev.release, 1, "release au retour au calme")
eq(ev.alarm[#ev.alarm], false, "sirène coupée")
eq(ev.broadcast[#ev.broadcast], "clear", "broadcast 'clear'")

-- 10. Routeur : portes & radar (avec permissions) ----------------------------
section("Routeur — portes & radar")
ctx.doors = doorsSvc.new(nil, logs)
ctx.radar = radarSvc.new({ logs = logs })
local rSilo = router.handle(ctx, req(REQ.DOOR_CMD, { token = adminTok, id = "silo_hatch", action = "open" }))
ok(rSilo.ok, "admin ouvre le silo")
local rAgentSilo = router.handle(ctx, req(REQ.DOOR_CMD, { token = agentTok, id = "silo_hatch", action = "open" }))
ok(not rAgentSilo.ok and rAgentSilo.error == "forbidden", "agent REFUSÉ sur le silo")
local rBunker = router.handle(ctx, req(REQ.DOOR_CMD, { token = agentTok, id = "bunker_main", action = "open" }))
ok(rBunker.ok, "agent ouvre le bunker (door:*)")
local rLock = router.handle(ctx, req(REQ.DOOR_CMD, { token = agentTok, action = "lockdown" }))
ok(rLock.ok and rLock.data.locked, "agent déclenche le LOCKDOWN")
local rRadar = router.handle(ctx, req(REQ.RADAR_STATE, { token = agentTok }))
ok(rRadar.ok and rRadar.data.defcon ~= nil, "RADAR_STATE renvoie le DEFCON")
local rDoorList = router.handle(ctx, req(REQ.DOOR_LIST, { token = adminTok }))
ok(rDoorList.ok and type(rDoorList.data.doors) == "table", "DOOR_LIST")

-- 11. Comptes & badges (via routeur) -----------------------------------------
section("Routeur — comptes & badges")
local frankId = rCreate.data.account.id
local rRole = router.handle(ctx, req(REQ.ACCOUNT_SETROLE, { token = adminTok, id = frankId, role = "agent" }))
ok(rRole.ok and rRole.data.account.role == "agent", "ACCOUNT_SETROLE par admin")
local rCard = router.handle(ctx, req(REQ.ACCOUNT_SETCARD, { token = adminTok, id = frankId, cardId = "BADGE-1" }))
ok(rCard.ok and rCard.data.account.hasCard, "ACCOUNT_SETCARD (émission badge)")
ok(accounts:byCardId("BADGE-1") ~= nil, "la carte émise résout bien le compte")
local rRoleF = router.handle(ctx, req(REQ.ACCOUNT_SETROLE, { token = agentTok, id = frankId, role = "admin" }))
ok(not rRoleF.ok and rRoleF.error == "forbidden", "agent REFUSÉ sur ACCOUNT_SETROLE")
local rSess = router.handle(ctx, req(REQ.SESSION_LIST, { token = adminTok }))
ok(rSess.ok and type(rSess.data.sessions) == "table", "SESSION_LIST par admin")

-- 12. Flotte à distance ------------------------------------------------------
section("Flotte (nodes)")
local sent = {}
local nsvc = nodesSvc.new({ send = function(a, m) sent[#sent + 1] = { a, m.command } end, logs = logsSvc.new() })
nsvc:register("node-A", "terminal")
nsvc:register("node-B", "server")
eq(#nsvc:list(), 2, "2 nœuds enregistrés")
local c1 = nsvc:command("node-A", "reboot", "admin")
ok(c1 and c1.sent, "commande envoyée à un nœud connu")
eq(sent[#sent][2], "reboot", "le transport a reçu 'reboot'")
local _, cr = nsvc:command("node-X", "reboot")
eq(cr, "unknown_node", "nœud inconnu refusé")
local _, cr2 = nsvc:command("node-A", "format")
eq(cr2, "bad_command", "commande invalide refusée")

section("Routeur — flotte")
ctx.nodes = nodesSvc.new({ send = function() end, logs = logs })
local rReg = router.handle(ctx, req(REQ.NODE_REGISTER, { kind = "terminal" }), { from = "node-Z" })
ok(rReg.ok, "NODE_REGISTER via meta.from (sans token)")
local rCmd = router.handle(ctx, req(REQ.NODE_CMD, { token = adminTok, address = "node-Z", command = "reboot" }))
ok(rCmd.ok, "admin: NODE_CMD reboot")
local rCmdF = router.handle(ctx, req(REQ.NODE_CMD, { token = agentTok, address = "node-Z", command = "reboot" }))
ok(not rCmdF.ok and rCmdF.error == "forbidden", "agent REFUSÉ sur NODE_CMD (fleet_control admin-only)")
local rNl = router.handle(ctx, req(REQ.NODE_LIST, { token = adminTok }))
ok(rNl.ok and type(rNl.data.nodes) == "table", "NODE_LIST admin")

-- 13. Collaboration ----------------------------------------------------------
section("Collaboration (messaging)")
local msvc = messagingSvc.new({ logs = logsSvc.new() })
local an = msvc:announce("admin", "Test annonce")
ok(an and an.text == "Test annonce", "annonce publiée")
eq(#msvc:getBoard(), 1, "le bulletin contient l'annonce")
local _, me = msvc:announce("admin", "")
eq(me, "empty", "annonce vide refusée")
msvc:send("admin", "bob", "Salut")
eq(#msvc:getInbox("bob"), 1, "message reçu par bob")
eq(#msvc:getInbox("carol"), 0, "carol n'a rien reçu")

section("Routeur — collaboration")
ctx.messaging = messagingSvc.new({ logs = logs })
accounts:create({ name = "guest", role = "invite", password = "g" })
local guestTok = router.handle(ctx, req(REQ.AUTH_PASSWORD, { name = "guest", password = "g" })).data.token
local rAnnAgent = router.handle(ctx, req(REQ.ANNOUNCE_POST, { token = agentTok, text = "Ronde 22h" }))
ok(rAnnAgent.ok, "agent publie une annonce")
local rAnnGuest = router.handle(ctx, req(REQ.ANNOUNCE_POST, { token = guestTok, text = "spam" }))
ok(not rAnnGuest.ok and rAnnGuest.error == "forbidden", "invité REFUSÉ pour ANNOUNCE_POST")
local rBoard = router.handle(ctx, req(REQ.BOARD_GET, { token = guestTok }))
ok(rBoard.ok and #rBoard.data.board >= 1, "invité peut lire le bulletin")
local rMsg = router.handle(ctx, req(REQ.MSG_SEND, { token = adminTok, to = "guest", text = "bienvenue" }))
ok(rMsg.ok, "admin envoie un message à guest")
local rInbox = router.handle(ctx, req(REQ.MSG_INBOX, { token = guestTok }))
ok(rInbox.ok and #rInbox.data.messages >= 1, "invité lit sa boîte de réception")

-- 14. Salle de contrôle : situation ------------------------------------------
section("Situation (salle de contrôle)")
local sit = situationSvc.new({ site = require("shared/site").CONFIG })
eq(sit:compute({ defcon = 5, contacts = {}, alert = false }, {}, false).impactRisk, "aucun", "pas d'alerte -> risque aucun")
local s1 = sit:compute({ defcon = 2, contacts = { { x = 0, y = 64, z = 100, speed = 20 } }, alert = true }, {}, false)
ok(s1.impactETA and math.abs(s1.impactETA - 5) < 0.01, "ETA = distance/vitesse (100/20 = 5s)")
eq(s1.impactRisk, "élevé", "ETA<=10s -> risque élevé")
eq(sit:compute({ defcon = 2, contacts = { {} }, alert = true }, {}, false).impactRisk, "inconnu", "alerte sans coords -> inconnu")
local s3 = sit:compute({ defcon = 5, contacts = {}, alert = false },
  { { id = "a", type = "airlock", state = {} }, { id = "b", type = "bunker", state = {} } }, false)
eq(s3.lockdownFullSeconds, 5, "temps lockdown complet = airlock(3) + porte(2)")
eq(#s3.importantDoors, 2, "portes importantes listées")

-- 15. Protocoles / overrides -------------------------------------------------
section("Protocoles / overrides")
local rec = { announces = 0, lockdown = 0, release = 0, alarms = {}, disabled = {} }
local mockD = {}
function mockD:lockdown() rec.lockdown = rec.lockdown + 1 end
function mockD:release() rec.release = rec.release + 1 end
local mockM = {}
function mockM:announce() rec.announces = rec.announces + 1 end
local mockN = {}
function mockN:commandAll(cmd, exclude) rec.disabled[#rec.disabled + 1] = { cmd, exclude } end
local psvc = protocolsSvc.new({
  doors = mockD, messaging = mockM, nodes = mockN, logs = logsSvc.new(),
  alarm = function(on) rec.alarms[#rec.alarms + 1] = on end,
})
local pr = psvc:run("2222", { drill = false }, "admin")
ok(pr and not pr.drill, "protocole réel exécuté")
eq(rec.lockdown, 1, "lockdown réel déclenché")
eq(rec.alarms[1], true, "sirène activée")
rec.lockdown = 0
local pd = psvc:run("2222", { drill = true }, "agent")
ok(pd and pd.drill, "protocole joué en drill")
eq(rec.lockdown, 0, "drill ne déclenche PAS le lockdown réel")
psvc:run("9999", {}, "admin")
local last = rec.disabled[#rec.disabled]
ok(last[1] == "blackout" and last[2] == "display", "override coupe les postes SAUF les écrans (display)")
local _, pu = psvc:run("0001", {}, "admin")
eq(pu, "unknown_protocol", "code inconnu refusé")
local _, pnd = psvc:run("0000", { drill = true }, "admin")
eq(pnd, "not_drillable", "protocole non-drillable refusé en drill")

section("Flotte — commandAll (override)")
local sent3 = {}
local nAll = nodesSvc.new({ send = function(a, m) sent3[#sent3 + 1] = { a, m.command } end, logs = logsSvc.new() })
nAll:register("t1", "terminal"); nAll:register("t2", "terminal"); nAll:register("d1", "display")
eq(nAll:commandAll("blackout", "display", "admin").count, 2, "blackout -> 2 terminaux, écran épargné")

section("Routeur — situation & protocoles")
ctx.situation = situationSvc.new({ radar = ctx.radar, doors = ctx.doors })
ctx.protocols = protocolsSvc.new({ doors = ctx.doors, messaging = ctx.messaging, nodes = ctx.nodes, logs = logs, alarm = function() end })
ok(router.handle(ctx, req(REQ.SITUATION_GET, { token = agentTok })).ok, "SITUATION_GET")
ok(#router.handle(ctx, req(REQ.PROTOCOL_LIST, { token = agentTok })).data.protocols >= 1, "PROTOCOL_LIST")
local rDrill = router.handle(ctx, req(REQ.PROTOCOL_RUN, { token = agentTok, code = "2222", drill = true }))
ok(rDrill.ok and rDrill.data.drill, "agent peut lancer un DRILL")
local rReal = router.handle(ctx, req(REQ.PROTOCOL_RUN, { token = agentTok, code = "2222", drill = false }))
ok(not rReal.ok and rReal.error == "forbidden", "agent REFUSÉ pour un protocole RÉEL")
ok(router.handle(ctx, req(REQ.PROTOCOL_RUN, { token = adminTok, code = "0000", drill = false })).ok, "admin exécute un protocole réel")

-- 15b. Sas — cycle temporisé + step wait ------------------------------------
section("Sas — cycle temporisé")
local scheduled = {}
local recD2 = {}
function recD2:write() end
local dsvc2 = doorsSvc.new(recD2, logsSvc.new(), { schedule = function(s, fn) scheduled[#scheduled + 1] = { s = s, fn = fn } end })
dsvc2:airlock("airlock_A", "inner", true, "t")
eq(#scheduled, 1, "ouverture d'un battant planifie une fermeture auto")
eq(scheduled[1].s, 3, "délai de fermeture = cycleSeconds (3)")
ok(dsvc2.state.airlock_A.inner == true, "battant ouvert avant échéance")
scheduled[1].fn() -- simule l'échéance du timer
ok(dsvc2.state.airlock_A.inner == false, "le timer referme le battant")

section("Protocole — step wait")
local slept = {}
local wsvc = protocolsSvc.new({ messaging = mockM, alarm = function() end, logs = logsSvc.new(),
  sleep = function(s) slept[#slept + 1] = s end })
wsvc:run("1111", { drill = false }, "admin") -- drill_evac contient un wait{s=3}
ok(#slept >= 1 and slept[1] == 3, "le step wait appelle sleep(3)")

-- 17. Supervision réacteur ---------------------------------------------------
section("Supervision réacteur")
local function findR(list, id) for _, x in ipairs(list) do if x.id == id then return x end end end
local pev = { alarm = {}, crit = {} }
local psvc = powerSvc.new({
  logs = logsSvc.new(),
  alarm = function(on) pev.alarm[#pev.alarm + 1] = on end,
  onCritical = function(r) pev.crit[#pev.crit + 1] = r.id end,
})
local st = psvc:update({ reactor_1 = { temp = 500, fuel = 100 }, grid = { energy = 1000 } })
eq(findR(st, "reactor_1").status, "ok", "réacteur ok en dessous du seuil")
eq(findR(st, "grid").status, "ok", "machine energyOnly = ok")
psvc:update({ reactor_1 = { temp = 850 } })
eq(findR(psvc:state(), "reactor_1").status, "warn", "warn au seuil d'avertissement (800)")
psvc:update({ reactor_1 = { temp = 1050 } })
eq(findR(psvc:state(), "reactor_1").status, "crit", "crit au seuil critique (1000)")
eq(#pev.crit, 1, "onCritical déclenché une fois (front montant)")
eq(pev.alarm[#pev.alarm], true, "alarme au critique")
psvc:update({ reactor_1 = { temp = 1050 } })
eq(#pev.crit, 1, "pas de re-déclenchement tant que critique")
psvc:update({ reactor_1 = { temp = 500 } })
eq(findR(psvc:state(), "reactor_1").status, "ok", "retour à ok réarme le front")

-- 18. Contre-mesures ---------------------------------------------------------
section("Contre-mesures")
local fired = {}
local dsvc = defenseSvc.new({ actuate = function(e) fired[#fired + 1] = e.id end, logs = logsSvc.new(), mode = "auto", engageLevel = 2 })
ok(dsvc:engage({ defcon = 2, contacts = {} }).fired >= 1, "auto: engage au DEFCON 2")
local before = #fired
dsvc:engage({ defcon = 2 })
eq(#fired, before, "pas de re-tir tant que l'alerte dure")
dsvc:standDown(); dsvc:engage({ defcon = 5 }); dsvc:engage({ defcon = 2 })
ok(#fired > before, "réengage après standDown")
dsvc:setMode("manual")
ok(dsvc:fire("admin").fired >= 1, "tir manuel en mode manual")
dsvc:setMode("off")
local _, offr = dsvc:fire("admin")
eq(offr, "mode_off", "mode off refuse le tir manuel")
eq(dsvc:engage({ defcon = 1 }).fired, 0, "mode off n'engage pas en auto")

section("Radar -> contre-mesures (onEscalate)")
local engaged = {}
local rdef = radarSvc.new({ logs = logsSvc.new(),
  onEscalate = function(defcon) engaged[#engaged + 1] = defcon end,
  onStandDown = function() engaged.down = true end })
rdef:update({ missiles = 0, signal = 0 })
rdef:update({ missiles = 1 })
eq(#engaged, 1, "onEscalate appelé à l'escalade")
rdef:update({ missiles = 0, signal = 0 })
ok(engaged.down, "onStandDown appelé en fin d'alerte")

section("Routeur — réacteur & défense")
ctx.power = psvc
ctx.defense = defenseSvc.new({ actuate = function() end, logs = logs, mode = "manual" })
ctx.scram = function(id) return id ~= nil end
ok(router.handle(ctx, req(REQ.POWER_STATE, { token = agentTok })).ok, "POWER_STATE")
local rScramF = router.handle(ctx, req(REQ.REACTOR_SCRAM, { token = agentTok, id = "reactor_1" }))
ok(not rScramF.ok and rScramF.error == "forbidden", "agent REFUSÉ pour REACTOR_SCRAM")
ok(router.handle(ctx, req(REQ.REACTOR_SCRAM, { token = adminTok, id = "reactor_1" })).ok, "admin: SCRAM")
ok(router.handle(ctx, req(REQ.DEFENSE_STATE, { token = agentTok })).ok, "DEFENSE_STATE")
local rModeF = router.handle(ctx, req(REQ.DEFENSE_MODE, { token = agentTok, mode = "auto" }))
ok(not rModeF.ok and rModeF.error == "forbidden", "agent REFUSÉ pour DEFENSE_MODE")
eq(router.handle(ctx, req(REQ.DEFENSE_MODE, { token = adminTok, mode = "auto" })).data.mode, "auto", "admin change le mode défense")

-- 19. Réglages (settings) + kiosk --------------------------------------------
section("Réglages (settings)")
local applied = {}
local setsvc = settingsSvc.new({ apply = function(k, v) applied[k] = v end })
local rset = setsvc:set("site.radius", "128", "admin")
ok(rset and rset.value == 128, "set d'un number coercé depuis string")
eq(applied["site.radius"], 128, "apply appelé avec la valeur")
local _, se1 = setsvc:set("unknown.key", "x")
eq(se1, "unknown_key", "clé inconnue refusée")
local _, se2 = setsvc:set("site.radius", "abc")
eq(se2, "bad_value", "valeur numérique invalide refusée")
ok(#setsvc:list() >= 5, "liste des réglages du schéma")

section("Routeur — kiosk & config")
ctx.settings = settingsSvc.new({ apply = function() end })
local rk = router.handle(ctx, req(REQ.KIOSK_GET))
ok(rk.ok and rk.data.defcon ~= nil, "KIOSK_GET fonctionne SANS token (info publique)")
ok(router.handle(ctx, req(REQ.SETTINGS_GET, { token = adminTok })).ok, "SETTINGS_GET admin")
local rsf = router.handle(ctx, req(REQ.SETTINGS_GET, { token = agentTok }))
ok(not rsf.ok and rsf.error == "forbidden", "agent REFUSÉ pour SETTINGS_GET")
ok(router.handle(ctx, req(REQ.SETTINGS_SET, { token = adminTok, key = "defense.engageLevel", value = "1" })).ok, "SETTINGS_SET admin")

-- 16. Installateur : cohérence du manifeste ----------------------------------
section("Installateur — manifeste")
local manifest = require("install/manifest")
local missing = 0
for _, r in ipairs(manifest.ROLE_LIST) do
  for _, rel in ipairs(manifest.ROLES[r]) do
    local f = io.open(root .. rel, "r")
    if f then f:close() else missing = missing + 1; print("  ✗ manquant [" .. r .. "] " .. rel) end
  end
end
eq(missing, 0, "tous les fichiers listés dans le manifeste existent")

-- Intégration transport complet (client -> fil -> serveur -> fil -> client) ---
section("Transport bout-en-bout (signé)")
local clientReq = protocol.request(protocol.REQ.PING)
clientReq.id = "e2e-1"
local onWire = netsec.encode(clientReq)                 -- côté client
local serverReq = netsec.decode(onWire)                 -- côté serveur (réception)
local serverResp = router.handle(ctx, serverReq, { from = "term-9" })
local respWire = netsec.encode(serverResp)              -- côté serveur (émission)
local clientResp = netsec.decode(respWire)              -- côté client (réception)
ok(clientResp and clientResp.ok and clientResp.id == "e2e-1", "aller-retour signé bout-en-bout")

-- Bilan ----------------------------------------------------------------------
print(string.rep("-", 40))
print(string.format("Tests: %d réussis, %d échoués", passed, failed))
os.exit(failed == 0 and 0 or 1)
