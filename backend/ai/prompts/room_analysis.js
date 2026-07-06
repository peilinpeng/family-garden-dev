"use strict";

const { BASE_SYSTEM, userBlock } = require("./base");
const version = "room-analysis-v2";

function build(payload, repairReason = "") {
  const instruction = `分析房间照片，只描述可见空间。顶层必须完整包含 room_type、style、suggested_room_theme、description、objects，可选 safety_note，不得增加其他字段。
room_type 只能是 bedroom/study/living_room/kitchen_corner/unknown。
style 只能是 warm_cozy/simple/nostalgic/bright/quiet。
suggested_room_theme 只能是 study_corner/reading_corner/rest_corner/family_corner/memory_corner。
objects 必须是 1..8 个 {object_type,zone}；object_type 只能是 desk/lamp/plant/photo_wall/bed/chair。
zone 只能是 back_wall/back_left/back_center/back_right/left_side/right_side/front_left/front_center/front_right/floor_center。
photo_wall 只能使用 back_wall，其他物件不能使用 back_wall。不得输出居住者身份或坐标。`;
  return { version, system: BASE_SYSTEM, user: userBlock(payload, instruction, repairReason), imageUrl: payload.image_url };
}

module.exports = { version, build };
