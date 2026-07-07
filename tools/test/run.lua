-- tools/test/run.lua
-- Suite de tests hors-jeu (Lua 5.3 standard). Exécuter depuis n'importe où :
--   lua5.3 tools/test/run.lua
-- Couvre : SHA-256/HMAC, réseau privé (netsec), sérialisation, rôles, comptes, auth, routeur.

-- Rend require("shared.x") etc. utilisable quel que soit le répertoire courant.
local here = debug.getinfo(1, "S").source:sub(2)
local root = here:gsub("tools/test/run%.lua$", "")
if root == "" then root = "./" end
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path

local sha2 = require("shared.sha2")
local netsec = require("shared.netsec")
local util = require("shared.util")
local roles = require("shared.roles")
local protocol = require("shared.protocol")
local accountsSvc = require("server.services.accounts")
local logsSvc = require("server.services.logs")
local authSvc = require("server.services.auth")
local doorsSvc = require("server.services.doors")
local radarSvc = require("server.services.radar")
local router = require("server.router")
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
