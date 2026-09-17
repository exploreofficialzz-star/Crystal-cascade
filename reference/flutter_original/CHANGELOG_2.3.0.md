# Crystal Cascade 2.3.0

## Cinematic event synchronization

- Made `moveVersion` the atomic trigger for the interaction director.
- Prevented rapid reaction transitions (`moved` → `matched` → `won`) from restarting and cutting off a single crystal move choreography.
- Preserved the complete anticipation → flight → landing → aftershock sequence through match and victory state changes.
- Kept puzzle state separate from presentation timing.

## Visual polish

- Improved consistency between actual crystal flight timing and scene-level effects.
- Avoided duplicate choreography restarts caused by multiple provider reactions during one move.

Flutter SDK/device build was not available in the packaging environment, so source-level validation was performed and the archive was integrity-checked.
