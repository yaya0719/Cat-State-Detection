import math

# 封閉式解: det(A_n) = (1/sqrt(5)) * [ ((3+sqrt(5))/2)^(n+1) - ((3-sqrt(5))/2)^(n+1) ]
def closed_form_det(n):
    sqrt5 = math.sqrt(5)
    r1 = (3 + sqrt5) / 2
    r2 = (3 - sqrt5) / 2
    return (1 / sqrt5) * (r1**(n + 1) - r2**(n + 1))

# 遞迴法
def recursive_det(n):
    if n == 1:
        return 3
    elif n == 2:
        return 8
    else:
        D = [0] * (n + 1)
        D[1] = 3
        D[2] = 8
        for i in range(3, n + 1):
            D[i] = 3 * D[i - 1] - D[i - 2]
        return D[n]

# 檢查前幾項是否一致
results = []
for n in range(1, 11):
    recur = recursive_det(n)
    closed = round(closed_form_det(n))
    results.append((n, recur, closed, recur == closed))

results
