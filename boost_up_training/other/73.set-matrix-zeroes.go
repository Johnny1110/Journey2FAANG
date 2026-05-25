/*
 * @lc app=leetcode id=73 lang=golang
 *
 * [73] Set Matrix Zeroes
 */

// @lc code=start
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

// @lc code=end

