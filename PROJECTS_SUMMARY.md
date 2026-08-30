# 📚 TỔNG HỢP CHI TIẾT 2 DỰ ÁN AUTOMATION SCRIPT (POTASSIUM / ROBLOX)

Tài liệu này tổng hợp toàn bộ thông tin kiến trúc, tính năng, cơ chế vận hành và đường dẫn mã nguồn của 2 dự án đang phát triển và duy trì:

---

## 🌟 DỰ ÁN 1: ARCANE LINEAGE - ALL-IN-ONE MASTER HUB

* **Tên Script**: `Arcane_Hub.lua` / `Arcane_Hub.luau`
* **Trò chơi**: *Arcane Lineage* (Roblox)
* **Giao diện**: **LinoriaLib** (kèm `ThemeManager` & `SaveManager` lưu cấu hình)
* **GitHub Repository**: [`ZeroDepTrai/Arcane-Lineage-Hub`](https://github.com/ZeroDepTrai/Arcane-Lineage-Hub) (Branch `main` - Commit `7e44346`)
* **GitHub Gist**: `c81661682d9297b3f8130a53bc900df8`
* **Loadstrings**:
  * **GitHub Gist Raw (Khuyên dùng - Chống Cache)**:
    ```lua
    loadstring(game:HttpGet("https://gist.githubusercontent.com/ZeroDepTrai/c81661682d9297b3f8130a53bc900df8/raw/Arcane_Hub.lua?t=" .. tick()))()
    ```
  * **GitHub Repo Raw**:
    ```lua
    loadstring(game:HttpGet("https://raw.githubusercontent.com/ZeroDepTrai/Arcane-Lineage-Hub/main/Arcane_Hub.lua"))()
    ```
* **Đường dẫn cục bộ (Local PC)**:
  * 📁 `C:\Users\nchit\AppData\Local\Potassium\scripts\Arcane_Hub.lua`
  * 📁 `C:\Users\nchit\AppData\Local\Potassium\scripts\Arcane_Hub.luau`
  * 📁 `C:\Users\nchit\AppData\Local\Potassium\workspace\Arcane_Hub.lua`
  * 📁 `C:\Users\nchit\AppData\Local\Potassium\workspace\Arcane_Hub.luau`

---

### 📌 Các Phân Hệ Tính Năng Của Arcane Hub:

#### 1. 💎 Tab Farm (`Tabs.AutoFarm`)
* **🌿 Ingredient Auto Hunter**:
  * Tự động quét Menu $\rightarrow$ Chọn Whitelist nguyên liệu (`Crylight`, `Hightail`, `Everthistle`, `Carnastool`, `Driproot`...) $\rightarrow$ Bay Sky-Tween 3 giai đoạn (mặc định độ cao $Y = 1500$) $\rightarrow$ Thu hoạch $\rightarrow$ Đổi Server.
  * `BlacklistDesert`: Tự động nhận diện và loại bỏ Crylight giả tại khu vực *Vastic Grave* và *Forgotten Sanctum*.
  * Tùy chỉnh tốc độ bay: `AscendSpeed`, `CruiseSpeed`, `DescendSpeed`, `PickupTimeout`.
* **⛏️ Auto Mine Ores**:
  * Đào quặng tự động theo Whitelist (`Ferrus`, `Aestic`, `Laneus`).
  * `AutoBuyPickaxe`: Tự động bay về Caldera mua cuốc mới ($50\text{ Gold}$) nếu trong kho chưa có.
  * Hook trực tiếp Remote Server `InventorySync` (nhận diện quặng vào kho với độ trễ $0\text{ ms}$).
* **⚔️ Auto Farm Level & Mobs**:
  * Tự động bay tới các bãi quái ngầm an toàn và đánh quái theo chu trình khép kín.
  * Hỗ trợ 8 chế độ bãi farm:
    1. `Auto (Detect Level 1 - 50)`: Tự động đổi bãi ngầm Caldera ($< 30$) hoặc khối cát Sa mạc ($\ge 30$).
    2. `Level 1 - 30 (Underground)`: Bãi ngầm dưới lòng đất Caldera.
    3. `Level 30 - 50 (Desert Block)`: Bãi an toàn trong lòng khối sa mạc.
    4. `The Crossing (Caldera / Starter Mobs)`: Slime, Bandit, Goblin.
    5. `Deeproot Canopy (Westwood / Forest Mobs)`: Quái rừng Westwood.
    6. `Waving Sands (Desert / Sand Mobs)`: Bọ cạp, Xác ướp sa mạc.
    7. `Withered Grove (Cursed Grove / Undead Mobs)`: Quái hắc ám undead.
    8. `Mount Thul (Snow Mountain / Frost Mobs)`: Quái băng tuyết, Yeti, Golem.
  * `AutoMeditate`: Tự động nhận diện dừng nhận Essence (đạt Cap Level) $\rightarrow$ Mô phỏng thiền phím `M` gặp NPC Aretim thăng cấp rồi tự quay lại bãi farm.
  * `🌙 Deeproot Night Safe Hover (Avoid Sentinel)`: Khi trời tối ($17:30 \rightarrow 06:30$), tự động bay lên độ cao $Y = 1200$ (bật Noclip) đứng đợi sáng để né siêu quái *Sentinel of Darkness*.
* **🔮 Corrupt Server Hunter & Webhook**:
  * `🔮 Auto Hop Hunt Corrupt Server`: Tự động chuyển server liên tục cho đến khi tìm thấy **Corrupt Server / Event Server** đặc biệt (nhận diện qua `CurrentEvent ~= "None"`, `ShadowSky == true`, `Lighting.ShadowCorrupt`, `Lighting.CursedSky`, quái `Aberrant`).
  * `🛑 Stay In Corrupt Server`: Tự động dừng hop ngay khi tìm thấy Corrupt Server để người chơi ở lại chiến đấu/săn đồ.
  * `🔔 Webhook Ping @everyone`: Tự động ping Discord và gửi Embed chi tiết: Tên Event, Số lượng người chơi, Server JobId, Mã Script Teleport trực tiếp vào Server, Region.
  * `🔍 Check Current Server Event`: Nút kiểm tra nhanh tình trạng event của server hiện tại.

---

#### 2. ⚔️ Tab Combat (`Tabs.AutoQTE`)
* **⚡ Auto Combat & Minigames QTE**:
  * **100% Perfect Dodge / Block**: Tự động né hoàn hảo không mất máu (ưu tiên Dodge, dự phòng Block).
  * Giải QTE toàn bộ vũ khí: Sword (Single-click $0.25\text{s}$ debounce), Dagger (bắt Weakpoint), Hammer (PID Power Bar), Axe (Equilibrium), Staff/Magic (Rune matching), Fist/Cestus (Combo), Spear (Taps, Lines & Curves), Mở khóa rương (Chest Lockpick).
  * `ReactionDelayMs`: Tùy chỉnh độ trễ mô phỏng người chơi ($0 \rightarrow 150\text{ ms}$).
* **⚔️ Auto Fight Engine & 🔒 Strict Custom Skill Priority**:
  * `Enable Auto Fight`: Tự động tung chiêu / đánh thường / thiền khi đến lượt trong trận đấu (hoạt động độc lập ngoài trận).
  * **3 Chế độ hành động khi tới lượt**:
    1. `Strike (Basic Attack)`: Chỉ đánh thường.
    2. `Auto Smart (Best Skill -> Strike)`: Tự động chọn skill tốn nhiều Energy nhất đang sẵn sàng, nếu hết skill thì đánh thường hoặc thiền.
    3. `Custom Skill`: **Strict Priority 4 Slot** (Ưu tiên tuần tự Slot 1 $\rightarrow$ 2 $\rightarrow$ 3 $\rightarrow$ 4).
  * **Cơ chế STRICT PRIORITY & Anti-Random**:
    * So khớp chính xác $100\%$ tên chiêu thức (`Exact Matching`).
    * Kiểm tra đồng thời: Cooldown (`CD`), Trạng thái khóa (`Sealed`), và lượng Energy thực tế của người chơi (`Status.Energy.Value >= Skill Cost`).
    * Nếu toàn bộ 4 slot đều không thể sử dụng:
      * Nếu bật `Auto Meditate in Combat`: Tự động Meditate sạc năng lượng.
      * Nếu tắt Meditate: **CHỈ** dùng `Basic Attack` (Strike / Magic Missile).
      * **Tuyệt đối KHÔNG** tự ý kích hoạt các skill lạ ngoài 4 slot đã cấu hình.
  * **Cơ chế Chống Softlock 1.0s Delay**: Toàn bộ thao tác chuyển trang `AttackButton`, chọn chiêu thức `SkillButton`, chọn quái `EnemyButton`, `Go` và `Meditate` đều được thiết lập độ trễ an toàn **$1.0\text{s}$**, loại bỏ $100\%$ lỗi kẹt lượt.

---

#### 3. 👁️ Tab Visuals & ✨ Quality of Life (QOL)
* **🔮 Enemy Skill Predictor & Combat HUD**:
  * `🔮 Enemy Skill Predictor & Combat HUD` *(Mặc định TẮT)*: Bảng HUD trực quan phân tích trực tiếp theo thời gian thực (hỗ trợ kéo thả):
    * **Máu (HP)** & **Năng Lượng (Energy)** của từng quái vật trên sân.
    * **Chiêu thức vừa dùng gần nhất** (`LastUsedAttack`).
    * **Dự đoán chiêu thức tiếp theo**: Thuật toán tự động đối chiếu lượng Energy hiện tại, Cooldown và bảng Skill của NPC để lọc ra các chiêu quái có thể tung ra (Tô đỏ các chiêu nguy hiểm như `Magma Pillar`, `Inferno`, `Armageddon`...).
    * **Bắt chiêu tức thì (Live Cast Indicator)**: Hook trực tiếp Remote `AttackIndicate` để hiển thị ngay chiêu quái đang vung trước khi thanh QTE xuất hiện.
  * `🏷️ Show Predictor On Enemy Heads (ESP)` *(Mặc định TẮT)*: Hiển thị thanh Energy & Chiêu dự đoán dạng Billboard trên đầu quái vật.
  * `🔔 Sound Alert On Danger Skills` *(Mặc định TẮT)*: Phát âm thanh cảnh báo khi quái tung chiêu nguy hiểm.
* **🔥 FPS Boost (Potato Mode) (Toggle)**: Ép `SmoothPlastic`, gỡ `TextureID` / `SurfaceAppearance`, ẩn cây cối thảm thực vật `MapGarbage.TreeGarbage`, tắt toàn bộ `Particle`, `Light`, `Shadows`, `Fog`, phẳng hóa mặt nước nhưng **vẫn giữ 3D Rendering**.
* **Ingredient ESP**: BillboardGui hiển thị khoảng cách và tên nguyên liệu theo Whitelist.
* **QOL Toggles**: `Reveal 'I Feel No Pain' HP & Mana`, `Reveal Unidentified Items`.

---

#### 4. 🏃 Tab Movement & 🌐 Teleport & ⚙️ Settings
* **Movement**: Fly Hack (`X`), NoClip (`V`), Velocity Speed (`B`), CFrame Speed (`N`), Infinite Jump (`J`).
* **Teleport**: Dịch chuyển Sky-Tween 35+ vị trí Class Trainers, Thành phố, Heavens Point Church, Thương nhân, Mỏ quặng...
* **Auto Load on Changing Server**: Tích hợp `queue_on_teleport` đa executor tự reload script khi chuyển server.
* **Unload Hub**: Giải phóng $100\%$ tài nguyên, kết nối, threads (kèm Predictor và CorruptHunter).

---
---

## 🛡️ DỰ ÁN 2: DUNGEON QUEST - AEONIC COMPANION ADDON

* **Tên Script**: `Aeonic_DQ_Companion_Addon.lua`
* **Trò chơi**: *Dungeon Quest* (Roblox)
* **Mục đích**: Addon tự động hóa toàn diện sảnh chờ (Lobby), trang bị, bán đồ, chọn map và nạp Aeonic Hub khi vào Dungeon.
* **Cơ chế Auto Load on Teleport**: Đảm bảo tự động nạp lại script qua `queue_on_teleport` khi chuyển đổi qua lại giữa **Lobby $\longleftrightarrow$ Dungeon**.
* **Đường dẫn cục bộ (Local PC)**:
  * 📁 `C:\Users\nchit\AppData\Local\Potassium\scripts\Aeonic_DQ_Companion_Addon.lua`
  * 📁 `C:\Users\nchit\AppData\Local\Potassium\workspace\Aeonic_DQ_Companion_Addon.lua`

---
*Tài liệu được cập nhật và đồng bộ toàn diện vào hệ thống lưu trữ.*
