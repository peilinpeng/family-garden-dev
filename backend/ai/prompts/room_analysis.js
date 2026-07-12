"use strict";

const { BASE_SYSTEM, userBlock, withoutImageTransport } = require("./base");
const version = "room-analysis-v4";

function build(payload, repairReason = "") {
  const instruction = `分析房间照片，只描述可见空间。顶层必须完整包含 room_type、style、suggested_room_theme、description、objects，可选 safety_note，不得增加其他字段。
room_type 只能是 bedroom/study/living_room/kitchen_corner/unknown。
style 只能是 warm_cozy/simple/nostalgic/bright/quiet。
suggested_room_theme 只能是 study_corner/reading_corner/rest_corner/family_corner/memory_corner。
objects 必须是 1..8 个 {object_type,zone}；object_type 只能是 desk/lamp/plant/photo_wall/bed/chair。
zone 只能是 back_wall/back_left/back_center/back_right/left_side/right_side/front_left/front_center/front_right/floor_center。
photo_wall 只能使用 back_wall，其他物件不能使用 back_wall。不得输出居住者身份或坐标。
忽略截图边框、按钮、文字、导航栏和其他界面叠层，只分析房间空间本身。
只输出照片中有明确视觉证据的受支持物件；不得把地毯、窗户、时钟、界面卡片或不支持的物件替换成 desk/lamp/plant/photo_wall/bed/chair。
误报比漏报更糟：不确定物件类型时直接省略，不能为了增加 objects 数量选择最接近的枚举。
desk 必须看得到桌面结构；chair 必须看得到座面与靠背轮廓；lamp 必须看得到灯罩、灯头或灯杆；plant 必须看得到叶片与花盆；photo_wall 必须看得到照片或相框组合；bed 必须看得到床垫或床头结构。
description 应概括空间、光线和主要可见陈设，不描述应用界面。`;
  return { version, system: BASE_SYSTEM, user: userBlock(withoutImageTransport(payload), instruction, repairReason), imageUrl: payload.image_url };
}

module.exports = { version, build };
