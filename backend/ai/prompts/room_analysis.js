"use strict";

const { BASE_SYSTEM, userBlock } = require("./base");
const version = "room-analysis-v1";

function build(payload, repairReason = "") {
  const instruction = `分析房间照片，只描述可见空间。objects 必须是 1..8 个 {object_type,zone}。
object_type 只能是 desk/lamp/plant/photo_wall/bed/chair；zone 必须来自 Gate 1 zone 枚举。
photo_wall 只能使用 back_wall，其他物件不能使用 back_wall。不得输出居住者身份或坐标。`;
  return { version, system: BASE_SYSTEM, user: userBlock(payload, instruction, repairReason), imageUrl: payload.image_url };
}

module.exports = { version, build };
