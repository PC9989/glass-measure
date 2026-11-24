# 玻璃度尺

Glass Measure — 在現場為窗膜報價量度玻璃。

這是一個原生 SwiftUI + ARKit App，給 iPad 及 iPhone 使用。工作、相片同報告都只留在裝置上，沒有帳號，亦不會上載。

## 用 Xcode 開啟

1. 用 **Xcode 16 或更新版本** 開啟 `GlassMeasure.xcodeproj`。
2. 選 target **GlassMeasure** → **Signing & Capabilities**，揀你的 Development Team。
3. 部署目標係 **iOS / iPadOS 17.0**。iPhone 同 iPad 都支援。
4. 揀一部實機做執行目標，然後按 Run。

模擬器沒有 LiDAR，相機擴增實境亦通常不可用。可以在模擬器建立工作、手動輸入尺寸，或者用相片圖庫試驗「照片估算」同 PDF。實地量度請用實機。

## 在實機執行

1. 用線連接 iPad 或 iPhone，解鎖並信任這部電腦。
2. Xcode 第一次安裝時，在裝置上開啟「設定 → 一般 → VPN 與裝置管理」（或「裝置管理」），信任你的開發者帳號。
3. 第一次進入量度畫面，允許相機。LiDAR 不需要另外的開關；系統若詢問環境感知，請允許，否則偵測不到牆身平面。
4. 建議橫向或直向都可以。iPad 會顯示工作列表同明細；iPhone 會先顯示列表，再進入工作。

最準的裝置係有 LiDAR 的 **iPad Pro**，以及 **iPhone 18 Pro / iPhone 18 Pro Max**。沒有 LiDAR 的裝置（例如 iPad mini）仍然可以量度，畫面會標明準確度較低。

## 點樣量度

玻璃會反光，往往沒有可供追蹤的特徵。量度對準的是 **窗框同牆身平面**，不是玻璃表面。

### 擴增實境

1. 打開一份工作，加入玻璃，選「擴增實境量度」。
2. 將裝置對準窗框，等到中心點可以落點。
3. **對角**：點窗框兩個對角，程式在牆身平面上畫出水平寬度、垂直高度的矩形。
4. **四角**：依序點四個角。第一點會鎖定平面，其後的點貼在同一平面上，避免玻璃本身吸不到深度。
5. 畫面即時顯示寬度、高度、對角線、面積。單位係毫米，並附厘米；面積係平方米。
6. 可拖動角點微調，用「拉尺校正」輸入一邊的實拉長度（只填一邊會等比縮放），再拍攝帶標註的相片。
7. 儲存後可以繼續下一塊玻璃。

沒有 LiDAR 時不會被擋住，但請以拉尺覆核最少一邊。

### 照片估算

這是另一種量度，**不是** LiDAR 實測。

1. 從相片圖庫、檔案，或拍攝一張靜態相片。請盡量正面拍攝窗框。斜拍、廣角同透視會令比例偏差。
2. 在相片上點四個角，或拉出一個矩形。可以雙指放大再標角。
3. **如果未輸入任何真實長度，App 只顯示寬高比**（例如 4:3），以及較精確的寬比高。不會顯示毫米、厘米或平方米，亦不會用 0 填數。
4. 可以先「儲存比例（待實尺）」。之後在玻璃明細按「輸入已知邊長」，填一邊的拉尺讀數（寬度或高度，單位毫米）。
5. 輸入之後，先按該邊的比例換算其餘尺寸同面積，並標成 **估算**。已知的那一邊會標成「實尺」，其餘標成「估算」。

### 手動輸入

裝置不支援擴增實境，或者你已經有拉尺數字時，可以同時輸入寬度及高度。對角線同面積只按這兩個數計算。只填一邊不會估算另一邊。

## PDF 報告

在工作明細底部按 **產生 PDF 報告**。可以預覽，再用分享送到「檔案」、WhatsApp、郵件或其他 App。

報告包含：

- 日期、報告編號、客戶／地盤、備註
- 每塊玻璃的狀態
- 已有尺寸的玻璃：寬 × 高、對角線、面積；拉尺校正、手動輸入、照片估算會分開標示
- 待實尺的玻璃：只列出寬高比，寬度、高度、面積欄係「待實尺」或「—」，**不會出現假毫米或假面積**
- 總面積。照片估算若已計入，會分開列出；待實尺不計入
- 有標註相片的話會附在後面
- 關於玻璃反光同照片透視的聲明

同一份報告的文字摘要可以另外分享。PDF 亦會寫入本機「檔案」App 裡玻璃度尺的「報告」資料夾。

## 所需功能

| 項目 | 用途 |
| --- | --- |
| 相機 | 擴增實境畫面，以及拍攝靜態相片 |
| ARKit 世界追蹤 | 將落點放在空間中 |
| 場景網格／LiDAR（有則用） | 幫助牆身平面；量度仍以平面為準，不依賴玻璃表面 |
| 相片圖庫／檔案 | 只在你揀選時讀取那一張相片 |
| 本機儲存 | SwiftData 保存工作；相片放在 App 內 |

`Info.plist` 的相機及環境感知說明係繁體中文。沒有加入相片圖庫的廣泛讀取權限；從圖庫選相用系統選擇器。

## 已知限制

- 玻璃、鏡同其他反光表面的深度通常不可靠。請點窗框或牆身，並用拉尺覆核。
- 沒有 LiDAR 時，平面要靠畫面特徵估計，誤差會較大。
- 照片估算假設相片大致正面。透視不能單靠一張相校正，所以結果只係估算。
- 未輸入已知邊長的相片 **沒有** 絕對尺寸。這是刻意的，避免把比例誤當成毫米。
- 擴增實境標註相片若在拍攝之後才做拉尺校正，相片上的數字可能仍是校正前的實測；明細會提醒。照片估算的標註會在你更改已知邊長後重畫。
- 此開發環境係 Linux，未能在此編譯或簽署 IPA。請在 Mac 上的 Xcode 開啟並安裝到實機。

## English

Glass Measure is an on-site window-pane measuring app for film quotes. Open `GlassMeasure.xcodeproj` in Xcode 16 or later, select your team, and run it on a device. LiDAR devices (iPad Pro, iPhone 18 Pro and iPhone 18 Pro Max) are the most accurate. Devices without LiDAR can still measure, with a lower-accuracy warning.

Live AR locks onto the wall or frame plane and does not expect the glass itself to track. A photo mode lets you mark corners and, until you enter one taped edge in millimetres, shows only the aspect ratio — no millimetres and no area. A job can export a Traditional Chinese PDF with panes, photos, totals, tape corrections, and estimates marked as such. Nothing is uploaded.
