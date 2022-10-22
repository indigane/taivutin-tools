local export = {}

function export.make_weak(before, strong, after, check)
	local weak = strong
	
	if strong == "pp" then
		weak = "p"
	elseif strong == "tt" then
		weak = "t"
	elseif strong == "kk" then
		weak = "k"
	elseif strong == "bb" then
		weak = "b"
	elseif strong == "dd" then
		weak = "d"
	elseif strong == "gg" then
		weak = "g"
	elseif strong == "p" then
		if mw.ustring.find(before, "p$") then
			weak = ""
		elseif mw.ustring.find(before, "m$") then
			weak = "m"
		else
			weak = "v"
		end
	elseif strong == "t" then
		if mw.ustring.find(before, "t$") then
			weak = ""
		elseif mw.ustring.find(before, "[lnr]$") then
			weak = mw.ustring.sub(before, -1)
		else
			weak = "d"
		end
	elseif strong == "k" then
		if mw.ustring.find(before, "k$") then
			weak = ""
		elseif mw.ustring.find(before, "n$") then
			weak = "g"
		elseif mw.ustring.find(before, "[hlr]$") and mw.ustring.find(after, "^e") then
			weak = "j"
		elseif mw.ustring.find(before .. "|" .. after, "[^aeiouyäö]([uy])|%1") then
			weak = "v"
		else
			weak = ""
		end
	elseif strong == "ik" then
		weak = "j"
	elseif strong == "mp" then
		weak = "mm"
	elseif strong == "lt" then
		weak = "ll"
	elseif strong == "nt" then
		weak = "nn"
	elseif strong == "rt" then
		weak = "rr"
	elseif strong == "nk" then
		weak = "ng"
	end
	
	if weak ~= check then
		require("Module:debug").track("fi-utilities/make weak mismatch")
	end
end

return export
