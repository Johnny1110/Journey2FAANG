# Chasing FAANG Journey

> Journey to the West (FAANG).

<br>

---

<br>

## 2026~2028 訓練重點：

1. 開始整理做的工作經驗，Behavioral 對談模擬，用英文寫出並練習表述。
2. 持續練習英文口說＋寫作。
3. 刷 SQL 考題。
4. 繼續每天刷一題算法，要練習解釋時空間複雜度。
5. 學系統設計，用英文練習回答。

<br>

---

<br>

## Algorithms Training

* 模式覆蓋：這些題目覆蓋了 20+ 種核心算法模式，掌握後可以解決 80% 的面試題
* 難度遞進：從基礎到進階，建立系統性知識
* 高頻出現：這些都是 FAANG 等大廠的真實面試題

<br>

### 學習方法論：

* 每道題都要理解時間/空間複雜度的權衡
* 寫出多種解法，理解優化過程
* 總結通用模板（如滑動窗口、二分查找模板）

<br>

__質量比數量更重要__

<br>

* 訓練集總目錄: -> [link](boost_up_training)
* NeetCode-150: -> [link](boost_up_training/neetcode150)

<br>
<br>

---

<br>
<br>

## SQL Training

* Phase 1-3 是核心，大概佔 6 成的面試題覆蓋率。`JOIN` + `GROUP BY` 是骨架，子查詢教你拆解多步驟問題，Window Function 是中高難度題的殺手鐧。
  
* Phase 4-6 是拉分項，CTE 讓你在面試現場寫出結構清晰的答案（考官會感謝你）。

* Phase 7 不是刷題而是做實驗，Senior 面試追問優化時能有條理地回答，這個你在 PostgreSQL 上有實戰基礎，補一下 EXPLAIN 的系統性理解就夠了。
每個 Phase 都有自我檢測題，過了就往下推。每天 1 題的話大概 14 週能走完，之後就進入隨機刷題階段。

<br>

目錄: -> [link](sql_training)

<br>
<br>

---

<br>
<br>

## System Design

* 跟演算法刷題最大的不同是你沒辦法靠「量」取勝。演算法題刷 200 題你就能涵蓋大部分 pattern，但係統設計題的答案是開放性的，同一題十個人畫出十種架構都可能拿高分。所以大綱的重心不是「題目數」而是組件理解深度 + 框架熟練度 + trade-off 表達能力。

* Phase 0 的四步驟架構是最重要的東西，比任何一道具體題目都重要。面試官評分的主要向度就是：你有沒有主動去釐清需求、有沒有做估算、有沒有講清楚為什麼選這個技術而不是那個。很多人技術很強但面試分數不高，就是因為跳過了需求分析直接畫圖。


* 資源方面，推薦先讀 ByteByteGo（Alex Xu 的 System Design Interview 那兩本書）。它用圖解方式把每道經典題拆解得很清楚，適合建立初始框架。等框架穩了之後再讀 DDIA（Designing Data-Intensive Applications），那本書的理論深度會讓你在 deep dive 環節甩開其他候選人。


目錄: -> [link](system_design_training)

<br>
<br>

---

<br>
<br>

## Technical & Behavioral Interview

* FAANG 每一家都有至少一輪專門的 behavioral round。

    Amazon 甚至是出了名的重視這一輪 — 他們有 16 隻 Leadership Principles，每一條都可能被拿來出題。
    Meta 也有獨立的 behavioral 環節來檢視你的 collaboration 和 conflict resolution。這一輪表現差是可以直接被刷掉的，不是走過場。

* Behavioral 考試的是你能不能用結構化的方式講清楚過去的工作經驗。典型問題像是
  * Tell me about a time you disagreed with your team and how you resolved it」
  * 「Describe a project that failed and what you learned」。
  
* 回答的框架通常用 STAR（Situation → Task → Action → Result），重點是事先準備好 5-8 個你工作中的故事，能靈活套用到不同問題上。

<br>

Behavioral — 準備 5-8 個工作故事，練習用 STAR 框架用英文講述。

<br>

Technical: -> [link](technical_training/README.md)

Behavioral: -> [link](behavioral_training/README.md)


<br>
<br>

---

<br>
<br>

## Bonus

<br>

* 2024/07/19: Algorithm of the shortest route between two subway stations (Taipei MRT) ([solution](bonus/taipei_mrt))
* 2024/07/24: About `[1, 2, 3]` Permutations ([solution](bonus/permutation))
* 2024/10/11: Generate Map Node: PreOrder, PostOrder, LevelOrder ([solution](bonus/map_node_prder))
* 2024/11/16: Hanota ⏳ ([solution](bonus/hanota))
* 2025/01/15: next greater element ([solution](bonus/next_greater_element))
* 2025/09/08: Design Pattern: Composite and Iterator (bonus/composite_and_iterator)

<br>
<br>

## Basic

* Learning about Time Complexity, Space complexity ([link](https://www.bilibili.com/video/BV14j411f7DJ/?spm_id_from=333.337.search-card.all.click&vd_source=9780a181ac9f1fee5f680f255ee5bc73))


<br>
<br>

---

<br>
<br>

## Interview In Action


1. 2026/02/14 __Circle__ Golang Backend 90 mins Algo Test (1面失敗)-> [link](interview_in_action/circle_260214)
2. 2026/03/09 __Binance__ Binance KYC Module Backend Interview (1面過關，2面失敗) -> [link](interview_in_action/binance_260309)
3. 2026/06/02 __MaiCoin__ MaiCoin Blockchain Engineer - Wallet Team (1面 ?) -> [link](interview_in_action/maicoin_260602/README.md)

<br>
<br>

## 免費資源

https://labuladong.online/zh/

<br>
<br>
<br>
<br>

