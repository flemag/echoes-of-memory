## SaveManager — Autoload singleton for persistent data in "Echoes of Memory".
## Uses JSON files stored in user:// with XOR cipher encryption and auto-save.
extends Node

## ── Signals ──────────────────────────────────────────────────────────────────
signal save_completed
signal load_completed
signal save_failed(error: String)

## ── Constants ────────────────────────────────────────────────────────────────
const SAVE_FILE := "user://echo_save.json"
const BACKUP_FILE := "user://echo_save_backup.json"
const ENCRYPTION_KEY := "EchoM3m0ry2026!"
const AUTO_SAVE_INTERVAL := 60.0          # seconds
const SAVE_VERSION := "1.0.0"

## Fields that are encrypted before writing to disk.
const ENCRYPTED_FIELDS := ["player_progress", "statistics"]

## ── Internal state ───────────────────────────────────────────────────────────
var _save_data: Dictionary = {}
var _is_dirty: bool = false
var _auto_save_timer: Timer

## ── Default save template ────────────────────────────────────────────────────
static func default_data() -> Dictionary:
        return {
                "version": SAVE_VERSION,
                "player_progress": {
                        "level": 1,
                        "xp": 0,
                        "total_score": 0,
                        "current_biome": "meadow",
                },
                "streak_data": {
                        "current_streak": 0,
                        "best_streak": 0,
                        "last_play_date": "",
                },
                "sanctuary_items": {},
                "emotion_fragments": [],
                "echo_queue": [],
                "settings": {
                        "music_volume": 0.8,
                        "sfx_volume": 1.0,
                        "notifications": true,
                        "theme": "dark",
                        "haptic": true,
                },
                "statistics": {
                        "total_plays": 0,
                        "perfect_combos": 0,
                        "sequences_completed": 0,
                        "echoes_redeemed": 0,
                        "total_play_time": 0.0,
                },
        }

#region ── Lifecycle ───────────────────────────────────────────────────────────
func _ready() -> void:
        _save_data = default_data()

        # Set up auto-save timer
        _auto_save_timer = Timer.new()
        _auto_save_timer.one_shot = false
        _auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
        _auto_save_timer.timeout.connect(_on_auto_save_timeout)
        add_child(_auto_save_timer)
        _auto_save_timer.start()

        # Attempt to load existing save on startup
        if has_save():
                var result := load_game()
                if not result.is_empty():
                        _save_data = result
                        _is_dirty = false

func _exit_tree() -> void:
        # Ensure data is persisted when the application closes
        if _is_dirty:
                save_game()
#endregion

#region ── Public API ──────────────────────────────────────────────────────────
## Persist current _save_data to disk, creating a backup first.
func save_game() -> void:
        # 1. Create a backup of the existing save (if any)
        if FileAccess.file_exists(SAVE_FILE):
                var bk := FileAccess.open(SAVE_FILE, FileAccess.READ)
                if bk:
                        var original := bk.get_as_text()
                        bk.close()
                        var bk_write := FileAccess.open(BACKUP_FILE, FileAccess.WRITE)
                        if bk_write:
                                bk_write.store_string(original)
                                bk_write.close()

        # 2. Deep-copy and encrypt sensitive fields
        var serialisable := _save_data.duplicate(true)
        for field in ENCRYPTED_FIELDS:
                if serialisable.has(field):
                        serialisable[field] = _xor_encrypt(JSON.stringify(serialisable[field]))

        # 3. Write JSON with indentation for readability
        var json_text := JSON.stringify(serialisable, "\t")
        var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
        if file:
                file.store_string(json_text)
                file.close()
                _is_dirty = false
                save_completed.emit()
        else:
                save_failed.emit("Could not open save file for writing: " + SAVE_FILE)


## Load save data from disk. Returns an empty Dictionary on failure.
func load_game() -> Dictionary:
        if not has_save():
                return {}

        var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
        if not file:
                save_failed.emit("Could not open save file for reading.")
                return {}

        var raw := file.get_as_text()
        file.close()

        var parsed: Variant = JSON.parse_string(raw)
        if parsed == null or not parsed is Dictionary:
                # Try loading from backup
                return _load_backup()

        var data: Dictionary = parsed

        # Decrypt encrypted fields
        for field in ENCRYPTED_FIELDS:
                if data.has(field) and data[field] is String:
                        var decrypted := _xor_decrypt(data[field])
                        var inner := JSON.parse_string(decrypted)
                        if inner != null:
                                data[field] = inner

        # Merge with defaults so new fields from updates are present
        data = _merge_defaults(data, default_data())

        load_completed.emit()
        return data


## Returns true if a save file exists on disk.
func has_save() -> bool:
        return FileAccess.file_exists(SAVE_FILE)


## Delete the save file and reset to defaults.
func reset_save() -> void:
        if FileAccess.file_exists(SAVE_FILE):
                DirAccess.remove_absolute(SAVE_FILE)
        if FileAccess.file_exists(BACKUP_FILE):
                DirAccess.remove_absolute(BACKUP_FILE)
        _save_data = default_data()
        _is_dirty = false


## Calculate how many consecutive days the player has played.
func get_streak_days() -> int:
        var last_date_str: String = _save_data.get("streak_data", {}).get("last_play_date", "")
        if last_date_str.is_empty():
                return 0

        var last_date := Time.get_datetime_dict_from_datetime_string(last_date_str, false)
        var now := Time.get_datetime_dict_from_system()
        var today := Time.get_date_string_from_system()

        if last_date_str == today:
                return _save_data["streak_data"]["current_streak"]

        # Check if yesterday
        var yesterday := _date_offset(now, -1)
        var yesterday_str := "%04d-%02d-%02d" % [yesterday["year"], yesterday["month"], yesterday["day"]]
        if last_date_str == yesterday_str:
                return _save_data["streak_data"]["current_streak"]
        return 0


## Record a play for today and update the streak counter.
func add_streak_day() -> void:
        var today := Time.get_date_string_from_system()
        var streak_data: Dictionary = _save_data.get("streak_data", {})
        var last_date_str: String = streak_data.get("last_play_date", "")

        if last_date_str == today:
                return  # Already recorded today

        var current: int = streak_data.get("current_streak", 0)

        if last_date_str.is_empty():
                current = 1
        else:
                var now := Time.get_datetime_dict_from_system()
                var yesterday := _date_offset(now, -1)
                var yesterday_str := "%04d-%02d-%02d" % [yesterday["year"], yesterday["month"], yesterday["day"]]
                if last_date_str == yesterday_str:
                        current += 1
                else:
                        current = 1  # Streak broken — restart

        streak_data["current_streak"] = current
        streak_data["last_play_date"] = today
        if current > streak_data.get("best_streak", 0):
                streak_data["best_streak"] = current

        _save_data["streak_data"] = streak_data
        _is_dirty = true


## Convenience helper to update a single statistics key.
func update_stat(key: String, value: Variant) -> void:
        var stats: Dictionary = _save_data.get("statistics", {})
        stats[key] = value
        _save_data["statistics"] = stats
        _is_dirty = true


## Return the raw save-data dictionary (read-only reference).
func get_data() -> Dictionary:
        return _save_data
#endregion

#region ── Auto-save ───────────────────────────────────────────────────────────
func _on_auto_save_timeout() -> void:
        if _is_dirty:
                save_game()
#endregion

#region ── Encryption (simple XOR cipher) ──────────────────────────────────────
## XOR-encrypt a string and return base64-encoded result.
func _xor_encrypt(plain: String) -> String:
        var bytes := plain.to_utf8_buffer()
        var key_bytes := ENCRYPTION_KEY.to_utf8_buffer()
        var key_len := key_bytes.size()

        for i in range(bytes.size()):
                bytes[i] = bytes[i] ^ key_bytes[i % key_len]

        return Marshalls.raw_to_base64(bytes)


## Decrypt a base64-encoded XOR cipher string.
func _xor_decrypt(cipher: String) -> String:
        var bytes := Marshalls.base64_to_raw(cipher)
        var key_bytes := ENCRYPTION_KEY.to_utf8_buffer()
        var key_len := key_bytes.size()

        for i in range(bytes.size()):
                bytes[i] = bytes[i] ^ key_bytes[i % key_len]

        return bytes.get_string_from_utf8()
#endregion

#region ── Helpers ─────────────────────────────────────────────────────────────
## Attempt to load from backup file (used when main save is corrupt).
func _load_backup() -> Dictionary:
        if not FileAccess.file_exists(BACKUP_FILE):
                save_failed.emit("Both save and backup files are missing or corrupt.")
                return {}

        var file := FileAccess.open(BACKUP_FILE, FileAccess.READ)
        if not file:
                return {}

        var raw := file.get_as_text()
        file.close()

        var parsed: Variant = JSON.parse_string(raw)
        if parsed == null or not parsed is Dictionary:
                save_failed.emit("Backup file is also corrupt.")
                return {}

        return parsed


## Recursively merge missing default keys into loaded data so new
## fields introduced in updates are always present.
func _merge_defaults(loaded: Dictionary, defaults: Dictionary) -> Dictionary:
        for key in defaults:
                if not loaded.has(key):
                        loaded[key] = defaults[key]
                elif defaults[key] is Dictionary and loaded[key] is Dictionary:
                        loaded[key] = _merge_defaults(loaded[key], defaults[key])
        return loaded


## Return a date dictionary offset by `days` from `base`.
func _date_offset(base: Dictionary, days: int) -> Dictionary:
        # Convert to Unix timestamp, offset, convert back
        var unix := Time.get_unix_time_from_datetime_dict(base) + float(days) * 86400.0
        return Time.get_datetime_dict_from_unix_time(int(unix))
#endregion
