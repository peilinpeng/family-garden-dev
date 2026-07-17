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
  let nextId = 1;

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
          limit() {
            return {
              async get() {
                assertCollectionExists(name);
                return {
                  data: [...rows(name).values()].filter((row) =>
                    Object.entries(query).every(([key, value]) => row[key] === value)),
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
      nextId = 1;
    },
    markMissing(name) {
      missingCollections.add(String(name));
    },
    wasCreated(name) {
      return createdCollections.has(String(name));
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
    assert.deepEqual(result, { ok: true, member_id: 'member_a', family_id: 'family_a', role: 'father', display_name: 'A' });
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
      content_type: 'image/png',
      base64_data: fakePng('fake-png').toString('base64'),
    }, 'token_a');
    assert.equal(uploaded.ok, true);
    assert.match(uploaded.upload_id, /^upload_[a-f0-9]{32}$/);
    assert.match(uploaded.image_url, /^https:\/\/example\.test\//);
    const row = db.get('uploads', uploaded.upload_id);
    assert.equal(row.family_id, 'family_a');
    assert.equal(row.owner_member_id, 'member_a');
    assert.match(row.cloud_path, /^ai_uploads\/[a-f0-9]{20}\/[a-f0-9]{20}\//);

    const resolved = await invoke({ action: 'resolve_image', upload_id: uploaded.upload_id }, 'token_a');
    assert.equal(resolved.ok, true);
    assert.equal(resolved.content_type, 'image/png');
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

  await scenario('只清理当前成员超过一天且未被记忆引用的上传', async () => {
    const png = fakePng('cleanup').toString('base64');
    const orphan = await invoke({ action: 'upload_image', content_type: 'image/png', base64_data: png }, 'token_a');
    db.get('uploads', orphan.upload_id).created_at = '2000-01-01T00:00:00.000Z';
    const referenced = await invoke({ action: 'upload_image', content_type: 'image/png', base64_data: png }, 'token_a');
    db.get('uploads', referenced.upload_id).created_at = '2000-01-01T00:00:00.000Z';
    db.seed('memories', 'memory_with_upload', { family_id: 'family_a', upload_id: referenced.upload_id });
    const result = await invoke({ action: 'cleanup_orphan_images' }, 'token_a');
    assert.equal(result.ok, true);
    assert.equal(result.deleted, 1);
    assert.equal(db.get('uploads', orphan.upload_id), undefined);
    assert.notEqual(db.get('uploads', referenced.upload_id), undefined);
  });

  await scenario('图片上传拒绝不支持类型、非法 base64 与超限输入', async () => {
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

  await scenario('共享仓 upsert 强制当前家庭 ID', async () => {
    const result = await invoke({ action: 'upsert', table: 'inventories', row: { kind: 'storehouse', family_id: 'family_b', stacks: [] } }, 'token_a');
    assert.equal(result.id, 'storehouse:family_a');
    assert.equal(db.get('inventories', result.id).family_id, 'family_a');
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
    const created = await invoke({
      action: 'upsert',
      table: 'farm_plots',
      row: {
        id: 'forged_plot',
        family_id: 'family_b',
        plot_index: 2,
        crop_id: 'corrato',
        planted_at_unix: 1800000000,
      },
    }, 'token_a');
    assert.equal(created.ok, true);
    assert.equal(created.id, 'farm_plot:family_a:2');
    assert.equal(db.get('farm_plots', created.id).family_id, 'family_a');
    assert.equal(db.get('farm_plots', created.id).plot_index, 2);
    assert.equal(db.get('farm_plots', created.id).crop_id, 'corrato');
    assert.equal(db.get('farm_plots', created.id).created_by_member_id, 'member_a');

    const visibleToSameFamily = await invoke({ action: 'query', table: 'farm_plots' }, 'token_a2');
    assert.deepEqual(visibleToSameFamily.rows.map((row) => row.id), ['farm_plot:family_a:2']);

    const occupied = await invoke({
      action: 'upsert',
      table: 'farm_plots',
      row: { plot_index: 2, crop_id: 'tomelone', planted_at_unix: 1800000060 },
    }, 'token_a2');
    assert.equal(occupied.code, 409);
    assert.equal(db.get('farm_plots', 'farm_plot:family_a:2').crop_id, 'corrato');

    const hiddenFromOtherFamily = await invoke({ action: 'query', table: 'farm_plots' }, 'token_b');
    assert.deepEqual(hiddenFromOtherFamily.rows, []);
  });

  await scenario('农场地块拒绝非法 plot 与 crop', async () => {
    assert.equal((await invoke({
      action: 'upsert',
      table: 'farm_plots',
      row: { plot_index: -1, crop_id: 'corrato' },
    }, 'token_a')).code, 400);
    assert.equal((await invoke({
      action: 'upsert',
      table: 'farm_plots',
      row: { plot_index: 2, crop_id: '../bad' },
    }, 'token_a')).code, 400);
  });

  await scenario('农场地块不能跨家庭删除', async () => {
    db.seed('farm_plots', 'farm_plot:family_a:3', {
      id: 'farm_plot:family_a:3',
      family_id: 'family_a',
      plot_index: 3,
      crop_id: 'corrato',
    });
    assert.equal((await invoke({
      action: 'delete',
      table: 'farm_plots',
      id: 'farm_plot:family_a:3',
    }, 'token_b')).code, 403);
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
    const result = await invoke({
      action: 'upsert',
      table: 'farm_plots',
      row: { plot_index: 4, crop_id: 'corrato' },
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
