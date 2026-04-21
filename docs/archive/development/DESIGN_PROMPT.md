# Google Stitch Design Prompt — MemoryMonitor App

## Project Overview

Design a premium native macOS menu bar application called **MemoryMonitor** — a real-time system health dashboard that lives in the menu bar and provides a beautiful, glanceable overview of a MacBook's health. The app should feel like it belongs in macOS — polished, minimal, and information-dense without being overwhelming.

---

## App Type & Behavior

- **Platform:** macOS 14+ (Sonoma / Sequoia)
- **Type:** Menu bar app + expandable dashboard window
- **Always-on:** Lives in the menu bar with a live-updating icon showing memory percentage
- **Interaction:** Click menu bar icon → popover with quick stats; click "Open Dashboard" → full window

---

## Current Features (to design around)

### 1. Menu Bar Icon
- Shows current memory usage percentage (e.g., "68%")
- Color-coded: green (< 75%), orange (75-85%), red (> 85%)
- Small CPU/memorychip icon next to the percentage

### 2. Menu Bar Popover (click to open)
When the user clicks the menu bar icon, a compact popover appears showing:

**Header:**
- Circular health score gauge (letter grade A-F with score out of 100)
- Battery percentage with icon
- Current time

**Quick Stats Row (3 cards side by side):**
- Memory: percentage + "X.X GB" used
- CPU: percentage + core count
- Disk: percentage + "X GB free"

**Top 3 Memory Hogs:**
- App icon + app name + memory usage in MB

**Network Speed:**
- Download speed (MB/s) + Upload speed (MB/s)

**Recommendations (1-2 tips):**
- Smart tips based on current system state (e.g., "Memory is high. Close unused apps.")

**Action Buttons:**
- "Open Dashboard" — opens full window
- "Settings..." — opens preferences
- "Quit" — exits app

### 3. Full Dashboard Window
A large, multi-tab window with a sidebar navigation:

**Sidebar (left):**
- Overview
- Memory
- CPU
- Disk
- Network
- Processes
- Guard (auto-kill runaway processes)

**Top Bar:**
- Health score circle (A-F grade)
- Quick stat pills (Memory %, CPU %, Disk %, Thermal state)
- Refresh button
- "Kill Top" button (terminates highest memory process)

**Tab Content Areas:**

#### Overview Tab
- Health Score card with recommendations
- Memory breakdown bar (colored segments: App Memory, Wired, Compressed, Cached, Free)
- CPU gauges (User, System, Idle)
- Disk usage gauge
- Network speeds
- Top processes table

#### Memory Tab
- Large circular gauge (animated arc)
- Detailed breakdown (Used, Free, Cached, Compressed, Wired, Swap)
- Memory breakdown bar chart
- History line chart (memory % over time)

#### CPU Tab
- 3 small circular gauges (User, System, Idle)
- CPU history line chart
- Top CPU processes list

#### Disk Tab
- Large circular gauge
- Storage bar (used/free)
- List of all mounted volumes

#### Network Tab
- Download/Upload speed cards
- Live line chart
- Battery & thermal state section

#### Processes Tab
- Table with columns: Icon, Process Name, Memory, Usage %, Kill button
- Sortable by memory usage

#### Guard Tab
- Enable/disable toggle
- Memory threshold slider
- CPU threshold slider
- Currently elevated processes
- Kill history log
- Whitelisted processes

### 4. Settings Window
- 4-tab sidebar: General, Alerts, Display, Guard
- General: Refresh interval, menu bar display mode, launch at login
- Alert thresholds (75%, 85%, 95%) with toggles
- Feature toggles (CPU, Disk, Network, Battery)
- Auto-kill configuration

---

## Design Direction

### Color Palette
- **Primary accent:** System blue (#007AFF)
- **Memory:** Blue gradient
- **CPU:** Purple gradient
- **Disk:** Orange gradient
- **Network:** Cyan gradient
- **Healthy:** Green (#34C759)
- **Warning:** Orange (#FF9500)
- **Critical:** Red (#FF3B30)
- **Background:** Adaptive (follows macOS light/dark mode)
- **Cards:** Slight translucent blur (like macOS Control Center)

### Typography
- SF Pro / SF Rounded for numbers and labels
- Monospaced digits for live-updating values
- Clear hierarchy: large titles, medium stats, small labels

### Visual Style
- **Inspired by:** macOS Control Center, Activity Monitor, iStat Menus
- **Feel:** Clean, data-rich, Apple-native
- **Gauges:** Smooth animated arcs with gradient strokes
- **Cards:** Subtle rounded corners, soft shadows, translucent backgrounds
- **Charts:** Smooth curves (not jagged), gradient fills under lines
- **Icons:** SF Symbols (Apple's native icon set)
- **Transitions:** Smooth 0.3s ease animations on tab switches and data updates

### Key Design Principles
1. **Glanceable** — Most important info visible in 1 second
2. **Native** — Should feel like an Apple-built app
3. **Progressive disclosure** — Simple overview → detailed breakdown
4. **Color-coded** — Green/orange/red instantly communicates status
5. **Live** — All numbers update in real-time with smooth animations
6. **Compact** — Menu bar popover fits in a small window without scrolling

---

## Specific UI Elements to Design

### 1. Health Score Gauge (Hero Element)
- Large circle (~100px) with thick stroke (10px)
- Animated arc filling based on score (0-100)
- Gradient stroke: green → yellow → orange → red
- Center shows letter grade (A/B/C/D/F) in bold SF Rounded
- Score number below in smaller text

### 2. Memory Gauge
- Circular progress ring (~140px)
- Animated arc with gradient (blue → purple)
- Center: large percentage number + "used" label
- Smooth animation on value change

### 3. Breakdown Bar
- Horizontal bar showing memory categories as colored segments
- Labels below with GB values
- Colors: Blue (App), Purple (Wired), Cyan (Compressed), Gray (Cached), Green (Free)

### 4. Quick Stat Pills
- Small capsule-shaped badges
- Icon + percentage text
- Background tinted with the stat's color

### 5. Process Table
- Clean table rows with app icon, name, memory bar, percentage
- Alternating row colors (subtle)
- Hover state with red kill button appearing

### 6. Line Charts
- Smooth catmull-rom interpolation
- Gradient fill under the line
- Thin grid lines
- Time axis at bottom, value axis on left

---

## Deliverables Expected

1. **Menu bar popover design** (compact, ~320px wide)
2. **Full dashboard window** (all 7 tabs)
3. **Settings window** (4 tabs)
4. **Component library** (gauges, pills, cards, tables)
5. **Dark mode + Light mode** versions
6. **Animated states** (gauges filling, charts updating)
7. **Responsive states** (popover, medium window, large window)

---

## Reference Apps (for inspiration)

- **Activity Monitor** (built-in macOS) — process tables, CPU/memory graphs
- **iStat Menus** — menu bar monitoring, beautiful gauges
- **macOS Control Center** — popover style, card layouts
- **CleanMyMac** — health scores, storage visualization
- **Macs Fan Control** — temperature gauges, thermal visualization

---

## Technical Constraints

- Must work in macOS menu bar popover (small, no scroll ideally)
- Window uses SwiftUI native components
- Charts use Swift Charts framework
- Icons use SF Symbols exclusively
- Must support both light and dark appearance
- Must work on MacBook displays (1440x900 to 3024x1964)
