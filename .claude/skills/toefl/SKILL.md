---
name: toefl
description: TOEFL-100 training workflow for GT OMSCS — generate weekly reading/writing practice, score answers, manage the vocabulary list and quizzes, add speaking topics. Use when the user types /toefl <subcommand>, says "toefl: <subcommand>", or asks for TOEFL practice/scoring/vocab.
---

# TOEFL-100 Training Workflow

所有 TOEFL 訓練檔案都在 `gt_omscs/toefl/`，總計畫見 `gt_omscs/toefl/README.md`。目標：舊制 100（新制 band 5.0–5.5）。所有練習題目一律使用 **2026 新制題型**。

子指令格式：`/toefl <subcommand>`（或 `toefl: <subcommand>`）。不帶參數時，列出可用子指令並顯示各項目最新進度。

## 通用規則

- 題目與範文一律全英文；評分與解說用繁體中文（保留英文術語）。
- 每次 init / score 之後，更新對應 README.md 的索引表（週次、日期、主題、分數）。
- 任何練習或批改中出現值得學的生字/片語，主動建議加入詞彙表（先列出來問，不要擅自加）。
- 週次資料夾編號：掃描現有 `weekXX/` 取最大值 +1，補零兩位（week01, week02…）。

## init reading

在 `gt_omscs/toefl/reading/weekXX/` 建立：

1. `README.md` — 一回完整閱讀練習，含計時要求（27 分鐘內），題型配置：
   - **Complete the Words** ×2 段：學術段落各挖 10 個字，每個字只給前半字母（如 `imp___ant`）
   - **Read in Daily Life** ×2 篇：email / 公告 / 通知（15–150 字），各 2–3 題四選一
   - **Read an Academic Passage** ×2 篇：~200 字學術短文（題材輪替：科學、歷史、社會、藝術、科技），各 5 題四選一（主旨、細節、推論、詞義、指代）
   - 題目後**不附答案**，答案留給 score 階段
2. `answer.md` — 空白作答模板（對應題號的作答格）

## score reading weekXX

讀 `weekXX/README.md`（題目）與 `weekXX/answer.md`（作答），產出 `weekXX/feedback.md`：

- 逐題對答案，給答對率與估計 band（1–6）
- 每題錯誤附解析：正解在原文哪裡、為什麼誘答選項錯
- 列出本回值得收錄的生字/片語清單，詢問是否加入詞彙表

## init writing

在 `gt_omscs/toefl/writing/weekXX/` 建立 `README.md` + `answer.md`，題型配置：

- **Build a Sentence** ×4：給打散的字塊，組出正確句子
- **Write an Email** ×1：情境題（教授、同學、學校行政），**限時 7 分鐘**，題目要標明收件人與必須涵蓋的 2–3 個要點
- **Writing for an Academic Discussion** ×1：附教授提問 + 兩位同學的立場發言，**限時 10 分鐘**，要求表態並回應同學觀點

## score writing weekXX

讀題目與作答，產出 `weekXX/feedback.md`：

- 每題給 band（1–6）+ 總評，維度：任務完成度 / 組織 / 文法 / 用字多樣性
- Email 與 Discussion 逐句修改（原句 → 修正 → 說明），最後附一篇 band 6 範文
- 超時或字數明顯不足要指出
- 列出可收錄詞彙，詢問是否加入詞彙表

## vocab add <word/phrase ...>

把生字加進 `gt_omscs/toefl/vocabulary/vocab.md` 表格（格式見該檔），自動補：音標（IPA）、詞性、繁中意思、一句貼近 OMSCS/工程師情境的例句、Source（哪次練習遇到的，不知道就填 manual）、★ 欄留空。日期用今天。

## vocab quiz

從 `vocab.md` 出複習測驗，存到 `gt_omscs/toefl/vocabulary/quiz/YYYY-MM-DD.md`：

- 選字優先序：★ 多的 > 最近 2 週新增 > 隨機舊字（比例約 4:4:2），一次 10–15 題
- 題型混合輪替：中翻英、句子克漏字、選詞填空（給 4 個近義候選）、用指定字造句
- 使用者作答後批改，並回寫 `vocab.md` 的 ★ 欄：答錯 +1★；該字連續兩次 quiz 答對 −1★（最低 0）
- 在 quiz 檔尾記錄成績與錯字清單

## more speaking topics

在 `gt_omscs/toefl/speaking/README.md` 的主題清單追加一批新主題（每類 5 個、checkbox 格式、不重複既有主題），分類沿用：Campus/學習、Work/科技、日常/觀點。
