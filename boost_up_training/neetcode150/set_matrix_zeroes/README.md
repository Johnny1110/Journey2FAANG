# 73. Set Matrix Zeroes

<br>

---

<br>

## Coding

```go
type Direction int

const UP Direction = 1
const DOWN Direction = 2
const LEFT Direction = 3
const RIGHT Direction = 4

func setZeroes(matrix [][]int) {
	// find all 0 at first
	// dfs expolore.
	idxs := [][]int{} // could replace with 1D array.
	for i := 0; i < len(matrix); i++ {
		for j := 0; j < len(matrix[i]); j++ {
			if matrix[i][j] == 0 {
				idxs = append(idxs, []int{i, j})
			}
		}
	}

	var dfs func(d Direction, row, col int)
	dfs = func(d Direction, row, col int) {
		// return
		if row < 0 || row >= len(matrix) || col < 0 || col >= len(matrix[0]) {
			return
		}

		// change current spot
		matrix[row][col] = 0

		// calc next idx
		switch d {
		case UP:
			row--
		case DOWN:
			row++
		case LEFT:
			col--
		case RIGHT:
			col++
		}
		dfs(d, row, col)
	}

	for _, idx := range idxs {
		row, col := idx[0], idx[1]
		dfs(UP, row, col)
		dfs(DOWN, row, col)
		dfs(LEFT, row, col)
		dfs(RIGHT, row, col)
	}
}
```

* 203/203 cases passed (65 ms)
* Your runtime beats 5.66 % of golang submissions
* Your memory usage beats 7.27 % of golang submissions (9.4 MB)


<br>
<br>

## Coding

```go
type Direction int

const UP Direction = 1
const DOWN Direction = 2
const LEFT Direction = 3
const RIGHT Direction = 4

func setZeroes(matrix [][]int) {
	// find all 0 at first
	// dfs expolore.
	idxs := [][]int{} // could replace with 1D array.
	for i := 0; i < len(matrix); i++ {
		for j := 0; j < len(matrix[i]); j++ {
			if matrix[i][j] == 0 {
				idxs = append(idxs, []int{i, j})
			}
		}
	}

	var dfs func(d Direction, row, col int)
	dfs = func(d Direction, row, col int) {
		// return
		if row < 0 || row >= len(matrix) || col < 0 || col >= len(matrix[0]) {
			return
		}

		// change current spot
		matrix[row][col] = 0

		// calc next idx
		switch d {
		case UP:
			row--
		case DOWN:
			row++
		case LEFT:
			col--
		case RIGHT:
			col++
		}
		dfs(d, row, col)
	}

	for _, idx := range idxs {
		row, col := idx[0], idx[1]
		dfs(UP, row, col)
		dfs(DOWN, row, col)
		dfs(LEFT, row, col)
		dfs(RIGHT, row, col)
	}
}
```

<br>
<br>

## Coding - 2

```go
func setZeroes(matrix [][]int) {
	// find all 0 at first
	// dfs expolore.
	idxs := [][]int{} // could replace with 1D array.
	for i := 0; i < len(matrix); i++ {
		for j := 0; j < len(matrix[i]); j++ {
			if matrix[i][j] == 0 {
				idxs = append(idxs, []int{i, j})
			}
		}
	}

	for _, idx := range idxs {
		row, col := idx[0], idx[1]
		for i := 0; i < len(matrix); i++ {
			matrix[i][col] = 0
		}
		for i := 0; i < len(matrix[row]); i++ {
			matrix[row][i] = 0
		}
	}
}
```

* 203/203 cases passed (34 ms)
* Your runtime beats 5.66 % of golang submissions
* Your memory usage beats 5.05 % of golang submissions (11.2 MB)


<br>
<br>

## Time & Space Complexity

```
Let m = rows, n = cols, k = number of zeros

Coding-1 (DFS):
  Time:  O(m*n + k*(m+n)) — scan + 4-direction DFS per zero
  Space: O(k) for idxs + O(m+n) call stack per DFS

Coding-2 (final, .go file):
  Time:  O(m*n + k*(m+n)) — scan + zero full row & col per zero
         Worst case (all zeros): O(m*n*(m+n)) due to repeated work
  Space: O(k) — up to O(m*n) in the worst case
```

---

## Score: 5 / 10

### What you did well
- Correctly collected original zero positions **before** mutating the matrix — avoiding the classic bug of marking new zeros as original zeros.
- Coding-2 removed the unnecessary DFS and is much simpler than Coding-1. Good self-improvement!

### Issues

**1. Repeated work on shared rows/columns**

If two zeros share the same row, you zero that row twice (once per zero). Same for columns. In the worst case (all cells are 0) this makes the algorithm `O(m*n*(m+n))`.

**2. Extra space for `idxs`**

You can do this with `O(m+n)` or even `O(1)` extra space.

---

## Hint — can you improve further?

**Step 1 → O(m*n) time, O(m+n) space**

Instead of storing every zero coordinate, store only *which rows* and *which cols* need to be zeroed (two boolean arrays/sets of size m and n). Then do a second pass to zero them. Each row/col is zeroed exactly once → no repeated work.

```
rows[i] = true  // row i needs zeroing
cols[j] = true  // col j needs zeroing
```

**Step 2 → O(m*n) time, O(1) space** *(the optimal solution)*

Hint: the matrix itself has a first row and a first column. Can you repurpose them as your `rows[]` and `cols[]` markers instead of allocating extra arrays? Be careful about the first row/col themselves — handle them separately.

Try implementing Step 1 first, then Step 2 if you want the optimal result.

---

## Coding - 3

```go
func setZeroes(matrix [][]int) {
	m, n := len(matrix), len(matrix[0])

	rows := make([]bool, m)
	cols := make([]bool, n)

	for i := 0; i < len(matrix); i++ {
		for j := 0; j < len(matrix[0]); j++ {
			if matrix[i][j] == 0 {
				rows[i], cols[j] = true, true
			}
		}
	}

	for row, clear := range rows {
		if clear {
			// row need clear to zero
			for i := 0; i < n; i++ {
				matrix[row][i] = 0
			}
		}
	}

	for col, clear := range cols {
		if clear {
			for i := 0; i < m; i++ {
				matrix[i][col] = 0
			}
		}
	}
}
```

* 203/203 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 79.81 % of golang submissions (8.3 MB)

---

## Coding - 4


```go
func setZeroes(matrix [][]int) {
	m, n := len(matrix), len(matrix[0])

	// handle first row
	for i := 0; i < n; i++ {
		if matrix[0][0] != 0 && matrix[0][i] == 0 {
			matrix[0][0] = 0
			break
		}
	}

	// handle first col
	for i := 0; i < m; i++ {
		if matrix[0][0] != 0 && matrix[i][0] == 0 {
			matrix[0][0] = 0
			break
		}
	}

	// run others
	for row := 1; row < m; row++ {
		for col := 1; col < n; col++ {
			if matrix[row][col] == 0 {
				matrix[0][col] = 0
				matrix[row][0] = 0
			}
		}
	}

	fmt.Printf("matrix: %v \n", matrix)

	for col := 0; col < n; col++ {
		if matrix[0][col] == 0 {
			// all | should -> o
			for row := 1; row < m; row++ {
				matrix[row][col] = 0
			}
		}
	}

	for row := 0; row < m; row++ {
		if matrix[row][0] == 0 {
			// all -- should -> o
			for col := 1; col < n; col++ {
				matrix[row][col] = 0
			}
		}
	}

	// handle first row or col
	for row := 0; row < m; row++ {
		if matrix[row][0] == 0 {
			// clear all |
			for row := 0; row < m; row++ {
				matrix[row][0] = 0
			}
			break
		}
	}

	for col := 0; col < n; col++ {
		if matrix[0][col] == 0 {
			// clear all --
			for col := 0; col < n; col++ {
				matrix[0][col] = 0
			}
			break
		}
	}
}
```

---

## Score: 9 / 10 (Coding-3), 4 / 10 (Coding-4)

### Coding-3 (O(m+n) space) — 9/10

**What you did well**
- Clean, readable, and correct. Using two boolean arrays (`rows[]`, `cols[]`) to track which rows/cols need zeroing is the textbook intermediate solution.
- Each row and column is zeroed **exactly once** — no repeated work. This brings the time complexity to strict `O(m*n)` regardless of zero distribution.
- Submission result: **0ms, beats 100%** — excellent.

**Why not 10?**
- You didn't push to the optimal O(1) space solution. For a FAANG interview, they'd likely ask: "Can you do this with constant extra space?" after seeing the O(m+n) version.
- Minor: the two separate zeroing loops (rows, then cols) are fine, but a single `for i for j` with `if rows[i] || cols[j]` would be slightly more concise. Not a real issue.

---

### Coding-4 (O(1) space attempt) — 4/10

**The idea is correct** — using the first row and first column as in-place markers is the optimal approach.

**But the implementation has bugs:**

**1. First row / first col detection is broken**

You use `matrix[0][0]` as a single flag for BOTH "first row has a zero" and "first col has a zero". One cell can't encode two independent booleans. The standard solution uses a **separate variable** (e.g., `firstRowHasZero bool`) to decouple them.

**2. Marker interpretation is wrong in the final cleanup**

At lines 307-335, you check `if matrix[row][0] == 0` to decide whether to zero the entire first column. But `matrix[row][0]` could be 0 as a **marker** (meaning "row `row` has a zero somewhere"), not as an indicator that the first column needs zeroing. Same bug for the first row. This causes incorrect zeroing.

Example that fails:
```
[1, 2, 3]
[4, 0, 6]
[7, 8, 9]
```

Expected:
```
[1, 0, 3]
[0, 0, 0]
[7, 0, 9]
```

Your Coding-4 would zero both the first row and first column incorrectly.

**3. Variable shadowing** — the inner `for row := 0` / `for col := 0` shadows the outer loop variable. It technically works but is a code smell.

**4. Debug `fmt.Printf` left in** (line 296).

---

### How to fix Coding-4 (O(1) space)

The standard in-place approach:

1. Use a single `bool` variable `firstRowZero` to remember if the first row originally had a zero.
2. Use `matrix[0][0]` only for "first column has a zero" (or vice versa).
3. Scan the submatrix `[1..m-1][1..n-1]`, use `matrix[i][0]` and `matrix[0][j]` as markers.
4. Zero based on markers (submatrix first, then first row/col based on the flags).

Try re-implementing with this in mind. The key insight: **one cell = one flag**. You can't pack two independent pieces of information into `matrix[0][0]` without a separate variable.
```

## Coding - 4

```go
func setZeroes(matrix [][]int) {
	m, n := len(matrix), len(matrix[0])

	firstRowHasZero := false

	// handle first row
	for i := 0; i < n; i++ {
		if matrix[0][i] == 0 {
			firstRowHasZero = true
			break
		}
	}

	// handle first col
	for i := 0; i < m; i++ {
		if matrix[i][0] == 0 {
			matrix[0][0] = 0
			break
		}
	}

	// run others
	for row := 1; row < m; row++ {
		for col := 1; col < n; col++ {
			if matrix[row][col] == 0 {
				matrix[0][col] = 0
				matrix[row][0] = 0
			}
		}
	}

	//fmt.Printf("matrix: %v \n", matrix)

	//--------------------------------------
	for col := 1; col < n; col++ {
		if matrix[0][col] == 0 {
			for row := 1; row < m; row++ {
				matrix[row][col] = 0
			}
		}
	}

	for row := 1; row < m; row++ {
		if matrix[row][0] == 0 {
			for col := 1; col < n; col++ {
				matrix[row][col] = 0
			}
		}
	}

	// handle first row & col
	if matrix[0][0] == 0 {
		for row := 0; row < m; row++ {
			matrix[row][0] = 0
		}
	}

	if firstRowHasZero {
		for col := 0; col < n; col++ {
			matrix[0][col] = 0
		}
	}
}
```


* 203/203 cases passed (1 ms)
* Your runtime beats 40 % of golang submissions
* Your memory usage beats 84.66 % of golang submissions (8.1 MB)
