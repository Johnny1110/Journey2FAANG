# TOEFL Reading Practice App

2026 新制 TOEFL 閱讀模擬練習程式。Vue 3 + Vite，純前端，資料存瀏覽器 localStorage。

<br>

## 啟動

```bash
cd gt_omscs/toefl/toefl-reading
npm install     # 第一次才需要
npm run dev     # http://localhost:5180
```

<br>

## 功能

| 功能 | 說明 |
| --- | --- |
| 兩種模式 | **計時模擬**（27 分鐘倒數，剩 3 分鐘變紅，時間到自動交卷）／**不計時練習**（只記錄用時） |
| 作答草稿 | 每次輸入自動存 localStorage，關掉瀏覽器再回來可接續 |
| 復盤 | 交卷後顯示總分、各 Part 分項得分、估計 band，逐題顯示正解與解析；可切換「只看錯的」 |
| 歷史紀錄 | 首頁展開可看所有作答紀錄，隨時重開任一次復盤 |

<br>

## 加新題目（重要）

**放一個 `src/data/weekXX.json` 進去就好**，程式用 `import.meta.glob` 自動偵測，不需要改任何程式碼。

用 `/toefl init reading` 時我會同時產生：

* `gt_omscs/toefl/reading/weekXX/README.md` — 給人看／列印的版本（不含答案）
* `gt_omscs/toefl/toefl-reading/src/data/weekXX.json` — 給程式用的版本（含答案與解析）

<br>

## 題庫格式

```jsonc
{
  "id": "week01",
  "week": 1,                  // 排序用
  "title": "Week 01",
  "date": "2026-08-08",
  "topics": ["主題 A", "主題 B"],
  "timeLimitSec": 1620,       // 計時模式的秒數，27 分鐘
  "parts": [
    {
      "id": "part1",
      "type": "cloze",        // Complete the Words
      "title": "Part 1 — Complete the Words",
      "instructions": "...",
      "blocks": [
        {
          "title": "Passage A",
          "template": "... that {{1}} nearly all land plants. ...",
          "blanks": [
            { "id": 1, "prefix": "supp", "missing": 4,
              "answer": "supports", "explanation": "..." }
          ]
        }
      ]
    },
    {
      "id": "part2",
      "type": "choice",       // 選擇題（Daily Life / Academic Passage 共用）
      "title": "Part 2 — Read in Daily Life",
      "blocks": [
        {
          "title": "Text 1",
          "style": "email",   // email | notice | academic，只影響外觀
          "body": ["段落一", "段落二"],   // 支援 **粗體**
          "questions": [
            { "id": 21, "prompt": "...",
              "options": ["A 選項", "B 選項", "C 選項", "D 選項"],
              "answer": "B", "explanation": "..." }
          ]
        }
      ]
    }
  ]
}
```

**格式規則**（`npm run check` 會驗證）：

* `template` 裡的 `{{n}}` 必須和 `blanks[].id` 一一對應
* `answer` 必須以 `prefix` 開頭，且 `prefix.length + missing === answer.length`
* 每題 4 個選項，`answer` 是 `A`–`D`，每題都要有 `explanation`
* 全卷題號從 1 連續編到最後一題，不可重複或跳號

<br>

## 估分說明

`estimateBand()` 是**自訂的進度追蹤用估算**，不是官方換算表 —— ETS 尚未公布 2026 新制的 raw-to-band 對照。

| 答對比例 | 估計 Band |
| --- | --- |
| ≥ 95% | 6.0 |
| ≥ 86% | 5.5 |
| ≥ 75% | 5.0 |
| ≥ 64% | 4.5 |
| ≥ 52% | 4.0 |
| ≥ 40% | 3.5 |

目標是穩定落在 **5.0 以上**（36 題要對 27 題以上）。
