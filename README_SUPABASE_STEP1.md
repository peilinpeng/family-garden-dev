# Family Garden Supabase Step 1

Files:
- `scripts/cloud_service.gd`
- `supabase_schema.sql`

## 1. Create Supabase tables and storage bucket

Open Supabase Dashboard → SQL Editor, paste and run:

`supabase_schema.sql`

This creates:
- family_members
- travel_places
- postcards
- messages
- mailbox_events
- family-photos bucket

## 2. Add CloudService to Godot

Copy:

`scripts/cloud_service.gd`

into your project:

`res://scripts/cloud_service.gd`

Then you can test it from `main.gd` by adding:

```gdscript
var cloud: CloudService

func _ready() -> void:
	cloud = CloudService.new()
	add_child(cloud)
	var data := await cloud.load_family_data()
	print(data)
```

## 3. First integration target

Do not integrate all features at once.

First, connect:
- Add Place → cloud.create_place_with_postcard(...)
- Delete Place → cloud.delete_place_and_postcards(...)
- Add Message → cloud.create_message(...)
- Startup → cloud.load_family_data()

Photo upload should be integrated after text cloud sync works.
