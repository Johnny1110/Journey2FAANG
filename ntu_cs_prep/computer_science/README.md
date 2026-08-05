# 筆試科目 II：計算機概論

> 80 分鐘手寫考試。範圍最廣的一科，也是你目前最大的缺口。策略：先建骨架（每個領域的 3～5 個核心概念），再用考古題決定深挖哪裡。

<br>

## 出題特性

計概不是要你每科都到專業課深度，而是考「廣度＋正確的基本觀念」：

* 名詞解釋與比較題（process vs thread、TCP vs UDP、compiler vs interpreter）
* 小計算題（進位轉換、2's complement、scheduling 平均等待時間、cache 概念計算）
* 申論題（輸入網址後發生什麼事、deadlock 如何預防）
* 趨勢題（AI/ML、資安近年常出現，寫得出正確名詞與一兩句原理就有分）

<br>

## 主題清單與高頻考點

### 1. 數字系統與資料表示
- [ ] 二／八／十六進位互轉 ★送分題，要快要準
- [ ] 2's complement 表示負數、加減法、overflow 判斷 ★高頻
- [ ] IEEE 754 浮點數格式（sign/exponent/mantissa）、為何 0.1+0.2 ≠ 0.3
- [ ] ASCII / Unicode / UTF-8 概念

### 2. 數位邏輯（基礎即可）
- [ ] AND/OR/NOT/XOR/NAND/NOR 真值表
- [ ] 布林代數化簡、De Morgan 定律
- [ ] 半加器／全加器概念

### 3. 計算機組織
- [ ] Von Neumann 架構、fetch-decode-execute cycle ★高頻
- [ ] CPU 元件：ALU、Control Unit、Register（PC、IR、MAR、MDR 各自作用）
- [ ] Pipeline 概念與 hazard（結構／資料／控制）
- [ ] Memory hierarchy：register → cache → RAM → disk，為何有效（locality！）★高頻
- [ ] Cache：hit/miss、direct-mapped vs set-associative（概念）
- [ ] RISC vs CISC 比較
- [ ] 中斷（interrupt）與 DMA

### 4. 作業系統 ★計概最重的一塊
- [ ] Process vs Thread、process 狀態圖（new/ready/running/waiting/terminated）★超高頻
- [ ] Context switch 是什麼、成本在哪
- [ ] Scheduling：FCFS / SJF / Priority / Round-Robin，**手算平均等待與周轉時間** ★超高頻
- [ ] 同步：race condition、critical section、mutex vs semaphore
- [ ] Deadlock 四條件、預防／避免（Banker's algorithm 概念）／偵測 ★高頻
- [ ] 記憶體管理：paging vs segmentation、virtual memory、page fault
- [ ] Page replacement：FIFO / LRU / Optimal 手算 ★高頻
- [ ] File system 基礎、inode 概念

### 5. 計算機網路
- [ ] OSI 七層 vs TCP/IP 四層，每層代表協定與設備 ★超高頻
- [ ] TCP vs UDP：差異、三次握手、各自應用場景 ★超高頻
- [ ] IP 定址：IPv4 分級、子網路遮罩計算、IPv4 vs IPv6
- [ ] 「在瀏覽器輸入網址後發生什麼事」：DNS → TCP → TLS → HTTP → render ★經典申論
- [ ] HTTP vs HTTPS、常見狀態碼、cookie/session
- [ ] 交換器 vs 路由器、MAC vs IP

### 6. 資料庫（與 sql_training 直接整合）
- [ ] Relational model：primary key / foreign key
- [ ] 正規化 1NF → BCNF：目的與判斷 ★高頻
- [ ] SQL 基本操作（你已經很熟，直接收割）
- [ ] Transaction 與 ACID ★高頻
- [ ] Index 原理（B+ tree，和資結章節互相呼應）
- [ ] SQL vs NoSQL 比較

### 7. 程式語言與軟體工程
- [ ] Compiler vs Interpreter、直譯／編譯／JIT
- [ ] OOP 四大特性：封裝、繼承、多型、抽象（要能各舉一例）
- [ ] Call by value vs call by reference
- [ ] 遞迴 vs 迭代
- [ ] 軟體開發週期、Waterfall vs Agile（概念）

### 8. 資訊安全與趨勢（近年愛考）
- [ ] 對稱式 vs 非對稱式加密、雜湊函數用途、數位簽章
- [ ] 常見攻擊：phishing、SQL injection、XSS、DDoS（原理一句話）
- [ ] AI/ML 名詞：supervised vs unsupervised、deep learning、LLM、overfitting
- [ ] 雲端運算：IaaS / PaaS / SaaS

<br>

## 資源

* 📖 骨架書：Brookshear, *Computer Science: An Overview*（計概課本經典，中譯本《計算機概論》）
* 🎬 [Crash Course Computer Science](https://www.youtube.com/playlist?list=PL8dPuuaLjXtNlUrzyH5r6jN9ulIgZBpdo)（40 集，每集 10 分鐘，英文字幕——順便練你的英文聽力，一舉兩得）
* 🎬 台大開放式課程（NTU OCW）／清大開放式課程：搜尋「計算機概論」「作業系統」（清大周志遠 OS 課是華語圈名課）
* 🎬 Harvard CS50x：計概廣度＋英文，適合當週末補充
* 🔗 OS 與計組是兩大重點，考古題寫完後如果發現這兩塊被電，再回來加深

<br>

## 練習卷紀錄

> 用 `ntu: 出題 {主題}` 請 Claude 出卷，作答放同資料夾 `answer.md`，再用 `score: ntu {資料夾}` 評分。

| 日期 | 練習卷 | 分數 | 檢討重點 |
|------|--------|------|----------|
| | | | |
