local export = {}
-- use bit32 for bitwise operations
local bit32 = require("bit32")

-- {{R:ka:GED}}
function export.R_ka_GED(frame)
	local term = frame.args[1]
	local data = [[a:2:{s:12:"word_metauri";s:]] .. string.len(term) .. [[:"]].. term .. [[";s:11:"word_statia";s:0:"";}]]
	return export.encode(data)
end

do local chr, ord, gsub, sub = string.char, string.byte, string.gsub, string.sub

local b64t = {
	[0] =
	'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
	'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
	'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/'
}
local b64r = {}
for k, v in pairs(b64t) do b64r[v] = k end

function export.encode(data)
	return (gsub(data, '..?.?', function (m)
		local b0, b1, b2 = ord(m, 1, 3)

		if not b1 then
			local c0 = bit32.rshift(b0, 2)
			local c1 = bit32.lshift(bit32.band(b0,  3), 4)
			return b64t[c0] .. b64t[c1] .. '=='
		elseif not b2 then
			local c0 = bit32.rshift(b0, 2)
			local c1 = bit32.lshift(bit32.band(b0,  3), 4) + bit32.rshift(b1, 4)
			local c2 = bit32.lshift(bit32.band(b1, 15), 2)
			return b64t[c0] .. b64t[c1] .. b64t[c2] .. '='
		else
			local c0 = bit32.rshift(b0, 2)
			local c1 = bit32.lshift(bit32.band(b0,  3), 4) + bit32.rshift(b1, 4)
			local c2 = bit32.lshift(bit32.band(b1, 15), 2) + bit32.rshift(b2, 6)
			local c3 = bit32.band(b2, 63)
			return b64t[c0] .. b64t[c1] .. b64t[c2] .. b64t[c3]
		end
	end))
end

function export.decode(data)
    local padding = false
    if #data % 4 ~= 0 then
        error('Invalid base64')
    end
	return (gsub(data, '(.)(.)(.)(.)', function (c0, c1, c2, c3)
        local t0, t1, t2, t3 = b64r[c0], b64r[c1], b64r[c2], b64r[c3]

        if padding then
            error('Invalid base64')
        end
        if c2 == '=' and c3 == '=' then
            if not t0 or not t1 then error('Invalid base64') end
            local b0 = bit32.lshift(t0, 2) + bit32.rshift(t1, 4)
            padding = true
            return chr(b0)
        elseif c3 == '=' then
            if not t0 or not t1 or not t2 then error('Invalid base64') end
            local b0 = bit32.lshift(t0, 2) + bit32.rshift(t1, 4)
            local b1 = bit32.band(bit32.lshift(t1, 4) + bit32.rshift(t2, 2), 255)
            padding = true
            return chr(b0) .. chr(b1)
        else
            if not t0 or not t1 or not t2 or not t3 then error('Invalid base64') end
            local b0 = bit32.lshift(t0, 2) + bit32.rshift(t1, 4)
            local b1 = bit32.band(bit32.lshift(t1, 4) + bit32.rshift(t2, 2), 255)
            local b2 = bit32.band(bit32.lshift(t2, 6) + t3                 , 255)
            return chr(b0) .. chr(b1) .. chr(b2)
        end
	end))
end

end

export.enc = export.encode
export.dec = export.decode

return export
