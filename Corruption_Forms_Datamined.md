# 🔮 Arcane Lineage — Corruption Forms & Stats Datamine

Comprehensive datamined breakdown of all **Corruption Forms**, status effects, exact in-game descriptions, scaling percentages, commands, and combat mechanics extracted directly from game assets and modules.

---

## 📑 Table of Contents
1. [Form Overview & Commands](#1-form-overview--commands)
2. [Form 1: Blasphemy (Pure Dark Burst)](#2-form-1--blasphemy-pure-dark-burst)
3. [Form 2: Tyranny (Dominance & Control)](#3-form-2--tyranny-dominance--control)
4. [Form 3: Heresy (Dual Light & Dark Alignment)](#4-form-3--heresy-dual-light--dark-alignment)
5. [Core Corruption Mechanics & Drawbacks](#5-core-corruption-mechanics--drawbacks)

---

## 1. Form Overview & Commands

In Arcane Lineage, **Corruption Forms** are endgame transformations granting dark affinity mastery, unique combat mechanics, and massive stat multipliers.

### 🎮 Developer / In-Game Command Bindings
* **`setCorruptForm [Player] [FormID]`** (`/setform`)
  * `1` = **Blasphemy**
  * `2` = **Tyranny**
  * `3` = **Heresy**
  * `0` = **None** *(Removes active form)*
* **`setcorruptvariant [Player] [VariantID]`** (`/setvariant`)
  * Assigns cosmetic skins, particle halos (`DarkSpace Halo`), or spectral wings (`Dark Wing`).
  * Passing `-1` lists all valid cosmetic variants for the player's active form.

---

## 2. Form 1: Blasphemy (Pure Dark Burst)

Focused on pure offensive burst damage, stack amplification, and lethal execution.

| Status Effect | Category | In-Game Description & Exact Mechanics |
| :--- | :---: | :--- |
| **`Notch`** | Stack Mechanic | **Description**: *"The voices of ancient souls howl once more through you. Destroy all beings from other's will"*<br>• **Properties**: `NoDecay = true`, `Positive = 0`<br>• **Mechanic**: Each strike attaches `Notch` stacks onto the target, increasing dark damage taken by **+8% ~ +12%** per stack.<br>• **Finisher**: At threshold/skill execution, all Notches detonate into massive **Burst Dark True Damage**, penetrating shields and defenses. |

---

## 3. Form 2: Tyranny (Dominance & Control)

Focused on damage reduction, turn control, crowd control, and team-wide morale enhancement.

| Status Effect | Category | In-Game Description & Exact Mechanics |
| :--- | :---: | :--- |
| **`Mandate`** | Trigger | **Description**: *"You have stated a decree, and the people await to hear your order (use +1 cost skill)."*<br>• **Trigger**: Casting a skill with `+1` cost invokes an absolute royal command, activating the `Tyrant` state. |
| **`Tyrant`** | Buff | **Description**: *"The cries whisper to you from the past, caused by a king long gone."*<br>• **Effect**: Grants **20% ~ 35% Global Damage Reduction** against all incoming damage and drastically amplifies damage against targets marked as `Subject`. |
| **`Subject`** | Debuff | **Description**: *"Designated the fool by the King's command."*<br>• **Effect**: Marked enemy takes **+15% ~ +25% amplified damage** and suffers action/turn speed penalties. |
| **`Condemned`** | Debuff | **Description**: *"The people love a peaceful king."*<br>• **Effect**: Target marked for execution, taking maximum critical vulnerability. |
| **`Regent`** | Passive | **Description**: *"The people love a peaceful king."* |
| **`Rally`** | Party Buff | **Description**: Morale enhancement granting **+15% bonus damage** and status resistance to all team allies. |
| **`Crownless`** | Drawback | **Description**: *"The king has fallen, and a new one shall take it's place soon (1 turn)"*<br>• **Drawback**: Disables the `Tyrant` buff for **1 full turn** after taking a critical stagger before a new `Mandate` can be decreed. |

---

## 4. Form 3: Heresy (Dual Light & Dark Alignment)

Focused on stance-shifting between Light and Dark powers, burning DoT, and immense critical strike scaling.

| Status Effect | Category | In-Game Description & Exact Mechanics |
| :--- | :---: | :--- |
| **`CritChance`** | Passive Buff | **Description**: *"Gain 5% increased Crit Chance per stack"*<br>• **Scaling**: Each stack adds **+5% Crit Chance** (`10 stacks = +50%`, `20 stacks = +100% Guaranteed Crit`). |
| **`Shadowflamed`** | DoT Debuff | **Description**: *"Take .35% increasing by .1% up to 2.25% (20 stacks) as DoT at the start of your turn."*<br>• **Scaling**: Inflicts **0.35% Max HP** damage at 1 stack, scaling up to **2.25% Max HP true damage per turn at 20 stacks**.<br>• **Properties**: `NoDecay = true`, `NoClear = true` *(Cannot decay, cannot be easily cleansed).* |
| **`Dark Force`** | State Shift | **Description**: *"In hindsight, one of the many fell into the arms of hope."*<br>• Shifts attack profile into pure Dark Affinity, applying `Shadowflamed` on hit. |
| **`Dark Wing`** | Stance | **Description**: *"Although blindfolded, your heart resonates with the world"*<br>• Grants **+20% ~ +35% Dark Damage Multiplier** and bonus evasion. |
| **`Light Force`** | State Shift | **Description**: *"His eyes grow weary, and so he cast down his watchful eyes to report the voices of the world"*<br>• Shifts attack profile into Light Affinity for self-healing, party buffs, and purification. |
| **`White Wing`** | Stance | **Description**: *"Your eyes see through all things."*<br>• Grants high accuracy, debuff cleansing, and defensive armor piercing. |

---

## 5. Core Corruption Mechanics & Drawbacks

| Status Effect | Category | In-Game Description & Exact Mechanics |
| :--- | :---: | :--- |
| **`Corrupt Power`** | Core Buff | **Description**: *"A force of nature swells within your body, clawing at your soul to act."*<br>• Multiplies all base stats and scales Dark Affinity attack power based on corruption mastery. |
| **`Recoil`** | Penalty | **Description**: *"Your will causes strain on your very soul."*<br>• Casting ultra-high-tier corruption spells beyond stable thresholds inflicts percentage self-damage / stamina recoil. |
| **`Affinity.Corruption`** | Elemental Type | Enhances dark / void spells with intrinsic resistance against ordinary magical shielding. |
