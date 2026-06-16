## IdleGrowth — Handles idle / offline growth calculation.
## When the player returns to the sanctuary after being away, this node
## calculates how much items have grown and how much memory dust was earned.
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Maximum offline time considered (seconds). 48 hours.
const MAX_OFFLINE_SECONDS: float = 172800.0
## Offline growth runs at 50 % of the normal active-play rate.
const OFFLINE_GROWTH_FACTOR: float = 0.5
## Minimum offline time (seconds) before showing a rewards popup. 10 minutes.
const MIN_OFFLINE_FOR_POPUP: float = 600.0

## Real-time thresholds for each growth transition (seconds, full speed).
const GROWTH_THRESHOLDS: Array = [
        3600.0,   # seed  → sprout   (1 hour)
        14400.0,  # sprout → blooming (4 hours)
        43200.0,  # blooming → radiant (12 hours)
]

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted after offline rewards have been computed.
signal offline_rewards_calculated(rewards: Dictionary)

# ---------------------------------------------------------------------------
# Growth Progress
# ---------------------------------------------------------------------------

## Returns progress [code]0.0 – 1.0[/code] towards the next growth stage
## for an item placed at [param placed_time] currently at [param growth_stage].
func get_growth_progress(placed_time: float, growth_stage: int) -> float:
        # Already at max stage.
        if growth_stage >= 3:
                return 1.0

        var now: float = Time.get_unix_time_from_system()
        var elapsed: float = now - placed_time

        # Subtract time already "consumed" by previous stages.
        var time_accounted: float = 0.0
        for i: int in range(growth_stage):
                if i < GROWTH_THRESHOLDS.size():
                        time_accounted += GROWTH_THRESHOLDS[i]

        var remaining: float = elapsed - time_accounted
        var required: float = GROWTH_THRESHOLDS[growth_stage] if growth_stage < GROWTH_THRESHOLDS.size() else 1.0

        return clampf(remaining / required, 0.0, 1.0)

# ---------------------------------------------------------------------------
# Offline Calculation
# ---------------------------------------------------------------------------

## Called when returning to the sanctuary after being away.
## [param last_timestamp] is the UNIX epoch of when the player last visited.
## Returns a dictionary with grown items, dust earned, and time away.
func calculate_offline_growth(last_timestamp: float) -> Dictionary:
        var now: float = Time.get_unix_time_from_system()
        var raw_time_away: float = now - last_timestamp

        # Cap at maximum offline window.
        var time_away: float = minf(raw_time_away, MAX_OFFLINE_SECONDS)
        # Apply the 50 % offline growth factor.
        var effective_time: float = time_away * OFFLINE_GROWTH_FACTOR

        var grown_items: Array = []
        var dust_earned: int = 0

        # Iterate every sanctuary item and determine its new stage.
        for item: Dictionary in SanctuaryManager.get_items().values():
                var placed: float = item["placed_time"]
                var old_stage: int = item["growth_stage"]
                var new_stage: int = _calculate_stage_from_time(placed, effective_time)
                if new_stage > old_stage:
                        item["growth_stage"] = new_stage
                        grown_items.append({"id": item["id"], "old_stage": old_stage, "new_stage": new_stage})

        # Memory dust from radiant items (50 % rate already applied to time).
        var radiant_count: int = 0
        for item: Dictionary in SanctuaryManager.get_items().values():
                if item["growth_stage"] >= 3:
                        radiant_count += 1

        var hours_offline: int = int(effective_time / 3600.0)
        dust_earned = radiant_count * hours_offline

        if dust_earned > 0:
                SanctuaryManager.memory_dust += dust_earned

        var rewards: Dictionary = {
                "grown_items": grown_items,
                "dust_earned": dust_earned,
                "time_away":   time_away,
        }

        # Only emit and show popup if the player was away long enough.
        if raw_time_away >= MIN_OFFLINE_FOR_POPUP and (not grown_items.is_empty() or dust_earned > 0):
                offline_rewards_calculated.emit(rewards)

        return rewards

# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

## Compute the growth stage for an item placed at [param placed_time],
## given an [param effective_elapsed] time in seconds (already factored).
func _calculate_stage_from_time(placed_time: float, effective_elapsed: float) -> int:
        var real_elapsed: float = Time.get_unix_time_from_system() - placed_time
        # We blend the real elapsed with the offline-capped effective time.
        # The effective_elapsed already accounts for the 50 % factor and cap.
        var elapsed: float = minf(real_elapsed, effective_elapsed + (real_elapsed - minf(real_elapsed, MAX_OFFLINE_SECONDS)))

        var stage: int = 0
        var cumulative: float = 0.0
        for threshold: float in GROWTH_THRESHOLDS:
                cumulative += threshold
                if real_elapsed >= cumulative:
                        stage += 1
                else:
                        break

        return mini(stage, 3)
