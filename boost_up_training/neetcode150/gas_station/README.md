# 134. Gas Station

<br>

---

<br>

## Thinking

```
gas  = [1,2,3,4,5]
cost = [3,4,5,1,2]
```

1. Feasibility is decided by the totals. If sum(gas) >= sum(cost), a valid start always exists. If not, none does. So you never need to search to decide whether an answer exists — only where it is.

2. Failed starts can be skipped in bulk. Suppose you start at i and your tank goes negative when you arrive at station j. Then no station strictly between i and j can be a valid start either. 

    __Why: to have reached some station k in that range from i, your tank was ≥ 0 on arrival at k. Starting fresh at k you'd have exactly 0 there, which is ≤ what you had before — so you'd run dry at j too, or sooner.__ That means you can jump the candidate start all the way to j + 1 instead of retrying i+1, i+2, and so on.

<br>
<br>

## Coding

```go
func canCompleteCircuit(gas []int, cost []int) int {
	n := len(gas)
	start := 0

	for start < n {
		tank, i, step := 0, start, 0

		for step < n {
			tank += gas[i] - cost[i] // fillin: +gas[i]  payout: -cost[i]
			if tank < 0 {
				break
			}

			i = (i + 1) % n
			step++
		}

		if step == n {
			return start
		}

		if i < start {
			return -1 // stop
		}

		start = i + 1 // every start in [start, i] is invalid
	}
	return -1
}
```

* 40/40 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 14.25 % of golang submissions (13 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = station count

Time: O(N)
Space: O(1)
```