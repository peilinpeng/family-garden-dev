extends Node

## 本地玩家的云端身份(autoload GameIdentity)。
## 离线/未配置 CloudBase 时始终为空 → 各系统按原本地逻辑(如 MemoryManager.selected_role_key)。
## 联机后由 CloudBaseBackend.bootstrap() 调 whoami() 填充,谁都不能伪造 member_id
## (它由服务端根据 member_token 解析,见 backend/cloudbase/data_gateway)。

signal identity_ready

var member_id: String = ""
var family_id: String = ""
var role: String = ""
var display_name: String = ""

func is_ready() -> bool:
	return member_id != ""

func set_identity(m_id: String, f_id: String, r: String, name: String) -> void:
	member_id = m_id
	family_id = f_id
	role = r
	display_name = name
	identity_ready.emit()

## 供本地玩家取用的角色:云身份优先,否则回退本地存档角色。
func local_role(fallback: String) -> String:
	return role if is_ready() and role != "" else fallback
