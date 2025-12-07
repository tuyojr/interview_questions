# Array Validation Problem

## Problem Description

You are given an implementation of a function:

```python
def solution(values, K, L)
```

that, for a given array `values` of N integers and integers K and L, should return `True` if:

- no element of array `values` appears more than L times;
- `values` does not contain any numbers bigger than K.

Otherwise, the function should return `False`.

## Examples

1. Given `values = [1, 1, 4, 4]`, `K = 4` and `L = 2`, the function should return `True`.

2. Given `values = [1, 1, 2, 4]`, `K = 4` and `L = 1`, the function should return `False`. Number 1 appears in the array twice, which is more than L.

3. Given `values = [4, 2, 5]`, `K = 5` and `L = 2`, the function should return `True`.

## Task

The attached code is still incorrect for some inputs. Despite the error(s), the code may produce a correct answer for the example test cases. The goal of the exercise is to find and fix the bug(s) in the implementation. You can modify at most three lines.

## Constraints

Assume that:

- N is an integer within the range [1..100,000];
- L is an integer within the range [1..N];
- K is an integer within the range [1..1,000,000,000];
- each element of array `values` is an integer within the range [1..1,000,000,000].

## Note

In your solution, focus on correctness. The performance of your solution will not be the focus of the assessment.
