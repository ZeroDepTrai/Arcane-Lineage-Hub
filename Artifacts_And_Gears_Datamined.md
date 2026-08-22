# 🛡️ Arcane Lineage — Artifacts & Gears Complete Datamine

Comprehensive datamined breakdown of all **Gears, Artifacts, Tier Scaling (T1–T6), Rarity Stat Budgets, Gold Fees, and Special Effects** extracted directly from `ReplicatedStorage.ItemRegistry`, `ReplicatedStorage.Libraries.ItemModifiers`, and `ReplicatedStorage.ItemNames`.

---

## 📑 Table of Contents
1. [Tier & Rarity Stat Scaling System](#1-tier--rarity-stat-scaling-system)
2. [Identification & Trait Removal Economy](#2-identification--trait-removal-economy)
3. [All Artifacts Breakdown (Passives & Actives)](#3-all-artifacts-breakdown-passives--actives)
4. [All Gears & Accessories Breakdown](#4-all-gears--accessories-breakdown)

---

## 1. Tier & Rarity Stat Scaling System

Equipment in Arcane Lineage rolls both **Rarity** (`Common` -> `Uncommon` -> `Rare` -> `Legendary` -> `Epic`) and **Tier** (`[T1]` to `[T6]`).

### 📊 Base Stat Budget by Rarity (Primary Stats Pool: Strength, Arcane, Endurance, Speed, Luck)

| Rarity | Single Stat Budget | Dual Stat Budget | Trait Slots | Rarity Color (Hex) |
| :--- | :---: | :---: | :---: | :--- |
| ⚪ **Common** | **+1** | **+2** | 0–1 Slots | `#C8C8C8` (Grey) |
| 🟢 **Uncommon** | **+2** | **+3** | 1 Slot | `#78D278` (Green) |
| 🔵 **Rare** | **+3** | **+4** | 1–2 Slots | `#5AA0F0` (Blue) |
| 🟡 **Legendary** | **+4** | **+5** | 2 Slots | `#F0BE50` (Gold) |
| 🟣 **Epic** | **+5** | **+6** | 2–3 Slots | `#BE6EF0` (Purple) |

---

### 📈 Tier Multipliers & Shape Scaling (`[T1]` – `[T6]`)

| Tier | Bonus Stat Points | Max Trait Slots | Tier Overflow Chance |
| :---: | :---: | :---: | :---: |
| **`[T1]`** | Base Rarity Stats (+0 Bonus) | 1 Slot | Base |
| **`[T2]`** | **+1 ~ +2** Additional Stat Points | 2 Slots | Low |
| **`[T3]`** | **+3 ~ +4** Additional Stat Points | 2 Slots | Moderate |
| **`[T4]`** | **+5 ~ +6** Additional Stat Points | 2 Slots | High |
| **`[T5]`** | **+7 ~ +8** Additional Stat Points | 2 Slots | Very High |
| **`[T6]`** *(Max Tier)* | **+9 ~ +12** Additional Stat Points | **3 Slots (Max)** | Pinnacle Roll |

* **Artifact Multiplier**: Artifacts inherit `ARTIFACT_BASE_MULTIPLIER = 1.5x` base stats and guarantee unique, game-changing active/passive skills.

---

## 2. Identification & Trait Removal Economy

| Rarity | Identification Fee (Gold) | Trait Removal / Reset Fee (Gold) |
| :--- | :---: | :---: |
| ⚪ **Common** | `50 Gold` | `250 Gold` |
| 🟢 **Uncommon** | `100 Gold` | `650 Gold` |
| 🔵 **Rare** | `200 Gold` | `1,250 Gold` |
| 🟡 **Legendary** | `450 Gold` | `4,500 Gold` |
| 🟣 **Epic** | `1,000 Gold` | `10,000 Gold` |

---

## 3. All Artifacts Breakdown (Passives & Actives)

| ID | Artifact Name | Category | Official In-Game Description & Special Effect |
| :---: | :--- | :---: | :--- |
| **6** | **Ancient Insignia** | Artifact | *A triangular tablet with three geometric inscriptions on it.*<br>• Grants ancient runic power and reduces spell mana costs. |
| **12** | **Arkhaia's Visage** | Artifact | *A shadowed mask with the seven-dot sigil Arkhaia pledged his life to Thanasius for. You hear the mask calling your name…*<br>• Grants Dark Affinity scaling and lifesteal on execution. |
| **35** | **Celestial Emblem** | Artifact | *Necklace of Power!*<br>• Grants immense all-around primary stat boosts across all attributes. |
| **36** | **Chaos Orb** | Artifact | *An orb of infinitely pulsing darkness, no doubt born from something sinister from the corruption.*<br>• Infuses dark chaos into skills; high-risk burst amplification. |
| **58** | **Darksigil** | Artifact | *An orb of infinitely pulsing darkness, no doubt born from something sinister from the corruption.*<br>• Enhances dark magic damage and corruption build-up. |
| **113 / 114** | **Heaven's Authority** | Artifact | *An ethereal artifact signifying its bearer has been granted permission to summon sheea warriors in times of need.*<br>• **Active**: Summons ethereal Sheea warriors to assist in combat. |
| **170** | **Metrom's Amulet** | Artifact | *A broken necklace that constantly pulses out a dark energy, as you hold it you feel it pull towards your neck.*<br>• High-tier arcane spell enhancement. |
| **179** | **Narthana's Sigil** | Artifact | *A metallic ankh that wields incredible restorative power, a piece of a greater tool once wielded by the god Narthana.*<br>• Drastically multiplies healing received and passive regeneration per turn. |
| **184** | **Paranoxian Crux** | Artifact | *A strange, crystalline object that exudes frigid energy. Runic writing is carved on all sides.*<br>• Unlocks cryogenic / frost ascension bonuses. |
| **195** | **Reality Watch** | Artifact | *A small handwatch that ticks with mysterious power. Past and future memories meld together.*<br>• Manipulates turn order and lowers skill cooldowns by 1 full turn. |
| **222** | **Shifting Hourglass** | Artifact | *An esoteric hourglass containing the torrid, adapting sands of the desert.*<br>• Adapts defensive resistance to the last damage element taken. |
| **223** | **Skyward Totem** | Artifact | *A cursed decrypt totem that appears to radiate cursed energy when near higher beings. (3 uses).*<br>• Used to summon higher celestial / boss entities. |
| **224** | **Darkened Totem** | Artifact | *An effigy of otherworldly whispering. Grasped by the end of all fate.*<br>• Summons endgame corruption encounters. |
| **225** | **Moonlit Charm** | Artifact | *You can't help but feel like you are being watched from beyond the sky while holding this.*<br>• Nighttime / Lunar combat buff. |
| **226** | **Starpoint Charm** | Artifact | *Sometimes it lets off a warmth, only for the feeling to vanish in an instant.*<br>• Cosmic affinity bonus and luck booster. |
| **237** | **Stellian Core** | Artifact | *A gem that radiates incredible power, just holding it fills your mind with incomprehensible noises.*<br>• Endgame raw magical power surge. |

---

## 4. All Gears & Accessories Breakdown

| ID | Gear Name | Type | In-Game Description & Combat Mechanics |
| :---: | :--- | :---: | :--- |
| **1** | **7 Leafed Everthistle** | Gear | *Raphion themselves blessed you!* — Extreme luck boost and item drop multiplier. |
| **7** | **Arbusta Tear** | Gear | *The smell of this object makes monsters attack you more!* — Taunt gear, increases monster aggro. |
| **13** | **Aspect of Maladaptation** | Gear | *A mass of Thorian’s flesh that pulsates in tandem with your heartbeat.* — Morphing stat buffs per turn. |
| **17** | **Band Of Crushing Force** | Gear | *With this, you feel like you can do extra damage if the opponent guards.* — Guard-break / Shield penetration damage. |
| **25** | **Blazing Brand** | Gear | *Your summon is now fire incarnate.* — Imbues summon attacks with Fire DoT. |
| **26** | **Blazing Perforator** | Gear | *The superheated fang of Yar’thul.* — Grants bonus burning piercing damage. |
| **37** | **Coagulated Finger Nail** | Gear | *A monster's nail..* — Bleed infliction on basic attacks. |
| **44** | **Crystal Sphere** | Gear | *This sphere can make your critical attacks more consistent!* — **+10% ~ +20% Critical Strike Chance**. |
| **45** | **Crystalized Star** | Gear | *A shining fragment of a star.* — Prolongs buff durations by +1 turn. |
| **48** | **Cursed Brand** | Gear | *Even when the Rot has taken over them, they still love their master.* — Imbues summons with Rot / Dark attacks. |
| **59** | **DeathBeak Dagger** | Gear | *You stare into the twitching eye of this makeshift dagger.* — Critical strike execution damage. |
| **60** | **Delicate Purse** | Gear | *For such a small bag, it can hold a lot of coin…* — **+25% Gold earned from fights**. |
| **62** | **Desert Escutcheon** | Gear | *A gilded shield bearing Ramizca’s emblem, worn and beaten.* — **+15% Physical & Fire Resistance**. |
| **63** | **Divine Promise** | Gear | *A promise that will always remain.* — Cheat death / Revive with 20% HP once per battle. |
| **64** | **Dragon Memoir** | Gear | *Brittle dragon bones that easily stick into opponents.* — Thorns / Counter-damage on hit. |
| **73** | **Dread Fang** | Gear | *Remains just as sharp.* — Armor penetration. |
| **75** | **Dust Devil's Eye** | Gear | *Essence gathered into an Elemental.* — Sand / Earth elemental damage boost. |
| **76** | **Dust Storm** | Gear | *Be one within the sand. You feel less tangible.* — **+15% Evasion / Dodge rate**. |
| **79** | **Elemental Infuser** | Gear | *Earrings that infuse your attacks.* — Infuses physical attacks with active element. |
| **80** | **Elementary Resonance** | Gear | *Extremely bright flashing crystals.* — Multi-element burst resonance. |
| **85** | **Eroded Blade** | Gear | *A cursed blade with a dull edge.* — True damage bypassing armor. |
| **86** | **Everbeating Drums** | Gear | *A drum that never stops beating.* — Soundwave AoE splash damage to adjacent enemies. |
| **88** | **Expedite Anklet** | Gear | *Ivory-white anklet with wings.* — **Drastically decreases dash cooldown out of combat**. |
| **98** | **Focused Mind** | Gear | *The light of Raphion soothes your mind…* — Mental status effect / Stun immunity. |
| **99** | **Forest Charm** | Gear | *You feel stronger inside the forest.* — Forest biome stat amplification. |
| **101** | **Frostburned Rune** | Gear | *A Frostburned Rune.* — Inflicts combined Chill & Burn debuffs. |
| **102** | **Frosty Topper** | Gear | *Square snowman spirit.* — Ice defense & frost aura. |
| **103** | **Frozen Diadem** | Gear | *A frigid crown.* — Frost spell damage boost. |
| **105** | **Gelat Band** | Gear | *Ring infused with slime chunks.* — Blunt damage absorption. |
| **106** | **Gilded Pouch** | Gear | *Majestic purse.* — **+50% Gold earned from fights**. |
| **107** | **Golem Rune Core** | Gear | *Vivid core from a golem.* — Defense & summon enhancement. |
| **108** | **Grain of Balance** | Gear | *Power is redirected towards all other stat points.* — Balances all primary stats evenly. |
| **125** | **Imbued Chains** | Gear | *Shares speed between people.* — Speed equalization / party haste. |
| **126** | **Imbuement Reliquary** | Gear | *Summons share your enchantment's effects.* — Summons copy weapon enchantments. |
| **127** | **Imperial Headband** | Gear | *Sacrificial power.* — Sacrifices summon HP for player damage boost. |
| **128** | **Impure Crown** | Gear | *Ryzar Infelio's crown.* — Dark damage surge at the cost of defense. |
| **134** | **Lethal Blackjack** | Gear | *Test your luck with gamble skills!* — Random high-multiplier gamble strike. |
| **147** | **Madseer's Codex** | Gear | *Metrom's grimoire.* — Massive arcane power in exchange for sanity/recoil. |
| **148** | **Magma Charm** | Gear | *Protects from volcano harsh environment.* — Lava & Extreme Heat immunity + Speed boost. |
| **174** | **Molten Carapace** | Gear | *When low, flame spirit defends you.* — Triggers molten shield at low HP (<30%). |
| **178** | **Narthana's Leaf** | Gear | *Glows with pure life energy.* — Massive regeneration per turn. |
| **182** | **Open Hand** | Gear | *Ramizca welcomes good and resists evil.* — Holy & Light affinity bonus. |
| **185** | **Parasitic Leech** | Gear | *Takes damage and heals from it.* — Converts a portion of damage taken into healing. |
| **186** | **Pathfinder Mark** | Gear | *Symbol of everlasting hope.* — Movement speed & stamina recovery boost. |
| **187** | **Phantom Ooze** | Gear | *Volatile and ambitious flesh.* — Random elemental mutation each turn. |
| **191** | **Ptera's Heart** | Gear | *Pain of yourself causes pain of others.* — Retaliation reflect damage. |
| **193** | **Ramizcan Idol** | Gear | *After blocking, strength grows in your arms.* — Grants **Strength Buff (+25%)** after successful Block/Parry. |
| **200** | **Ring of Heroism** | Gear | *Strength when your allies suffer.* — Multiplies attack power when teammates fall below 50% HP. |
| **203** | **Sanguine Fang** | Gear | *Endless bloodlust.* — High life-steal on physical hits. |
| **219** | **Shard of Blight** | Gear | *Deep connection to the rot.* — **+25% Dark Affinity Damage**. |
| **221** | **Shattered Clock Hand** | Gear | *Ticks in a rhythmic way.* — Chance to instantly reset a skill cooldown. |
| **231** | **Snorb** | Gear | *Lightmarked essence orb.* — Essence absorption booster. |
| **233** | **Spiked Steel Ball** | Gear | *Additional damage as you attack.* — Extra physical piercing proc on strike. |
| **234** | **Spore Root** | Gear | *Mushroom perched on shoulder.* — Chance to stun and poison attacking enemies. |
| **239** | **Stone Brand** | Gear | *Summon's skin hardens.* — **+30% Damage Reduction for Summons**. |
| **246** | **Tainted Quiver** | Gear | *Runic inscriptions.* — Ranged / Piercing damage scaling. |
| **248** | **Tear Blood Crystal** | Gear | *Scent of blood heightens senses.* — Attack speed and critical rate up against bleeding targets. |
| **251** | **The Biggest Pebble** | Gear | *Escape while you still can!* — Guarantees 100% successful flee from combat. |
| **252** | **The Last Straw** | Gear | *Make them wait too long.* — Turn delay penalty on enemies. |
| **253** | **The Smallest Boulder** | Gear | *Smallest things make the biggest impact.* — High stagger impact on heavy strikes. |
| **255** | **Traveler's Lamp** | Gear | *Rustic lantern.* — Increases visibility in caves, dark zones, and dungeons. |
| **258** | **Vainglorious Locket** | Gear | *Regrets of the fallen Tyrannus.* — Tyranny / Domination power multiplier. |
| **259** | **Ages Pages** | Gear | *A million stories in a single sentence.* — Spell versatility boost. |
| **260** | **Blooming Eye** | Gear | *True sight revealed.* — Reveals enemy weaknesses and stat counters. |
| **261** | **Crystalline Spike** | Gear | *Turns foes to stone.* — Chance to Petrify / Crystallize enemies. |
| **262** | **Shadow Gauntlets** | Gear | *Soul ravishing feasting.* — Dark soul drain on melee strikes. |
| **263** | **Infected Skin** | Gear | *Beyond physical planes.* — True damage reflection. |
| **264** | **Lucky Horns** | Gear | *Spark ruin and terror.* — **+15% Critical Chance & Critical Multiplier**. |
| **268** | **Vow of Ruin** | Gear | *Pact with teammate, absorbs 25% damage for 3 turns then explodes.* — Co-op damage absorption & detonation. |
| **269** | **Vulcan Knuckle** | Gear | *Charged with the power of fire!* — High bonus Fire Damage on Fist / Cestus attacks. |
| **272** | **Wicked Crown** | Gear | *Rotten energy expels poison.* — Converts poison damage taken into healing. |
| **273** | **Yar'thuls Wrath** | Gear | *Draconic soul fuses with you, skin chars with inferno.* — **Massive Fire Affinity & Flame Cloak**. |
| **290–295** | **Event / Holiday Gears** | Gear | Rabbit Pelt, Egg Shelmet, Chocolate Egg, Party Egg, Gleaming Carrot, Rabbit's Foot. |
