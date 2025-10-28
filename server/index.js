// server/index.js
import cors from "cors";
import express from "express";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { v4 as uuid } from "uuid";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA = path.join(__dirname, "data.json");

function load() {
  if (!fs.existsSync(DATA)) {
    fs.writeFileSync(DATA, JSON.stringify({ users:{}, contacts:{}, groups:{}, messages:{} }, null, 2));
  }
  return JSON.parse(fs.readFileSync(DATA, "utf8"));
}
function save(db) {
  fs.writeFileSync(DATA, JSON.stringify(db, null, 2));
}

// ---------- helpers ----------
function ensure(db) {
  db.users ||= {};
  db.contacts ||= {};
  db.groups ||= {};
  db.messages ||= {};
}
function userByPhoneName(db, displayName, phone) {
  return Object.values(db.users).find(u => u.displayName === displayName && u.phone === phone);
}
function getUser(db, userId) {
  const u = db.users[userId];
  if (!u) throw new Error("user_not_found");
  return u;
}
function isVerifiedContact(db, ownerId, linkedUserId) {
  const list = db.contacts[ownerId] || [];
  return list.some(c => c.linkedUserId === linkedUserId && (c.state || "").toLowerCase()==="verified");
}
function groupById(db, groupId) {
  const g = db.groups[groupId];
  if (!g) throw new Error("group_not_found");
  return g;
}
function pushSystemEvent(db, groupId, text) {
  db.messages[groupId] ||= [];
  db.messages[groupId].push({
    id: uuid(),
    groupId,
    senderUserId: "system",
    senderName: "System",
    text,
    timestamp: new Date().toISOString(),
  });
}

// ---------- app ----------
const app = express();
app.use(cors());
app.use(express.json());

// request log
app.use((req,res,next)=>{
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// ---------- TEST ----------
app.get("/api/test", (req,res)=> {
  res.json({status:"ok",message:"API reachable",timestamp:new Date().toISOString()});
});

// ---------- USERS ----------
app.get("/api/users", (req,res)=>{
  const db = load(); ensure(db);
  res.json(Object.values(db.users));
});

app.post("/api/users", (req,res)=>{
  const db = load(); ensure(db);
  const { displayName, phone } = req.body || {};
  if (!displayName || !phone) return res.status(400).json({error:"displayName and phone required"});
  // if exists, return it (so demo login pulls dataset)
  const existing = userByPhoneName(db, displayName, phone);
  if (existing) return res.json(existing);

  const userId = uuid();
  const identityKeyHex = uuid().replace(/-/g, "");
  const fingerprint = identityKeyHex.slice(0,12).toUpperCase();
  db.users[userId] = { userId, displayName, phone, identityKeyHex, fingerprint, createdAt: new Date().toISOString() };
  save(db);
  res.json(db.users[userId]);
});

// ---------- CONTACTS ----------
app.get("/api/contacts/:ownerId", (req,res)=>{
  const db = load(); ensure(db);
  const { ownerId } = req.params;
  getUser(db, ownerId);
  res.json(db.contacts[ownerId] || []);
});

app.get("/api/contacts/:ownerId/verified", (req,res)=>{
  const db = load(); ensure(db);
  const { ownerId } = req.params;
  const list = (db.contacts[ownerId] || []).filter(c => (c.state||"").toLowerCase()==="verified");
  res.json(list);
});

app.post("/api/contacts/:ownerId/add", (req,res)=>{
  const db = load(); ensure(db);
  const { ownerId } = req.params;
  const { name, phone } = req.body || {};
  if (!name || !phone) return res.status(400).json({error:"name and phone required"});
  db.contacts[ownerId] ||= [];
  const entry = {
    contactId: uuid(),
    name, phone,
    linkedUserId: null,
    state: "unverified",
    attestation: "added",
    createdAt: new Date().toISOString()
  };
  db.contacts[ownerId].push(entry);
  save(db);
  res.json(entry);
});

// Bind a contact to a real user and mark verified
app.post("/api/contacts/:ownerId/link-verify", (req,res)=>{
  const db = load(); ensure(db);
  const { ownerId } = req.params;
  const { contactId, linkedUserId, attestation } = req.body || {};
  if (!contactId || !linkedUserId) return res.status(400).json({error:"contactId and linkedUserId required"});
  const list = db.contacts[ownerId] || [];
  const idx = list.findIndex(c => c.contactId === contactId);
  if (idx < 0) return res.status(404).json({error:"contact_not_found"});
  if (!db.users[linkedUserId]) return res.status(404).json({error:"linked_user_not_found"});

  list[idx].linkedUserId = linkedUserId;
  list[idx].state = "verified";
  list[idx].attestation = attestation || "verified";
  save(db);
  res.json(list[idx]);
});

// ---------- GROUPS ----------
app.get("/api/groups", (req,res)=>{
  const db = load(); ensure(db);
  res.json(Object.values(db.groups));
});

app.get("/api/groups/:groupId", (req,res)=>{
  const db = load(); ensure(db);
  const g = groupById(db, req.params.groupId);
  const pending = (g.members||[]).filter(m => !m.verified);
  res.json({ ...g, pending });
});

// Create group
app.post("/api/groups", (req,res)=>{
  const db = load(); ensure(db);
  const { name, creatorUserId, admins, endorsementsNeeded } = req.body || {};
  if (!name || !creatorUserId) return res.status(400).json({error:"name and creatorUserId required"});
  const groupId = uuid();
  const members = [{ userId: creatorUserId, role: "admin", verified: true }];
  (admins||[]).forEach(a=>{
    if (a !== creatorUserId) members.push({ userId:a, role:"admin", verified:true });
  });
  db.groups[groupId] = {
    groupId, name, ownerId: creatorUserId,
    endorsementsNeeded: endorsementsNeeded ?? 1,
    members,
    endorsements: [],
    createdAt: new Date().toISOString()
  };
  pushSystemEvent(db, groupId, `Group "${name}" created.`);
  save(db);
  res.json(db.groups[groupId]);
});

// Invite: only from Verified Contact list
app.post("/api/groups/:groupId/invite", (req,res)=>{
  const db = load(); ensure(db);
  const { groupId } = req.params;
  const { inviterUserId, joinerUserId } = req.body || {};
  if (!inviterUserId || !joinerUserId) return res.status(400).json({error:"inviterUserId and joinerUserId required"});

  const g = groupById(db, groupId);
  getUser(db, inviterUserId);
  getUser(db, joinerUserId);

  if (!isVerifiedContact(db, inviterUserId, joinerUserId)) {
    return res.status(400).json({error:"verify_first", message:"This contact is not verified. Go verify before adding."});
  }

  const exists = (g.members||[]).some(m => m.userId === joinerUserId);
  if (!exists) {
    g.members ||= [];
    g.members.push({ userId: joinerUserId, role: "member", verified: (g.endorsementsNeeded||1) <= 1 });
    if ((g.endorsementsNeeded||1) > 1) {
      pushSystemEvent(db, groupId, `@${db.users[joinerUserId].displayName} invited by @${db.users[inviterUserId].displayName}. Needs ${g.endorsementsNeeded} endorsements.`);
    } else {
      pushSystemEvent(db, groupId, `@${db.users[joinerUserId].displayName} added by @${db.users[inviterUserId].displayName}.`);
    }
    save(db);
  }
  res.json(g);
});

// Endorse a pending member
app.post("/api/groups/:groupId/endorse", (req,res)=>{
  const db = load(); ensure(db);
  const { groupId } = req.params;
  const { endorserUserId, joiningUserId } = req.body || {};
  const g = groupById(db, groupId);
  getUser(db, endorserUserId);
  getUser(db, joiningUserId);

  const endorserIsMember = (g.members||[]).some(m => m.userId === endorserUserId);
  if (!endorserIsMember) return res.status(403).json({error:"not_member"});

  const joiner = (g.members||[]).find(m => m.userId === joiningUserId);
  if (!joiner) return res.status(404).json({error:"joining_user_not_in_group"});
  if (joiner.verified) return res.json(g);

  g.endorsements ||= [];
  const already = g.endorsements.some(e => e.endorser === endorserUserId && e.endorsed === joiningUserId);
  if (!already) {
    g.endorsements.push({ endorser: endorserUserId, endorsed: joiningUserId, timestamp: new Date().toISOString() });
  }

  const needed = g.endorsementsNeeded || 1;
  const have = g.endorsements.filter(e => e.endorsed === joiningUserId).length;
  if (have >= needed) {
    joiner.verified = true;
    pushSystemEvent(db, groupId, `@${db.users[joiningUserId].displayName} is now active (endorsements ${have}/${needed}).`);
  } else {
    pushSystemEvent(db, groupId, `Endorsement ${have}/${needed} for @${db.users[joiningUserId].displayName}.`);
  }

  save(db);
  res.json(g);
});

// ---------- MESSAGES ----------
app.get("/api/groups/:groupId/messages", (req, res) => {
  const db = load(); ensure(db);
  const { groupId } = req.params;
  const userId = req.query.userId; // expect ?userId=... in request

  const g = groupById(db, groupId);
  if (!g) return res.status(404).json({ error: "group_not_found" });

  // check if user is member
  const member = (g.members || []).find(m => m.userId === userId);
  if (!member) return res.status(403).json({ error: "not_member" });

  // ❌ If not yet verified, block history
  if (!member.verified) {
    return res.json([
      {
        id: "system-pending",
        groupId,
        senderUserId: "system",
        senderName: "System",
        text: "🔒 You are pending endorsement. You will see history once approved.",
        timestamp: new Date().toISOString()
      }
    ]);
  }

  // ✅ Verified members see all messages
  const list = db.messages[groupId] || [];
  res.json(list);
});

app.post("/api/groups/:groupId/messages", (req,res)=>{
  const db = load(); ensure(db);
  const { groupId } = req.params;
  const { senderUserId, text } = req.body || {};
  if (!senderUserId || !text) return res.status(400).json({error:"senderUserId and text required"});
  const g = groupById(db, groupId);

  const isMember = (g.members||[]).some(m => m.userId === senderUserId && m.verified);
  if (!isMember) return res.status(403).json({error:"not_active_member"});

  db.messages[groupId] ||= [];
  const senderName = db.users[senderUserId]?.displayName || senderUserId;
  db.messages[groupId].push({
    id: uuid(),
    groupId,
    senderUserId,
    senderName,
    text,
    timestamp: new Date().toISOString(),
  });
  save(db);
  res.json({ok:true});
});

// ---------- start ----------
const PORT = process.env.PORT || 4000;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Ceremony-Chat backend on http://0.0.0.0:${PORT}`);
});
