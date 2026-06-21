# Family Garden Godot MVP v2

This is the first asset-ready Godot implementation for Family Garden.

It is designed for Godot 4.7.x.

## MVP features

- Shared Garden main scene
- Background image support
- Four houses as clickable entries
- Family Tree interaction
- Mailbox interaction
- Bench display
- Player movement with WASD / arrow keys
- Three family NPCs
- Plant mode: click the garden to place flowers/trees/mushrooms/signs
- Drag placed items with left mouse button
- Delete placed items with right mouse button
- Local save/load via `user://family_garden_save_v2.json`

## Where to place your AI-generated assets

Put your cleaned PNG files in these paths:

```text
assets/backgrounds/shared_garden.png
assets/garden/family_tree.png
assets/garden/mailbox.png
assets/garden/bench.png
assets/garden/flower.png          optional
assets/garden/tree.png            optional
assets/garden/mushroom.png        optional
assets/garden/sign.png            optional

assets/houses/house_father.png
assets/houses/house_mother.png
assets/houses/house_player.png
assets/houses/house_partner.png

assets/characters/player_peilin.png
assets/characters/npc_father.png
assets/characters/npc_mother.png
assets/characters/npc_partner.png

assets/backgrounds/room_father.png   optional
assets/backgrounds/room_mother.png   optional
assets/backgrounds/room_player.png   optional
assets/backgrounds/room_partner.png  optional
```

If an asset is missing, the game uses a simple placeholder so the project can still run.

## Important asset note

Most AI images show a fake checkerboard background. That is not real transparency.
Before importing, remove the checkerboard background using Photopea, Photoshop, remove.bg, or another background remover, then export as PNG with alpha.

If you do not remove it, the checkerboard will appear in the game.

## How to open

1. Open Godot.
2. Click Import.
3. Select this folder's `project.godot`.
4. Click Import & Edit.
5. Press Run.

## Controls

```text
WASD / Arrow keys: move
Click Family Tree: open memory panel
Click Mailbox: open mailbox panel
Click houses: enter a room placeholder
P: toggle plant mode
Bottom buttons: choose plant type / save / reset / back garden
Plant mode ON + click ground: plant item
Left-drag planted item: move
Right-click planted item: delete
```

## Current scope

This project is intentionally minimal. It is the playable skeleton for the gift-game MVP.
The next development steps are:

1. Replace placeholders with cleaned assets.
2. Add real room backgrounds.
3. Add mailbox data and notes.
4. Add family tree memory timeline.
5. Export Web build.
