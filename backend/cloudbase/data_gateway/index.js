// CloudBase 云函数:data_gateway(每用户身份版 + 自助加入)
// Godot(HTTP)统一入口,对云数据库做 CRUD。集合 = 表名。
//
// 鉴权模型(每用户):
//  - 每个家庭成员在 members 集合里有一条独立记录:{family_id, member_token, role, display_name}。
//  - 客户端在 Authorization: Bearer <member_token> 里带自己的令牌。
//  - 网关用 member_token 服务端查 members → 解析出 {family_id, member_id, role}。
//    **body 里任何 family_id / member_id 一律忽略,不信客户端。**
//  - 无效/缺失令牌 → 401(join_family 例外,见下)。
//  - members 集合**不在 TABLES 白名单**:客户端任何 action 都够不着它,只能被本文件内部
//    resolveMember() 直接查询;member_token 永不通过 API 回传或可被改写。
//  - 个人数据(库存背包)按 owner_member_id 强制隔离:成员只能读写自己的背包行;
//    共享仓(storehouse)按 family_id 共享,家庭内任意成员可读写。
//
// 自助加入(join_family):**不需要令牌**——这就是发令牌本身的那一步。玩家在游戏里选完
// 角色/起完昵称,客户端传 {family_id, role, display_name},服务端随机生成一个新令牌、
// 建一条 members 记录、把令牌返回给客户端(客户端存进本机 user://,永不写进代码仓库)。
// 没有邀请码校验——任何知道 family_id 的人都能自助加入,这是产品侧确认接受的权衡
// (私人家庭游戏场景,不是防真实攻击者的公开平台)。
//
// 部署:见同目录 README.md。

const cloudbase = require('@cloudbase/node-sdk');
const crypto = require('crypto');

const app = cloudbase.init({ env: process.env.TCB_ENV || cloudbase.SYMBOL_CURRENT_ENV });
const db = app.database();

// 可被 action 直接读写的集合(members 不在其中,只能靠 resolveMember 内部查)
const TABLES = new Set([
  'memories', 'nodes', 'answers', 'rooms', 'room_objects', 'families',
  'inventories', 'travel_places', 'postcards', 'messages', 'mailbox_events',
]);

// 自助加入时允许选的角色(对应客户端 characters.json 里的 4 套立绘)
const VALID_ROLES = new Set(['father', 'mother', 'partner', 'player']);

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

// 用 member_token 解析身份;返回 {member_id, family_id, role, display_name} 或 null。
async function resolveMember(token) {
  if (!token) return null;
  const res = await db.collection('members').where({ member_token: token }).limit(1).get();
  const rows = res.data || [];
  if (rows.length === 0) return null;
  const doc = rows[0];
  return {
    member_id: String(doc._id || doc.id),
    family_id: String(doc.family_id),
    role: String(doc.role || ''),
    display_name: String(doc.display_name || ''),
  };
}

// 单个集合查询失败(如集合还没手动创建)不应拖垮整批 snapshot——降级返回空数组,
// 让其它已就绪的集合仍能正常同步。
async function queryGeneric(table, familyId) {
  try {
    const res = await db.collection(table).where({ family_id: familyId }).limit(1000).get();
    return res.data || [];
  } catch (err) {
    console.warn('[data_gateway] query failed for table=' + table + ': ' + (err && err.message || err));
    return [];
  }
}

// inventories 专属:只能看到「本家庭共享仓」+「自己的背包」,看不到别人的背包。
// 集合还没建好时降级返回空,不抛出。
async function queryInventories(familyId, memberId) {
  try {
    const shared = await db.collection('inventories')
      .where({ family_id: familyId, kind: 'storehouse' }).limit(10).get();
    const own = await db.collection('inventories')
      .where({ family_id: familyId, kind: 'backpack', owner_member_id: memberId }).limit(10).get();
    return [...(shared.data || []), ...(own.data || [])];
  } catch (err) {
    console.warn('[data_gateway] query failed for table=inventories: ' + (err && err.message || err));
    return [];
  }
}

async function upsertInventories(row, familyId, memberId) {
  const kind = String(row.kind || '');
  if (kind === 'backpack') {
    const id = 'backpack:' + memberId;               // 服务端强制,客户端传的 id 一律忽略
    const doc = { id, family_id: familyId, kind: 'backpack', owner_member_id: memberId, stacks: row.stacks || [] };
    await db.collection('inventories').doc(id).set(doc);
    return { ok: true, id };
  }
  if (kind === 'storehouse') {
    const id = 'storehouse:' + familyId;              // 每家庭一份,家庭内任意成员可写
    const doc = { id, family_id: familyId, kind: 'storehouse', stacks: row.stacks || [] };
    await db.collection('inventories').doc(id).set(doc);
    return { ok: true, id };
  }
  return { ok: false, error: 'bad inventory kind' };
}

exports.main = async (event) => {
  const body = parseBody(event);
  const action = body.action || '';

  // —— join_family:自助加入,不需要令牌(这一步本身就是发令牌) ——
  if (action === 'join_family') {
    const famId = String(body.family_id || '').trim();
    const role = String(body.role || '').trim();
    const displayName = String(body.display_name || '').trim().slice(0, 60);
    if (!famId || !VALID_ROLES.has(role)) {
      return { ok: false, error: 'family_id required, role must be one of father/mother/partner/player' };
    }
    try {
      const memberToken = crypto.randomBytes(24).toString('hex');
      const added = await db.collection('members').add({
        family_id: famId,
        member_token: memberToken,
        role,
        display_name: displayName || role,
      });
      return { ok: true, member_token: memberToken, member_id: added.id };
    } catch (err) {
      return { ok: false, error: String((err && err.message) || err) };
    }
  }

  // —— 鉴权:服务端用 member_token 解析身份(join_family 之外的所有 action 都需要) ——
  const identity = await resolveMember(bearerToken(event));
  if (!identity) return { ok: false, code: 401, error: 'unauthorized' };
  const { family_id: familyId, member_id: memberId } = identity;

  try {
    if (action === 'whoami') {
      return { ok: true, member_id: memberId, family_id: familyId, role: identity.role, display_name: identity.display_name };
    }

    if (action === 'snapshot') {
      const tables = Array.isArray(body.tables) ? body.tables : [];
      const out = {};
      for (const t of tables) {
        if (!TABLES.has(t)) continue;
        out[t] = t === 'inventories' ? await queryInventories(familyId, memberId) : await queryGeneric(t, familyId);
      }
      return { ok: true, tables: out };
    }

    if (action === 'query') {
      if (!TABLES.has(body.table)) return { ok: false, error: 'bad table' };
      const rows = body.table === 'inventories'
        ? await queryInventories(familyId, memberId)
        : await queryGeneric(body.table, familyId);
      return { ok: true, rows };
    }

    if (action === 'upsert') {
      if (!TABLES.has(body.table)) return { ok: false, error: 'bad table' };
      const incoming = Object.assign({}, body.row || {});

      if (body.table === 'inventories') {
        return await upsertInventories(incoming, familyId, memberId);
      }

      // 通用表:强制 family_id,保留服务端已有字段,客户端不能覆盖别家的行
      const id = String(incoming.id || '');
      let existing = {};
      if (id) {
        const got = await db.collection(body.table).doc(id).get().catch(() => ({ data: [] }));
        if (got.data && got.data.length) {
          if (String(got.data[0].family_id) !== familyId) {
            return { ok: false, code: 403, error: 'forbidden' };
          }
          existing = got.data[0];
        }
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
      const got = await db.collection(body.table).doc(id).get().catch(() => ({ data: [] }));
      if (!got.data || !got.data.length) return { ok: false, error: 'not found' };
      const row = got.data[0];
      if (String(row.family_id) !== familyId) return { ok: false, code: 403, error: 'forbidden' };
      if (body.table === 'inventories' && row.kind === 'backpack' && String(row.owner_member_id) !== memberId) {
        return { ok: false, code: 403, error: 'forbidden' };
      }
      await db.collection(body.table).doc(id).remove();
      return { ok: true };
    }

    return { ok: false, error: 'unknown action: ' + action };
  } catch (err) {
    return { ok: false, error: String((err && err.message) || err) };
  }
};
