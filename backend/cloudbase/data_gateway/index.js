// CloudBase 云函数:data_gateway
// Godot(HTTP)统一入口,对云数据库做 CRUD。集合 = 表名,每行带 family_id。
// 支持 action: snapshot(批量拉) / query(单表拉) / upsert(写) / delete(删)。
//
// 部署:见同目录 README.md。需绑定 HTTP 触发,并在云函数环境装 @cloudbase/node-sdk。

const cloudbase = require('@cloudbase/node-sdk');

const app = cloudbase.init({ env: process.env.TCB_ENV || cloudbase.SYMBOL_CURRENT_ENV });
const db = app.database();

// 允许的集合(白名单,避免任意表写入)
const TABLES = new Set([
  'memories', 'nodes', 'answers', 'rooms', 'room_objects', 'families',
  'inventories', 'travel_places', 'postcards', 'messages', 'mailbox_events',
]);

function parseBody(event) {
  if (event && typeof event.body === 'string') {
    try { return JSON.parse(event.body); } catch (e) { return {}; }
  }
  return (event && event.body) || event || {};
}

async function queryTable(table, familyId) {
  let q = db.collection(table);
  if (familyId) q = q.where({ family_id: familyId });
  const res = await q.limit(1000).get();
  return res.data || [];
}

exports.main = async (event) => {
  const body = parseBody(event);
  const action = body.action || '';
  const familyId = body.family_id || '';

  try {
    if (action === 'snapshot') {
      const tables = Array.isArray(body.tables) ? body.tables : [];
      const out = {};
      for (const t of tables) {
        if (TABLES.has(t)) out[t] = await queryTable(t, familyId);
      }
      return { ok: true, tables: out };
    }

    if (action === 'query') {
      if (!TABLES.has(body.table)) return { ok: false, error: 'bad table' };
      return { ok: true, rows: await queryTable(body.table, familyId) };
    }

    if (action === 'upsert') {
      if (!TABLES.has(body.table)) return { ok: false, error: 'bad table' };
      const row = Object.assign({}, body.row || {}, { family_id: familyId });
      const id = String(row.id || '');
      if (id) {
        // set:存在即覆盖,不存在即创建
        await db.collection(body.table).doc(id).set(row);
        return { ok: true, id };
      }
      const added = await db.collection(body.table).add(row);
      return { ok: true, id: added.id };
    }

    if (action === 'delete') {
      if (!TABLES.has(body.table)) return { ok: false, error: 'bad table' };
      await db.collection(body.table).doc(String(body.id)).remove();
      return { ok: true };
    }

    return { ok: false, error: 'unknown action: ' + action };
  } catch (err) {
    return { ok: false, error: String(err && err.message || err) };
  }
};
