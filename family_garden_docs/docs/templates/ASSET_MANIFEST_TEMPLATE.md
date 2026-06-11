# Asset Manifest 模板

建议将下表复制到表格工具或 CSV 中使用。

| asset_id | file_name | scene | category | function | clickable | collision | foreground | states | size | transparent | owner | status | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| node_garden_memory_flower_01 | node_garden_memory_flower_01_new.png | garden | node | memory_card_entry | yes | no | no | new/read/grown | 256x256 | yes | A | todo | 点击后打开记忆卡 |
| node_fishpond_bottle_01 | node_fishpond_bottle_01_closed.png | fishpond | node | bottle_question | yes | no | no | closed/open | 256x256 | yes | A | todo | 点击后打开漂流瓶 |
| scene_garden_bg_01 | scene_garden_bg_01.png | garden | background | main_scene | no | no | no | none | 1280x720 | no | A | todo | 不包含交互物件 |

## status 字段

- todo：还没做
- generating：生成中
- ready：已产出，待导入
- tested：已导入测试
- imported：已进入项目
- need_revision：需要返工
