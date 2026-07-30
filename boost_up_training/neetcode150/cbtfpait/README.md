# 105. Construct Binary Tree from Preorder and Inorder Traversal

<br>

---

<br>

## Desc

Given two integer arrays preorder and inorder where preorder is the preorder traversal of a binary tree and inorder is the inorder traversal of the same tree, construct and return the binary tree.

* Preorder (前序) -> 順序是根節點、左子節點、右子節點，根排在前面。
* Inorder (中序) -> 順序是左子節點、根節點、右子節點，根排在中間。
* Postorder (後序) -> 順序是左子節點、右子節點、根節點，根排在後面。
* Level-order (層序) -> 順序是由根節點一層一層往下，由左往右。

<br>

Wiki: -> [link](https://ithelp.ithome.com.tw/articles/10205571#:~:text=%E7%9B%AE%E5%89%8D%E7%90%86%E8%AB%96%E4%B8%8A%E6%9C%89%E5%9B%9B%E7%A8%AE%E8%BC%B8%E5%87%BA%E9%A0%86%E5%BA%8F%EF%BC%9A,%E5%B1%A4%E5%BA%8F%E9%81%8D%E6%AD%B7(Level%2Dorder%20Traversal))

<br>

* pre: `[3, 9, 20, 15, 7]`
* in: `[9, 3, 15, 20, 7]`

* output: 

```
      3
    /   \
   9     20
        /   \
       15    7    
```

<br>

Hint: -> [link](https://chatgpt.com/share/6a6ac8fa-9964-83ee-821e-a53ca1584fae)

<br>
<br>

## Coding

```go
func buildTree(preorder []int, inorder []int) *TreeNode {
	if len(preorder) == 0 {
		return nil
	}

	root := newNode(preorder[0])
	inorderRootIdx := orderSearch(root.Val, inorder)

	leftRemainSize := inorderRootIdx

	// build root.Left
	left := buildTree(preorder[1:leftRemainSize+1], inorder[:inorderRootIdx])
	// build root.Right
	right := buildTree(preorder[leftRemainSize+1:], inorder[inorderRootIdx+1:])

	root.Left = left
	root.Right = right

	return root
}

func orderSearch(target int, vals []int) int {
	for i, val := range vals {
		if val == target {
			return i
		}
	}
	return -1
}

func newNode(val int) *TreeNode {
	return &TreeNode{
		Val: val,
	}
}
```

<br>
<br>

## Time & Space Enhancement

```
Assume: nodeSize = N, treeHieght = M

Time: O(N²)
Space: O(M) -> recursive max call stacks
```

<br>
<br>

## Optimization

The most expensive part is `orderSearch(...)`, so we can create a map[val][index].

this design will improve O(n) search to O(1).

and also, instead of using recursive calls, we can change to using:

```
build(
    preLeft,
    preRight,
    inLeft,
    inRight,
)
```

<br>

## Coding - 2

```go
func buildTree(preorder []int, inorder []int) *TreeNode {
	if len(preorder) == 0 {
		return nil
	}

	inMap := make(map[int]int)
	for i, val := range inorder {
		inMap[val] = i
	}

	var build func(preLeft, preRight, inLeft, inRight int) *TreeNode
	build = func(preLeft, preRight, inLeft, inRight int) *TreeNode {

		if preLeft > preRight {
			return nil
		}

		root := newNode(preorder[preLeft])
		rootIdxOnInorder := inMap[root.Val]    // 1
		leftCount := rootIdxOnInorder - inLeft // 1 - 0 = 1
		//rightCount := inRight - rootIdxOnInorder // 4 - 1 = 3

		// left
		root.Left = build(preLeft+1, preLeft+leftCount, inLeft, rootIdxOnInorder-1)
		//right
		root.Right = build(preLeft+leftCount+1, preRight, rootIdxOnInorder+1, inRight)

		return root
	}

	return build(0, len(preorder)-1, 0, len(inorder)-1)
}

func newNode(val int) *TreeNode {
	return &TreeNode{
		Val: val,
	}
}
```

* 203/203 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 8.92 % of golang submissions (6.3 MB)