import numpy as np 

arrival=[0,5,13,21,29]
departure=[0,8,16,24,32]

n=5

for i in range(n):
    currentArr=arrival+10
    myorder = "|{0}, {1}, {2}, {3}, {4},"
    print(myorder.format(currentArr[0],currentArr[1],currentArr[2],currentArr[3],currentArr[4]))




print('Press any key...')
wait = input()