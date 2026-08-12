# 127. Word Ladder

<br>

---

<br>

## Example

```
Input: beginWord = "hit", endWord = "cog", wordList = ["hot","dot","dog","lot","log","cog"]
Output: 5

Explanation: One shortest transformation sequence is:
"hit" -> "hot" -> "dot" -> "dog" -> cog"
which is 5 words long.
```

<br>
<br>

## Coding 

```go
type WordQueue []string

func (q *WordQueue) Len() int {
	return len(*q)
}

func (q *WordQueue) Push(val string) {
	*q = append(*q, val)
}

func (q *WordQueue) Pop() string {
	val := (*q)[0]
	*q = (*q)[1:]
	return val
}

func ladderLength(beginWord string, endWord string, wordList []string) int {
	wordLen := len(beginWord)
	idxLetterSet := make([]map[uint8]bool, wordLen) // slice index is beginWord index map key is possible letter could be.
	graphState := make(map[string]int)              // 1 valid, 2 visited

	for i := range wordLen {
		idxLetterSet[i] = make(map[uint8]bool)
	}

	for _, word := range wordList {
		graphState[word] = 1 // init graph state
		for i, letter := range word {
			idxLetterSet[i][uint8(letter)] = true
		}
	}

	if graphState[endWord] != 1 {
		return 0 // no way to find result.
	}

	queue := WordQueue([]string{})
	level := 0

	queue.Push(beginWord)
	graphState[beginWord] = 2

	for queue.Len() > 0 {
		level++

		levelLen := queue.Len()
		for range levelLen {
			word := queue.Pop()

			bytes := []byte(word)

			for i, b := range bytes {

				letterSet := idxLetterSet[i] // map[uint8]bool

				for alp, _ := range letterSet {
					bytes[i] = alp

					tw := string(bytes)

					if tw == endWord {
						return level + 1
					}

					if graphState[tw] != 1 {
						continue // skip if already visited or invalid.
					}

					queue.Push(tw)
					graphState[tw] = 2
				}

				// recover word
				bytes[i] = b
			}
		}
	}

	return 0
}
```

* 57/57 cases passed (100 ms)
* Your runtime beats 49.26 % of golang submissions
* Your memory usage beats 42.14 % of golang submissions (9.3 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: M = wordLen, N = size of wordList

Time: O(N · M²)
Space: O(N · M)
```