# NRDF Project
# Kieran Molloy

def decodeGA(encodedSolution):
    # Decode GA Problem as defined here###
    
    # Deconstruct Solution String into Elements
    operator=encodedSolution[0:2]
    line=encodedSolution[2:8]
    rollingStock=encodedSolution[8:12]
    origin=encodedSolution[12:20]
    stations=encodedSolution[20:-8]
    destination=encodedSolution[-8:]
    print(operator)
    print(line)
    print(rollingStock)
    print(origin)
    print(stations)
    print(destination)




if __name__ == "__main__":
    testString="01234567890123456789012345678901234567890"
    decodeGA(testString)
    print("Everything passed")