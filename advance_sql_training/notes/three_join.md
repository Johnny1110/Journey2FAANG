# Nested Loop / Hash / Merge Join 三種 Join 演算法

<br>

---

<br>

## 三種 Join 演算法

Join 本質是 "對每一列 outer，找出 inner 中符合條件的列" 的配對問題．配對問題只有三類解法：

* 暴力比對: Nested Loop
* 建立索引/雜湊表 O(1) 查找: Hash Join
* 先排序，然後用雙指標線性掃: Merge Join

<br>
<br>

## Nested Loop Join

```go
for _, o := range outer {
    for _, i := range inner {
        if match(0, i) {
            emit(o, i)
        }
    }
}
```

Time Complexity: `O(N * M)`

但是如果 inner 那層有 index 就不一樣了:

```go
for _, o := range outer {
    for _, i := range indexLookup(inner, o.key) { // O(log M)
        emit(o, i)
    }
}
```

Time Complexity: `O(N * log M)`

這會是比較常見的 Nested Loop + Index Scan 組合．

#### 優勢

* outer 很小 (幾千列)，inner 有 index -> 幾乎無成本
* `LIMIT 10` 查詢 -> 拿到 10 rows 就停了，不用跑完全部 loop．


<br>
<br>

## Hash Join

Hash Join 分兩個階段

### 階段 1: Build - 把 inner (較小的那邊) 全部 load 到 Hash Table

```go
ht := make(map[Key][]Row)
for _, i := range inner {
    ht[i.key] = append(ht[i.key], i)
}
```

### 階段 2: Probe - outer 掃一次，每列查表


```go
for _, o := range outer {
    for _, i := range ht[o.key] {
        emit(o, i)
    }
}
```

Time Complexity: `O(N + M)`

代價：

* 組塞 (blocking): build 階段必須組塞，跑完 build 才能進 probe 階段邊跑邊吐結果．
* 吃記憶體：雜湊表要塞進 `work_mem`

#### 記憶體不夠怎麼辦 → Hybrid Hash Join（Grace Hash Join）：

用 hash 值的高位元把兩邊都切成 N 個 batch 寫到 temp file。因為 `hash(k)` 相同的列必定落在同一個 batch，所以 batch 之間互不相干，可以一個一個處理。

在 `EXPLAIN ANALYZE` 看到這個就是 spill 了：

```
Buckets: 1024  Batches: 16  Memory Usage: 4096kB
```

`Batches > 1`  代表有寫磁碟。通常代表 `work_mem` 太小，或列數估計失準（更常見的原因）。

限制：只支援等值條件（`=`，且該型別要有 hash opclass）。

<br>
<br>

## Merge Join

前提：兩邊都已經按照 __join key__ 排序．然後用 2 pointers 掃描：

```go
i, j := 0, 0
for i < len(L) && j < len(R) {
    switch {
        case L[i].key < R[j].key:
            i++
        case L[i].key > R[j].key:
            j++
        default:
            // equals -> process
    }
}
```

麻煩在重複值。若左邊有 3 個 `k=5`、右邊有 2 個 `k=5`，要輸出 6 組笛卡兒積。單純的雙指標做不到，需要 __mark / restore (倒帶)__：

```
L: 5 5 5 6      R: 5 5 7
   ^               ^ mark 在這

配完 (L0,R0)(L0,R1) → R 走到 7，L 前進到 L1
L1 也是 5 → restore：R 倒帶回 mark (R0)
配完 (L1,R0)(L1,R1) → 再 restore
...

```

這也是為什麼 merge join 對 inner 需要能倒帶的輸入（Materialize 節點常出現在這裡）。

#### 何時為優勢

* 兩邊 __本來就有序__（走 index scan，排序免費）→ 大表 join 大表的最佳解
* 需要輸出有序結果（後面接 `ORDER BY` / `MERGE JOIN` 串接）
* 記憶體壓力比 Hash Join 小（sort 可以外部排序，且是循序 I/O）

#### 何時為劣勢

* 要為了 join 額外做兩次 Sort。那多半不如直接 Hash Join。