---
date: 2026-02-15
status: complete
description: Responsive vertical ControlPanel for narrow viewports
---

# Responsive vertical ControlPanel for narrow viewports

## Context

On mobile portrait, the horizontal control bar at `bottom-2 right-2` gets cut off — it's wider than the viewport. Need to switch to a vertical layout on narrow screens, positioned top-left, stacking controls top-to-bottom.

## Approach

Use Tailwind responsive classes (mobile-first) to switch layout at `sm:` breakpoint (640px):

- **Narrow (default)**: `top-2 left-2`, `flex-col`, compact vertical strip
- **Wide (`sm:`)**: `bottom-2 right-2`, `flex-row`, current horizontal bar

### File: `ui/src/ControlPanel.svelte`

#### Outer container class changes

```
Default (narrow):  absolute top-2 left-2 flex flex-col items-start gap-1 ...
sm+ (wide):        sm:top-auto sm:left-auto sm:bottom-2 sm:right-2 sm:flex-row sm:items-center sm:gap-1.5 sm:max-w-[min(36rem,calc(100vw-1rem))]
```

#### Element-level changes

| Element | Narrow | Wide (sm:) |
|---------|--------|------------|
| Middot separators | `hidden` | `sm:inline` |
| Slider (`<input range>`) | `hidden` | `sm:block sm:flex-1 sm:min-w-48` |
| Date span | Shown (still useful) | Shown |
| All buttons/selects | Stacked vertically | Inline |

#### Mobile date navigation (historical mode)

The slider is hidden on narrow, so add compact prev/next buttons visible only on mobile:

```svelte
<div class="flex items-center gap-1 sm:hidden">
  <button onclick={() => onSliderChange(Math.max(0, selectedDateIdx - 1))}>‹</button>
  <span class="text-[10px] opacity-60">{selectedDate}</span>
  <button onclick={() => onSliderChange(Math.min(histDates.length - 1, selectedDateIdx + 1))}>›</button>
</div>
```

The wide-screen date span gets `hidden sm:inline` so it only shows alongside the slider.

### Verification
- `npm run build` passes
- Dev: Chrome DevTools mobile emulation (e.g. iPhone 14) — controls stack vertically top-left
- Dev: Desktop width — controls remain horizontal bottom-right as before
