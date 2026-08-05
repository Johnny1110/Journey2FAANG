# Phase 0 診斷考

> 目的：找出兩科目前水位，決定六個月計畫的火力分配。不是要考好，是要誠實暴露弱點。
>
> **規則**：兩科各 45 分鐘，手寫或打字皆可，**不查資料**。不會就寫「不會」，這對診斷最有價值。
> 作答寫在本資料夾 `answer.md`，完成後對 Claude 說 `score: ntu mock_exams/00_diagnostic`。

<br>

---

## 第一科：資料結構（50 分，45 分鐘）

**1.（8 分）** 寫出下列各段程式的時間複雜度（Big-O），並用一句話說明理由：

```c
// (a)
for (i = 0; i < n; i++)
    for (j = 0; j < n; j = j + 2)
        sum++;

// (b)
for (i = 1; i < n; i = i * 2)
    sum++;

// (c) 遞迴式 T(n) = 2T(n/2) + n, T(1) = 1
// (d) 遞迴式 T(n) = T(n-1) + 1, T(1) = 1
```

**2.（6 分）** 完成下表（填入平均時間複雜度）：

| 操作 | Array | Singly Linked List |
|------|-------|--------------------|
| 隨機存取第 k 個元素 | | |
| 已知位置後插入元素 | | |
| 搜尋某值 | | |

**3.（6 分）** 將中序運算式 `A + B * C - ( D / E )` 轉為後序（postfix）運算式，並寫出轉換時 stack 的變化過程（至少列出 3 個關鍵時刻的 stack 內容）。

**4.（8 分）** 某二元樹的走訪結果：
* Preorder：`A B D E C F`
* Inorder：`D B E A C F`

(a) 畫出這棵樹。(b) 寫出 Postorder。

**5.（8 分）** 依序將 `50, 30, 70, 20, 40, 60, 80, 35` 插入一棵空的 BST：
(a) 畫出最終的樹。(b) 刪除節點 `30` 之後畫出結果（說明你採用的刪除策略）。

**6.（6 分）** 將陣列 `[3, 9, 2, 1, 4, 5]` 用 bottom-up 方式建成 **max-heap**，畫出建堆完成後的陣列內容，並簡述為什麼 bottom-up build-heap 是 O(n) 而不是 O(n log n)。

**7.（4 分）** Hash table 大小 7，hash function 為 `h(k) = k mod 7`，用 **linear probing** 依序插入 `10, 24, 31, 17, 21`，畫出最終表格（index 0～6）。

**8.（4 分）** 下列排序法哪些是 stable？哪些 worst case 為 O(n²)？
`Insertion sort, Selection sort, Merge sort, Quick sort, Heap sort`

<br>

---

## 第二科：計算機概論（50 分，45 分鐘）

**1.（6 分）**
(a) 將十進位 `156` 轉為二進位與十六進位。
(b) 用 8-bit 2's complement 表示 `-37`。
(c) 8-bit 2's complement 能表示的整數範圍是？

**2.（4 分）** 為什麼在多數程式語言中 `0.1 + 0.2 != 0.3`？請從浮點數表示法的角度解釋。

**3.（6 分）** 簡述 CPU 的 fetch–decode–execute cycle，並說明 Program Counter（PC）在其中的角色。

**4.（6 分）** 什麼是 memory hierarchy？為什麼 cache 能有效提升效能？（提示：locality）

**5.（6 分）** 比較 process 與 thread：定義、資源共享方式、context switch 成本，各舉一個適用場景。

**6.（8 分）** 三個 process 同時在 time 0 抵達：

| Process | Burst Time |
|---------|-----------|
| P1 | 24 |
| P2 | 3 |
| P3 | 3 |

分別用 (a) FCFS（依 P1→P2→P3 順序）與 (b) SJF 排程，計算兩種方式的**平均等待時間**，並說明結果差異的原因。

**7.（4 分）** 寫出 deadlock 發生的四個必要條件。

**8.（6 分）** 比較 TCP 與 UDP：可靠性、連線方式、速度，各舉一個典型應用。TCP 三次握手的過程是什麼？

**9.（6 分）** 在瀏覽器輸入 `https://www.ntu.edu.tw` 按下 Enter 後，到頁面顯示為止發生了哪些事？請依序描述（至少涵蓋 DNS、TCP、HTTP 三個環節）。

**10.（4 分）** 名詞解釋（各 2 分，各 2～3 句話）：
(a) 資料庫的 ACID 特性
(b) Supervised learning vs Unsupervised learning
