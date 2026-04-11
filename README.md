# RememberMyRare

A World of Warcraft (Retail) addon that automatically marks both your **minimap** and **world map** with skull pins wherever you have killed a rare mob — persisting across sessions, days, and all characters on your account.

Never forget where you found that rare again.

---

## Features

- Automatically detects rare and rare-elite kills — no manual interaction needed
- Pins appear on both the **minimap** and the **world map**
- Pins persist indefinitely across sessions (5 minutes ago or 5 days ago — it remembers)
- **Account-wide** — kills on any character are visible to all your alts
- Hover a pin to see the mob name, kill date, and kill count
- `/rmr list` to review all tracked kills in chat

---

## Installation

1. Download or clone this repo
2. Copy the folder into your WoW addons directory and name it exactly `RememberMyRare`:

```
World of Warcraft\_retail_\Interface\AddOns\RememberMyRare\
```

3. Launch WoW (or `/reload` if already in-game)
4. Enable the addon in the **AddOns** menu on the character select screen
5. Type `/rmr` in chat to confirm it loaded

---

## Quick Start

1. Find and kill any rare mob (silver dragon portrait border)
2. A chat message confirms: `RememberMyRare: Recorded <name> kill.`
3. Open the world map (`M`) — a skull pin marks the kill location
4. Check your minimap — the pin appears there too, floating to the edge when out of range
5. Hover a pin to see details

That's it. No setup required.

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/rmr` | Show how many rare kills are tracked |
| `/rmr list` | List all kills with name, date, map, and kill count |
| `/rmr clear` | Begin wipe of all saved kills (requires confirmation) |
| `/rmr confirm` | Confirm a pending `/rmr clear` |

---

## Map Pins

**World map** — pins appear on the zone map where you killed the rare, and also on the continent map so you can see at a glance which zones you've cleared. Open with `M`.

**Minimap** — pins appear when you are in the same zone as the kill. When the location is off-screen the pin floats to the nearest edge of the minimap so you always know which direction to head.

**Tooltip** — hover any pin to see:
- Mob name (in rare gold)
- Date and time of kill
- Kill count (if killed more than once)

---

## Cross-Session Persistence

Kill data is stored in WoW's **SavedVariables** system (`RMR_DB`), which is written to disk whenever you log out or reload your UI. Pins survive:

- UI reloads (`/reload`)
- Logging out and back in
- Game patches and restarts
- Switching characters (data is account-wide)

There is no expiry — pins stay until you explicitly run `/rmr clear`.

---

## Troubleshooting

**Pins not appearing after a kill**
- Make sure you actually targeted the rare before killing it — the addon uses your target to detect classification. AoE kills on rares you never targeted will not be recorded.
- Run `/console scriptErrors 1` to surface any Lua errors in chat.

**No chat confirmation message after kill**
- The mob may not be classified as `rare` or `rareelite` by Blizzard. Some world bosses or event mobs use different classifications and won't be detected.

**Pins from a previous session are gone**
- This should not happen — if it does, check that the `RememberMyRare` folder name exactly matches the `.toc` filename. A mismatch prevents SavedVariables from loading.

**Want to start fresh in a new zone**
- Pins persist indefinitely by design. Use `/rmr clear` → `/rmr confirm` to wipe all data.

---

## Development

### Run unit tests

Requires Lua 5.4 and LuaUnit (installed via LuaRocks):

```powershell
$env:LUA_PATH = "C:\Users\kpasc\.luarocks\share\lua\5.4\?.lua;;"
& "C:\Users\kpasc\AppData\Local\Programs\Lua\bin\lua.exe" tests/run_tests.lua -v
```

Or if you added the profile function:

```powershell
rmr-test
```

### Deploy to WoW for in-game testing

```powershell
Copy-Item "C:\dev\remember-my-rare\*.lua" "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\RememberMyRare\" -Force
```

Then `/reload` in-game.

### Useful in-game debug commands

| Command | Purpose |
|---------|---------|
| `/console scriptErrors 1` | Show Lua errors in chat |
| `/rmr list` | Verify kills are being recorded |
| `/reload` | Reload UI without logging out |
| `/framestack` | Identify UI frames under your cursor |
