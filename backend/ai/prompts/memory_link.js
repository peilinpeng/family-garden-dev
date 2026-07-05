"use strict";

const { BASE_SYSTEM, userBlock } = require("./base");
const version = "memory-link-v1";

function build(payload, repairReason = "") {
  const instruction = `判断新记忆与候选记忆是否存在可解释的内容重叠，最多返回 3 条 links；不可靠时 links=[]。
relation_type 只能是 same_place/same_people/same_theme/same_era，node_type 固定 memory_link。
只能引用输入中的 memory_id，不得输出坐标或推断人物关系。`;
  return { version, system: BASE_SYSTEM, user: userBlock(payload, instruction, repairReason), imageUrl: "" };
}

module.exports = { version, build };
