"use strict";

const { BASE_SYSTEM, userBlock } = require("./base");
const version = "kitchen-dish-v2";

function build(payload, repairReason = "") {
  const instruction = `根据 ingredients 生成一个温暖、轻松、适合家庭厨房玩法的创意料理说明。
只能基于请求中列出的食材发挥，不得添加请求外的关键食材；可以描述口感、做法氛围和摆盘感觉。
这是游戏里的创意料理，不是家庭真实记忆。不得编造用户家庭成员、地点、经历或传统。
name 为 1..40 字符；description 为 1..240 字符；serving_note 为 1..120 字符；family_question 为 8..120 字符。
family_question 只能是开放式餐桌话题，不能预设某件事已经发生。
同时返回 visual，用于客户端渲染 soft pixel 菜品图，风格参考：暖色、低饱和、清晰轮廓、像素点阵、白色/奶油色盘子或容器、少量高亮和绿色点缀。
visual.style 固定为 soft_pixel_food_icon；shape 只能是 plate/bowl/jar/mug/breakfast_plate；
plate_color/base_color/garnish_color 必须是 #RRGGBB；accent_colors 必须是 1..4 个 #RRGGBB。
visual 不能包含坐标、尺寸、文字、logo、人物或现实照片信息。
只返回 name/description/serving_note/family_question/visual/safety_note。`;
  return { version, system: BASE_SYSTEM, user: userBlock(payload, instruction, repairReason), imageUrl: "" };
}

module.exports = { version, build };
