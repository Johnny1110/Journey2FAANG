package setmatrixzeroes

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
