#!/usr/bin/env python3
"""验证 Gate 1 JSON Schema、请求样例、mock 响应和关键拒绝用例。"""

from __future__ import annotations

import copy
import json
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker
from jsonschema.exceptions import ValidationError
from referencing import Registry, Resource


AI_DIR = Path(__file__).resolve().parents[1]
SCHEMA_DIR = AI_DIR / "schemas"
FIXTURE_DIR = Path(__file__).resolve().parent / "fixtures"
MOCK_DIR = AI_DIR.parent / "mocks"


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


schemas = {path.name: load_json(path) for path in sorted(SCHEMA_DIR.glob("*.schema.json"))}
store = {schema["$id"]: schema for schema in schemas.values()}
registry = Registry().with_resources(
    (schema_id, Resource.from_contents(schema)) for schema_id, schema in store.items()
)
for schema in schemas.values():
    Draft202012Validator.check_schema(schema)


def validator(schema_name: str) -> Draft202012Validator:
    schema = schemas[schema_name]
    return Draft202012Validator(schema, registry=registry, format_checker=FormatChecker())


def validate(schema_name: str, value) -> None:
    validator(schema_name).validate(value)


def expect_invalid(schema_name: str, value, label: str) -> None:
    try:
        validate(schema_name, value)
    except ValidationError:
        return
    raise AssertionError(f"应拒绝但通过：{label}")


cases = {
    "generate-memory-card": "memory_card_mock.json",
    "generate-bottle-question": "bottle_question_mock.json",
    "generate-kitchen-dish": "kitchen_dish_mock.json",
    "analyze-room-photo": "room_analysis_mock.json",
    "cross-memory-link": "cross_memory_link_mock.json",
}

for endpoint, mock_name in cases.items():
    validate(f"{endpoint}.request.schema.json", load_json(FIXTURE_DIR / f"{endpoint}.request.json"))
    response = {
        "ok": True,
        "data": load_json(MOCK_DIR / mock_name),
        "meta": {
            "request_id": "req_contract_test",
            "provider": "mock",
            "model": "mock",
            "prompt_version": f"{endpoint}-v1",
            "source": "mock",
            "result": "complete",
        },
    }
    validate(f"{endpoint}.response.schema.json", response)

failure = {
    "ok": False,
    "error": {"code": "AI_TIMEOUT", "message": "AI 服务超时。", "retryable": True},
    "meta": {"request_id": "req_timeout"},
}
for endpoint in cases:
    validate(f"{endpoint}.response.schema.json", failure)
validate("moderate-user-content.response.schema.json", failure)

moderation_request = {
    "kind": "memory_card_edit",
    "texts": ["和家人在花园里种树。"],
    "language": "zh-CN",
}
validate("moderate-user-content.request.schema.json", moderation_request)
validate(
    "moderate-user-content.response.schema.json",
    {
        "ok": True,
        "data": {"approved": True, "safety_note": "已通过安全检查。"},
        "meta": {
            "request_id": "req_moderation",
            "provider": "content-safety",
            "model": "tencent",
            "prompt_version": "user-content-safety-v1",
            "source": "ai",
            "result": "complete",
        },
    },
)
expect_invalid(
    "moderate-user-content.request.schema.json",
    {"kind": "bottle_answer", "texts": [], "language": "zh-CN"},
    "内容审核缺少文本",
)

upload_request = {
    "memory_id": "mem_upload",
    "input_type": "photo",
    "upload_id": "upload_0123456789abcdef0123456789abcdef",
    "language": "zh-CN",
}
validate("generate-memory-card.request.schema.json", upload_request)

empty_link = {
    "ok": True,
    "data": {"links": [], "safety_note": "没有找到足够可靠的关联。"},
    "meta": {
        "request_id": "req_empty",
        "provider": "hunyuan",
        "model": "test-model",
        "prompt_version": "cross-memory-link-v1",
        "source": "ai",
        "result": "empty",
    },
}
validate("cross-memory-link.response.schema.json", empty_link)

inconsistent_empty = copy.deepcopy(empty_link)
inconsistent_empty["meta"]["result"] = "complete"
expect_invalid(
    "cross-memory-link.response.schema.json",
    inconsistent_empty,
    "空关联错误标记为 complete",
)

expect_invalid(
    "generate-memory-card.request.schema.json",
    {"memory_id": "mem_1", "input_type": "photo", "language": "zh-CN"},
    "记忆卡片缺少图片和文字",
)

forged_identity = load_json(FIXTURE_DIR / "generate-memory-card.request.json")
forged_identity["family_id"] = "another_family"
expect_invalid(
    "generate-memory-card.request.schema.json",
    forged_identity,
    "客户端伪造 family_id",
)

missing_source_memory = load_json(FIXTURE_DIR / "cross-memory-link.request.json")
for field in ("title", "description", "memory_type"):
    missing_source_memory.pop(field)
expect_invalid(
    "cross-memory-link.request.schema.json",
    missing_source_memory,
    "跨记忆请求只提供新记忆 ID",
)

bad_memory = load_json(MOCK_DIR / "memory_card_mock.json")
bad_memory["x"] = 640
expect_invalid(
    "generate-memory-card.response.schema.json",
    {"ok": True, "data": bad_memory, "meta": response["meta"]},
    "AI 输出坐标",
)

bad_memory = load_json(MOCK_DIR / "memory_card_mock.json")
bad_memory["suggested_scene"] = "moon"
expect_invalid(
    "generate-memory-card.response.schema.json",
    {"ok": True, "data": bad_memory, "meta": response["meta"]},
    "非法场景枚举",
)

bad_bottle = load_json(MOCK_DIR / "bottle_question_mock.json")
bad_bottle["question"] = "问" * 121
expect_invalid(
    "generate-bottle-question.response.schema.json",
    {"ok": True, "data": bad_bottle, "meta": response["meta"]},
    "漂流瓶问题超长",
)

bad_dish = load_json(MOCK_DIR / "kitchen_dish_mock.json")
bad_dish["family_story"] = "这是你们去年旅行时第一次做的菜。"
expect_invalid(
    "generate-kitchen-dish.response.schema.json",
    {"ok": True, "data": bad_dish, "meta": response["meta"]},
    "厨房料理夹带额外家庭事实字段",
)

bad_dish_request = load_json(FIXTURE_DIR / "generate-kitchen-dish.request.json")
bad_dish_request["ingredients"][0]["x"] = 12
expect_invalid(
    "generate-kitchen-dish.request.schema.json",
    bad_dish_request,
    "厨房食材夹带坐标",
)

bad_room = load_json(MOCK_DIR / "room_analysis_mock.json")
bad_room["objects"] = bad_room["objects"] * 3
expect_invalid(
    "analyze-room-photo.response.schema.json",
    {"ok": True, "data": bad_room, "meta": response["meta"]},
    "房间物件超过 8 个",
)

bad_room = load_json(MOCK_DIR / "room_analysis_mock.json")
bad_room["objects"][0]["x"] = 320
expect_invalid(
    "analyze-room-photo.response.schema.json",
    {"ok": True, "data": bad_room, "meta": response["meta"]},
    "房间物件夹带坐标",
)

bad_room = load_json(MOCK_DIR / "room_analysis_mock.json")
bad_room["objects"][3]["zone"] = "front_left"
expect_invalid(
    "analyze-room-photo.response.schema.json",
    {"ok": True, "data": bad_room, "meta": response["meta"]},
    "墙面物件落入地面 zone",
)

bad_link = copy.deepcopy(load_json(MOCK_DIR / "cross_memory_link_mock.json"))
bad_link["links"][0]["relation_type"] = "same_feeling"
expect_invalid(
    "cross-memory-link.response.schema.json",
    {"ok": True, "data": bad_link, "meta": response["meta"]},
    "非法关联类型",
)

bad_fallback = {
    "ok": True,
    "data": load_json(MOCK_DIR / "memory_card_mock.json"),
    "meta": {
        "request_id": "req_bad_fallback",
        "provider": "mock",
        "model": "mock",
        "prompt_version": "generate-memory-card-v1",
        "source": "fallback",
        "result": "complete",
    },
}
expect_invalid(
    "generate-memory-card.response.schema.json",
    bad_fallback,
    "fallback 缺少 fallback_reason",
)

wrong_result = copy.deepcopy(bad_fallback)
wrong_result["meta"]["source"] = "mock"
wrong_result["meta"]["result"] = "empty"
expect_invalid(
    "generate-memory-card.response.schema.json",
    wrong_result,
    "非空 data 错误标记为 empty",
)

print(f"Gate 1 契约测试通过：{len(schemas)} 个 Schema，5 组生成请求/mock + 1 组内容审核，扩展拒绝与空结果场景通过。")
