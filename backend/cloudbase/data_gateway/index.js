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
  'farm_plots',
]);
const AUDITED_TABLES = new Set([
  'memories', 'nodes', 'answers', 'rooms', 'room_objects', 'families',
  'travel_places', 'postcards', 'messages', 'mailbox_events',
  'farm_plots',
]);
const AUTO_CREATE_TABLES = new Set([
  'travel_places', 'postcards', 'messages', 'mailbox_events', 'farm_plots',
]);

// 自助加入时允许选的角色(对应客户端 characters.json 里的 4 套立绘)
const VALID_ROLES = new Set(['father', 'mother', 'partner', 'player']);
const FORBIDDEN_OBJECT_KEYS = new Set(['__proto__', 'prototype', 'constructor']);
const IMAGE_MIME_TO_EXT = new Map([
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
]);
const MAX_IMAGE_BYTES = 6 * 1024 * 1024;
const TEMP_URL_TTL_SECONDS = 10 * 60;
const ORPHAN_UPLOAD_MIN_AGE_MS = 24 * 60 * 60 * 1000;
const ORPHAN_UPLOAD_DELETE_LIMIT = 25;
const FARM_PLOT_COUNT = 36;
const FARM_CROP_ID_RE = /^[a-z0-9_]{1,40}$/;

// CloudBase database 依赖当前仍包含旧版 lodash.set/unset。请求进入 SDK 前拒绝原型链键、
// 过深或异常庞大的对象，避免客户端输入触发 prototype pollution 或遍历型 DoS。
function hasUnsafeObjectShape(root) {
  const stack = [{ value: root, depth: 0 }];
  let inspected = 0;
  while (stack.length > 0) {
    const { value, depth } = stack.pop();
    if (value === null || typeof value !== 'object') continue;
    if (depth > 32 || ++inspected > 10000) return true;
    for (const key of Object.keys(value)) {
      if (FORBIDDEN_OBJECT_KEYS.has(key)) return true;
      stack.push({ value: value[key], depth: depth + 1 });
    }
  }
  return false;
}

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

function stableScope(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex').slice(0, 20);
}

function uploadDocumentId() {
  return 'upload_' + crypto.randomBytes(16).toString('hex');
}

function hasExpectedImageSignature(bytes, contentType) {
  if (contentType === 'image/jpeg') {
    return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  if (contentType === 'image/png') {
    return bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  }
  if (contentType === 'image/webp') {
    return bytes.length >= 12 && bytes.subarray(0, 4).toString('ascii') === 'RIFF' && bytes.subarray(8, 12).toString('ascii') === 'WEBP';
  }
  return false;
}

function imageDimensions(bytes, contentType) {
  if (contentType === 'image/png' && bytes.length >= 24 && bytes.subarray(12, 16).toString('ascii') === 'IHDR') {
    return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
  }
  if (contentType === 'image/jpeg') {
    const sofMarkers = new Set([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf]);
    let offset = 2;
    while (offset + 8 < bytes.length) {
      if (bytes[offset] !== 0xff) { offset += 1; continue; }
      const marker = bytes[offset + 1];
      offset += 2;
      if (marker === 0xd8 || marker === 0xd9) continue;
      if (offset + 2 > bytes.length) break;
      const length = bytes.readUInt16BE(offset);
      if (length < 2 || offset + length > bytes.length) break;
      if (sofMarkers.has(marker) && length >= 7) {
        return { width: bytes.readUInt16BE(offset + 5), height: bytes.readUInt16BE(offset + 3) };
      }
      offset += length;
    }
  }
  if (contentType === 'image/webp' && bytes.length >= 30) {
    const chunk = bytes.subarray(12, 16).toString('ascii');
    if (chunk === 'VP8X') {
      return { width: 1 + bytes.readUIntLE(24, 3), height: 1 + bytes.readUIntLE(27, 3) };
    }
    if (chunk === 'VP8L' && bytes[20] === 0x2f) {
      return {
        width: 1 + bytes[21] + ((bytes[22] & 0x3f) << 8),
        height: 1 + (bytes[22] >> 6) + (bytes[23] << 2) + ((bytes[24] & 0x0f) << 10),
      };
    }
    if (chunk === 'VP8 ' && bytes[23] === 0x9d && bytes[24] === 0x01 && bytes[25] === 0x2a) {
      return { width: bytes.readUInt16LE(26) & 0x3fff, height: bytes.readUInt16LE(28) & 0x3fff };
    }
  }
  return null;
}

function validImageDimensions(dimensions) {
  if (!dimensions) return false;
  const { width, height } = dimensions;
  return Number.isInteger(width) && Number.isInteger(height)
    && width >= 32 && height >= 32
    && width <= 12000 && height <= 12000
    && width * height <= 40_000_000;
}

function decodeImage(body) {
  const contentType = String(body.content_type || '').toLowerCase().trim();
  const extension = IMAGE_MIME_TO_EXT.get(contentType);
  if (!extension) return { error: 'unsupported image type' };
  const encoded = String(body.base64_data || '');
  // base64 理论上约为原文件的 4/3；先做字符串上限，避免在解码前分配超大 Buffer。
  if (!encoded || encoded.length > Math.ceil(MAX_IMAGE_BYTES * 4 / 3) + 8) {
    return { error: 'image too large' };
  }
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(encoded) || encoded.length % 4 !== 0) {
    return { error: 'invalid base64 image' };
  }
  const bytes = Buffer.from(encoded, 'base64');
  if (!bytes.length || bytes.length > MAX_IMAGE_BYTES) return { error: 'image too large' };
  if (!hasExpectedImageSignature(bytes, contentType)) return { error: 'image signature mismatch' };
  const dimensions = imageDimensions(bytes, contentType);
  if (!validImageDimensions(dimensions)) return { error: 'invalid image dimensions' };
  return { bytes, contentType, extension, width: dimensions.width, height: dimensions.height };
}

async function temporaryImageUrl(fileId) {
  const result = await app.getTempFileURL({
    fileList: [{ fileID: fileId, maxAge: TEMP_URL_TTL_SECONDS }],
  });
  const first = result && Array.isArray(result.fileList) ? result.fileList[0] : null;
  const url = String(first && (first.tempFileURL || first.download_url) || '');
  if (!url) throw new Error('temporary image URL unavailable');
  return url;
}

async function findUpload(uploadId, familyId) {
  if (!/^upload_[a-f0-9]{32}$/.test(uploadId)) return null;
  const got = await db.collection('uploads').doc(uploadId).get().catch(() => ({ data: [] }));
  const row = got.data && got.data[0];
  if (!row || String(row.family_id) !== familyId) return null;
  return row;
}

async function isUploadReferenced(uploadId, familyId) {
  const result = await db.collection('memories').where({ family_id: familyId, upload_id: uploadId }).limit(1).get();
  return Boolean(result.data && result.data.length > 0);
}

async function cleanupOrphanUploads(familyId, memberId) {
  const uploadsResult = await db.collection('uploads').where({ family_id: familyId, owner_member_id: memberId }).limit(200).get().catch(() => ({ data: [] }));
  const cutoff = Date.now() - ORPHAN_UPLOAD_MIN_AGE_MS;
  let deleted = 0;
  for (const row of uploadsResult.data || []) {
    if (deleted >= ORPHAN_UPLOAD_DELETE_LIMIT) break;
    const uploadId = String(row.id || row._id || '');
    const createdAt = Date.parse(String(row.created_at || ''));
    if (!uploadId || !Number.isFinite(createdAt) || createdAt > cutoff) continue;
    try {
      if (await isUploadReferenced(uploadId, familyId)) continue;
      await app.deleteFile({ fileList: [String(row.file_id)] });
      await db.collection('uploads').doc(uploadId).remove();
      deleted += 1;
    } catch (_) {
      // 引用查询或存储删除失败时保留元数据，下一次启动再安全重试。
    }
  }
  return deleted;
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

async function listFamilyMembers(familyId) {
  const res = await db.collection('members').where({ family_id: familyId }).limit(100).get();
  return (res.data || []).map((doc) => ({
    member_id: String(doc._id || doc.id),
    family_id: String(doc.family_id || ''),
    role: String(doc.role || ''),
    display_name: String(doc.display_name || ''),
  }));
}

// 单个集合查询失败(如集合还没手动创建)不应拖垮整批 snapshot——降级返回空数组,
// 让其它已就绪的集合仍能正常同步。
async function queryGeneric(table, familyId) {
  try {
    const res = await db.collection(table).where({ family_id: familyId }).limit(1000).get();
    return res.data || [];
  } catch (err) {
    try {
      if (await ensureCollectionAfterMissingError(table, err)) return [];
    } catch (createErr) {
      console.warn('[data_gateway] auto-create failed for table=' + table + ': ' + (createErr && createErr.message || createErr));
    }
    console.warn('[data_gateway] query failed for table=' + table + ': ' + (err && err.message || err));
    return [];
  }
}

function isMissingCollectionError(err) {
  const text = String((err && (err.code || err.message)) || err || '');
  return text.includes('DATABASE_COLLECTION_NOT_EXIST')
    || text.includes('COLLECTION_NOT_EXIST')
    || text.includes('Db or Table not exist')
    || text.includes('collection not exist');
}

async function ensureCollectionAfterMissingError(table, err) {
  if (!AUTO_CREATE_TABLES.has(table) || !isMissingCollectionError(err)) return false;
  try {
    await db.createCollection(table);
    console.warn('[data_gateway] auto-created missing collection: ' + table);
    return true;
  } catch (createErr) {
    const text = String((createErr && (createErr.code || createErr.message)) || createErr || '');
    if (text.includes('already exist') || text.includes('COLLECTION_ALREADY_EXISTS')) return true;
    throw err;
  }
}

async function setGenericDocument(table, id, row) {
  try {
    await db.collection(table).doc(id).set(row);
  } catch (err) {
    if (!(await ensureCollectionAfterMissingError(table, err))) throw err;
    await db.collection(table).doc(id).set(row);
  }
}

async function addGenericDocument(table, row) {
  try {
    return await db.collection(table).add(row);
  } catch (err) {
    if (!(await ensureCollectionAfterMissingError(table, err))) throw err;
    return await db.collection(table).add(row);
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

function normalizeFarmPlot(row, familyId) {
  const plotIndex = Number(row.plot_index);
  if (!Number.isInteger(plotIndex) || plotIndex < 0 || plotIndex >= FARM_PLOT_COUNT) {
    return { error: 'bad farm plot index' };
  }
  const cropId = String(row.crop_id || '').trim();
  if (!FARM_CROP_ID_RE.test(cropId)) return { error: 'bad farm crop_id' };
  const plantedAt = String(row.planted_at || '').trim();
  const plantedAtUnix = Number(row.planted_at_unix || 0);
  const stableId = `farm_plot:${familyId}:${plotIndex}`;
  return {
    row: {
      id: stableId,
      plot_index: plotIndex,
      crop_id: cropId,
      planted_at: plantedAt || new Date().toISOString(),
      planted_at_unix: Number.isFinite(plantedAtUnix) && plantedAtUnix > 0
        ? Math.floor(plantedAtUnix)
        : Math.floor(Date.now() / 1000),
    },
  };
}

exports.main = async (event) => {
  const body = parseBody(event);
  if (hasUnsafeObjectShape(body)) {
    return { ok: false, code: 400, error: 'invalid object structure' };
  }
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

    if (action === 'list_family_members') {
      return { ok: true, family_id: familyId, members: await listFamilyMembers(familyId) };
    }

    if (action === 'upload_image') {
      const decoded = decodeImage(body);
      if (decoded.error) return { ok: false, code: 400, error: decoded.error };
      const uploadId = uploadDocumentId();
      const cloudPath = [
        'ai_uploads', stableScope(familyId), stableScope(memberId),
        uploadId + '.' + decoded.extension,
      ].join('/');
      const uploaded = await app.uploadFile({ cloudPath, fileContent: decoded.bytes });
      const fileId = String(uploaded && (uploaded.fileID || uploaded.fileId) || '');
      if (!fileId) throw new Error('upload did not return fileID');
      const row = {
        id: uploadId,
        family_id: familyId,
        owner_member_id: memberId,
        file_id: fileId,
        cloud_path: cloudPath,
        content_type: decoded.contentType,
        size_bytes: decoded.bytes.length,
        width: decoded.width,
        height: decoded.height,
        created_at: new Date().toISOString(),
      };
      try {
        await db.collection('uploads').doc(uploadId).set(row);
      } catch (err) {
        await app.deleteFile({ fileList: [fileId] }).catch(() => {});
        throw err;
      }
      const imageUrl = await temporaryImageUrl(fileId);
      return {
        ok: true,
        upload_id: uploadId,
        image_url: imageUrl,
        content_type: decoded.contentType,
        size_bytes: decoded.bytes.length,
        width: decoded.width,
        height: decoded.height,
        expires_in: TEMP_URL_TTL_SECONDS,
      };
    }

    if (action === 'resolve_image') {
      const uploadId = String(body.upload_id || '');
      const upload = await findUpload(uploadId, familyId);
      if (!upload) return { ok: false, code: 404, error: 'image not found' };
      return {
        ok: true,
        upload_id: uploadId,
        image_url: await temporaryImageUrl(String(upload.file_id)),
        content_type: String(upload.content_type || ''),
        size_bytes: Number(upload.size_bytes || 0),
        width: Number(upload.width || 0),
        height: Number(upload.height || 0),
        expires_in: TEMP_URL_TTL_SECONDS,
      };
    }

    if (action === 'delete_image') {
      const uploadId = String(body.upload_id || '');
      const upload = await findUpload(uploadId, familyId);
      if (!upload) return { ok: false, code: 404, error: 'image not found' };
      if (String(upload.owner_member_id) !== memberId) {
        return { ok: false, code: 403, error: 'forbidden' };
      }
      if (await isUploadReferenced(uploadId, familyId)) {
        return { ok: false, code: 409, error: 'image is referenced' };
      }
      await app.deleteFile({ fileList: [String(upload.file_id)] });
      await db.collection('uploads').doc(uploadId).remove();
      return { ok: true };
    }

    if (action === 'cleanup_orphan_images') {
      return { ok: true, deleted: await cleanupOrphanUploads(familyId, memberId) };
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

      if (body.table === 'farm_plots') {
        const normalized = normalizeFarmPlot(incoming, familyId);
        if (normalized.error) return { ok: false, code: 400, error: normalized.error };
        incoming.id = normalized.row.id;
        incoming.plot_index = normalized.row.plot_index;
        incoming.crop_id = normalized.row.crop_id;
        incoming.planted_at = normalized.row.planted_at;
        incoming.planted_at_unix = normalized.row.planted_at_unix;
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
          if (body.table === 'farm_plots') {
            return { ok: false, code: 409, error: 'plot occupied' };
          }
        }
      }
      const cleanIncoming = Object.assign({}, incoming);
      delete cleanIncoming.family_id;
      delete cleanIncoming.created_by_member_id;
      delete cleanIncoming.updated_by_member_id;
      const audit = AUDITED_TABLES.has(body.table)
        ? {
            created_by_member_id: existing.created_by_member_id || memberId,
            updated_by_member_id: memberId,
            updated_at: new Date().toISOString(),
          }
        : {};
      const cleanExisting = Object.assign({}, existing);
      delete cleanExisting._id;
      const merged = Object.assign({}, cleanExisting, cleanIncoming, { family_id: familyId }, audit);
      if (id) {
        await setGenericDocument(body.table, id, merged);
        return { ok: true, id };
      }
      const added = await addGenericDocument(body.table, merged);
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
