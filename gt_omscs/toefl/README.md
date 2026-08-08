# TOEFL-100 (2026)

<br>

---

<br>

TOEFL 100 分是 GT-OMSCS 入學門檻。必須先達成這一個目標才有後續。這邊紀錄所有 TOEFL 的練習計畫進度與免費學習資源。

<br>

## 目標

| 項目 | 要求 |
| --- | --- |
| GT OMSCS 門檻 | 舊制總分 **≥ 100**，各科 **≥ 19** |
| 新制對照 | 舊制 100 ≈ 新制 **5.0 (C1)**；安全目標 **5.5**（舊制 107–113） |
| 過渡期 | 2026–2028 成績單同時顯示新制 (1–6)、舊制 (0–120)、CEFR |

> 2026/1/21 起 TOEFL iBT 全面改版：總長縮短到 2 小時內、Reading/Listening 改為 multistage adaptive（答對越多題目越難）、計分改為 1–6 分制（0.5 級距），總分 = 四科平均。

<br>

## 2026 新制題型總覽

| Section | 時間 | 題數 | 題型 |
| --- | --- | --- | --- |
| Reading | ~27 min | 35–48 | Complete the Words（段落填字）/ Read in Daily Life（email、公告短文）/ Read an Academic Passage（~200 字學術短文） |
| Listening | ~27 min | 35–45 | Listen and Choose a Response / Conversation / Announcement / Academic Talk |
| Writing | ~23 min | 12 | Build a Sentence / Write an Email（7 分鐘）/ Academic Discussion（10 分鐘） |
| Speaking | ~8 min | 11 | Listen and Repeat（7 題）/ Take an Interview（4 題，每題 45 秒） |

<br>

## 訓練計畫（16 週為一輪，可依模考結果調整）

| 階段 | 週次 | 重點 |
| --- | --- | --- |
| Phase 1 — 摸底 | W1–W2 | 做一次官方免費模考記錄起始分數；建立每日聽力習慣；開始累積詞彙表 |
| Phase 2 — 分項強化 | W3–W12 | 每週固定練習量（見下表），弱項加倍 |
| Phase 3 — 衝刺 | W13–W16 | 每週一次完整計時模考 + 檢討，報名正式考試 |

### 每週固定練習量

| 項目 | 頻率 | 方式 |
| --- | --- | --- |
| [Reading](reading/README.md) | 每週 1 回 | Claude 出題 → 用 [App](toefl-reading/README.md) 計時作答 → 當場自動批改復盤 |
| [Writing](writing/README.md) | 每週 1 回 | Claude 出題（計時）→ 我作答 → Claude 評分 |
| [Listening](listening/README.md) | 每天 20–30 min | 網路資源：精聽（聽寫）+ 泛聽（podcast） |
| [Speaking](speaking/README.md) | 每週 ≥ 3 次 | ChatGPT / Grok 語音對話，照主題清單練 |
| [Vocabulary](vocabulary/README.md) | 隨時累積 | 練習中遇到的生字記入詞彙表，每週 Claude 出複習測驗 |

<br>

## 怎麼跟 Claude 協作

已建立專案 skill：`.claude/skills/toefl/SKILL.md`，用 `/toefl <subcommand>` 觸發（打 `toefl: <subcommand>` 也通）。不帶參數的 `/toefl` 會列出子指令與目前進度。

閱讀練習另有 Vue App：`cd gt_omscs/toefl/toefl-reading && npm run dev`，支援計時模擬、自動批改、逐題復盤。

| 指令 | 效果 |
| --- | --- |
| `/toefl init reading` | 建立下一週 `reading/weekXX/`，產出新制題型的閱讀練習題 |
| `/toefl score reading week01` | 評分我的閱讀作答，寫入該週 `feedback.md` |
| `/toefl init writing` | 建立下一週 `writing/weekXX/`，產出寫作題目（含計時要求） |
| `/toefl score writing week01` | 以新制 rubric 評分作文，寫入該週 `feedback.md` |
| `/toefl vocab add <word/phrase>` | 把生字加進詞彙表（自動補音標、詞性、例句） |
| `/toefl vocab quiz` | 根據詞彙表出複習測驗考我 |
| `/toefl more speaking topics` | 在口說主題清單追加一批新主題 |

<br>

## 進度紀錄

| 日期 | 事件 | 結果 |
| --- | --- | --- |
| 2026-08-08 | 建立訓練計畫 | - |
