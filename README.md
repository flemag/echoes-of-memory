# 🌟 Echoes of Memory

> *Reconstruct your past, one memory at a time...*

**Echoes of Memory** is a narrative puzzle memory game for mobile devices. Watch a sequence of colors and sounds, then reproduce it by tapping. Simple to learn, impossible to put down — thanks to deep gamification inspired by the best idle, merge, and collection games.

## 🎮 Core Gameplay

- **Simon Says meets emotional storytelling**: Watch sequences of colored nodes light up with unique tones, then tap them back in order
- **5-second learning curve**: Tap, watch, repeat. That's it.
- **Infinite procedural content**: Every sequence is generated from a seeded "memory tree" — no two runs are the same
- **Echo system**: Failed sequences don't disappear — they resonate and return as modified "echoes" for a second chance
- **Emotional fragments**: Collect 8 emotion types (Joy, Nostalgia, Anger, Serenity, Wonder, Melancholy, Courage, Hope) based on performance

## 🌿 Sanctuary

Your personal garden that grows in real-time:

- **Place items** powered by collected emotion fragments
- **Watch them grow** through 4 stages (seed → sprout → blooming → radiant) over hours/days
- **Idle rewards**: Radiant items produce "Memory Dust" passively
- **Offline growth**: Your garden continues growing at 50% speed while you're away
- **5 biomes**: Meadow → Forest → Cavern → Ocean → Cosmos (unlocked by level)

## 📊 Gamification

| Feature | Description |
|---------|-------------|
| **Combo system** | Chain perfect sequences for up to 3x score multiplier |
| **Daily streaks** | Play every day to build your streak and earn bonuses |
| **Collection** | Discover all 8 emotion types — from common (Joy) to rare (Hope) |
| **Shared Dreams** | Share sequences with friends via codes — async social |
| **Echo mechanic** | Failed sequences return modified for bonus XP |
| **Narrative unlock** | 10 story memories revealed as you progress |
| **Seasonal events** | Weather and calendar-based events |

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| **Engine** | Godot 4.3+ |
| **Language** | GDScript |
| **Storage** | JSON files (local, offline-first) |
| **Audio** | Procedural (AudioStreamGenerator — no audio files needed) |
| **Graphics** | Procedural (all UI drawn in code — no sprite assets needed) |
| **Platform** | Android / iOS / Web |

## 📁 Project Structure

```
echoes-of-memory/
├── project.godot              # Godot project configuration
├── data/
│   ├── emotions.json          # 8 emotion type definitions
│   ├── memories.json          # 10 narrative memories
│   └── sanctuary_items.json   # Sanctuary items & biome data
├── scenes/
│   ├── main_menu/             # Title screen
│   ├── game/                  # Main gameplay scene
│   ├── sanctuary/             # Garden/sanctuary view
│   ├── collection/            # Emotion fragment gallery
│   └── settings/              # Options & preferences
├── scripts/
│   ├── global/                # Autoload singletons
│   │   ├── save_manager.gd    # JSON save/load system
│   │   ├── game_manager.gd    # Game state & progression
│   │   ├── audio_manager.gd   # Procedural audio generation
│   │   └── scene_manager.gd   # Animated scene transitions
│   ├── game/                  # Gameplay scripts
│   │   ├── sequence_generator.gd
│   │   ├── memory_node.gd
│   │   ├── echo_system.gd
│   │   ├── score_system.gd
│   │   └── game_scene.gd
│   ├── sanctuary/             # Garden scripts
│   │   ├── sanctuary_manager.gd
│   │   ├── garden_element.gd
│   │   ├── idle_growth.gd
│   │   └── sanctuary_scene.gd
│   ├── collection/            # Collection scripts
│   │   ├── emotion_fragment.gd
│   │   ├── collection_manager.gd
│   │   └── collection_scene.gd
│   └── ui/                    # UI scripts
│       ├── main_menu.gd
│       ├── settings_scene.gd
│       ├── hud.gd
│       └── share_panel.gd
└── .github/
    └── workflows/
        └── ci.yml             # GitHub Actions CI
```

## 🚀 Getting Started

### Prerequisites

- [Godot 4.3+](https://godotengine.org/download) (Standard or .NET version)
- Android SDK (for Android export) or Xcode (for iOS export)

### Running the Project

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/echoes-of-memory.git
   cd echoes-of-memory
   ```

2. **Open in Godot:**
   - Launch Godot Editor
   - Click "Import" and select the `project.godot` file
   - Click "Import & Edit"

3. **Run the game:**
   - Press F5 or the Play button in the top-right
   - The game runs at 720×1280 (mobile portrait orientation)

### Exporting

**Android:**
1. Install Android build template: Project → Install Android Build Template
2. Configure keystore in Editor → Editor Settings → Export
3. Project → Export → Add Android → Configure → Export

**iOS:**
1. Project → Export → Add iOS → Configure bundles
2. Export Xcode project → Build with Xcode

**Web:**
1. Project → Export → Add HTML5 → Export

## 🎨 Design Philosophy

- **Zero external assets**: All graphics and audio are generated procedurally in code
- **Offline-first**: The entire game works without internet. Social features are async (share codes)
- **Mobile-native**: Touch-first design, portrait orientation, haptic feedback
- **Emotional depth**: Every mechanic ties back to the narrative of reconstructing lost memories
- **Ethical monetization**: Cosmetic battle pass + optional boosts — no pay-to-win, no dark patterns

## 📜 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

## 🙏 Credits

- **Game Design**: Inspired by Simon Says, Monument Valley, Merge Mansion, Duolingo's streak system, and the cozy gaming movement
- **Engine**: [Godot Engine](https://godotengine.org/) — free and open source
- **Audio**: Procedurally generated using AudioStreamGenerator
