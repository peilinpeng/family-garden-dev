"use strict";

const { BASE_SYSTEM, userBlock } = require("./base");
const version = "memory-link-v3";

function build(payload, repairReason = "") {
  const instruction = `比较新记忆的 title/description/memory_type 与每个候选记忆，判断是否存在可解释的内容重叠；最多返回 3 条 links，不可靠时 links=[]。
relation_type 只能是 same_place/same_people/same_theme/same_era，node_type 固定 memory_link。
只能引用输入中的 memory_id，不得输出坐标或推断人物关系。
同一对 memory_id（不区分 a/b 顺序）最多返回一条 link；若同时存在多种关系，只保留证据最强的一种。
每条 link 必须完整包含 memory_id_a、memory_id_b、relation_type、confidence、question、node_type 六个字段；confidence 必须是 0 到 1 的数字，question 必须是 1 到 140 字的温和问题。
顶层只能包含 links 和可选 safety_note。`;
  return { version, system: BASE_SYSTEM, user: userBlock(payload, instruction, repairReason), imageUrl: "" };
}

module.exports = { version, build };
