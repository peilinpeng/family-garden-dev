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
  'farm_plots', 'farm_livestock', 'farm_activity_log', 'kitchen_dishes',
]);
const AUDITED_TABLES = new Set([
  'memories', 'nodes', 'answers', 'rooms', 'room_objects', 'families',
  'travel_places', 'postcards', 'messages', 'mailbox_events',
  'farm_plots', 'farm_livestock', 'farm_activity_log', 'kitchen_dishes',
]);
const AUTO_CREATE_TABLES = new Set([
  'travel_places', 'postcards', 'messages', 'mailbox_events', 'farm_plots', 'farm_livestock', 'farm_activity_log',
  'kitchen_dishes',
]);

// 自助加入时允许选的角色（对应客户端 characters.json 里的 6 个家庭身份）。
const VALID_ROLES = new Set(['father', 'mother', 'grandfather', 'grandmother', 'partner', 'player']);
const FORBIDDEN_OBJECT_KEYS = new Set(['__proto__', 'prototype', 'constructor']);
const IMAGE_MIME_TO_EXT = new Map([
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
]);
const IMAGE_UPLOAD_PURPOSES = new Set(['ai', 'travel']);
const MAX_IMAGE_BYTES = 6 * 1024 * 1024;
const TEMP_URL_TTL_SECONDS = 10 * 60;
const ORPHAN_UPLOAD_MIN_AGE_MS = 24 * 60 * 60 * 1000;
const ORPHAN_UPLOAD_DELETE_LIMIT = 25;
const CASCADE_DELETE_BATCH_SIZE = 100;
const FARM_PLOT_COUNT = 36;
const INVENTORY_ITEM_ID_RE = /^[a-z0-9_:-]{1,80}$/;
const INVENTORY_OPERATION_ID_RE = /^[a-zA-Z0-9_:-]{8,120}$/;
const STOREHOUSE_SLOT_COUNT = 120;
const RECENT_OPERATION_LIMIT = 32;
const FARM_STAGE_COUNT = 7;
const AUDITABLE_ACTIONS = new Set([
  'join_family', 'whoami', 'list_family_members', 'upload_image', 'resolve_image',
  'delete_image', 'cleanup_orphan_images', 'delete_place_bundle', 'mutate_storehouse',
  'farm_action', 'snapshot', 'query', 'upsert', 'delete',
]);
const FARM_CROPS = new Map([
  ['corrato', { stageDuration: 90, baseYield: 2 }],
  ['tomelone', { stageDuration: 120, baseYield: 2 }],
  ['peanks', { stageDuration: 120, baseYield: 2 }],
  ['cauliviol', { stageDuration: 150, baseYield: 3 }],
  ['bottarries', { stageDuration: 120, baseYield: 2 }],
  ['safruma', { stageDuration: 120, baseYield: 2 }],
  ['mooam', { stageDuration: 120, baseYield: 2 }],
  ['reoin', { stageDuration: 120, baseYield: 2 }],
  ['rocue', { stageDuration: 120, baseYield: 2 }],
  ['sproccili', { stageDuration: 120, baseYield: 2 }],
  ['cacorange', { stageDuration: 120, baseYield: 2 }],
  ['popacom', { stageDuration: 120, baseYield: 2 }],
  ['chuf', { stageDuration: 120, baseYield: 2 }],
  ['trevainne', { stageDuration: 120, baseYield: 2 }],
  ['cacerries', { stageDuration: 120, baseYield: 2 }],
  ['aubaba', { stageDuration: 120, baseYield: 2 }],
]);
const FARM_LIVESTOCK = new Map([
  ['chicken_coop', { outputItemId: 'egg', outputQuantity: 1, cooldown: 120 }],
  ['cow_shed', { outputItemId: 'milk', outputQuantity: 1, cooldown: 180 }],
]);

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

// 生产日志只保存可枚举的动作、请求 ID、耗时和稳定错误分类。不得把 token、家庭 ID、
// 成员 ID、图片内容或服务端异常原文写入日志，避免把家庭隐私扩散到云函数日志系统。
function requestIdFromEvent() {
  // 不接受客户端传入的 request ID，避免恶意客户端把 token 或私人内容伪装成可记录字段。
  return 'gw_' + crypto.randomBytes(12).toString('hex');
}

function auditAction(value) {
  return AUDITABLE_ACTIONS.has(value) ? value : 'unknown';
}

function auditErrorClass(result, code) {
  if (!result || result.ok) return undefined;
  if (code === 400) return 'invalid_request';
  if (code === 401) return 'unauthorized';
  if (code === 403) return 'forbidden';
  if (code === 404) return 'not_found';
  if (code === 409) return 'conflict';
  return 'internal_error';
}

function requestAuditRecord({ requestId, action, startedAt, result }) {
  const suppliedCode = Number(result && result.code);
  const code = Number.isInteger(suppliedCode) && suppliedCode >= 100 && suppliedCode <= 599
    ? suppliedCode
    : (result && result.ok ? 200 : 400);
  const record = {
    event: 'data_gateway_request_completed',
    request_id: requestId,
    action: auditAction(action),
    ok: Boolean(result && result.ok),
    code,
    duration_ms: Math.max(0, Date.now() - startedAt),
  };
  const errorClass = auditErrorClass(result, code);
  if (errorClass) record.error_class = errorClass;
  return record;
}

function writeRequestAudit(record, sink = console) {
  // CloudBase 函数日志仅稳定采集标准输出；不要使用 info/warn/error 等分级接口，
  // 以便控制台可按 request_id 检索这条结构化审计记录。
  sink.log(JSON.stringify(record));
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
  const references = [
    ['memories', 'upload_id'],
    ['travel_places', 'photo_upload_id'],
    ['postcards', 'photo_upload_id'],
  ];
  for (const [table, field] of references) {
    const result = await db.collection(table)
      .where({ family_id: familyId, [field]: uploadId })
      .limit(1)
      .get();
    if (result.data && result.data.length > 0) return true;
  }
  return false;
}

async function removeUpload(uploadId, familyId) {
  const upload = await findUpload(uploadId, familyId);
  if (!upload || await isUploadReferenced(uploadId, familyId)) return false;
  await app.deleteFile({ fileList: [String(upload.file_id)] });
  await db.collection('uploads').doc(uploadId).remove();
  return true;
}

async function deletePlaceBundle(placeId, familyId) {
  if (!placeId) return { ok: false, code: 400, error: 'missing place id' };
  const got = await db.collection('travel_places').doc(placeId).get();
  const place = got.data && got.data[0];
  if (!place) return { ok: false, code: 404, error: 'place not found' };
  if (String(place.family_id) !== familyId) return { ok: false, code: 403, error: 'forbidden' };

  const uploadIds = new Set();
  const placeUploadId = String(place.photo_upload_id || '');
  if (placeUploadId) uploadIds.add(placeUploadId);

  const deletedPostcardIds = [];
  const deletedEventIds = [];

  // 每批删除后重新查询第一页，避免 skip + delete 导致后续记录移位漏删。
  // 任意查询或删除失败都会抛出，由入口返回失败并保留地点，下一次可安全重试。
  while (true) {
    const postcardResult = await db.collection('postcards')
      .where({ family_id: familyId, place_id: placeId })
      .limit(CASCADE_DELETE_BATCH_SIZE)
      .get();
    const postcards = postcardResult.data || [];
    if (postcards.length === 0) break;

    for (const postcard of postcards) {
      const postcardId = String(postcard._id || postcard.id || '');
      if (!postcardId) throw new Error('linked postcard missing id');
      const postcardUploadId = String(postcard.photo_upload_id || '');
      if (postcardUploadId) uploadIds.add(postcardUploadId);

      while (true) {
        const eventResult = await db.collection('mailbox_events')
          .where({ family_id: familyId, target_id: postcardId })
          .limit(CASCADE_DELETE_BATCH_SIZE)
          .get();
        const events = eventResult.data || [];
        if (events.length === 0) break;
        for (const event of events) {
          const eventId = String(event._id || event.id || '');
          if (!eventId) throw new Error('linked mailbox event missing id');
          await db.collection('mailbox_events').doc(eventId).remove();
          deletedEventIds.push(eventId);
        }
      }

      await db.collection('postcards').doc(postcardId).remove();
      deletedPostcardIds.push(postcardId);
    }
  }
  await db.collection('travel_places').doc(placeId).remove();

  const deletedUploadIds = [];
  for (const uploadId of uploadIds) {
    if (await removeUpload(uploadId, familyId)) deletedUploadIds.push(uploadId);
  }
  return {
    ok: true,
    place_id: placeId,
    postcard_ids: deletedPostcardIds,
    event_ids: deletedEventIds,
    deleted_upload_ids: deletedUploadIds,
  };
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
    // 共享仓禁止再用整份客户端快照覆盖；所有改动必须走 mutate_storehouse 事务接口。
    return { ok: false, code: 409, error: 'storehouse snapshot writes disabled' };
  }
  return { ok: false, error: 'bad inventory kind' };
}

function documentRow(result) {
  const data = result && result.data;
  if (Array.isArray(data)) return data[0] || null;
  return data && typeof data === 'object' ? data : null;
}

function transactionValue(result) {
  return result && typeof result.result === 'object' ? result.result : result;
}

function cleanDocument(row) {
  const clean = Object.assign({}, row || {});
  delete clean._id;
  return clean;
}

function inventoryDocument(kind, familyId, memberId, existing = null) {
  const id = kind === 'storehouse' ? `storehouse:${familyId}` : `backpack:${memberId}`;
  return Object.assign(cleanDocument(existing), {
    id,
    family_id: familyId,
    kind,
    stacks: Array.isArray(existing && existing.stacks) ? existing.stacks : [],
    version: Math.max(0, Number(existing && existing.version) || 0),
  }, kind === 'backpack' ? { owner_member_id: memberId } : {});
}

function normalizeInventoryChanges(value) {
  if (!Array.isArray(value) || value.length > 32) return { error: 'bad inventory changes' };
  const merged = new Map();
  for (const raw of value) {
    const id = String(raw && raw.id || '').trim();
    const quantity = Number(raw && (raw.quantity ?? raw.qty));
    const maxStack = Number(raw && raw.max_stack || 99);
    if (!INVENTORY_ITEM_ID_RE.test(id) || !Number.isInteger(quantity) || quantity <= 0 || quantity > 1_000_000) {
      return { error: 'bad inventory change' };
    }
    const previous = merged.get(id) || { id, quantity: 0, max_stack: 99 };
    previous.quantity += quantity;
    previous.max_stack = Math.max(1, Math.min(9_999_999, Number.isInteger(maxStack) ? maxStack : 99));
    if (previous.quantity > 1_000_000) return { error: 'inventory change too large' };
    merged.set(id, previous);
  }
  return { changes: [...merged.values()] };
}

function normalizeStacks(value) {
  if (!Array.isArray(value)) return [];
  const stacks = [];
  for (const raw of value.slice(0, STOREHOUSE_SLOT_COUNT)) {
    const id = String(raw && raw.id || '').trim();
    const count = Number(raw && raw.count);
    if (INVENTORY_ITEM_ID_RE.test(id) && Number.isInteger(count) && count > 0 && count <= 9_999_999) {
      stacks.push({ id, count });
    }
  }
  return stacks;
}

function recentOperation(row, operationId) {
  const operations = Array.isArray(row && row.recent_operations) ? row.recent_operations : [];
  return operations.find((item) => String(item && item.id || '') === operationId) || null;
}

function recordOperationResult(row, operationId, operationResult) {
  const recent = (Array.isArray(row && row.recent_operations) ? row.recent_operations : [])
    .filter((item) => item && typeof item === 'object' && String(item.id || '') !== operationId)
    .slice(-(RECENT_OPERATION_LIMIT - 1));
  recent.push({ id: operationId, result: operationResult });
  return Object.assign(cleanDocument(row), {
    recent_operations: recent,
    updated_at: new Date().toISOString(),
  });
}

function applyInventoryChanges(row, consumes, grants, operationId, operationResult = {}) {
  const stacks = normalizeStacks(row.stacks);
  for (const change of consumes) {
    let left = change.quantity;
    for (let i = stacks.length - 1; i >= 0 && left > 0; i -= 1) {
      if (stacks[i].id !== change.id) continue;
      const taken = Math.min(stacks[i].count, left);
      stacks[i].count -= taken;
      left -= taken;
      if (stacks[i].count <= 0) stacks.splice(i, 1);
    }
    if (left > 0) return { error: 'insufficient inventory', code: 409, item_id: change.id };
  }
  for (const change of grants) {
    let left = change.quantity;
    for (const stack of stacks) {
      if (stack.id !== change.id || stack.count >= change.max_stack) continue;
      const added = Math.min(change.max_stack - stack.count, left);
      stack.count += added;
      left -= added;
      if (left <= 0) break;
    }
    while (left > 0 && stacks.length < STOREHOUSE_SLOT_COUNT) {
      const added = Math.min(change.max_stack, left);
      stacks.push({ id: change.id, count: added });
      left -= added;
    }
    if (left > 0) return { error: 'inventory full', code: 409, item_id: change.id };
  }
  const recorded = recordOperationResult(row, operationId, operationResult);
  return {
    row: Object.assign(recorded, {
      stacks,
      version: Math.max(0, Number(row.version) || 0) + 1,
    }),
  };
}

async function mutateStorehouse(body, familyId, memberId) {
  const operationId = String(body.operation_id || '').trim();
  if (!INVENTORY_OPERATION_ID_RE.test(operationId)) {
    return { ok: false, code: 400, error: 'bad operation_id' };
  }
  const parsedConsumes = normalizeInventoryChanges(body.consumes || []);
  const parsedGrants = normalizeInventoryChanges(body.grants || []);
  if (parsedConsumes.error || parsedGrants.error || (parsedConsumes.changes.length === 0 && parsedGrants.changes.length === 0)) {
    return { ok: false, code: 400, error: parsedConsumes.error || parsedGrants.error || 'empty inventory mutation' };
  }
  const id = `storehouse:${familyId}`;
  const wrapped = await db.runTransaction(async (transaction) => {
    const ref = transaction.collection('inventories').doc(id);
    const existing = inventoryDocument('storehouse', familyId, memberId, documentRow(await ref.get()));
    const duplicate = recentOperation(existing, operationId);
    if (duplicate) {
      return { ok: true, duplicate: true, id, version: existing.version, stacks: existing.stacks };
    }
    const changed = applyInventoryChanges(
      existing,
      parsedConsumes.changes,
      parsedGrants.changes,
      operationId,
      { kind: 'storehouse_mutation' },
    );
    if (changed.error) {
      return {
        ok: false,
        code: changed.code,
        error: changed.error,
        item_id: changed.item_id,
        id,
        version: existing.version,
        stacks: existing.stacks,
      };
    }
    const next = Object.assign(changed.row, { id, family_id: familyId, kind: 'storehouse' });
    await ref.set(next);
    return { ok: true, id, version: next.version, stacks: next.stacks };
  }, 3);
  return transactionValue(wrapped);
}

function farmPlotResponse(row) {
  if (!row) return {};
  return {
    id: String(row.id || row._id || ''),
    plot_index: Number(row.plot_index),
    crop_id: String(row.crop_id || ''),
    planted_at: String(row.planted_at || ''),
    planted_at_unix: Number(row.planted_at_unix || 0),
    watered: Boolean(row.watered),
    watered_at_unix: Number(row.watered_at_unix || 0),
    fertilized: Boolean(row.fertilized),
    fertilized_at_unix: Number(row.fertilized_at_unix || 0),
  };
}

async function performFarmAction(body, identity) {
  const familyId = identity.family_id;
  const memberId = identity.member_id;
  const actionType = String(body.farm_action || '').trim();
  const operationId = String(body.operation_id || '').trim();
  if (!INVENTORY_OPERATION_ID_RE.test(operationId)) {
    return { ok: false, code: 400, error: 'bad operation_id' };
  }
  if (!new Set(['plant', 'water', 'fertilize', 'harvest', 'uproot', 'collect_livestock']).has(actionType)) {
    return { ok: false, code: 400, error: 'bad farm action' };
  }

  if (actionType === 'collect_livestock') {
    await queryGeneric('farm_livestock', familyId);
  } else {
    await queryGeneric('farm_plots', familyId);
  }

  const wrapped = await db.runTransaction(async (transaction) => {
    const storehouseId = `storehouse:${familyId}`;
    const backpackId = `backpack:${memberId}`;
    const storehouseRef = transaction.collection('inventories').doc(storehouseId);
    const backpackRef = transaction.collection('inventories').doc(backpackId);
    let storehouse = inventoryDocument('storehouse', familyId, memberId, documentRow(await storehouseRef.get()));
    let backpack = inventoryDocument('backpack', familyId, memberId, documentRow(await backpackRef.get()));
    const duplicate = recentOperation(storehouse, operationId) || recentOperation(backpack, operationId);
    if (duplicate) {
      return Object.assign({
        ok: true,
        duplicate: true,
        farm_action: actionType,
        storehouse,
        backpack,
      }, duplicate.result || {});
    }

    const consumeAnywhere = async (itemId, quantity, result) => {
      const spec = [{ id: itemId, quantity, max_stack: 99 }];
      let changed = applyInventoryChanges(storehouse, spec, [], operationId, result);
      if (!changed.error) {
        storehouse = Object.assign(changed.row, { id: storehouseId, family_id: familyId, kind: 'storehouse' });
        await storehouseRef.set(storehouse);
        return true;
      }
      changed = applyInventoryChanges(backpack, spec, [], operationId, result);
      if (!changed.error) {
        backpack = Object.assign(changed.row, {
          id: backpackId,
          family_id: familyId,
          kind: 'backpack',
          owner_member_id: memberId,
        });
        await backpackRef.set(backpack);
        return true;
      }
      return false;
    };

    const grantStorehouse = async (itemId, quantity, result) => {
      const changed = applyInventoryChanges(
        storehouse,
        [],
        [{ id: itemId, quantity, max_stack: 99 }],
        operationId,
        result,
      );
      if (changed.error) return false;
      storehouse = Object.assign(changed.row, { id: storehouseId, family_id: familyId, kind: 'storehouse' });
      await storehouseRef.set(storehouse);
      return true;
    };

    // 把完整业务结果写回发生库存变动的文档；无库存变动的动作写入共享仓。
    // 这样响应丢失后的同 operation_id 重试仍能恢复地块删除、畜牧冷却等权威结果。
    const persistFarmResult = async (operationResult) => {
      if (recentOperation(storehouse, operationId)) {
        storehouse = recordOperationResult(storehouse, operationId, operationResult);
        await storehouseRef.set(storehouse);
        return;
      }
      if (recentOperation(backpack, operationId)) {
        backpack = recordOperationResult(backpack, operationId, operationResult);
        await backpackRef.set(backpack);
        return;
      }
      storehouse = recordOperationResult(storehouse, operationId, operationResult);
      await storehouseRef.set(storehouse);
    };

    if (actionType === 'collect_livestock') {
      const sourceId = String(body.source_id || '').trim();
      const definition = FARM_LIVESTOCK.get(sourceId);
      if (!definition) return { ok: false, code: 400, error: 'bad livestock source' };
      const livestockId = `farm_livestock:${familyId}:${sourceId}`;
      const livestockRef = transaction.collection('farm_livestock').doc(livestockId);
      const existing = documentRow(await livestockRef.get());
      const now = Math.floor(Date.now() / 1000);
      const lastCollectedAt = Number(existing && existing.last_collected_at_unix || 0);
      if (lastCollectedAt > 0 && now - lastCollectedAt < definition.cooldown) {
        return { ok: false, code: 409, error: 'livestock cooling down', retry_after: definition.cooldown - (now - lastCollectedAt) };
      }
      const result = { amount: definition.outputQuantity, source_id: sourceId };
      if (!(await grantStorehouse(definition.outputItemId, definition.outputQuantity, result))) {
        return { ok: false, code: 409, error: 'inventory full' };
      }
      const livestock = {
        id: livestockId,
        family_id: familyId,
        source_id: sourceId,
        last_collected_at_unix: now,
        updated_by_member_id: memberId,
        updated_at: new Date().toISOString(),
      };
      await livestockRef.set(livestock);
      await persistFarmResult({ amount: definition.outputQuantity, livestock });
      return { ok: true, farm_action: actionType, amount: definition.outputQuantity, livestock, storehouse, backpack };
    }

    const plotIndex = Number(body.plot_index);
    if (!Number.isInteger(plotIndex) || plotIndex < 0 || plotIndex >= FARM_PLOT_COUNT) {
      return { ok: false, code: 400, error: 'bad farm plot index' };
    }
    const plotId = `farm_plot:${familyId}:${plotIndex}`;
    const plotRef = transaction.collection('farm_plots').doc(plotId);
    const existing = documentRow(await plotRef.get());
    if (existing && String(existing.last_operation_id || '') === operationId) {
      return { ok: true, duplicate: true, farm_action: actionType, plot: farmPlotResponse(existing), storehouse, backpack };
    }
    const now = Math.floor(Date.now() / 1000);

    if (actionType === 'plant') {
      const cropId = String(body.crop_id || '').trim();
      if (!FARM_CROPS.has(cropId)) return { ok: false, code: 400, error: 'bad farm crop_id' };
      if (existing) return { ok: false, code: 409, error: 'plot occupied' };
      const result = { plot_index: plotIndex, crop_id: cropId };
      if (!(await consumeAnywhere(`seed_${cropId}`, 1, result))) {
        return { ok: false, code: 409, error: 'seed unavailable' };
      }
      const plot = {
        id: plotId,
        family_id: familyId,
        plot_index: plotIndex,
        crop_id: cropId,
        planted_at: new Date().toISOString(),
        planted_at_unix: now,
        watered: false,
        watered_at_unix: 0,
        fertilized: false,
        fertilized_at_unix: 0,
        created_by_member_id: memberId,
        updated_by_member_id: memberId,
        updated_at: new Date().toISOString(),
        last_operation_id: operationId,
      };
      await plotRef.set(plot);
      await persistFarmResult({ plot: farmPlotResponse(plot) });
      return { ok: true, farm_action: actionType, plot: farmPlotResponse(plot), storehouse, backpack };
    }

    if (!existing || String(existing.family_id || '') !== familyId) {
      return { ok: false, code: 404, error: 'plot not found' };
    }
    if (actionType === 'uproot') {
      await plotRef.remove();
      await persistFarmResult({ deleted_plot_id: plotId });
      return { ok: true, farm_action: actionType, deleted_plot_id: plotId, storehouse, backpack };
    }
    const plot = Object.assign(cleanDocument(existing), { updated_by_member_id: memberId, updated_at: new Date().toISOString(), last_operation_id: operationId });
    if (actionType === 'water') {
      plot.watered = true;
      plot.watered_at_unix = now;
      await plotRef.set(plot);
      await persistFarmResult({ plot: farmPlotResponse(plot) });
      return { ok: true, farm_action: actionType, plot: farmPlotResponse(plot), storehouse, backpack };
    }
    if (actionType === 'fertilize') {
      if (Boolean(plot.fertilized)) return { ok: false, code: 409, error: 'already fertilized' };
      const result = { plot_index: plotIndex, crop_id: String(plot.crop_id || '') };
      if (!(await consumeAnywhere('fertilizer', 1, result))) {
        return { ok: false, code: 409, error: 'fertilizer unavailable' };
      }
      plot.fertilized = true;
      plot.fertilized_at_unix = now;
      await plotRef.set(plot);
      await persistFarmResult({ plot: farmPlotResponse(plot) });
      return { ok: true, farm_action: actionType, plot: farmPlotResponse(plot), storehouse, backpack };
    }

    const crop = FARM_CROPS.get(String(plot.crop_id || ''));
    const matureAt = Number(plot.watered_at_unix || 0) + (crop ? crop.stageDuration : 120) * (FARM_STAGE_COUNT - 1);
    if (!Boolean(plot.watered) || now < matureAt) return { ok: false, code: 409, error: 'crop not mature' };
    const amount = (crop ? crop.baseYield : 2) + (Boolean(plot.fertilized) ? 1 : 0);
    const result = { amount, plot_index: plotIndex, crop_id: String(plot.crop_id || '') };
    if (!(await grantStorehouse(`produce_${plot.crop_id}`, amount, result))) {
      return { ok: false, code: 409, error: 'inventory full' };
    }
    await plotRef.remove();
    await persistFarmResult({ amount, deleted_plot_id: plotId });
    return { ok: true, farm_action: actionType, amount, deleted_plot_id: plotId, storehouse, backpack };
  }, 3);
  return transactionValue(wrapped);
}

async function handleRequest(event) {
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
      return { ok: false, error: 'family_id required, role must be one of father/mother/grandfather/grandmother/partner/player' };
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
      return { ok: false, code: 500, error: String((err && err.message) || err) };
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
      const purpose = String(body.purpose || 'ai');
      if (!IMAGE_UPLOAD_PURPOSES.has(purpose)) {
        return { ok: false, code: 400, error: 'unsupported image purpose' };
      }
      const uploadId = uploadDocumentId();
      const cloudPath = [
        'private_uploads', stableScope(familyId), stableScope(memberId), purpose,
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
        purpose,
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
        purpose,
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
        purpose: String(upload.purpose || 'ai'),
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

    if (action === 'delete_place_bundle') {
      return await deletePlaceBundle(String(body.place_id || ''), familyId);
    }

    if (action === 'mutate_storehouse') {
      return await mutateStorehouse(body, familyId, memberId);
    }

    if (action === 'farm_action') {
      return await performFarmAction(body, identity);
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
      if (body.table === 'farm_plots' || body.table === 'farm_livestock') {
        return { ok: false, code: 409, error: 'farm writes require farm_action' };
      }
      const incoming = Object.assign({}, body.row || {});

      if (body.table === 'inventories') {
        return await upsertInventories(incoming, familyId, memberId);
      }

      if (body.table === 'farm_activity_log') {
        incoming.actor_member_id = memberId;
        incoming.actor_role = identity.role;
        incoming.actor_name = identity.display_name || identity.role || '家人';
      }

      if (body.table === 'travel_places' || body.table === 'postcards') {
        // 新写入不再接受永久公开地址；历史 photo_path 仅通过 existing 保留只读兼容。
        delete incoming.photo_path;
        const uploadId = String(incoming.photo_upload_id || '');
        if (uploadId) {
          const upload = await findUpload(uploadId, familyId);
          if (!upload || String(upload.purpose || 'ai') !== 'travel') {
            return { ok: false, code: 400, error: 'invalid travel photo upload' };
          }
        }
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
      if (body.table === 'farm_plots' || body.table === 'farm_livestock') {
        return { ok: false, code: 409, error: 'farm writes require farm_action' };
      }
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
    return { ok: false, code: 500, error: String((err && err.message) || err) };
  }
}

exports.main = async (event) => {
  const startedAt = Date.now();
  const requestId = requestIdFromEvent(event);
  const body = parseBody(event);
  const action = typeof body.action === 'string' ? body.action : '';
  let result;
  try {
    result = await handleRequest(event);
  } catch (_) {
    // 未捕获异常不能把 SDK 或数据库细节回传给客户端；详细定位依赖 request_id 对应的结构化日志。
    result = { ok: false, code: 500, error: 'internal server error' };
  }
  writeRequestAudit(requestAuditRecord({ requestId, action, startedAt, result }));
  return { ...result, request_id: requestId };
};

exports._observability = {
  requestIdFromEvent,
  requestAuditRecord,
  writeRequestAudit,
};
