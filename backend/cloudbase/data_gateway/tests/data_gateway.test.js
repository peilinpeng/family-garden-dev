const assert = require('node:assert/strict');
const test = require('node:test');

function fakePng(label = '') {
  const header = Buffer.alloc(24);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(header, 0);
  header.write('IHDR', 12, 'ascii');
  header.writeUInt32BE(64, 16);
  header.writeUInt32BE(64, 20);
  return Buffer.concat([header, Buffer.from(label)]);
}

function fakeJpeg() {
  return Buffer.from([0xff, 0xd8, 0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x40, 0x00, 0x40, 0x01, 0x01, 0x11, 0x00, 0xff, 0xd9]);
}

function fakeWebp() {
  const bytes = Buffer.alloc(30);
  bytes.write('RIFF', 0, 'ascii');
  bytes.write('WEBP', 8, 'ascii');
  bytes.write('VP8X', 12, 'ascii');
  bytes.writeUIntLE(63, 24, 3);
  bytes.writeUIntLE(63, 27, 3);
  return bytes;
}
const Module = require('node:module');

function createMemoryDatabase() {
  const tables = new Map();
  const missingCollections = new Set();
  const createdCollections = new Set();
  const queryFailures = new Map();
  let nextId = 1;
  let transactionTail = Promise.resolve();

  function rows(name) {
    if (!tables.has(name)) tables.set(name, new Map());
    return tables.get(name);
  }

  function assertCollectionExists(name) {
    if (!missingCollections.has(name)) return;
    const err = new Error(`[ResourceNotFound] Db or Table not exist: ${name}`);
    err.code = 'DATABASE_COLLECTION_NOT_EXIST';
    throw err;
  }

  function collection(name) {
    return {
      where(query) {
        return {
          limit(maxRows) {
            return {
              async get() {
                assertCollectionExists(name);
                const remainingFailures = queryFailures.get(name) || 0;
                if (remainingFailures > 0) {
                  queryFailures.set(name, remainingFailures - 1);
                  throw new Error(`simulated query failure: ${name}`);
                }
                return {
                  data: [...rows(name).values()].filter((row) =>
                    Object.entries(query).every(([key, value]) => row[key] === value))
                    .slice(0, maxRows),
                };
              },
            };
          },
        };
      },
      doc(id) {
        return {
          async get() {
            assertCollectionExists(name);
            const row = rows(name).get(String(id));
            return { data: row ? [structuredClone(row)] : [] };
          },
          async set(value) {
            assertCollectionExists(name);
            if (Object.hasOwn(value, '_id')) throw new Error('不能更新_id的值');
            rows(name).set(String(id), { ...structuredClone(value), _id: String(id) });
            return { id: String(id) };
          },
          async remove() {
            assertCollectionExists(name);
            rows(name).delete(String(id));
            return { deleted: 1 };
          },
        };
      },
      async add(value) {
        assertCollectionExists(name);
        const id = `doc_${nextId++}`;
        rows(name).set(id, { ...structuredClone(value), _id: id });
        return { id };
      },
    };
  }

  return {
    collection,
    async runTransaction(updateFunction) {
      const previous = transactionTail;
      let release;
      transactionTail = new Promise((resolve) => { release = resolve; });
      await previous;
      try {
        const result = await updateFunction({ collection });
        return { result, errMsg: 'runTransaction:ok' };
      } finally {
        release();
      }
    },
    async createCollection(name) {
      missingCollections.delete(String(name));
      createdCollections.add(String(name));
      rows(name);
      return { name };
    },
    reset() {
      tables.clear();
      missingCollections.clear();
      createdCollections.clear();
      queryFailures.clear();
      nextId = 1;
      transactionTail = Promise.resolve();
    },
    markMissing(name) {
      missingCollections.add(String(name));
    },
    wasCreated(name) {
      return createdCollections.has(String(name));
    },
    failNextQuery(name, count = 1) {
      queryFailures.set(String(name), count);
    },
    seed(name, id, value) {
      rows(name).set(String(id), { ...structuredClone(value), _id: String(id) });
    },
    get(name, id) {
      return rows(name).get(String(id));
    },
  };
}

const db = createMemoryDatabase();
const storage = new Map();
const originalLoad = Module._load;
Module._load = function mockCloudBase(request, parent, isMain) {
  if (request === '@cloudbase/node-sdk') {
    return {
      SYMBOL_CURRENT_ENV: Symbol('test-env'),
      init: () => ({
        database: () => db,
        async uploadFile({ cloudPath, fileContent }) {
          const fileID = `cloud://test-env.${cloudPath}`;
          storage.set(fileID, Buffer.from(fileContent));
          return { fileID };
        },
        async getTempFileURL({ fileList }) {
          return {
            fileList: fileList.map(({ fileID }) => ({
              fileID,
              tempFileURL: storage.has(fileID) ? `https://example.test/${encodeURIComponent(fileID)}` : '',
            })),
          };
        },
        async deleteFile({ fileList }) {
          for (const fileID of fileList) storage.delete(fileID);
          return { fileList };
        },
      }),
    };
  }
  return originalLoad.call(this, request, parent, isMain);
};
const gateway = require('../index.js');
Module._load = originalLoad;

function seedMembers() {
  db.seed('members', 'member_a', {
    family_id: 'family_a', member_token: 'token_a', role: 'father', display_name: 'A',
  });
  db.seed('members', 'member_b', {
    family_id: 'family_b', member_token: 'token_b', role: 'mother', display_name: 'B',
  });
}

async function invoke(body, token = '') {
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  return gateway.main({ body: JSON.stringify(body), headers });
}

test('data_gateway 身份、家庭隔离与 CRUD 回归', async (t) => {
  async function scenario(name, run) {
    await t.test(name, async () => {
      db.reset();
      storage.clear();
      seedMembers();
      await run();
    });
  }

  await scenario('join_family 创建独立成员令牌', async () => {
    const result = await invoke({ action: 'join_family', family_id: 'family_a', role: 'player', display_name: '新成员' });
    assert.equal(result.ok, true);
    assert.match(result.member_token, /^[a-f0-9]{48}$/);
    assert.equal(db.get('members', result.member_id).family_id, 'family_a');
  });

  await scenario('join_family 接受祖辈家庭身份', async () => {
    for (const role of ['grandfather', 'grandmother']) {
      const result = await invoke({ action: 'join_family', family_id: 'family_a', role, display_name: role });
      assert.equal(result.ok, true);
      assert.equal(db.get('members', result.member_id).role, role);
    }
  });

  await scenario('join_family 拒绝非法角色', async () => {
    assert.equal((await invoke({ action: 'join_family', family_id: 'family_a', role: 'admin' })).ok, false);
  });

  await scenario('join_family 拒绝缺失家庭', async () => {
    assert.equal((await invoke({ action: 'join_family', role: 'player' })).ok, false);
  });

  await scenario('拒绝原型链污染键', async () => {
    const event = { body: '{"action":"upsert","table":"memories","row":{"__proto__":{"polluted":true}}}', headers: { Authorization: 'Bearer token_a' } };
    const result = await gateway.main(event);
    assert.equal(result.code, 400);
    assert.equal({}.polluted, undefined);
  });

  await scenario('无令牌请求返回 401', async () => {
    assert.equal((await invoke({ action: 'whoami' })).code, 401);
  });

  await scenario('无效令牌请求返回 401', async () => {
    assert.equal((await invoke({ action: 'whoami' }, 'invalid')).code, 401);
  });

  await scenario('whoami 只返回当前成员身份', async () => {
    const result = await invoke({ action: 'whoami' }, 'token_a');
    assert.deepEqual(
      { ...result, request_id: undefined },
      { ok: true, member_id: 'member_a', family_id: 'family_a', role: 'father', display_name: 'A', request_id: undefined }
    );
    assert.match(result.request_id, /^gw_[a-f0-9]{24}$/);
  });

  await scenario('list_family_members 只返回同家庭公开成员信息', async () => {
    db.seed('members', 'member_a2', {
      family_id: 'family_a', member_token: 'secret_token_a2', role: 'player', display_name: 'A2',
    });
    const result = await invoke({ action: 'list_family_members' }, 'token_a');
    assert.equal(result.ok, true);
    assert.equal(result.family_id, 'family_a');
    assert.deepEqual(
      new Set(result.members.map((member) => member.member_id)),
      new Set(['member_a', 'member_a2'])
    );
    assert.equal(result.members.some((member) => Object.hasOwn(member, 'member_token')), false);
    assert.equal(result.members.some((member) => member.member_id === 'member_b'), false);
  });

  await scenario('受控图片上传、家庭内解析与上传者删除', async () => {
    const uploaded = await invoke({
      action: 'upload_image',
      purpose: 'travel',
      content_type: 'image/png',
      base64_data: fakePng('fake-png').toString('base64'),
    }, 'token_a');
    assert.equal(uploaded.ok, true);
    assert.match(uploaded.upload_id, /^upload_[a-f0-9]{32}$/);
    assert.match(uploaded.image_url, /^https:\/\/example\.test\//);
    const row = db.get('uploads', uploaded.upload_id);
    assert.equal(row.family_id, 'family_a');
    assert.equal(row.owner_member_id, 'member_a');
    assert.equal(row.purpose, 'travel');
    assert.match(row.cloud_path, /^private_uploads\/[a-f0-9]{20}\/[a-f0-9]{20}\/travel\//);

    const resolved = await invoke({ action: 'resolve_image', upload_id: uploaded.upload_id }, 'token_a');
    assert.equal(resolved.ok, true);
    assert.equal(resolved.content_type, 'image/png');
    assert.equal(resolved.purpose, 'travel');
    assert.equal((await invoke({ action: 'delete_image', upload_id: uploaded.upload_id }, 'token_a')).ok, true);
    assert.equal(db.get('uploads', uploaded.upload_id), undefined);
    assert.equal(storage.size, 0);
  });

  await scenario('图片记录不能跨家庭解析', async () => {
    const uploaded = await invoke({
      action: 'upload_image', content_type: 'image/jpeg', base64_data: fakeJpeg().toString('base64'),
    }, 'token_a');
    const result = await invoke({ action: 'resolve_image', upload_id: uploaded.upload_id }, 'token_b');
    assert.equal(result.code, 404);
  });

  await scenario('图片只能由上传成员删除', async () => {
    db.seed('members', 'member_a2', {
      family_id: 'family_a', member_token: 'token_a2', role: 'player', display_name: 'A2',
    });
    const uploaded = await invoke({
      action: 'upload_image', content_type: 'image/webp', base64_data: fakeWebp().toString('base64'),
    }, 'token_a');
    const result = await invoke({ action: 'delete_image', upload_id: uploaded.upload_id }, 'token_a2');
    assert.equal(result.code, 403);
  });

  await scenario('已被记忆引用的图片不能直接删除', async () => {
    const uploaded = await invoke({
      action: 'upload_image', content_type: 'image/png', base64_data: fakePng('referenced').toString('base64'),
    }, 'token_a');
    db.seed('memories', 'memory_with_upload', { family_id: 'family_a', upload_id: uploaded.upload_id });
    const result = await invoke({ action: 'delete_image', upload_id: uploaded.upload_id }, 'token_a');
    assert.equal(result.code, 409);
    assert.notEqual(db.get('uploads', uploaded.upload_id), undefined);
    assert.equal(storage.size, 1);
  });

  await scenario('旅行照片只保存受控引用并拒绝跨家庭 upload_id', async () => {
    const uploaded = await invoke({
      action: 'upload_image',
      purpose: 'travel',
      content_type: 'image/png',
      base64_data: fakePng('travel').toString('base64'),
    }, 'token_a');
    const created = await invoke({
      action: 'upsert',
      table: 'travel_places',
      row: {
        id: 'place_private',
        title: '私密旅行',
        photo_upload_id: uploaded.upload_id,
        photo_path: 'https://public.example.test/leak.jpg',
      },
    }, 'token_a');
    assert.equal(created.ok, true);
    const row = db.get('travel_places', 'place_private');
    assert.equal(row.photo_upload_id, uploaded.upload_id);
    assert.equal(Object.hasOwn(row, 'photo_path'), false);

    const foreignUpload = await invoke({
      action: 'upload_image',
      purpose: 'travel',
      content_type: 'image/jpeg',
      base64_data: fakeJpeg().toString('base64'),
    }, 'token_b');
    const forged = await invoke({
      action: 'upsert',
      table: 'travel_places',
      row: { id: 'place_forged', photo_upload_id: foreignUpload.upload_id },
    }, 'token_a');
    assert.equal(forged.code, 400);
    assert.equal(db.get('travel_places', 'place_forged'), undefined);

    const aiUpload = await invoke({
      action: 'upload_image',
      content_type: 'image/png',
      base64_data: fakePng('ai-only').toString('base64'),
    }, 'token_a');
    const wrongPurpose = await invoke({
      action: 'upsert',
      table: 'postcards',
      row: { id: 'postcard_wrong_purpose', photo_upload_id: aiUpload.upload_id },
    }, 'token_a');
    assert.equal(wrongPurpose.code, 400);
    assert.equal(db.get('postcards', 'postcard_wrong_purpose'), undefined);
  });

  await scenario('地点级联删除记录、邮箱事件和受控照片', async () => {
    db.seed('members', 'member_a2', {
      family_id: 'family_a', member_token: 'token_a2', role: 'player', display_name: 'A2',
    });
    const uploaded = await invoke({
      action: 'upload_image',
      purpose: 'travel',
      content_type: 'image/png',
      base64_data: fakePng('place-bundle').toString('base64'),
    }, 'token_a');
    db.seed('travel_places', 'place_bundle', {
      family_id: 'family_a', photo_upload_id: uploaded.upload_id,
    });
    db.seed('postcards', 'postcard_bundle', {
      family_id: 'family_a', place_id: 'place_bundle', photo_upload_id: uploaded.upload_id,
    });
    db.seed('mailbox_events', 'event_bundle', {
      family_id: 'family_a', target_id: 'postcard_bundle',
    });

    const crossFamily = await invoke({ action: 'delete_place_bundle', place_id: 'place_bundle' }, 'token_b');
    assert.equal(crossFamily.code, 403);
    assert.notEqual(db.get('travel_places', 'place_bundle'), undefined);

    // 同家庭成员可以删除共享地点；网关在移除业务引用后回收私有对象。
    const deleted = await invoke({ action: 'delete_place_bundle', place_id: 'place_bundle' }, 'token_a2');
    assert.equal(deleted.ok, true);
    assert.deepEqual(deleted.postcard_ids, ['postcard_bundle']);
    assert.deepEqual(deleted.event_ids, ['event_bundle']);
    assert.deepEqual(deleted.deleted_upload_ids, [uploaded.upload_id]);
    assert.equal(db.get('travel_places', 'place_bundle'), undefined);
    assert.equal(db.get('postcards', 'postcard_bundle'), undefined);
    assert.equal(db.get('mailbox_events', 'event_bundle'), undefined);
    assert.equal(db.get('uploads', uploaded.upload_id), undefined);
    assert.equal(storage.size, 0);
  });

  await scenario('地点级联删除查询失败时保留父记录并可安全重试', async () => {
    const uploaded = await invoke({
      action: 'upload_image',
      purpose: 'travel',
      content_type: 'image/png',
      base64_data: fakePng('retry-bundle').toString('base64'),
    }, 'token_a');
    db.seed('travel_places', 'place_retry', {
      family_id: 'family_a', photo_upload_id: uploaded.upload_id,
    });
    db.seed('postcards', 'postcard_retry', {
      family_id: 'family_a', place_id: 'place_retry', photo_upload_id: uploaded.upload_id,
    });

    db.failNextQuery('postcards');
    const failed = await invoke({ action: 'delete_place_bundle', place_id: 'place_retry' }, 'token_a');
    assert.equal(failed.ok, false);
    assert.match(String(failed.error), /simulated query failure/);
    assert.notEqual(db.get('travel_places', 'place_retry'), undefined);
    assert.notEqual(db.get('postcards', 'postcard_retry'), undefined);
    assert.notEqual(db.get('uploads', uploaded.upload_id), undefined);
    assert.equal(storage.size, 1);

    const retried = await invoke({ action: 'delete_place_bundle', place_id: 'place_retry' }, 'token_a');
    assert.equal(retried.ok, true);
    assert.equal(db.get('travel_places', 'place_retry'), undefined);
    assert.equal(db.get('postcards', 'postcard_retry'), undefined);
    assert.equal(db.get('uploads', uploaded.upload_id), undefined);
    assert.equal(storage.size, 0);
  });

  await scenario('地点级联删除完整处理超过单批上限的关联记录', async () => {
    const uploaded = await invoke({
      action: 'upload_image',
      purpose: 'travel',
      content_type: 'image/png',
      base64_data: fakePng('large-bundle').toString('base64'),
    }, 'token_a');
    db.seed('travel_places', 'place_large', {
      family_id: 'family_a', photo_upload_id: uploaded.upload_id,
    });
    for (let index = 0; index < 101; index += 1) {
      const postcardId = `postcard_large_${index}`;
      db.seed('postcards', postcardId, {
        family_id: 'family_a',
        place_id: 'place_large',
        photo_upload_id: uploaded.upload_id,
      });
      db.seed('mailbox_events', `event_large_${index}`, {
        family_id: 'family_a', target_id: postcardId,
      });
    }
    for (let index = 0; index < 100; index += 1) {
      db.seed('mailbox_events', `event_large_extra_${index}`, {
        family_id: 'family_a', target_id: 'postcard_large_0',
      });
    }

    const deleted = await invoke({ action: 'delete_place_bundle', place_id: 'place_large' }, 'token_a');
    assert.equal(deleted.ok, true);
    assert.equal(deleted.postcard_ids.length, 101);
    assert.equal(new Set(deleted.postcard_ids).size, 101);
    assert.equal(deleted.event_ids.length, 201);
    assert.equal(new Set(deleted.event_ids).size, 201);
    assert.equal(db.get('travel_places', 'place_large'), undefined);
    assert.equal(db.get('postcards', 'postcard_large_100'), undefined);
    assert.equal(db.get('mailbox_events', 'event_large_extra_99'), undefined);
    assert.equal(db.get('uploads', uploaded.upload_id), undefined);
    assert.equal(storage.size, 0);
  });

  await scenario('只清理当前成员超过一天且未被业务记录引用的上传', async () => {
    const png = fakePng('cleanup').toString('base64');
    const orphan = await invoke({ action: 'upload_image', content_type: 'image/png', base64_data: png }, 'token_a');
    db.get('uploads', orphan.upload_id).created_at = '2000-01-01T00:00:00.000Z';
    const referenced = await invoke({ action: 'upload_image', content_type: 'image/png', base64_data: png }, 'token_a');
    db.get('uploads', referenced.upload_id).created_at = '2000-01-01T00:00:00.000Z';
    db.seed('travel_places', 'place_with_upload', {
      family_id: 'family_a', photo_upload_id: referenced.upload_id,
    });
    const result = await invoke({ action: 'cleanup_orphan_images' }, 'token_a');
    assert.equal(result.ok, true);
    assert.equal(result.deleted, 1);
    assert.equal(db.get('uploads', orphan.upload_id), undefined);
    assert.notEqual(db.get('uploads', referenced.upload_id), undefined);
  });

  await scenario('引用查询失败时直接删除和孤儿清理都必须保留照片', async () => {
    const uploaded = await invoke({
      action: 'upload_image',
      purpose: 'travel',
      content_type: 'image/png',
      base64_data: fakePng('fail-closed').toString('base64'),
    }, 'token_a');
    db.get('uploads', uploaded.upload_id).created_at = '2000-01-01T00:00:00.000Z';
    db.seed('travel_places', 'place_fail_closed', {
      family_id: 'family_a', photo_upload_id: uploaded.upload_id,
    });

    db.failNextQuery('travel_places');
    const directDelete = await invoke({
      action: 'delete_image', upload_id: uploaded.upload_id,
    }, 'token_a');
    assert.equal(directDelete.ok, false);
    assert.match(String(directDelete.error), /simulated query failure/);
    assert.notEqual(db.get('uploads', uploaded.upload_id), undefined);
    assert.equal(storage.size, 1);

    db.failNextQuery('travel_places');
    const cleanup = await invoke({ action: 'cleanup_orphan_images' }, 'token_a');
    assert.equal(cleanup.ok, true);
    assert.equal(cleanup.deleted, 0);
    assert.notEqual(db.get('uploads', uploaded.upload_id), undefined);
    assert.equal(storage.size, 1);
  });

  await scenario('图片上传拒绝不支持类型、非法 base64 与超限输入', async () => {
    assert.equal((await invoke({
      action: 'upload_image', purpose: 'avatar', content_type: 'image/png', base64_data: fakePng().toString('base64'),
    }, 'token_a')).code, 400);
    assert.equal((await invoke({
      action: 'upload_image', content_type: 'image/gif', base64_data: 'YWJjZA==',
    }, 'token_a')).code, 400);
    assert.equal((await invoke({
      action: 'upload_image', content_type: 'image/png', base64_data: '***',
    }, 'token_a')).code, 400);
    assert.equal((await invoke({
      action: 'upload_image', content_type: 'image/png', base64_data: Buffer.from('not-a-png').toString('base64'),
    }, 'token_a')).code, 400);
    const tiny = fakePng('tiny');
    tiny.writeUInt32BE(1, 16);
    tiny.writeUInt32BE(1, 20);
    assert.equal((await invoke({
      action: 'upload_image', content_type: 'image/png', base64_data: tiny.toString('base64'),
    }, 'token_a')).code, 400);
    assert.equal((await invoke({
      action: 'upload_image', content_type: 'image/png', base64_data: 'A'.repeat(8 * 1024 * 1024 + 16),
    }, 'token_a')).code, 400);
  });

  await scenario('snapshot 忽略非白名单集合', async () => {
    db.seed('memories', 'a1', { family_id: 'family_a', title: 'A' });
    const result = await invoke({ action: 'snapshot', tables: ['memories', 'members'] }, 'token_a');
    assert.equal(result.tables.memories.length, 1);
    assert.equal(Object.hasOwn(result.tables, 'members'), false);
  });

  await scenario('通用查询按家庭隔离', async () => {
    db.seed('memories', 'a1', { family_id: 'family_a', title: 'A' });
    db.seed('memories', 'b1', { family_id: 'family_b', title: 'B' });
    const result = await invoke({ action: 'query', table: 'memories' }, 'token_a');
    assert.deepEqual(result.rows.map((row) => row.title), ['A']);
  });

  await scenario('禁止查询 members 集合', async () => {
    assert.equal((await invoke({ action: 'query', table: 'members' }, 'token_a')).ok, false);
  });

  await scenario('库存查询只返回家庭共享仓和本人背包', async () => {
    db.seed('inventories', 'shared', { family_id: 'family_a', kind: 'storehouse' });
    db.seed('inventories', 'own', { family_id: 'family_a', kind: 'backpack', owner_member_id: 'member_a' });
    db.seed('inventories', 'other', { family_id: 'family_a', kind: 'backpack', owner_member_id: 'someone_else' });
    const result = await invoke({ action: 'query', table: 'inventories' }, 'token_a');
    assert.deepEqual(new Set(result.rows.map((row) => row._id)), new Set(['shared', 'own']));
  });

  await scenario('背包 upsert 强制当前成员所有权', async () => {
    const result = await invoke({ action: 'upsert', table: 'inventories', row: { id: 'forged', kind: 'backpack', owner_member_id: 'member_b', stacks: [] } }, 'token_a');
    assert.equal(result.id, 'backpack:member_a');
    assert.equal(db.get('inventories', result.id).owner_member_id, 'member_a');
  });

  await scenario('共享仓拒绝客户端整份快照覆盖', async () => {
    const result = await invoke({ action: 'upsert', table: 'inventories', row: { kind: 'storehouse', family_id: 'family_b', stacks: [] } }, 'token_a');
    assert.equal(result.code, 409);
    assert.equal(db.get('inventories', 'storehouse:family_a'), undefined);
  });

  await scenario('共享仓事务原子扣发、幂等并返回权威版本', async () => {
    db.seed('inventories', 'storehouse:family_a', {
      id: 'storehouse:family_a', family_id: 'family_a', kind: 'storehouse', version: 4,
      stacks: [{ id: 'produce_corrato', count: 2 }],
    });
    const body = {
      action: 'mutate_storehouse', operation_id: 'craft:test:0001',
      consumes: [{ id: 'produce_corrato', quantity: 2, max_stack: 99 }],
      grants: [{ id: 'dish_tomato_egg', quantity: 1, max_stack: 99 }],
    };
    const result = await invoke(body, 'token_a');
    assert.equal(result.ok, true);
    assert.equal(result.version, 5);
    assert.deepEqual(result.stacks, [{ id: 'dish_tomato_egg', count: 1 }]);
    const duplicate = await invoke(body, 'token_a');
    assert.equal(duplicate.ok, true);
    assert.equal(duplicate.duplicate, true);
    assert.equal(duplicate.version, 5);
  });

  await scenario('共享仓并发争抢最后一份库存只允许一个成功', async () => {
    db.seed('inventories', 'storehouse:family_a', {
      id: 'storehouse:family_a', family_id: 'family_a', kind: 'storehouse', version: 0,
      stacks: [{ id: 'dish_tomato_egg', count: 1 }],
    });
    const makeRequest = (operationId) => invoke({
      action: 'mutate_storehouse', operation_id: operationId,
      consumes: [{ id: 'dish_tomato_egg', quantity: 1, max_stack: 99 }], grants: [],
    }, 'token_a');
    const results = await Promise.all([makeRequest('meal:concurrent:1'), makeRequest('meal:concurrent:2')]);
    assert.equal(results.filter((result) => result.ok).length, 1);
    assert.equal(results.filter((result) => result.code === 409).length, 1);
    assert.deepEqual(db.get('inventories', 'storehouse:family_a').stacks, []);
  });

  await scenario('库存 upsert 拒绝未知 kind', async () => {
    assert.equal((await invoke({ action: 'upsert', table: 'inventories', row: { kind: 'mystery' } }, 'token_a')).ok, false);
  });

  await scenario('通用 upsert 覆盖伪造 family_id', async () => {
    const result = await invoke({ action: 'upsert', table: 'memories', row: { id: 'memory_a', family_id: 'family_b', title: '安全' } }, 'token_a');
    assert.equal(db.get('memories', result.id).family_id, 'family_a');
  });

  await scenario('家庭共享记录强制成员审计字段', async () => {
    const created = await invoke({
      action: 'upsert',
      table: 'travel_places',
      row: {
        id: 'place_a',
        family_id: 'family_b',
        created_by_member_id: 'forged_creator',
        updated_by_member_id: 'forged_updater',
        title: '家庭旅行',
      },
    }, 'token_a');
    assert.equal(created.ok, true);
    assert.equal(db.get('travel_places', 'place_a').family_id, 'family_a');
    assert.equal(db.get('travel_places', 'place_a').created_by_member_id, 'member_a');
    assert.equal(db.get('travel_places', 'place_a').updated_by_member_id, 'member_a');

    db.seed('members', 'member_a2', {
      family_id: 'family_a', member_token: 'token_a2', role: 'player', display_name: 'A2',
    });
    await invoke({
      action: 'upsert',
      table: 'travel_places',
      row: {
        id: 'place_a',
        created_by_member_id: 'forged_again',
        updated_by_member_id: 'forged_again',
        title: '家庭旅行更新',
      },
    }, 'token_a2');
    assert.equal(db.get('travel_places', 'place_a').created_by_member_id, 'member_a');
    assert.equal(db.get('travel_places', 'place_a').updated_by_member_id, 'member_a2');
  });

  await scenario('农场动态按家庭共享且强制成员审计字段', async () => {
    db.seed('members', 'member_a2', {
      family_id: 'family_a', member_token: 'token_a2', role: 'mother', display_name: 'A2',
    });
    const created = await invoke({
      action: 'upsert',
      table: 'farm_activity_log',
      row: {
        id: 'farm_log_a',
        family_id: 'family_b',
        created_by_member_id: 'forged_creator',
        updated_by_member_id: 'forged_updater',
        actor_member_id: 'forged_member',
        actor_role: 'forged_role',
        actor_name: '伪造名字',
        action: 'harvest',
        detail: '收获了红番茄 ×2',
      },
    }, 'token_a');
    assert.equal(created.ok, true);
    assert.equal(db.get('farm_activity_log', 'farm_log_a').family_id, 'family_a');
    assert.equal(db.get('farm_activity_log', 'farm_log_a').created_by_member_id, 'member_a');
    assert.equal(db.get('farm_activity_log', 'farm_log_a').updated_by_member_id, 'member_a');
    assert.equal(db.get('farm_activity_log', 'farm_log_a').actor_member_id, 'member_a');
    assert.equal(db.get('farm_activity_log', 'farm_log_a').actor_role, 'father');
    assert.equal(db.get('farm_activity_log', 'farm_log_a').actor_name, 'A');

    const visibleToSameFamily = await invoke({ action: 'query', table: 'farm_activity_log' }, 'token_a2');
    assert.deepEqual(visibleToSameFamily.rows.map((row) => row.id), ['farm_log_a']);

    const hiddenFromOtherFamily = await invoke({ action: 'query', table: 'farm_activity_log' }, 'token_b');
    assert.deepEqual(hiddenFromOtherFamily.rows, []);
  });

  await scenario('农场地块按家庭共享且使用稳定文档 ID', async () => {
    db.seed('members', 'member_a2', {
      family_id: 'family_a', member_token: 'token_a2', role: 'player', display_name: 'A2',
    });
    db.seed('inventories', 'storehouse:family_a', {
      id: 'storehouse:family_a', family_id: 'family_a', kind: 'storehouse', version: 0,
      stacks: [{ id: 'seed_corrato', count: 1 }, { id: 'seed_tomelone', count: 1 }],
    });
    const created = await invoke({
      action: 'farm_action', farm_action: 'plant', operation_id: 'farm:stable-id:a',
      plot_index: 2, crop_id: 'corrato',
    }, 'token_a');
    assert.equal(created.ok, true);
    assert.equal(created.plot.id, 'farm_plot:family_a:2');
    assert.equal(db.get('farm_plots', created.plot.id).family_id, 'family_a');
    assert.equal(db.get('farm_plots', created.plot.id).plot_index, 2);
    assert.equal(db.get('farm_plots', created.plot.id).crop_id, 'corrato');
    assert.equal(db.get('farm_plots', created.plot.id).created_by_member_id, 'member_a');

    const visibleToSameFamily = await invoke({ action: 'query', table: 'farm_plots' }, 'token_a2');
    assert.deepEqual(visibleToSameFamily.rows.map((row) => row.id), ['farm_plot:family_a:2']);

    const occupied = await invoke({
      action: 'farm_action', farm_action: 'plant', operation_id: 'farm:stable-id:a2',
      plot_index: 2, crop_id: 'tomelone',
    }, 'token_a2');
    assert.equal(occupied.code, 409);
    assert.equal(db.get('farm_plots', 'farm_plot:family_a:2').crop_id, 'corrato');

    const hiddenFromOtherFamily = await invoke({ action: 'query', table: 'farm_plots' }, 'token_b');
    assert.deepEqual(hiddenFromOtherFamily.rows, []);

    const uprooted = await invoke({
      action: 'farm_action', farm_action: 'uproot', operation_id: 'farm:stable-id:uproot', plot_index: 2,
    }, 'token_a2');
    assert.equal(uprooted.ok, true);
    assert.equal(uprooted.deleted_plot_id, 'farm_plot:family_a:2');
    assert.equal(db.get('farm_plots', 'farm_plot:family_a:2'), undefined);
  });

  await scenario('农场地块拒绝非法 plot 与 crop', async () => {
    assert.equal((await invoke({
      action: 'farm_action', farm_action: 'plant', operation_id: 'farm:invalid:plot',
      plot_index: -1, crop_id: 'corrato',
    }, 'token_a')).code, 400);
    assert.equal((await invoke({
      action: 'farm_action', farm_action: 'plant', operation_id: 'farm:invalid:crop',
      plot_index: 2, crop_id: '../bad',
    }, 'token_a')).code, 400);
  });

  await scenario('农场事务原子完成播种、浇水、施肥和收获', async () => {
    db.seed('inventories', 'storehouse:family_a', {
      id: 'storehouse:family_a', family_id: 'family_a', kind: 'storehouse', version: 0,
      stacks: [{ id: 'seed_corrato', count: 1 }, { id: 'fertilizer', count: 1 }],
    });
    const planted = await invoke({
      action: 'farm_action', farm_action: 'plant', operation_id: 'farm:plant:0001', plot_index: 1, crop_id: 'corrato',
    }, 'token_a');
    assert.equal(planted.ok, true);
    assert.equal(planted.plot.plot_index, 1);
    assert.deepEqual(planted.storehouse.stacks, [{ id: 'fertilizer', count: 1 }]);
    const plantedRetry = await invoke({
      action: 'farm_action', farm_action: 'plant', operation_id: 'farm:plant:0001', plot_index: 1, crop_id: 'corrato',
    }, 'token_a');
    assert.equal(plantedRetry.duplicate, true);
    assert.equal(plantedRetry.plot.id, 'farm_plot:family_a:1');
    assert.deepEqual(plantedRetry.storehouse.stacks, [{ id: 'fertilizer', count: 1 }]);

    const watered = await invoke({
      action: 'farm_action', farm_action: 'water', operation_id: 'farm:water:0001', plot_index: 1,
    }, 'token_a');
    assert.equal(watered.ok, true);
    assert.equal(watered.plot.watered, true);

    const fertilized = await invoke({
      action: 'farm_action', farm_action: 'fertilize', operation_id: 'farm:fertilize:0001', plot_index: 1,
    }, 'token_a');
    assert.equal(fertilized.ok, true);
    assert.equal(fertilized.plot.fertilized, true);
    const mature = db.get('farm_plots', 'farm_plot:family_a:1');
    mature.watered_at_unix = Math.floor(Date.now() / 1000) - 1000;
    db.seed('farm_plots', 'farm_plot:family_a:1', mature);

    const harvested = await invoke({
      action: 'farm_action', farm_action: 'harvest', operation_id: 'farm:harvest:0001', plot_index: 1,
    }, 'token_a');
    assert.equal(harvested.ok, true);
    assert.equal(harvested.amount, 3);
    assert.equal(db.get('farm_plots', 'farm_plot:family_a:1'), undefined);
    assert.deepEqual(harvested.storehouse.stacks, [{ id: 'produce_corrato', count: 3 }]);
    const harvestedRetry = await invoke({
      action: 'farm_action', farm_action: 'harvest', operation_id: 'farm:harvest:0001', plot_index: 1,
    }, 'token_a');
    assert.equal(harvestedRetry.duplicate, true);
    assert.equal(harvestedRetry.deleted_plot_id, 'farm_plot:family_a:1');
    assert.equal(harvestedRetry.amount, 3);
    assert.deepEqual(harvestedRetry.storehouse.stacks, [{ id: 'produce_corrato', count: 3 }]);
  });

  await scenario('两个家庭成员并发播种同一地块只消耗一颗种子', async () => {
    db.seed('members', 'member_a2', {
      family_id: 'family_a', member_token: 'token_a2', role: 'player', display_name: 'A2',
    });
    db.seed('inventories', 'storehouse:family_a', {
      id: 'storehouse:family_a', family_id: 'family_a', kind: 'storehouse', version: 0,
      stacks: [{ id: 'seed_corrato', count: 1 }],
    });
    const request = (token, operationId) => invoke({
      action: 'farm_action', farm_action: 'plant', operation_id: operationId, plot_index: 2, crop_id: 'corrato',
    }, token);
    const results = await Promise.all([
      request('token_a', 'farm:plant:member-a'),
      request('token_a2', 'farm:plant:member-a2'),
    ]);
    assert.equal(results.filter((result) => result.ok).length, 1);
    assert.equal(results.filter((result) => result.code === 409).length, 1);
    assert.deepEqual(db.get('inventories', 'storehouse:family_a').stacks, []);
  });

  await scenario('畜牧收集使用家庭远端冷却并阻止并发重复领取', async () => {
    db.seed('members', 'member_a2', {
      family_id: 'family_a', member_token: 'token_a2', role: 'player', display_name: 'A2',
    });
    const request = (token, operationId) => invoke({
      action: 'farm_action', farm_action: 'collect_livestock', operation_id: operationId, source_id: 'chicken_coop',
    }, token);
    const results = await Promise.all([
      request('token_a', 'farm:livestock:member-a'),
      request('token_a2', 'farm:livestock:member-a2'),
    ]);
    assert.equal(results.filter((result) => result.ok).length, 1);
    assert.equal(results.filter((result) => result.code === 409).length, 1);
    assert.deepEqual(db.get('inventories', 'storehouse:family_a').stacks, [{ id: 'egg', count: 1 }]);
    assert.equal(db.get('farm_livestock', 'farm_livestock:family_a:chicken_coop').family_id, 'family_a');
    const successfulIndex = results.findIndex((result) => result.ok);
    const retryToken = successfulIndex === 0 ? 'token_a' : 'token_a2';
    const retryOperation = successfulIndex === 0 ? 'farm:livestock:member-a' : 'farm:livestock:member-a2';
    const retry = await request(retryToken, retryOperation);
    assert.equal(retry.duplicate, true);
    assert.equal(retry.livestock.source_id, 'chicken_coop');
    assert.deepEqual(db.get('inventories', 'storehouse:family_a').stacks, [{ id: 'egg', count: 1 }]);
  });

  await scenario('农场权威表拒绝通用写删绕过事务', async () => {
    db.seed('farm_plots', 'farm_plot:family_a:3', {
      id: 'farm_plot:family_a:3',
      family_id: 'family_a',
      plot_index: 3,
      crop_id: 'corrato',
    });
    assert.equal((await invoke({
      action: 'upsert',
      table: 'farm_plots',
      row: { plot_index: 3, crop_id: 'tomelone' },
    }, 'token_a')).code, 409);
    assert.equal((await invoke({
      action: 'delete',
      table: 'farm_plots',
      id: 'farm_plot:family_a:3',
    }, 'token_a')).code, 409);
    assert.equal((await invoke({
      action: 'upsert',
      table: 'farm_livestock',
      row: { id: 'forged', source_id: 'chicken_coop' },
    }, 'token_a')).code, 409);
    assert.equal((await invoke({
      action: 'delete',
      table: 'farm_livestock',
      id: 'farm_livestock:family_a:chicken_coop',
    }, 'token_a')).code, 409);
    assert.equal(db.get('farm_plots', 'farm_plot:family_a:3').crop_id, 'corrato');
  });

  await scenario('Gate5 集合缺失时自动创建并重试写入', async () => {
    db.markMissing('travel_places');
    const result = await invoke({
      action: 'upsert',
      table: 'travel_places',
      row: { id: 'place_auto_create', title: '自动建表' },
    }, 'token_a');
    assert.equal(result.ok, true);
    assert.equal(db.wasCreated('travel_places'), true);
    assert.equal(db.get('travel_places', 'place_auto_create').family_id, 'family_a');
  });

  await scenario('farm_plots 集合缺失时自动创建并重试写入', async () => {
    db.markMissing('farm_plots');
    db.seed('inventories', 'storehouse:family_a', {
      id: 'storehouse:family_a', family_id: 'family_a', kind: 'storehouse', version: 0,
      stacks: [{ id: 'seed_corrato', count: 1 }],
    });
    const result = await invoke({
      action: 'farm_action', farm_action: 'plant', operation_id: 'farm:auto-create:plot',
      plot_index: 4, crop_id: 'corrato',
    }, 'token_a');
    assert.equal(result.ok, true);
    assert.equal(db.wasCreated('farm_plots'), true);
    assert.equal(db.get('farm_plots', 'farm_plot:family_a:4').family_id, 'family_a');
  });

  await scenario('farm_activity_log 集合缺失时自动创建并重试写入', async () => {
    db.markMissing('farm_activity_log');
    const result = await invoke({
      action: 'upsert',
      table: 'farm_activity_log',
      row: { id: 'farm_log_auto_create', action: 'plant', detail: '种下了红番茄种子' },
    }, 'token_a');
    assert.equal(result.ok, true);
    assert.equal(db.wasCreated('farm_activity_log'), true);
    assert.equal(db.get('farm_activity_log', 'farm_log_auto_create').family_id, 'family_a');
  });


  await scenario('通用 upsert 保留已有服务端字段', async () => {
    db.seed('memories', 'memory_a', { family_id: 'family_a', server_only: 'keep', title: '旧' });
    await invoke({ action: 'upsert', table: 'memories', row: { id: 'memory_a', title: '新' } }, 'token_a');
    assert.equal(db.get('memories', 'memory_a').server_only, 'keep');
    assert.equal(db.get('memories', 'memory_a').title, '新');
  });

  await scenario('禁止覆盖其他家庭的同 ID 记录', async () => {
    db.seed('memories', 'memory_b', { family_id: 'family_b', title: 'B' });
    assert.equal((await invoke({ action: 'upsert', table: 'memories', row: { id: 'memory_b', title: '攻击' } }, 'token_a')).code, 403);
  });

  await scenario('删除不存在记录返回 not found', async () => {
    assert.equal((await invoke({ action: 'delete', table: 'memories', id: 'missing' }, 'token_a')).error, 'not found');
  });

  await scenario('禁止删除其他家庭记录', async () => {
    db.seed('memories', 'memory_b', { family_id: 'family_b' });
    assert.equal((await invoke({ action: 'delete', table: 'memories', id: 'memory_b' }, 'token_a')).code, 403);
  });

  await scenario('禁止删除同家庭其他成员背包', async () => {
    db.seed('inventories', 'other_pack', { family_id: 'family_a', kind: 'backpack', owner_member_id: 'someone_else' });
    assert.equal((await invoke({ action: 'delete', table: 'inventories', id: 'other_pack' }, 'token_a')).code, 403);
  });

  await scenario('允许删除本人家庭记录', async () => {
    db.seed('memories', 'memory_a', { family_id: 'family_a' });
    assert.equal((await invoke({ action: 'delete', table: 'memories', id: 'memory_a' }, 'token_a')).ok, true);
    assert.equal(db.get('memories', 'memory_a'), undefined);
  });

  await scenario('未知 action 稳定拒绝', async () => {
    assert.match((await invoke({ action: 'unknown' }, 'token_a')).error, /unknown action/);
  });
});

test('data_gateway 可观测性记录使用白名单字段并返回可关联请求 ID', () => {
  const { requestIdFromEvent, requestAuditRecord, writeRequestAudit } = gateway._observability;
  assert.match(requestIdFromEvent({ headers: { 'X-Request-ID': 'token_a_should_not_be_used' } }), /^gw_[a-f0-9]{24}$/);

  const record = requestAuditRecord({
    requestId: 'release-20260825.1',
    action: 'token_a_should_not_be_used',
    startedAt: Date.now() - 7,
    result: { ok: false, code: 401, error: 'Bearer token_a must never appear in logs' },
  });
  assert.deepEqual(Object.keys(record).sort(), ['action', 'code', 'duration_ms', 'error_class', 'event', 'ok', 'request_id']);
  assert.equal(record.action, 'unknown');
  assert.equal(record.error_class, 'unauthorized');
  const calls = [];
  writeRequestAudit(record, {
    write: (line) => calls.push(line),
  });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].endsWith('\n'), true);
  assert.equal(calls[0].includes('token_a'), false);
  assert.equal(calls[0].includes('Bearer'), false);
});
