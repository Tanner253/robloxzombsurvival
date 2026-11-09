# UAL retarget (Quaternius Universal Animation Library, CC0 → R15)

How the survivor's combat clips (gun aim, shot, reload, hit, fall, roll) were made. S1b now owns
melee and tool animations; this is the same path for them.

1. **Source:** Zona's `assets-src/characters/ual` Godot GLB (UAL, CC0; credited in CREDITS.md).
2. **Retarget:** `python -I tools/ual/ual_retarget.py <ual.glb> clips.json <ClipName> [<ClipName> ...]`
   (needs numpy). For each R15 part it takes the matching UAL bone's world-rotation delta from an
   R15-like rest pose (arms straightened to hang down), turns glTF +Z-forward into Roblox -Z, and
   writes each part's rotation relative to its parent part, in character space, at 15 fps. The
   hips also carry a translation scaled to the survivor's hip height.
3. **Generate data:** `python -I tools/ual/gen_ual_module.py clips.json src/shared/Data/UalClips.luau`,
   then `stylua`. Never edit `UalClips.luau` by hand.
4. **Play:** `Controllers/CombatControl.luau` (`UAL`, `UAL_PARENTS`, `ualClip`, around lines 288-440)
   reads each rig joint's frame J (from its AnimationConstraint attachments, or its Motor6D C0/C1),
   converts every character-space rotation D into the joint's frame as `J^-1 * D * J`, builds a
   KeyframeSequence, and registers it with `AnimationClipProvider:RegisterAnimationClip` (no upload,
   no asset id). A rig missing a part UAL drives gets nil and falls back to the hand-keyed spec.

UAL's clip names are listed in the GLB (e.g. `Sword_Attack`, `Punch_Jab`, `Pistol_Shoot`); the
melee ones are the place to start for 13.4.
