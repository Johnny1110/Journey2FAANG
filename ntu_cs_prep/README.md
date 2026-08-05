# NTU-CS 碩士在職專班 入學準備總部

> 目標：116 學年度 台大資訊工程學系碩士在職專班（2027/09 入學，筆試約 2027/03）

<br>

---

<br>

## 考試情報（以 115 學年度為基準，116 簡章約 2027/01 初公告後更新）

| 項目 | 內容 |
|------|------|
| 招生名額 | 8 名 |
| 報考人數 | 約 28 人（115 學年度准考證號推估），錄取率約 28% |
| 報考資格 | 資訊相關工作經驗**合計 3 年以上**，且**同一機構連續 1 年以上**（不含服役），算至報名截止日 |
| 資料審查 | **30%** — 學位證書、成績單、年資證明、個人資料表、工作成果、推薦函 2 封（至多 3 封） |
| 筆試 | **30%** — 計算機概論（09:00–10:20）＋ 資料結構（10:40–12:00），各 80 分鐘，地點資訊系館（德田館） |
| 口試 | **40%** — 只有「筆試＋審查」總成績**前 12 名**能參加，筆試一週後舉行 |
| 簡章公告 | 約 1 月初 |
| 報名期限 | 約 2 月底 ～ 3 月初 |
| 筆試日期 | 約 3 月中下旬（115 學年度為 3/20） |
| 修業規定 | 最低 24 學分（不含論文），最低修業 2 年，與一般生合班上課 |

### 官方連結

* [資工系碩士在職專班入學規定](https://www.csie.ntu.edu.tw/zh_tw/Admission/Announcement13/%E8%B3%87%E8%A8%8A%E5%B7%A5%E7%A8%8B%E5%AD%B8%E7%B3%BB%E7%A2%A9%E5%A3%AB%E5%9C%A8%E8%81%B7%E5%B0%88%E7%8F%AD%E5%85%A5%E5%AD%B8%E8%A6%8F%E5%AE%9A-88615574)
* [115 學年度筆試公告（考科與時程參考）](https://www.csie.ntu.edu.tw/zh_tw/Admission/Announcement11/-%E7%A0%94%E7%A9%B6%E6%89%80-115%E5%AD%B8%E5%B9%B4%E5%BA%A6-%E8%B3%87%E8%A8%8A%E5%B7%A5%E7%A8%8B%E5%AD%B8%E7%B3%BB%E7%A2%A9%E5%A3%AB%E5%9C%A8%E8%81%B7%E5%B0%88%E7%8F%AD-%E6%8B%9B%E7%94%9F%E7%AD%86%E8%A9%A6%E5%85%AC%E5%91%8A-51688826)
* [台大碩士在職專班招生報名系統](https://exam.aca.ntu.edu.tw/GPU/)
* [台大圖書館考古題系統](https://exam.lib.ntu.edu.tw/)

<br>

---

<br>

## 戰略分析

1. **筆試是入場券，口試是決勝點。** 筆試只佔 30%，但沒進前 12 名就沒有口試資格。目標不是筆試滿分，而是「穩進前 12」＋ 把口試 40% 打好。
2. **資料結構是你的優勢科目。** NeetCode-150 的訓練與資結高度重疊，缺的只是「手寫申論／計算／畫圖追蹤」的答題模式（例如手畫 AVL 旋轉、追蹤 heap 建堆過程）。
3. **計算機概論是最大缺口。** 範圍廣：計組、OS、網路、資料庫、程式語言、資安與趨勢。需要系統性建立骨架。SQL Training 已 cover 資料庫一大塊。
4. **在職身分是共同劣勢＝你的相對優勢。** 對手多數也是在職、準備時間有限；你已有每天刷題的紀律，維持節奏就贏一半。
5. **備審 30% 可以提前鎖定分數。** 工作成果集、推薦函品質完全操之在己，12 月前開始準備，不要拖到報名前。

<br>

---

<br>

## 六個月讀書計畫（2026/08 ～ 2027/03）

> 節奏建議：平日每天 1～1.5 小時（可與現有刷題整合），週末每天 2～3 小時。

### Phase 0 — 定位（2026/08，現在）

* [ ] 完成診斷模擬考：[mock_exams/00_diagnostic](mock_exams/00_diagnostic/README.md)，找出兩科目前水位
* [ ] 到[台大考古題系統](https://exam.lib.ntu.edu.tw/)搜尋「資訊工程學系碩士在職專班」與資工所「計算機概論」「資料結構」歷屆試題，存到 `past_exams/`
* [ ] 確立每週讀書時段（寫進行事曆）

### Phase 1 — 資料結構主線（2026/09 ～ 2026/10 中，6 週）

詳細主題清單：[data_structures/README.md](data_structures/README.md)

| 週次 | 主題 |
|------|------|
| W1 | 複雜度分析（Big-O/Ω/Θ、遞迴式）＋ Array / Linked List |
| W2 | Stack / Queue（含中序轉後序、括號匹配等經典手寫題） |
| W3 | Tree：走訪、由走訪序列重建樹、BST 插入刪除 |
| W4 | AVL 旋轉、B-tree / B+ tree、Heap（建堆、heap sort） |
| W5 | Hashing（碰撞處理手算）＋ Sorting 全家桶（穩定性、複雜度表） |
| W6 | Graph（BFS/DFS、Topological Sort、MST、Dijkstra）＋ 總複習小考 |

### Phase 2 — 計算機概論主線（2026/10 中 ～ 2026/12 中，8 週）

詳細主題清單：[computer_science/README.md](computer_science/README.md)。此階段資結降為維持量：每週一份練習卷。

| 週次 | 主題 |
|------|------|
| W7 | 數字系統、資料表示（2's complement、IEEE 754）、數位邏輯基礎 |
| W8–W9 | 計算機組織：CPU 運作週期、pipeline、cache、memory hierarchy |
| W10–W11 | 作業系統：process/thread、scheduling、同步與 deadlock、記憶體管理、virtual memory |
| W12 | 計算機網路：OSI/TCP-IP、IP 定址、TCP vs UDP、DNS/HTTP |
| W13 | 資料庫（與 SQL Training 整合：正規化、ACID、索引）＋ 程式語言概念 |
| W14 | 資訊安全、AI/ML 趨勢名詞（計概愛考時事）＋ 總複習小考 |

### Phase 3 — 考古題輪（2026/12 中 ～ 2027/01，6 週）

作法與紀錄：[past_exams/README.md](past_exams/README.md)

* 每週 1～2 份考古題，**限時 80 分鐘手寫**
* 建立錯題本 → 產出弱點清單 → 回頭補對應章節
* [ ] **12 月底前**：邀請 2 位推薦人（主管／曾合作的資深工程師／大學教授），給對方至少一個月
* [ ] 1 月初：追蹤 116 學年度簡章公告，確認考科與日期是否變動

### Phase 4 — 衝刺＋備審（2027/02 ～ 筆試，6 週）

* 每週一次**全真模擬**（週末上午 9:00 開始，兩科連考，中間休息 20 分鐘）：[mock_exams/README.md](mock_exams/README.md)
* [ ] 備審資料完稿：個人資料表、工作成果集（見 [interview_and_docs/README.md](interview_and_docs/README.md)）
* [ ] 2 月底～3 月初：完成報名＋上傳資料
* 錯題本二輪複習，只補弱點不開新章節

### Phase 5 — 口試週（筆試後 ～ 口試，1 週）

* 口試題庫演練：[interview_and_docs/README.md](interview_and_docs/README.md)
* 與 [behavioral_training](../behavioral_training/README.md) 整合：STAR 框架直接改成中文口試版

<br>

---

<br>

## 與 Claude 的協作方式

| 指令 | 效果 |
|------|------|
| `ntu: init week{N}` | 依讀書計畫建立該週資料夾＋出一份台大筆試風格練習卷（名詞解釋／計算／追蹤／申論） |
| `ntu: 出題 {主題}` | 針對指定主題出練習卷（例：`ntu: 出題 AVL tree`） |
| `ntu: mock` | 出一份 80 分鐘全真模擬考（指定科目：計概或資結） |
| `score: ntu {資料夾}` | 依 0~10 評分你的手寫答案（拍照或打字放 `answer.md`），並給出檢討與補強建議 |

<br>

---

<br>

## 目錄

* [data_structures/](data_structures/README.md) — 筆試科目 I：資料結構
* [computer_science/](computer_science/README.md) — 筆試科目 II：計算機概論
* [past_exams/](past_exams/README.md) — 考古題訓練與錯題本
* [mock_exams/](mock_exams/README.md) — 模擬考（含 Phase 0 診斷考）
* [interview_and_docs/](interview_and_docs/README.md) — 備審資料（30%）＋ 口試（40%）
