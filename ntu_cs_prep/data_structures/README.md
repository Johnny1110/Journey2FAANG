# 筆試科目 I：資料結構

> 80 分鐘手寫考試。你的 NeetCode 底子已經 cover 觀念，這裡要練的是「紙筆答題模式」：畫圖、追蹤過程、證明複雜度、名詞解釋。

<br>

## 與 NeetCode 的關鍵差異

| NeetCode（線上刷題） | 台大筆試（紙筆） |
|---------------------|----------------|
| 寫出能 AC 的程式 | 手畫資料結構每一步變化（AVL 旋轉、heap 建堆） |
| 複雜度自己心裡有數 | 要**寫出推導過程**（遞迴式、攤銷分析） |
| 不考名詞定義 | 名詞解釋是送分題（例：何謂 stable sort？何謂 complete binary tree？） |
| 用慣用語言 | 常要求 pseudo code 或 C，注重正確性不注重語法糖 |

<br>

## 主題清單與高頻考點

### 1. 複雜度分析
- [ ] Big-O / Big-Ω / Big-Θ 定義（會考數學定義！）
- [ ] 常見遞迴式求解：T(n)=2T(n/2)+n、T(n)=T(n-1)+n、Master Theorem 基本型
- [ ] 給程式碼段求時間複雜度（雙迴圈、對半、遞迴）

### 2. Array / Linked List
- [ ] 單向／雙向／環狀鏈結串列的插入刪除（畫圖＋pseudo code）
- [ ] 反轉 linked list 手寫
- [ ] Array vs Linked List 操作複雜度比較表

### 3. Stack / Queue
- [ ] 中序 → 後序（postfix）轉換手算 ★超高頻
- [ ] Postfix 運算式求值（用 stack 追蹤）
- [ ] 用兩個 stack 實作 queue（反之亦然）
- [ ] Circular queue 的 front/rear 指標運算

### 4. Tree
- [ ] Preorder / Inorder / Postorder / Level-order 走訪 ★超高頻
- [ ] 由 preorder+inorder（或 postorder+inorder）重建樹 ★超高頻
- [ ] Complete / Full / Skewed binary tree 定義與節點數性質（n₀ = n₂ + 1）
- [ ] BST 插入、刪除（三種 case：葉、單子、雙子）
- [ ] Threaded binary tree（概念）
- [ ] Expression tree

### 5. 平衡樹與多路樹
- [ ] AVL：LL / RR / LR / RL 四種旋轉，逐步插入畫圖 ★高頻
- [ ] B-tree / B+ tree：插入分裂、刪除合併，2-3 tree / 2-3-4 tree
- [ ] Red-Black tree（性質即可，通常不考細節）

### 6. Heap
- [ ] Max/Min heap 定義、array 表示法（parent = i/2）
- [ ] Build-heap（bottom-up O(n) 的理由要會講）
- [ ] Insert / delete-max 追蹤
- [ ] Heap sort 逐步過程

### 7. Hashing
- [ ] Hash function 設計：division、mid-square、folding
- [ ] 碰撞處理：chaining、linear probing、quadratic probing、double hashing（手算填表 ★高頻）
- [ ] Load factor 與效能關係、rehashing

### 8. Graph
- [ ] 表示法：adjacency matrix vs adjacency list（空間比較）
- [ ] BFS / DFS 走訪順序手寫 ★高頻
- [ ] Topological sort（Kahn's / DFS 法）
- [ ] MST：Prim、Kruskal 逐步執行 ★高頻
- [ ] Shortest path：Dijkstra 表格法追蹤 ★高頻，Bellman-Ford / Floyd-Warshall（概念）
- [ ] Connected components、articulation point（概念）

### 9. Sorting
- [ ] Insertion / Selection / Bubble / Merge / Quick / Heap / Radix 全部要會**手動追蹤前幾回合** ★超高頻
- [ ] 複雜度總表（best / average / worst / space / stable）要能默寫
- [ ] Quick sort worst case 何時發生、如何避免（median-of-three、random pivot）
- [ ] 何時選哪個排序（幾乎排好→insertion；連結串列→merge；範圍小整數→counting/radix）

### 10. Searching 與其他
- [ ] Binary search 手寫（含邊界證明）
- [ ] Union-Find（含 path compression 概念）
- [ ] KMP failure function 手算（偶爾出現）

<br>

## 資源

* 📖 聖經本：Horowitz, *Fundamentals of Data Structures in C*（台灣資結考試的出題根據地）
* 🎬 台大開放式課程（NTU OCW）：搜尋「資料結構與演算法」（蔡欣穆老師版本在 YouTube 也找得到）
* 🎬 你已有的 [labuladong](https://labuladong.online/zh/) 拿來補觀念
* 🔗 NeetCode 已刷題目 → 每章複習時回頭對應：Tree 章對應你刷過的 binary tree 題、Graph 章對應 graph 題，把「寫過的 code」轉述成「紙上的圖與文字」

<br>

## 練習卷紀錄

> 用 `ntu: 出題 {主題}` 請 Claude 出卷，卷子放 `weekXX_{topic}/README.md`，作答放同資料夾 `answer.md`，再用 `score: ntu {資料夾}` 評分。

| 日期 | 練習卷 | 分數 | 檢討重點 |
|------|--------|------|----------|
| | | | |
