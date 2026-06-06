local k = require("kutil")

function _1692(a, b)
    
    local ones = b % 10          
    local tens = math.floor((b % 100) / 10) 
    local hundreds = math.floor(b / 100)    
    
    local step3 = a * ones
    local step4 = a * tens
    local step5 = a * hundreds
    local step6 = a * b
    print(step3)
    print(step4)
    print(step5)
    print(step6)
end

function _1430(a, b, c)
    local total = a * b * c
    
    local total_str = tostring(total)
    
    local counts = {}
    for i = 0, 9 do
        counts[i] = 0
    end
    
    for i = 1, #total_str do
        local digit = tonumber(total_str:sub(i, i))
        
        counts[digit] = counts[digit] + 1
    end
    
    for i = 0, 9 do
        print(counts[i])
    end
end

function _1071(a)

    local t = {2, 3, 5, 12, 18, 24}
local m = 0
local n = 0
    for i = 1, #t do
        if t[i] % a == 0 then
            n = n + t[i]          
        end
        if a % t[i] == 0 then
            m = m + t[i]
        end
    end
    print(m)
    print(n)
end

function _1402(n, k)
    local t = {}
    for i = 1, n do
        if n % i == 0 then
            t[#t + 1] = i
        end
    end
    if #t < k then
        print(0)
    else
        print(t[k])
    end
end

function _2809(n)
    local t = {}
    for i = 1, n do
        if n % i == 0 then
            t[#t + 1] = i
        end
    end
    for i = 1, #t do
        io.write(t[i] .. " ")
    end
end

function _1658(a, b)
    local t = {}
    for i = 1, a do
        if a % i == 0 and b % i == 0 then
            t[#t + 1] = i
        end
    end
    print(t[#t])    
    print(a * b / t[#t])  
end

local function get_gcd(a, b)
    while b ~= 0 do
        local r = a % b
        a = b
        b = r
    end
    return a
end
local function get_lcm(a, b)
    return (a / get_gcd(a, b)) * b
end

function _1002(...)
    local t = {...}
    
    local final_gcd = t[1]
    local final_lcm = t[1]
    
    for i = 2, #t do
        final_gcd = get_gcd(final_gcd, t[i])
        final_lcm = get_lcm(final_lcm, t[i])
    end
    
    io.write(final_gcd .." ".. final_lcm .. "\n")
end

local function get_gcd(a, b)
    while b ~= 0 do
        local r = a % b
        a = b
        b = r
    end
    return a
end

local function get_lcm(a, b)
    return (a / get_gcd(a, b)) * b
end

function _5545(p, v, k)
    local paint_cycle = p + 1
    local gloss_cycle = v + 1
    
    local total_paint_fail = math.floor(k / paint_cycle)
    local total_gloss_fail = math.floor(k / gloss_cycle)
    
    local both_fail_cycle = get_lcm(paint_cycle, gloss_cycle)

    local b = math.floor(k / both_fail_cycle)
    local c = total_gloss_fail - b
    local d = total_paint_fail - b
    local a = k - (b + c + d)
    
    print(a .. " " .. b .. " " .. c .. " " .. d)
end

function _1009(...)
    local numbers = {...}
    
    for i = 1, #numbers do
        local num = numbers[i]
        
        if num == 0 then 
            break 
        end
        
        local reverse_num = 0 
        local digit_sum = 0  
        local temp = num    
        
        while temp > 0 do
            local remainder = temp % 10               
            reverse_num = (reverse_num * 10) + remainder
            digit_sum = digit_sum + remainder       
            
            temp = math.floor(temp / 10)             
        end
        
        print(reverse_num .. " " .. digit_sum)
    end
end

function _2811(a, b, c, d, e)
    local t = {a, b, c, d, e}
    
    for i = 1, #t do
        local num = t[i]
        
        if num == 1 then
            print("number one")
            
        else
            local is_prime = true
            
            local limit = math.floor(math.sqrt(num))
            for j = 2, limit do
                if num % j == 0 then
                    is_prime = false 
                    break           
                end
            end
            
            if is_prime then
                print("prime number")
            else
                print("composite number")
            end
        end
    end
end

local function is_prime(num)
    if num < 2 then return false end
    local limit = math.floor(math.sqrt(num))
    for i = 2, limit do
        if num % i == 0 then
            return false
        end
    end
    return true
end

function _1901(...)
    local numbers = {...}
    
    for i = 1, #numbers do
        local m = numbers[i]
        
        local left_prime = m
        while left_prime >= 2 and not is_prime(left_prime) do
            left_prime = left_prime - 1
        end
        
        local right_prime = m
        while not is_prime(right_prime) do
            right_prime = right_prime + 1
        end
        
        local left_dist = (left_prime >= 2) and (m - left_prime) or math.huge
        local right_dist = right_prime - m
        
        if left_dist < right_dist then
            print(left_prime)
        elseif right_dist < left_dist then
            print(right_prime)
        else
            if left_prime == right_prime then
                print(left_prime)
            else
                print(left_prime .. " " .. right_prime)
            end
        end
    end
end


local function is_prime(num)
    if num < 2 then return false end
    local limit = math.floor(math.sqrt(num))
    for i = 2, limit do
        if num % i == 0 then
            return false
        end
    end
    return true
end

function _1740(m, n)
    local total_sum = 0
    local min_prime = nil 
    
    for i = m, n do
        if is_prime(i) then
            total_sum = total_sum + i
            
            if min_prime == nil then
                min_prime = i
            end
        end
    end
    
    if min_prime == nil then
        print(-1)
    else
        print(total_sum)
        print(min_prime)
    end
end

function _2813(m, n)
local count = 0

for i = m, n do
    if i > 1 then
        local is_prime = true
        local limit = math.floor(math.sqrt(i))
        
        for j = 2, limit do
            if i % j == 0 then
                is_prime = false
                break
            end
        end
        
        if is_prime then
            count = count + i / i
        end
    end
end
print(count)
end

function _2814(binary_input)
    local binary_str = tostring(binary_input)
    local decimal = 0
    local power = 1
    
    for i = #binary_str, 1, -1 do
        local bit = string.sub(binary_str, i, i)
        if bit == "1" then
            decimal = decimal + power
        end
        power = power * 2
    end
    
    print(decimal)
end

function _1534(n, b)
    local digits = "0123456789ABCDEF"
    local result = ""
    
    if n == 0 then return "0" end
    
    while n > 0 do
        local remainder = (n % b) + 1
        local char = string.sub(digits, remainder, remainder)
        result = char .. result
        n = math.floor(n / b)
    end
    
    print(result)
end

local BASE_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local function to_decimal(s, a)
    local dec = 0
    s = string.upper(s) 
    
    for i = 1, #s do
        local char = string.sub(s, i, i)
        local val = string.find(BASE_CHARS, char) - 1
        dec = dec * a + val
    end
    return dec
end

local function from_decimal(dec, b)
    if dec == 0 then return "0" end
    
    local result = ""
    while dec > 0 do
        local remainder = (dec % b) + 1
        local char = string.sub(BASE_CHARS, remainder, remainder)
        result = char .. result
        dec = math.floor(dec / b)
    end
    return result
end

function _3106(a, s, b)
    s = tostring(s) 
    
    local dec = to_decimal(s, a)
    local result = from_decimal(dec, b)
    
    print(result)
end

function _4977(n)
    local int_part = math.floor(n)
    local frac_part = n - int_part
    
    local int_bin = ""
    if int_part == 0 then
        int_bin = "0"
    else
        while int_part > 0 do
            local remainder = int_part % 2
            int_bin = remainder .. int_bin
            int_part = math.floor(int_part / 2)
        end
    end
    
    local frac_bin = ""
    for i = 1, 4 do
        frac_part = frac_part * 2
        local bit = math.floor(frac_part)
        frac_bin = frac_bin .. bit
        frac_part = frac_part - bit 
    end
    
    print(int_bin .. "." .. frac_bin)
end