# Wind device model v1

Model-only GLB, meters, Godot Y-up. No gameplay script, collision or wind particles are included. Materials are embedded.

Editable Blender source: C:/Code/UITxVNG/blend_backup/wind_charger_and_lift_v1.blend

WindCharger: Rotor is a separate pivot (rotate local Y in Godot). Charge_Lens_0..2 remain individually addressable. WindHitTarget is the intake marker.
WindLift: Platform is a separate moving root, initially at local Y=1.27m. UpperStop marker is Y=4.10m. Frame and WindOutlet stay fixed. PlatformSurface is the deck marker; WindVfxOrigin marks the outlet. Deck diameter is about3.84m; full frame height about5.32m.

The paired preview illustrates raised position; conduit and wind ribbons in that image are presentation-only geometry, not included in either GLB. The standalone lift GLB starts in the lower position.

preview_v1.png uses Blender Workbench studio lighting for a lightweight geometry/material-color check, not Godot lighting. No Godot runtime test has been performed.
