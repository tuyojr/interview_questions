
def solution(values, K, L):
    n = len(values)
    for i in range(0, n):
        if values[i] > K:
            return False
    return all(values.count(v) <= L for v in set(values))