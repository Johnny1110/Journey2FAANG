# Interview In Action Strengthen Training

<br>

---

<br>

## Weakness

1. 2026/06/04 - 數字處理類型問屜不夠敏銳，array 類問題思考不夠準確快速

    * 數字處理類型的部分要更多練習，要對數字更加敏感．像是 float 如果有精度問題 `149.9999991` or `150.0000001` 需要更多的練習熟悉．
    * 對於 array 處理直覺不夠敏銳 (一個字串型態的數字，要數有幾個小數位數需要想很久。)

<br>

## Reinforcement Learning

> 針對 Weakness 紀錄挑選的 LeetCode 練習題，練到能 blind 75 等級的流暢度。

### 數字處理 & 精度敏感度

> 目標：建立整數運算直覺，避開浮點精度陷阱，溢位判斷自動化。

| # | 題號 | 題目 | 練習重點 |
|---|------|------|----------|
| 1 | 7 | Reverse Integer | 32-bit 溢位判斷 (`> math.MaxInt32/10`) |
| 2 | 9 | Palindrome Number | 純數字反轉，不用字串，後半反轉比較 |
| 3 | 29 | Divide Two Integers | 位元運算模擬除法，邊界 `math.MinInt32 / -1` |
| 4 | 67 | Add Binary | 字串進位加法，從右往左遍歷 |
| 5 | 69 | Sqrt(x) | 整數平方根，二分查找邊界 |
| 6 | 149 | Max Points on a Line | 斜率用 GCD 化成分數避開浮點精度 |
| 7 | 166 | Fraction to Recurring Decimal | 長除法模擬，循環小數檢測，HashMap 記錄餘數位置 |
| 8 | 415 | Add Strings | 字串數字加法，carry 進位處理 |

### Array / String 索引直覺

> 目標：two-pointer、從後遍歷、split 解析等基本操作變成肌肉記憶。

| # | 題號 | 題目 | 練習重點 |
|---|------|------|----------|
| 1 | 58 | Length of Last Word | 從後往前遍歷，跳過 trailing spaces |
| 2 | 125 | Valid Palindrome | two-pointer + 跳過非字母數字 |
| 3 | 151 | Reverse Words in a String | 反轉 + 多餘空格處理，in-place 思維 |
| 4 | 165 | Compare Version Numbers | 用 `strings.Split(version, ".")` 解析數字，對齊比較 |
| 5 | 344 | Reverse String | 雙指針原地反轉 |
| 6 | 392 | Is Subsequence | two-pointer 子序列判斷 |
| 7 | 680 | Valid Palindrome II | two-pointer + 最多刪除一個字元的判斷 |

