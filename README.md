# Dublin Cycle Counters — Rhythm & Geography (Jan–Jun 2025)

Interactive data visualisation exploring **daily cycling rhythm** (time) and **station differences** (geography) across Dublin using publicly available cycle counter data.

[![2-minute walkthrough](https://github.com/XxAG17xX/data-visualisation-projects/blob/main/exported.png)](https://www.youtube.com/watch?v=y4HOfzA9i00)
> Click to watch a 2-minute narrated walkthrough.

---

## What this shows

The visualisation combines three coordinated views:

- **Left:** small-multiples **radial charts** showing a 24-hour cycling “rhythm” per station (hourly profile).
- **Right:** a **map bubble view** showing station intensity for the currently selected hour.
- **Bottom-right:** a **ranked bar chart** of daily totals to compare stations at a glance.

(These are implemented as a single Processing sketch with coordinated selection and filtering.)  

---

## Data

This project uses:
- `cycle-counts-1-jan-9-june-2025.csv` (cycle counts, time series)
- `dublin-city-cycle-counter-locations.csv` (station lat/lon)
- `dublin_dark_map.png` (map background)

Optional fonts:
- `Inter-Regular.ttf`
- `Inter-SemiBold.ttf`

---

## Key interactions

- **Hour selection** to see how geography changes throughout the day.
- **Station selection** that highlights the same station consistently across views.
- **Weekday vs weekend** comparison to reveal behavioural differences.
- **Normalisation toggle** to compare absolute volume vs relative patterns.

---

## Engineering / implementation notes

- Built as a **single-file Processing sketch** for clarity and reproducibility.
- Handles real-world timestamp parsing and aggregation into a consistent hourly representation.
- Uses animation for readability (bar transitions + bubble growth) and to make state changes obvious.
- Includes UI sizing/layout tuned for legibility (titles, labels, tooltips).

---

## How to run

1. Install **Processing** (Java mode).
2. Put the data + assets in the sketch `data/` folder:
   - `cycle-counts-1-jan-9-june-2025.csv`
   - `dublin-city-cycle-counter-locations.csv`
   - `dublin_dark_map.png`
   - *(optional)* `Inter-Regular.ttf`, `Inter-SemiBold.ttf`
3. Open the sketch and press **Run**.
---

## BUT WHY DO THIS?

- Turning messy, real-world civic data into a usable analytical interface.
- Utilising encodings representing in the optimal way for analysis:
  - radial = cyclical daily rhythm
  - map bubbles = geographic comparison
  - ranked bars = quick station ordering
- Coordinated multiple views (selection + filtering) like dashboard products.
- Iteration on readability and interaction design (layout, labels, tooltips, animation).

---

## Short walkthrough video

▶ https://www.youtube.com/watch?v=y4HOfzA9i00
