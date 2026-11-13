# 190. Reverse Bits

<br>


---


<br>

## Desc

```
Input: n = 43261596
Output: 964176192

Explanation:

Integer	    Binary
43261596	00000010100101000001111010011100
964176192	00111001011110000010100101000000


```

## Coding

```go
func reverseBits(n int) int {
	val := 0

	for i := 31; i >= 0; i-- {
		a := n / (1 << i)
		if a == 1 {
			x := 31 - i
			val += (1 << x)
		}

		n = n % (1 << i)
	}
	return val
}
```

<br>
<br>

## Time & Space Complexity

```
Assume: 

Time: O(1) -- fix 32 bits
Space: O(1)
```