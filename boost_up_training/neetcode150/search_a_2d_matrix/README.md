# 74. Search a 2D Matrix

<br>

---

<br>

You are given an `m x n` integer matrix, matrix with the following two properties:

* Each row is sorted in non-decreasing order.
* The first integer of each row is greater than the last integer of the previous row.

Given an integer target, return true if target is in matrix or false otherwise.

You must write a solution in O(log(m * n)) time complexity.

<br>

## Coding


```go
func searchMatrix(matrix [][]int, target int) bool {
	m, n := len(matrix), len(matrix[0])
	// locate row (bin search):
	mid := 0
	left, right := 0, m-1
	for left <= right {
		mid = (left + right) / 2
		val := matrix[mid][0]
		if val == target { // spot on
			return true
		} else if val > target {
			right = mid - 1
		} else {
			left = mid + 1
		}
	}

	row := left - 1
	if row < 0 {
		row = 0
	}

	// locate col (bin search):
	col := 0
	left, right = 0, n-1
	for left <= right {
		col = (left + right) / 2
		val := matrix[row][col]
		if val == target { // spot on
			return true
		} else if val > target {
			right = col - 1
		} else {
			left = col + 1
		}
	}

	return false
}
```

## Time & Space Complixity

```
Assume: m = row count, n = col count

Time: O(log2(m) * log2(n))

Space: O(1)
```

## Feedback (Round 1)

**Score: 6 / 10** — see issues below, all addressed in Coding - 2.

---

## Feedback (Round 2 — Coding - 2)

**Score: 8 / 10**

### What's improved
- Dead code removed, row selection simplified to `row = right`. Clean and correct.

### What still needs attention

**1. Time complexity is still not quite right.** You wrote `O(log2(m) + log2(n))`. While `O(log m + log n)` is technically correct, the problem asks for **O(log(m*n))**. You should explicitly state the equivalence:

```
Time: O(log m + log n) = O(log(m*n))
```

Because `log(a) + log(b) = log(a*b)`. In an interview, the interviewer wants to hear `O(log(m*n))` to match the constraint.

**2. Try the single-pass approach.** You can treat the entire matrix as a flattened sorted array of length `m*n`. Map index `i` → `matrix[i/n][i%n]` and do one binary search. This eliminates the row-selection logic entirely and is the "canonical" solution for this problem:

```go
func searchMatrix(matrix [][]int, target int) bool {
    m, n := len(matrix), len(matrix[0])
    left, right := 0, m*n-1
    for left <= right {
        mid := (left + right) / 2
        val := matrix[mid/n][mid%n]
        if val == target {
            return true
        } else if val > target {
            right = mid - 1
        } else {
            left = mid + 1
        }
    }
    return false
}
```

Give it a try — it'll build confidence with binary search, which you mentioned is a weak area.

<br>

---

<br>

## Coding - 2

```go
func searchMatrix(matrix [][]int, target int) bool {
	m, n := len(matrix), len(matrix[0])
	// locate row (bin search):
	mid := 0
	left, right := 0, m-1
	for left <= right {
		mid = (left + right) / 2
		val := matrix[mid][0]
		if val == target { // spot on
			return true
		} else if val > target {
			right = mid - 1
		} else {
			left = mid + 1
		}
	}

	row := right
	if row < 0 {
		row = 0
	}

	// locate col (bin search):
	col := 0
	left, right = 0, n-1
	for left <= right {
		col = (left + right) / 2
		val := matrix[row][col]
		if val == target { // spot on
			return true
		} else if val > target {
			right = col - 1
		} else {
			left = col + 1
		}
	}

	return false
}
```

## Time Space Complixity

```
Time: O(log2(m) + log2(n))
```

## Coding - 3

```go
func searchMatrix(matrix [][]int, target int) bool {
	m, n := len(matrix), len(matrix[0])
	left, right := 0, m*n-1
	for left <= right {
		mid := (left + right) / 2
		val := matrix[mid/n][mid%n]
		if val == target {
			return true
		} else if val > target {
			right = mid - 1
		} else {
			left = mid + 1
		}
	}
	return false
}
```

```
Time: O(log(m*n))
Space: O(1)
```

## Feedback (Round 3 — Coding - 3)

**Score: 10 / 10**

This is the canonical solution. Single binary search on the flattened matrix using `mid/n` and `mid%n` for index mapping. Clean, correct, and hits the required `O(log(m*n))` bound.

No further improvements needed on this problem. Good progression from the original two-pass approach.