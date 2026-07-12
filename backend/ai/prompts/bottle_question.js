"use strict";

const { BASE_SYSTEM, userBlock } = require("./base");
const version = "bottle-question-v3";

function build(payload, repairReason = "") {
  const instruction = `生成一个温和、开放、低压力的家庭回忆问题，不预设答案。question 为 8..120 字符。
优先选择 memory_stats 中较少出现的回忆类型，并严格避开 avoid_topics 中列出的主题。
scene 只是问题出现的游戏场景，不代表用户现实中去过该地点；不得因为 fishpond 等场景名虚构鱼池、湖边或任何共同经历。
没有具体记忆证据时使用“有没有一件……”“哪一次……”等开放表达，不得使用“还记得我们曾经……”这类预设事件已经发生的说法。
只返回 question/target_memory_type/suggested_scene/prompt_type/tone/safety_note。
prompt_type 只能是 shared_memory/personal_memory/directed_memory，tone 固定 warm。`;
  return { version, system: BASE_SYSTEM, user: userBlock(payload, instruction, repairReason), imageUrl: "" };
}

module.exports = { version, build };
