# Mount Pre-Check Flowchart Redesign

**Date:** 2026-03-15
**Status:** Approved

## Problem

The current `CombatMountPreCheckView` uses two separate screens for the Galopp confirmation and Reiten check. This feels disconnected — users navigate between screens for what is logically a two-step prerequisite flow.

## Design

Combine both steps into a single vertical flowchart view.

### Layout (top to bottom)

- **Header bar** — back chevron, "Reiten Check" title, X dismiss (unchanged)
- **Flowchart area** — centered vertically in remaining space:
  - **Step 1 node** — Galopp confirmation (horse icon + question + Yes/No buttons)
  - **Connector** — `chevron.down.circle.fill` SF Symbol
  - **Step 2 node** — Reiten check (dice icon + roll button or manual confirm)

### States

**Initial:**
- Step 1: full opacity, interactive
- Connector: muted color
- Step 2: 0.4 opacity, non-interactive

**After Galopp confirmed (Yes):**
- Step 1 collapses (animated) to compact confirmed state: `[✓ Galopp]` with green tint
- Connector: accent colored
- Step 2: animates to full opacity, becomes interactive

**After Galopp denied (No):**
- Immediately returns to `.attackChoice` (no failure state shown)

**After Reiten result:**
- Success: green checkmark + "Reiten check passed!" + Continue button → `onSuccess`
- Failure: red xmark + "Reiten check failed!" + Back button → `.attackChoice`

### Step 2 variants

- **Hero has Reiten talent:** "Roll Reiten Check" button opens `TalentProbeModal` overlay. Result displays inline on the node.
- **Hero lacks Reiten talent:** "Did the Reiten check succeed?" with Yes/No buttons.

### Visual details

- Connector icon: `chevron.down.circle.fill` in accent color
- All transitions use `DSAAnimation.standard`
- Neo-Brutalist style maintained (bold borders, filled backgrounds)
- Step 2 inactive state: 0.4 opacity

## Scope

Only `CombatMountPreCheckView` is affected. No changes to `CombatStep` enum, `CombatMountDamageView`, or any other combat views.
