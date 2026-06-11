# 08｜AI 美术资产提示词库

## 1. 使用说明

本文档用于批量生产 Family Garden 的美术资产。使用时请遵守：

1. 场景背景和交互物件分开生成；
2. 交互物件必须透明背景；
3. 不生成文字、logo、水印；
4. 不模仿具体受版权保护的游戏画风；
5. 所有资产生成后必须登记到 asset manifest；
6. 同一类物件不同状态必须保持相同尺寸和相似轮廓。

---

## 2. 全局风格提示词

所有提示词都可以附加以下风格段落：

```text
Warm hand-painted 2D mobile game art, cozy family memory garden, soft watercolor texture, gentle sunlight, rounded shapes, low saturation colors, peaceful and healing atmosphere, storybook illustration style, clean composition, clear readable objects, suitable for a horizontal 16:9 mobile game scene, soft shadows, no harsh contrast, no realistic 3D, no photorealism, no complex perspective, no text, no logos.
```

负面提示词：

```text
photorealistic, realistic 3D, cyberpunk, dark fantasy, horror, dramatic lighting, high contrast, cluttered details, messy composition, text, watermark, logo, UI text, distorted objects, broken perspective, overly detailed, anime character focus, copyrighted style, fighting scene, weapons, monsters.
```

---

# 3. 家庭花园 Garden

## 3.1 家庭花园背景

```text
Create a horizontal 16:9 background for a cozy family memory garden in a 2D mobile game.

The scene is a small peaceful garden used as a digital family third space. It has a soft grass field, a winding path, gentle flower beds, a small water corner, wooden signs leading to other memory places, and warm afternoon sunlight. The center area should remain open for interactive memory flowers and photo boards to be placed later.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, low saturation colors, peaceful and healing atmosphere, storybook illustration, clean composition.

Requirements: background only, 1280x720, no characters, no text, no UI, no logos, no clickable icons, no overly detailed objects.
```

## 3.2 记忆花｜新记忆状态

```text
Create a single interactive memory flower asset for a cozy 2D mobile game.

The flower represents a new family memory growing in a garden. It should look gentle, magical, and warm, with soft petals, a small leafy stem, and a subtle glowing center. The silhouette must be clear and readable on a mobile screen.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, healing atmosphere.

Requirements: isolated object, transparent background, clean silhouette, suitable as a clickable map node, no text, no logo.

Variant: new unread memory, slightly glowing.
```

## 3.3 记忆花｜已读状态

```text
Create a single interactive memory flower asset for a cozy 2D mobile game.

This is the read state of a memory flower. It should look calm and gentle, with a softer glow than the unread version. Keep the same general shape, size, and silhouette as the unread memory flower.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes.

Requirements: isolated object, transparent background, clean silhouette, no text, no logo.
```

## 3.4 记忆花｜成长状态

```text
Create a single interactive grown memory flower asset for a cozy 2D mobile game.

This flower represents a family memory that has been answered and enriched. It should look fuller and slightly more alive, with more petals, small leaves, and a warm gentle glow. Keep it consistent with the previous memory flower design.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, healing atmosphere.

Requirements: isolated object, transparent background, clean silhouette, suitable as a clickable map node, no text, no logo.
```

## 3.5 照片牌

```text
Create a single wooden photo board asset for a cozy 2D mobile game garden.

The object is a small warm wooden sign or board where a family photo can be displayed. It should have a blank rectangular photo area, small leaves or flowers around it, and a gentle handmade feeling.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, cozy family memory atmosphere.

Requirements: isolated object, transparent background, clean silhouette, no actual photo, no readable text, no logo, suitable as a clickable object.
```

## 3.6 场景入口木牌

```text
Create a single wooden direction sign asset for a cozy 2D family memory garden game.

The sign should be simple, warm, rounded, and handmade. It will be used as an entrance to another memory scene such as a fishpond, farm, room, or old street. Leave the sign blank with no readable text.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes.

Requirements: isolated object, transparent background, clean silhouette, suitable as a clickable scene entrance, no text, no logo.
```

---

# 4. 爸爸鱼塘 Fishpond

## 4.1 鱼塘背景

```text
Create a horizontal 16:9 background for a cozy 2D mobile game scene called Dad's Fishpond.

The scene is a small peaceful fishpond at the edge of a family garden. It has calm water, soft grass, a wooden fishing platform, a simple fishing rod, small stones, water plants, and warm afternoon light. The right side should have space for a floating memory bottle. The center water area should be clear and readable.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, low saturation colors, peaceful family memory atmosphere.

Requirements: background only, 1280x720, no characters, no text, no UI, no logo, no interactive bottle included.
```

## 4.2 漂流瓶｜未打开

```text
Create a single floating memory bottle asset for a cozy 2D mobile game.

The bottle is small and warm-looking, with a rolled paper note inside and a soft cork. It should feel like a gentle family memory question waiting to be opened.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, peaceful atmosphere.

Requirements: isolated object, transparent background, clean silhouette, readable on mobile screen, suitable as a clickable object, no text, no logo.

Variant: closed bottle.
```

## 4.3 漂流瓶｜已打开

```text
Create a single opened memory bottle asset for a cozy 2D mobile game.

The bottle has a small paper note partly coming out, with a gentle warm glow. It should look like a family memory question has been discovered.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes.

Requirements: isolated object, transparent background, clean silhouette, no readable text, no logo.

Variant: opened bottle.
```

## 4.4 鱼竿

```text
Create a single 2D game prop: an old fishing rod leaning beside a small pond.

The object should feel personal and nostalgic, like a father's hobby item in a family memory game. It should be simple, warm, and readable at small size.

Style: warm hand-painted 2D mobile game art, soft watercolor texture, rounded shapes, cozy and gentle.

Requirements: isolated object, transparent background, clean silhouette, no text, no logo.
```

## 4.5 水面涟漪记忆节点

```text
Create a single magical water ripple asset for a cozy 2D mobile game.

The ripple represents a family memory emerging from a fishpond after someone answers a memory bottle question. It should look soft, warm, and slightly glowing, not dramatic.

Style: warm hand-painted 2D game art, soft watercolor texture, gentle glow, low saturation colors.

Requirements: isolated object, transparent background, clean silhouette, suitable as a clickable map node, no text, no logo.
```

---

# 5. 爷爷农场 Farm

## 5.1 农场背景

```text
Create a horizontal 16:9 background for a cozy 2D mobile game scene called Grandpa's Farm.

The scene is a small warm family farm with a few vegetable plots, a tiny wooden shed, simple fences, old farming tools, soft grass, and warm sunlight. The center should have open soil plots where memory seeds can grow. The scene should feel nostalgic, peaceful, and lived-in.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, low saturation colors, healing storybook atmosphere.

Requirements: background only, 1280x720, no characters, no text, no UI, no logo, no memory seeds included.
```

## 5.2 记忆种子

```text
Create a single magical memory seed asset for a cozy 2D mobile game.

The seed should look like a small glowing seed planted in soil, representing a family story waiting to grow. It should be simple, warm, and readable.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes.

Requirements: isolated object, transparent background, clean silhouette, suitable as a clickable map node, no text, no logo.
```

## 5.3 发芽记忆

```text
Create a single sprouting memory seed asset for a cozy 2D mobile game.

The seed has started to grow into a small green sprout with a soft warm glow, representing a family memory that has been partially answered.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, healing atmosphere.

Requirements: isolated object, transparent background, clean silhouette, suitable as a clickable map node, no text, no logo.
```

## 5.4 成熟记忆作物

```text
Create a single grown memory crop asset for a cozy 2D mobile game.

The crop represents a family memory that has been shared and enriched. It should look like a small warm plant with leaves and tiny glowing fruits or flowers.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, peaceful and healing.

Requirements: isolated object, transparent background, clean silhouette, suitable as a clickable map node, no text, no logo.
```

---

# 6. AI 个人房间 Room

## 6.1 房间背景

```text
Create a horizontal 16:9 background for a cozy personal room in a 2D mobile game.

The room should feel warm, lived-in, and personal. It has a simple wall and floor, a window, soft light, and enough empty space for furniture objects such as a desk, lamp, plant, bed, and photo wall to be placed later.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, low saturation colors, peaceful family memory atmosphere.

Requirements: background only, 1280x720, no characters, no UI, no text, no logo, do not include fixed furniture except basic wall, floor, window, and door.
```

## 6.2 书桌

```text
Create a single cozy wooden desk asset for a 2D mobile game personal room.

The desk should feel warm and personal, suitable for a family memory room. It can have simple books and small items, but no readable text.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes.

Requirements: isolated object, transparent background, clean silhouette, suitable as a room prop, no text, no logo.
```

## 6.3 台灯

```text
Create a single small desk lamp asset for a cozy 2D mobile game room.

The lamp should feel warm, gentle, and personal, with a soft yellow glow.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes.

Requirements: isolated object, transparent background, clean silhouette, no text, no logo.
```

## 6.4 照片墙

```text
Create a single photo wall asset for a cozy 2D mobile game room.

The photo wall should include several blank photo frames and small decorative notes, but no readable text. It should feel like a place where family memories can be displayed.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, warm nostalgic atmosphere.

Requirements: isolated object, transparent background, clean silhouette, suitable as a clickable object, no text, no logo.
```

## 6.5 植物

```text
Create a single small potted plant asset for a cozy 2D mobile game room.

The plant should be warm, simple, and friendly, suitable for a personal memory room. It should not be too detailed.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes.

Requirements: isolated object, transparent background, clean silhouette, no text, no logo.
```

---

# 7. 老街 / 胡同 Old Street

## 7.1 老街背景

```text
Create a horizontal 16:9 background for a nostalgic old neighborhood street in a cozy 2D mobile game.

The scene should feel like a warm old residential street carrying childhood and family memories. It may include old brick walls, small doors, windows, a bench, a bicycle, plants, hanging laundry, and warm sunlight. The composition should leave clear open space for clickable memory objects such as doorplates, windows, and photo walls.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, low saturation colors, nostalgic but not sad, peaceful family memory atmosphere.

Requirements: background only, 1280x720, no characters, no text, no UI, no logos, no specific real-world landmark.
```

## 7.2 老照片墙

```text
Create a single old photo wall asset for a nostalgic 2D mobile game street scene.

The object should include several blank photo frames attached to an old wall board. It should feel warm, nostalgic, and suitable for displaying family memories. Do not include actual readable text or real photos.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes.

Requirements: isolated object, transparent background, clean silhouette, suitable as a clickable object, no text, no logo.
```

## 7.3 门牌

```text
Create a single old residential doorplate asset for a cozy 2D mobile game old street scene.

The doorplate should feel warm and nostalgic, like an entrance to an old family memory. Leave the plate blank with no readable text.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, low saturation colors.

Requirements: isolated object, transparent background, clean silhouette, clickable object, no text, no logo.
```

---

# 8. 旅行明信片 Travel

## 8.1 明信片节点

```text
Create a single travel postcard asset for a cozy 2D mobile game.

The postcard should look warm and nostalgic, with a blank image area, a small stamp-like decoration, and soft rounded corners. It represents a family travel memory.

Style: warm hand-painted 2D game art, soft watercolor texture, low saturation colors, peaceful travel memory atmosphere.

Requirements: isolated object, transparent background, clean silhouette, suitable as a clickable map node, no readable text, no logo.
```

## 8.2 行李箱

```text
Create a single small suitcase asset for a cozy 2D mobile game travel memory scene.

The suitcase should feel warm, simple, and nostalgic, suitable for a family travel memory area.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes.

Requirements: isolated object, transparent background, clean silhouette, no text, no logo.
```

---

# 9. UI Prompt

## 9.1 记忆卡片

```text
Create a soft game UI panel for a memory card in a cozy family memory game.

The panel should look like warm paper or a gentle scrapbook card. It should have space for a title, a photo area, a short description, a question, and a button area. Use rounded corners, soft beige and cream colors, subtle shadows, and a warm hand-painted style.

Requirements: horizontal mobile game UI, no actual text, no logo, no watermark, clean layout, suitable for 1280x720 screen.
```

## 9.2 漂流瓶问题面板

```text
Create a soft game UI panel for a memory bottle question in a cozy family memory game.

The panel should feel like a small paper note taken from a bottle. It should have space for one warm question, an answer area, and a submit button. Use rounded corners, soft paper texture, gentle shadows, and warm colors.

Style: hand-painted storybook UI, cozy, healing, low-pressure.

Requirements: no actual text, no logo, no watermark, suitable for horizontal mobile game screen.
```

## 9.3 横屏提示

```text
Create a simple warm UI illustration for a mobile game rotation prompt.

The image should gently suggest that the player rotate their phone to landscape mode. It should include a simple phone icon turning sideways, soft flowers or small leaves around it, and a warm cozy feeling.

Style: hand-painted 2D game UI, soft watercolor texture, rounded shapes, gentle colors.

Requirements: no readable text, no logo, transparent or simple background, suitable for a cozy family memory game.
```

---

# 10. 角色 Prompt

```text
Create a cute small mascot character for a cozy family memory garden game.

The character should be simple, warm, rounded, and friendly. It should feel like a gentle companion in a healing mobile game. The design can be inspired by a small vegetable-like creature, such as a potato or carrot, but should be original and not based on any existing character.

Style: warm hand-painted 2D game art, soft watercolor texture, rounded shapes, simple silhouette, low saturation colors.

Requirements: isolated character, transparent background, front view, suitable for a 2D mobile game, no text, no logo, no complex details.
```
