"use strict";

const { BASE_SYSTEM, userBlock } = require("./base");
const version = "bottle-question-v1";

function build(payload, repairReason = "") {
  const instruction = `生成一个温和、开放、低压力的家庭回忆问题，不预设答案。question 为 8..120 字符。
只返回 question/target_memory_type/suggested_scene/prompt_type/tone/safety_note。
prompt_type 只能是 shared_memory/personal_memory/directed_memory，tone 固定 warm。`;
  return { version, system: BASE_SYSTEM, user: userBlock(payload, instruction, repairReason), imageUrl: "" };
}

module.exports = { version, build };
