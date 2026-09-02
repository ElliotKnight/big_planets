# 🌇 GOODLIFE

A habit tracker where your good days literally build a world.

GOODLIFE is a single-file web app: tick off your daily goals on a neon grid, and watch a floating island in space grow — skyscrapers gain glowing floors, trees blossom, sheep have lambs, ducks arrive on ponds, and locals wander over to the pub. Log how each day felt and the island's weather follows your mood, from bright sunshine to full thunderstorms.

## ✨ Features

- **Neon habit grid** — goals as rows, days as columns. Ticks come with pop animations, particle bursts, and a rising Web Audio "plink" combo when you chain them. Streak badges and monthly/all-time stats included.
- **Your world** — a 3D floating island (Three.js) as the centrepiece. Every tick evolves a goal's object one stage (7 stages max), then overflows onto a new tile:
  - **Objects**: skyscraper, tree, house, flower patch, sheep, church, pond, bar — with style variants (Steel/Glass/Brick towers, Oak/Pine/Cherry trees, Cottage/Seaside/Brick houses).
  - **You choose** each new object's type, style, facing direction, and tile via the add-goal picker.
- **A living island** — butterflies orbit the trees, lambs roam and visit the neighbours, residents leave their houses to read under a tree or grab a pint at the bar, ducks paddle on fully-grown ponds, and a helicopter lands on the tallest tower's helipad.
- **Mood-driven weather** — mark each day 😄 / 😐 / 😞. The average of your latest 10 entries drives the sky: dull clouds, light rain, or full storms with lightning on the low end; clear bright sun on the high end. Max out the happiness and **euphoria mode** kicks in — the grass blooms into flowers (butterflies land on them), the planets turn into pulsing disco balls, shooting stars become hearts, and a rooftop party starts.
- **Set in space** — starfield, nebulae, alien planets and shooting stars all around the island.

## 🚀 Getting started

No build, no install, no server:

1. Clone the repo.
2. Open `index.html` in a modern browser.

That's it. The habit grid works fully offline; the 3D world needs an internet connection (Three.js is loaded from a CDN).

## 💾 Your data

- Progress auto-saves to your browser's `localStorage` on every change — use the same browser to keep your world growing.
- **Export / Import** buttons in the toolbar write/read a JSON backup file, so you can move between browsers or keep snapshots.

## 🛠 Tech

- One self-contained `index.html`: vanilla JS + CSS, no framework, no build step.
- 3D rendered with [Three.js](https://threejs.org/) (r160, via CDN import map).
- Sound via the Web Audio API — no audio assets.
