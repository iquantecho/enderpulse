# Changelog

All notable changes to EnderPulse are documented here.

## 1.1.0 - 2026-08-22

- Initial public release.
- Add spectrum, mirrored pulse, and radial orbit visualizations.
- Add four palettes and controls for bands, sensitivity, smoothing, glow,
  background opacity, and silence fade delay.
- Add Cava dependency gating and bounded process recovery.
- Add DMS 1.5 desktop-widget and per-instance settings support.
- Cap Cava input and Canvas rendering near 30 FPS and coalesce pending frames.
- Reuse fixed band buffers and replace per-band shadow blur with a cheaper glow.
- Suspend audio/render work while hidden or silent and harden restart cleanup.
- Add regression checks for throttling, configuration, and process lifecycle.
- Register EnderPulse as a composite DankBar and desktop plugin.
- Add a compact Unicode Braille spectrum for horizontal and vertical bars.
- Add system-output, default-microphone, detected-source, and custom-source audio targeting.
- Add independent DankBar variants so output and microphone visualizers can run side by side.
- Fix DankBar pills receiving zero height and keep compact Braille responsive during Cava ramp-up.
- Seed output and microphone choices automatically and deduplicate delayed variant creation.
- Clarify that widgets are placed only from DankBar settings; plugin settings manage optional source profiles.
- Store generated Cava configurations atomically in Quickshell's per-shell cache
  and restrict them to the owning user.
- Require DMS 1.5.1 for the injected popout service used by the DankBar widget.
- Replace synthetic performance checks with executable parser and structured metadata tests.
- Disable microphone auto-gain and gate low ambient input without reducing
  louder bar heights; system-output auto-sensitivity is unchanged.
