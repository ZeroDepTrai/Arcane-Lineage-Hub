# ⚔️ Arcane Lineage — Enchantment System (Datamined)

> **DataKey**: `44: Enchantment` (từ module `DataKeys` trong ReplicatedStorage)  
> **Verified**: getgc() + ItemRegistry + Wiki cross-reference

---

## 🔑 Cơ Chế Cốt Lõi

| Thuộc Tính | Chi Tiết |
|:---|:---|
| **Gắn Vào** | **Nhân vật**, KHÔNG phải vũ khí — tự áp dụng lên vũ khí đang trang bị |
| **Số Slot Hoạt Động** | **Chỉ 1 enchant tại 1 thời điểm** |
| **Khi Thay Mới** | Enchant cũ bị **thay thế vĩnh viễn** |
| **Khi Chết** | Enchant **giữ nguyên** (không mất khi chết thường) |
| **Lưu Trữ** | **Không thể** lưu nhiều enchant — chỉ 1 active |
| **Áp Dụng Cho** | **Weapon (vũ khí) chỉ** — Armor/Gear/Artifact KHÔNG thể enchant |
| **Bậc Nâng Cấp** | **Không có** — mỗi enchant là 1 bậc duy nhất |

> [!WARNING]  
> Dùng **Arkhaia's Curse** hoặc **Rapheon's Blessing** sẽ **ghi đè ngay lập tức** enchant hiện tại thành Spectral hoặc Blessed.

---

## ✨ Danh Sách Tất Cả Enchant

### 🔥 INFERNO
| | |
|:---|:---|
| **Loại** | Offensive / Status |
| **Level Yêu Cầu** | 25+ |
| **Hiệu Ứng** | Tấn công có **cơ hội gây Burning**. Gây **+20% sát thương** lên kẻ thù đang bị Burning |
| **Vị Trí** | Mount Thul (khu vực Volcano) |
| **Cách Lấy** | Từ cửa vào Volcano, đi **bên trái** → tìm **tường giả (illusory wall)** → vượt **parkour challenge** → nói chuyện với **entity NPC** cuối đường |
| **Phù Hợp** | Build Fire / Offensive, class có thể stack Burn |

---

### 💰 MIDAS
| | |
|:---|:---|
| **Loại** | Utility / Offensive |
| **Level Yêu Cầu** | 35+ |
| **Hiệu Ứng** | Tăng **gold nhận được** từ kill + **tỷ lệ drop item**. Có **16.6% cơ hội** gây **+15% bonus damage** mỗi đòn |
| **Vị Trí** | Caldera Inn (town bắt đầu) |
| **Cách Lấy** | Đánh bại boss **Yar'thul the Blazing Dragon** → nói chuyện với NPC **Lodyssa** ở Inn → **Bán 250 items** cho Lodyssa |
| **Phù Hợp** | Build farm/loot, build Luck stat |

---

### ☠️ REAPER
| | |
|:---|:---|
| **Loại** | Offensive / Sustain |
| **Level Yêu Cầu** | 35+ |
| **Hiệu Ứng** | **Lifesteal 10%** cơ hội hút 10% sát thương đã gây thành HP. Sát thương tăng **tối đa +25%** theo HP còn thiếu của kẻ thù (đánh đau hơn khi kẻ thù sắp chết). Passive HP regen |
| **Vị Trí** | Phòng bí mật trong khu vực Desert |
| **Cách Lấy** | Cần **max lives** + **Lineage Shard** trong túi → Tìm **cửa đỏ phát sáng (Red Door)** trong desert → Tương tác với **gai đỏ (red spikes)** bên trong |
| ⚠️ **Cảnh Báo** | Nếu không đủ điều kiện HP hoặc item → **chết ngay lập tức** |
| **Phù Hợp** | Build DPS solo, execute-style |

---

### 🎵 LIFESONG
| | |
|:---|:---|
| **Loại** | Support / Healing |
| **Level Yêu Cầu** | 30+ |
| **Hiệu Ứng** | Tăng **+20% tất cả healing** (vào và ra). Tấn công có **30% cơ hội** kích hoạt **healing buff 3 turns** cho bản thân và đồng đội |
| **Vị Trí** | Deeproot Depths — Forgotten Sanctum |
| **Cách Lấy** | Vượt **parkour challenge** trong Deeproot Depths → vào hidden Forgotten Sanctum → tương tác với **trụ xanh lá (green pillar)** |
| **Phù Hợp** | Class Saint / Healer, build support |

---

### 💀 CURSED
| | |
|:---|:---|
| **Loại** | Offensive / Utility |
| **Level Yêu Cầu** | 35+ |
| **Hiệu Ứng** | **16.6% cơ hội** áp **random debuff** khi tấn công. **Miễn nhiễm Cess Ground damage**. Gây **+10% sát thương** lên kẻ thù bị Cursed hoặc Sundered |
| **Vị Trí** | Khu vực Cessgrounds |
| **Cách Lấy** | Quest nhiều bước từ NPC **Jyphar**: (1) Bắt **10 xác chết bị nguyền**, (2) Gặp mushroom độc trong chiến đấu, (3) Dùng kỹ năng **Toxic Burst** trong khi bị Poisoned để tự gây Cursed, (4) Kết thúc trận còn bị debuff, (5) Chết bởi **đám mây độc** tại Cessgrounds |
| **Phù Hợp** | Build debuff stacking, farm Cessgrounds, dark/necro class |

---

### ✨ BLESSED
| | |
|:---|:---|
| **Loại** | Defensive / Utility |
| **Level Yêu Cầu** | **Covenant Rank 20** (Church of Rapheon) |
| **Hiệu Ứng** | Tích **stack "Light"** mỗi đòn đánh. Tại **3 stacks** → nổ ra gây **2% max HP của kẻ thù** + áp **Sundered 2 turns**. Kháng nhiều loại sát thương |
| **Vị Trí** | Church of Rapheon (qua portal Sky Man ở Deeproot Canopy) |
| **Cách Lấy** | Gia nhập **Church of Rapheon** → đạt **Rank 20** → đánh boss **Seraphon** → nhận **Rapheon's Blessing** → dùng item để áp enchant |
| **Phù Hợp** | Build defensive, anti-armor, thành viên Church of Rapheon |

---

### 👻 SPECTRAL
| | |
|:---|:---|
| **Loại** | Offensive |
| **Level Yêu Cầu** | **Covenant Rank 20** (Cult of Thanasius) |
| **Hiệu Ứng** | **50% cơ hội** mỗi đòn đánh **bỏ qua toàn bộ Damage Reduction** của kẻ thù |
| **Vị Trí** | Temple of Norn (Cult of Thanasius) |
| **Cách Lấy** | Gia nhập **Cult of Thanasius** → đạt **Rank 20** → đánh boss **Arkhaia** → nhận **Arkhaia's Curse** → dùng item để áp enchant |
| **Phù Hợp** | Build anti-tank (kẻ thù có DR cao), thành viên Cult of Thanasius |

---

### 🧊 HIEMAL
| | |
|:---|:---|
| **Loại** | Offensive / Crowd Control |
| **Level Yêu Cầu** | Chưa xác nhận (nội dung level cao) |
| **Hiệu Ứng** | **25% cơ hội** áp **debuff freeze-related** khi tấn công |
| **Vị Trí** | Khu vực boss encounter |
| **Cách Lấy** | Đánh bại boss **Handaconda** ở **trạng thái Corrupted** → nói chuyện với NPC **Thurisaz** |
| **Phù Hợp** | Build CC / crowd control, synergy frost/ice |

---

### ❄️ FROSTED *(Event độc quyền)*
| | |
|:---|:---|
| **Loại** | Offensive (Event) |
| **Level Yêu Cầu** | Không yêu cầu |
| **Hiệu Ứng** | Tấn công có cơ hội áp **Cold debuff 2 turns**. Crit vào kẻ thù bị Cold → kích **AOE frost explosion**. Với weapon frost → cơ hội Cold **nhân đôi** |
| **Vị Trí** | NPC Event tại Caldera Town |
| **Cách Lấy** | Đổi **500 Crystalized Joy** với NPC Event trong event **"Solstice of Light"** (Seasonal) |
| **Phù Hợp** | Build frost/ice, AOE burst damage, CC synergy |

---

## 📊 Bảng So Sánh Tổng Hợp

| Enchant | Loại | Lvl | Hiệu Ứng Chính | Cách Lấy |
|:---:|:---:|:---:|:---|:---|
| 🔥 **Inferno** | Offensive | 25+ | Burn + **+20% dmg vs burning** | Volcano false wall parkour |
| 💰 **Midas** | Utility | 35+ | +Gold/drops + **16.6% → +15% dmg** | Bán 250 items cho NPC Lodyssa (Caldera) |
| ☠️ **Reaper** | DPS | 35+ | Lifesteal + **+25% dmg vs low HP** | Desert Red Door (Lineage Shard + max lives) |
| 🎵 **Lifesong** | Support | 30+ | **+20% heal** + proc healing buff | Deeproot parkour → green pillar |
| 💀 **Cursed** | Debuff | 35+ | Random debuff + **Cess immunity** | Quest Jyphar (Cessgrounds) |
| ✨ **Blessed** | Defensive | Rank 20 | Light stacks → **sunder + 2% HP dmg** | Church of Rapheon Rank 20 + Seraphon boss |
| 👻 **Spectral** | Anti-Tank | Rank 20 | **50% ignore Damage Reduction** | Cult of Thanasius Rank 20 + Arkhaia boss |
| 🧊 **Hiemal** | CC | ❓ | **25% freeze debuff** | Corrupted Handaconda + NPC Thurisaz |
| ❄️ **Frosted** | Event | — | Cold + **AOE frost explosion on crit** | Event: 500 Crystalized Joy |

---

## 🎯 Khuyến Nghị Theo Build

| Mục Tiêu Build | Enchant Tốt Nhất |
|:---|:---|
| **DPS / Solo** | Reaper hoặc Spectral |
| **Fire / Elemental** | Inferno |
| **Farm Gold / Drop** | Midas |
| **Healer / Support** | Lifesong |
| **Debuff / Dark** | Cursed |
| **Anti-Tank (phá DR)** | Spectral |
| **CC / Frost** | Frosted (event) hoặc Hiemal |
| **Defensive / Light** | Blessed |

---

## 📝 Lưu Ý Quan Trọng

> [!IMPORTANT]
> - **Artifact và Gear KHÔNG có enchant slot** — chỉ weapon bị ảnh hưởng
> - **Không thể lưu nhiều enchant** — chỉ 1 active tại 1 thời điểm
> - Hai enchant covenant (**Blessed** và **Spectral**) cần gia nhập faction tương ứng
> - **Reaper** là enchant nguy hiểm nhất để farm — sai điều kiện = chết ngay

> [!TIP]
> **Spectral** hiện được coi là **enchant PvP/PvE mạnh nhất** vì 50% ignore DR không thể bị counter bằng cách stack armor.  
> **Reaper** tốt nhất cho solo boss vì lifesteal + execute damage.
