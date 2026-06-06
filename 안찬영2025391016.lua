local k = require("kutil")

function _1430()
    local a = io.read("*n")
    local b = io.read("*n")
    local c = io.read("*n")
    if not a or not b or not c then 
        return 
    end

    local result = a * b * c
    local resultString = tostring(result)
    
    local counts = {}
    for i = 0, 9 do
        counts[i] = 0
    end
    
    for i = 1, #resultString do
        local digit = tonumber(resultString:sub(i, i))
        counts[digit] = counts[digit] + 1
    end
    
    for i = 0, 9 do
        print(counts[i])
    end
end

function _1658()
    local a = io.read("*n")
    local b = io.read("*n")
    if not a or not b then 
        return 
    end

    local t = {}
    for i = 1, a do
        if a % i == 0 and b % i == 0 then
            t[#t + 1] = i
        end
    end
    print(t[#t])    
    print(a * b / t[#t])  
end

local function GetGcd(a, b)
    while b ~= 0 do
        local r = a % b
        a = b
        b = r
    end
    return a
end

local function GetLcm(a, b)
    return (a / GetGcd(a, b)) * b
end

function _1002()
    local n = io.read("*n")
    if not n or n < 1 then 
        return 
    end

    local finalGcd = io.read("*n")
    local finalLcm = finalGcd

    for i = 2, n do
        local num = io.read("*n")
        finalGcd = GetGcd(finalGcd, num)
        finalLcm = GetLcm(finalLcm, num)
    end
    
    io.write(finalGcd .. " " .. finalLcm .. "\n")
end

function _1009()
    while true do
        local num = io.read("*n")
        if not num or num == 0 then 
            break 
        end
        
        local reverseNum = 0 
        local digitSum = 0  
        local temp = num    
        
        while temp > 0 do
            local remainder = temp % 10               
            reverseNum = (reverseNum * 10) + remainder
            digitSum = digitSum + remainder       
            temp = math.floor(temp / 10)             
        end
        
        print(reverseNum .. " " .. digitSum)
    end
end

function _2811()
    for i = 1, 5 do
        local num = io.read("*n")
        if not num then 
            return
        end
        
        if num == 1 then
            print("number one")
        else
            local isPrime = true
            local limit = math.floor(math.sqrt(num))
            for j = 2, limit do
                if num % j == 0 then 
                    isPrime = false 
                    break           
                end
            end
            
            if isPrime then
                print("prime number")
            else
                print("composite number")
            end
        end
    end
end

local function IsPrime(num)
    if num < 2 then 
        return false 
    end
    local limit = math.floor(math.sqrt(num))
    for i = 2, limit do
        if num % i == 0 then
            return false
        end
    end
    return true
end

function _1740()
    local m = io.read("*n")
    local n = io.read("*n")
    if not m or not n then
        return
    end

    local totalSum = 0
    local minPrime = nil 
    
    for i = m, n do
        if IsPrime(i) then
            totalSum = totalSum + i
            if minPrime == nil then
                minPrime = i
            end
        end
    end
    
    if minPrime == nil then
        print(-1)
    else
        print(totalSum)
        print(minPrime)
    end
end

local base = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local function ToDecimal(s, a)
    local dec = 0
    s = string.upper(s)
    for i = 1, #s do
        local char = string.sub(s, i, i)
        local val = string.find(base, char) - 1
        dec = dec * a + val
    end
    return dec
end

local function FromDecimal(dec, b)
    if dec == 0 then
        return "0"
    end
    local result = ""
    while dec > 0 do
        local remainder = (dec % b) + 1
        local char = string.sub(base, remainder, remainder)
        result = char .. result
        dec = math.floor(dec / b)
    end
    return result
end

function _3106()
    local input = io.read("*l")
    if not input then 
        return 
    end
    
    local aString, s, bString = input:match("(%S+)%s+(%S+)%s+(%S+)")
    
    if not aString or not s or not bString then 
        return  
    end
    
    local a = tonumber(aString)
    local b = tonumber(bString)
    
    local dec = ToDecimal(s, a)
    local result = FromDecimal(dec, b)
    print(result)
end

