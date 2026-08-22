# TOEFL Reading

<br>

---

<br>

每週一回，由 Claude 依 2026 新制題型出題。**推薦用 App 練習**（可計時、自動批改、當場復盤）：

```bash
cd gt_omscs/toefl/toefl-reading && npm run dev
```

App 說明見 [toefl-reading/README.md](../toefl-reading/README.md)。

<br>

## 兩種練習方式

| 方式 | 流程 |
| --- | --- |
| **App**（推薦） | 啟動後選週次 → 選計時／不計時 → 作答 → 交卷 → 當場看正解與解析 |
| 紙筆／Markdown | 寫在 `weekXX/answer.md` → 說 `/toefl score reading weekXX` → Claude 產出 `weekXX/feedback.md` |

App 的題庫在 `toefl-reading/src/data/weekXX.json`（含答案），本資料夾的 `weekXX/README.md` 是不含答案的列印版，兩者題目相同。用 `/toefl init reading` 會同時產生。

<br>

## 新制題型（每回練習應涵蓋）

| 題型 | 說明 | 練習重點 |
| --- | --- | --- |
| Complete the Words | 學術段落中每段 10 個單字缺後半字母，補完 | 詞彙量 + 構詞（字首字尾） |
| Read in Daily Life | email、公告等生活短文（15–150 字），2–3 題選擇 | 快速抓目的與細節 |
| Read an Academic Passage | ~200 字學術短文，5 題選擇 | 主旨、推論、指代、詞義 |

計時要求：整回控制在 **27 分鐘**內完成，模擬真實節奏。

<br>

## 練習索引

| 週次 | 日期 | 主題 | 分數 |
| --- | --- | --- | --- |
| [Week 01](week01/README.md) | 2026-08-08 | Soil & Sediment（科學）、Coffeehouses（歷史／社會） | 未作答 |
| [Week 02](week02/README.md) | 2026-08-15 | Batteries & Undersea Cables（科技）、Paint Tubes & Art Restoration（藝術） | 未作答 |
