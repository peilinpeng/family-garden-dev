// CloudBase 云函数:data_gateway(安全加固版)
// Godot(HTTP)统一入口,对云数据库做 CRUD。集合 = 表名。
//
// 安全模型:
//  - 客户端在 Authorization: Bearer <access_key> 里带「家庭访问密钥」。
//  - 网关用 access_key 在服务端查 families 集合 → 解析出 family_id。**绝不信客户端传的 family_id。**
//  - 无效/缺失密钥 → 401。所有读写只作用于解析出的 family_id。
//  - 客户端永远不能写 access_key 字段;families.access_key 由后台预先种入。
//
// 部署:见同目录 README.md。需先给某家庭种一条 families 行(含随机 access_key)。

const cloudbase = require('@cloudbase/node-sdk');

const app = cloudbase.init({ env: process.env.TCB_ENV || cloudbase.SYMBOL_CURRENT_ENV });
const db = app.database();
const _ = db.command;

// 可写集合白名单(避免任意表)
const TABLES = new Set([
  'memories', 'nodes', 'answers', 'rooms', 'room_objects', 'families',
  'inventories', 'travel_places', 'postcards', 'messages', 'mailbox_events',
]);
// 服务端专属、客户端永不可写的字段
const PROTECTED_FIELDS = ['access_key'];

function parseBody(event) {
  if (event && typeof event.body === 'string') {
    try { return JSON.parse(event.body); } catch (e) { return {}; }
  }
  return (event && event.body) || event || {};
}

function bearerToken(event) {
  const h = (event && event.headers) || {};
  const raw = h.authorization || h.Authorization || '';
  const m = /^Bearer\s+(.+)$/i.exec(raw);
  return m ? m[1].trim() : '';
}

// 用 access_key 解析家庭;返回 { family_id } 或 null
async function resolveFamily(token) {
  if (!token) return null;
  const res = await db.collection('families').where({ access_key: token }).limit(1).get();
  const rows = res.data || [];
  if (rows.length === 0) return null;
  const doc = rows[0];
  return { family_id: String(doc._id || doc.id || doc.family_id) };
}

function stripProtected(obj) {
  const o = Object.assign({}, obj);
  for (const f of PROTECTED_FIELDS) delete o[f];
  return o;
}

async function queryTable(table, familyId) {
  const res = await db.collection(table).where({ family_id: familyId }).limit(1000).get();
  return (res.data || []).map(stripProtected); // 不把 access_key 等回传客户端
}

exports.main = async (event) => {
  const body = parseBody(event);
  const action = body.action || '';

  // —— 鉴权:服务端解析 family_id ——
  const fam = await resolveFamily(bearerToken(event));
  if (!fam) return { ok: false, code: 401, error: 'unauthorized' };
  const familyId = fam.family_id;

  try {
    if (action === 'snapshot') {
      const tables = Array.isArray(body.tables) ? body.tables : [];
      const out = {};
      for (const t of tables) if (TABLES.has(t)) out[t] = await queryTable(t, familyId);
      return { ok: true, tables: out };
    }

    if (action === 'query') {
      if (!TABLES.has(body.table)) return { ok: false, error: 'bad table' };
      return { ok: true, rows: await queryTable(body.table, familyId) };
    }

    if (action === 'upsert') {
      if (!TABLES.has(body.table)) return { ok: false, error: 'bad table' };
      const incoming = stripProtected(body.row || {});      // 客户端不能写保护字段
      const id = String(incoming.id || '');
      // merge-preserve:保留服务端已有字段(如 access_key),强制 family_id
      let existing = {};
      if (id) {
        const got = await db.collection(body.table).doc(id).get().catch(() => ({ data: [] }));
        if (got.data && got.data.length) existing = got.data[0];
      }
      const merged = Object.assign({}, existing, incoming, { family_id: familyId });
      if (id) {
        await db.collection(body.table).doc(id).set(merged);
        return { ok: true, id };
      }
      const added = await db.collection(body.table).add(merged);
      return { ok: true, id: added.id };
    }

    if (action === 'delete') {
      if (!TABLES.has(body.table)) return { ok: false, error: 'bad table' };
      const id = String(body.id);
      // 只能删本家庭的行
      const got = await db.collection(body.table).doc(id).get().catch(() => ({ data: [] }));
      if (got.data && got.data.length && String(got.data[0].family_id) === familyId) {
        await db.collection(body.table).doc(id).remove();
        return { ok: true };
      }
      return { ok: false, error: 'not found or forbidden' };
    }

    return { ok: false, error: 'unknown action: ' + action };
  } catch (err) {
    return { ok: false, error: String((err && err.message) || err) };
  }
};
