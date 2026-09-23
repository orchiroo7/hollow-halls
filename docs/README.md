# Hollow Halls 2.5D — web build

The browser build of [`../hollow_halls_25d`](../hollow_halls_25d). Everything in
here except this file and `vercel.json` is generated — **do not edit it by
hand**, it is overwritten on every export.

It is meant to be opened on a phone and handed to someone, so it ships with
on-screen controls: a stick, ATTACK / JUMP / DASH, and a camera bar. On a
desktop nothing changes — the keys work as they always did.

## Rebuilding it

From the game folder, with the Godot 4.7.2 web export templates installed:

```bash
godot --headless --path . --export-release "Web"
```

The preset lives in `../hollow_halls_25d/export_presets.cfg`. Two things in it
matter:

- **`variant/thread_support=false`.** The threaded build needs
  `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers, which
  rules out hosts that will not let you set headers (GitHub Pages, itch.io). The
  single-threaded build runs anywhere, and this game is boxes — it does not need
  the threads.
- **`html/head_include`.** A little CSS and JS injected into the page. It stops
  the browser stealing `Tab` (focus) and `Space` (scroll) from the game, and it
  turns off the touch gestures a browser would otherwise answer itself — pinch
  zoom, double-tap zoom, rubber-band scrolling — so a drag reaches the game
  instead of moving the page around it.

## Deploying it

Any static host works. No server, no build step, no headers required.

**Vercel** — from this folder:

```bash
npx vercel --prod
```

It opens a browser to log in the first time, then prints the URL.

**Netlify** — drag this folder onto <https://app.netlify.com/drop>.

**GitHub Pages** — commit this folder, then Settings → Pages → deploy from that
folder. Works because the build is single-threaded.

**itch.io** — zip this folder, upload, tick *This file will be played in the
browser*, and set the viewport to 1280×720.

## Size

`index.wasm` is about 40 MB, which is the Godot engine itself; the game is the
~95 KB `index.pck`. Every host above serves it compressed, so the real download
is roughly 10 MB. First load takes a few seconds on a normal connection.

## On a phone

Hold it **sideways**. In portrait the game says so and waits, because a
16:9 game squeezed into a portrait strip shows you almost nothing.

The controls only appear on a touch screen. The stick springs to wherever your
left thumb lands rather than sitting in a fixed spot, and in the free orbit a
drag on the right half of the screen swings the camera.
