# 🧬 Arcane Lineage — Traits Complete Datamine

Comprehensive datamined breakdown of all **Trait Families, Tier 1 (T1) vs Tier 2 (T2) Stats, Triggers, Percentage Values, Hard Caps, and Stacking Rules** extracted directly from `ReplicatedStorage.Libraries.TraitRegistry` and `ReplicatedStorage.Libraries.ItemModifiers`.

---

## 📑 Table of Contents
1. [Trait Mechanics & Orb Overview](#1-trait-mechanics--orb-overview)
2. [🔴 Strength Trait Family](#2--strength-trait-family)
3. [🟢 Endurance Trait Family](#3--endurance-trait-family)
4. [🔵 Arcane Trait Family](#4--arcane-trait-family)
5. [🟡 Speed Trait Family](#5--speed-trait-family)
6. [🟣 Luck Trait Family](#6--luck-trait-family)
7. [Trait Removal & Reforge Costs](#7-trait-removal--reforge-costs)

---

## 1. Trait Mechanics & Orb Overview

* **Trait Orbs**: Rolled using Orb Tier 1 (T1) or Orb Tier 2 (T2) corresponding to each attribute family (`Strength Orb`, `Endurance Orb`, `Arcane Orb`, `Speed Orb`, `Luck Orb`).
* **Slot Compatibility**:
  - `Both`: Can appear on both **Artifacts** and **Gears**.
  - `Gear`: Can only roll on **Gears / Armor / Accessories**.
* **Stacking Behavior**:
  - Most traits stack additively up to their specified **Cap**.
  - Traits marked with `NoStack` only take the highest rolled value across equipped items.

---

## 2. 🔴 Strength Trait Family
*Theme Color: `#E45C54` (Crimson Red)*

| Trait Name | Allowed Slots | Trigger Type | T1 Value | T2 Value | Hard Cap / Stacking | In-Game Description |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Heavy Hand** | Both | `OnHit` | **+5%** | **+9%** | No Cap | *Skills costing 2 or more energy deal increased damage.* |
| **Riposte** | Both | `OnBlock` | **+8%** | **+14%** | **Cap: 50%** | *A successful block returns a portion of the blocked damage.* |
| **Cleave** | Both | `OnHit` | **+7%** | **+11%** | No Cap | *Deal increased damage to targets below half health (<50% HP).* |
| **Momentum** | Gear | `OnHit` | **+2% / turn** | **+4% / turn** | **Max 3 Stacks (+12%)** | *Each consecutive turn you attack, your damage rises. Caps at 3 turns.* |
| **Sunder** | Gear | `OnHit` | **-3 Flat DR** | **-5 Flat DR** | 1 Turn Duration | *Your hits reduce the target's damage reduction for one turn.* |

---

## 3. 🟢 Endurance Trait Family
*Theme Color: `#78C882` (Emerald Green)*

| Trait Name | Allowed Slots | Trigger Type | T1 Value | T2 Value | Hard Cap / Stacking | In-Game Description |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Vital** | Both | `Passive` | **+3% Max HP** | **+6% Max HP** | No Cap | *Increases your maximum health.* |
| **Convalescent** | Gear | `TurnStart` | **+2% Max HP** | **+4% Max HP** | **Cap: 20%** | *Heal a share of max health at the start of a turn in which you took no damage.* |
| **Lifebound** | Gear | `OnDamaged` | **+4% Recover** | **+7% Recover** | **Cap: 35%** | *Recover a portion of the damage you take.* |
| **Unyielding** | Both | `OnDamaged` | **-20% Damage** | **-30% Damage** | **Cap: 60%** | *The first hit you take each fight is heavily reduced.* |
| **Stalwart** | Gear | `Passive` | **+5 Flat DR** | **+8 Flat DR** | Above 50% HP | *Gain damage reduction while above half health (>50% HP).* |

---

## 4. 🔵 Arcane Trait Family
*Theme Color: `#8C82F0` (Royal Violet)*

| Trait Name | Allowed Slots | Trigger Type | T1 Value | T2 Value | Hard Cap / Stacking | In-Game Description |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Conduit** | Both | `TurnStart` | **6% Chance** | **10% Chance** | **Cap: 40%** | *Chance to gain an extra energy at the start of your turn.* |
| **Attuned** | Both | `OnHit` | **5% Chance** | **8% Chance** | **Cap: 35%** | *Chance to refund energy when you land an attack.* |
| **Channeling** | Gear | `OnBlock` | **15% Chance** | **25% Chance** | **Cap: 60%** | *A successful block has a chance to grant energy.* |
| **Resonant** | Gear | `Passive` | **-1 Energy** | **-1 Energy** | `NoStack` | *Your first skill each fight costs one less energy. Does not stack.* |
| **Overflow** | Gear | `TurnStart` | **+1 Max Energy** | **+2 Max Energy** | `NoStack` | *Increases your maximum energy. Does not stack.* |

---

## 5. 🟡 Speed Trait Family
*Theme Color: `#F0CD64` (Amber Gold)*

| Trait Name | Allowed Slots | Trigger Type | T1 Value | T2 Value | Hard Cap / Stacking | In-Game Description |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Preemptive** | Both | `Passive` | **+2 Initiative** | **+3 Initiative** | No Cap | *Increases your Initiative (turn priority).* |
| **Fleet** | Gear | `OnHit` | **+10% Damage** | **+16% Damage** | Turn 1 Only | *Deal increased damage on the opening turn of a fight.* |
| **Opportunist** | Both | `OnHit` | **+5% Damage** | **+8% Damage** | Turn Order Check | *Deal increased damage to targets that act after you.* |
| **Fleeting** | Gear | `OnDodge` | **+8% Damage** | **+14% Damage** | Next Attack | *A successful dodge makes your next attack deal increased damage.* |
| **Evasive** | Gear | `Passive` | **+12% Window** | **+20% Window** | **Cap: 40%** | *Widens your dodge QTE window.* |

---

## 6. 🟣 Luck Trait Family
*Theme Color: `#D778DC` (Amethyst Magenta)*

| Trait Name | Allowed Slots | Trigger Type | T1 Value | T2 Value | Hard Cap / Stacking | In-Game Description |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Fortunate** | Both | `Passive` | **+2% Crit Rate** | **+4% Crit Rate** | **Cap: 25%** | *Increases your critical hit chance.* |
| **Devastating** | Both | `OnCrit` | **+10% Crit Dmg** | **+16% Crit Dmg** | No Cap | *Critical hits deal additional damage.* |
| **Scavenger** | Gear | `OnKill` | **+8% Gold/Drops**| **+13% Gold/Drops**| No Cap | *Increases gold and drop chance from kills.* |
| **Windfall** | Gear | `OnKill` | **12% Chance** | **20% Chance** | **Cap: 50%** | *A kill has a chance to refund the energy you spent that turn.* |
| **Uncanny** | Gear | `OnDamaged` | **8% Chance** | **13% Chance** | **Cap: 40%** (1x/fight) | *Chance to ignore a hit entirely. Once per fight.* |

---

## 7. Trait Removal & Reforge Costs

Removing an unwanted trait from gear requires paying the Trait Destroyer NPC:

| Item Rarity | Trait Removal Fee (Gold) | Max Trait Slots Available |
| :--- | :---: | :---: |
| ⚪ **Common** | `250 Gold` | 1 Slot |
| 🟢 **Uncommon** | `650 Gold` | 1 Slot |
| 🔵 **Rare** | `1,250 Gold` | 2 Slots |
| 🟡 **Legendary** | `4,500 Gold` | 2 Slots |
| 🟣 **Epic** | `10,000 Gold` | **3 Slots (Max)** |
