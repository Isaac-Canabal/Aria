# Aria — Mockups

Envía documentos, imágenes y archivos entre dispositivos cercanos, sin cables ni cuentas en la nube.

Static implementation of the `Aria - Mockups.dc.html` design document from
[Claude Design](https://claude.ai/design/p/8fbc370f-fe55-459c-853d-1266699e6ea0).
The gallery covers the main flow (send, receive, tracking, history, settings) on
both platforms, including success, error and empty states.

## Viewing

Open `index.html` in a browser. No build step, no dependencies, no JavaScript —
plain HTML and CSS. The only network request is the Inter webfont that the
design system imports.

## Layout

```
index.html        the gallery: 8 Android screens + 4 Windows windows
css/nocturne.css  the Nocturne design system, verbatim from the design project
css/aria.css      gallery scaffolding, device chrome, and Aria's own patterns
```

`css/nocturne.css` is a copy of the design system's source of truth
(`_ds/nocturne-b255dd8f-91e4-4856-a9f5-6ab06f0ddc97/styles.css`). Keep it
byte-identical so a re-sync from the design project stays a clean diff — put
anything Aria-specific in `css/aria.css` instead.

## Notes on the port

The source document is a Claude Design canvas file: it relies on `<x-dc>`,
`<helmet>` and `<x-import>` custom elements provided by the canvas runtime
(`support.js`), and mounts each phone screen inside the `AndroidDevice` React
component from `android-frame.jsx`. None of that runtime is needed to render the
mockups, so this port drops it:

- **Android frame** — `android-frame.jsx`'s bezel, Material 3 status bar and
  gesture nav are reimplemented as the `.android` CSS component. The status-bar
  clock, camera punch-hole and nav pill are drawn with pseudo-elements, so each
  screen only carries its own content. The frame is used with `dark`, no app bar
  and no keyboard, so those parts of the component weren't needed.
- **Design system bundle** — `_ds_bundle.js` exports no components; only
  `styles.css` carries anything.
- **Icons** — the document repeats the same inline SVGs across screens; here they
  live in one sprite at the top of `index.html` and are referenced with `<use>`.
  Stroke weight varies per placement, so it rides a `--sw` custom property.
- **Inline styles** — folded into named classes in `css/aria.css`. Values that
  genuinely vary per instance (badge size, stack gap, progress width) stay inline
  as custom properties.

One deliberate addition: the "Esperando conexión…" dot on the Recibir screen
pulses, which a static mockup couldn't show.
