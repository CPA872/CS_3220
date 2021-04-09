nums = [4, 2, 3, 1, 6, 5, 9, 7, 10, 8]
nums = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
for i in range(len(nums)):
    for j in range(i + 1, len(nums)):
        if nums[i] > nums[j]:
            temp = nums[i]
            nums[i] = nums[j]
            nums[j] = temp

print(nums)
