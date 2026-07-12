"use strict";

const { BASE_SYSTEM, userBlock, withoutImageTransport } = require("./base");
const version = "memory-card-v3";

function build(payload, repairReason = "") {
  const instruction = `生成一张记忆卡片。title<=40，description<=300，question 为 8..120 字符，confidence 为 0..1。
memory_type 只能是 travel/childhood/home/daily_life/family_event/personal_room/old_memory。
suggested_scene 只能是当前已完整支持的 garden/fishpond。
node_type 只能是 memory_flower/memory_seed/photo_board/postcard。
question 应邀请用户补充原始输入没有提供的感受、声音、气味、后续变化或难忘瞬间；不得只是要求复述 description 中已经明确写出的事实。
不得编造未在输入中出现的人物关系、地点、时间或事件。`;
  return { version, system: BASE_SYSTEM, user: userBlock(withoutImageTransport(payload), instruction, repairReason), imageUrl: payload.image_url || "" };
}

module.exports = { version, build };
