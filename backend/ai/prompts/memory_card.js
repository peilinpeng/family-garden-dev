"use strict";

const { BASE_SYSTEM, userBlock } = require("./base");
const version = "memory-card-v1";

function build(payload, repairReason = "") {
  const instruction = `生成一张记忆卡片。title<=40，description<=300，question<=120，confidence 为 0..1。
memory_type 只能是 travel/childhood/home/daily_life/family_event/personal_room/old_memory。
suggested_scene 只能是 garden/fishpond/farm/old_street/room/travel_area。
node_type 只能是 memory_flower/memory_seed/photo_board/postcard。`;
  return { version, system: BASE_SYSTEM, user: userBlock(payload, instruction, repairReason), imageUrl: payload.image_url || "" };
}

module.exports = { version, build };
