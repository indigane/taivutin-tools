local m_utilities = require("Module:utilities")
local m_links = require("Module:links")
local m_bit32 = require("bit32")

local export = {}

local lang = require("Module:languages").getByCode("fi")

-- Functions that do the actual inflecting by creating the forms of a basic term.
local inflections = {}

local kotus_grad_type = {
	["kk-k"] = "A",
	["pp-p"] = "B",
	["tt-t"] = "C",
	["k-"] = "D",
	["p-v"] = "E",
	["t-d"] = "F",
	["nk-ng"] = "G",
	["mp-mm"] = "H",
	["lt-ll"] = "I",
	["nt-nn"] = "J",
	["rt-rr"] = "K",
	["k-j"] = "L",
	["k-v"] = "M"
}

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local infl_type = frame.args[1] or error("Inflection type has not been specified. Please pass parameter 1 to the module invocation")
	local args = frame:getParent().args
	local infl_types = {infl_type}
	
	infl_types = mw.text.split(infl_type, "%-")
	
	for _, type in ipairs(infl_types) do
		if not inflections[type] then
			error("Unknown inflection type '" .. infl_type .. "'")
		end
	end
	
	local pos = args["pos"]; if not pos or pos == "" then pos = "noun" end
	local allow_possessive = pos == "noun" or pos == "adj" and not args["noposs"]
	
	-- initialize data for full inflection process
	local data = {argpos = 1, num = 1, words = {}}
	local argobj = {args = args, pos = 1}
	local extra = ""
	local poss_forms = {}
	local vh = nil
	
	for num, infl_type in ipairs(infl_types) do
		-- initialize data for single word
		local word_data = {forms = {}, title = nil, categories = {}}
		
		-- word index
		word_data.num = num
		data.num = num
		
		-- Generate the forms
		inflections[infl_type](argobj, word_data)
		postprocess_word(argobj, word_data, num == #infl_types)
		word_data.class = infl_type
		data["words"][num] = word_data

		-- generate possessive forms (nom.sg. only)
		if allow_possessive and not args["poss"] then
			generate_possessive_forms(poss_forms, argobj, word_data, num == #infl_types)
		end
	end
	
	if #(data["words"]) == 1 then
		vh = data["words"][1]["vh"]
	end

	-- table
	if allow_possessive and next(poss_forms) ~= nil then
		extra = make_possessive_table(args, poss_forms, pos, infl_type)
	end

	-- join the inflected word components
	export.join_words(data, function (n) return args["space" .. tostring(n)] or args["space"] or " " end)
	
	-- Postprocess
	postprocess(args, data)
	
	if args["type"] then
		table.insert(data.categories, "fi-decl with type")
	end
	
	if args["nocheck"] then
		table.insert(data.categories, "fi-decl with nocheck")
	end
	
	if args["nosg"] then
		table.insert(data.categories, "fi-decl with nosg")
	end
	
	if args["nopl"] then
		table.insert(data.categories, "fi-decl with nopl")
	end
	
	return make_table(data, vh) .. extra .. m_utilities.format_categories(data.categories, lang)
		.. require("Module:TemplateStyles")("Module:fi-nominals/style.css")
end

function get_params(argobj, num, invert_grades)
	local params = {}
	local args = argobj.args
	local pos = argobj.pos
	
	if num == 5 then
		params.base = args[pos] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{1}}}"); if not params.base or params.base == "" then error("Parameter " .. tostring(pos) .. " (base stem) may not be empty.") end
		params.strong = args[pos + 1] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{2}}}"); if not params.strong then error("Parameter " .. tostring(pos + 1) .. " (nominative grade) may not be omitted.") end
		params.weak = args[pos + 2] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{3}}}"); if not params.weak then error("Parameter " .. tostring(pos + 2) .. " (genitive grade) may not be omitted.") end
		params.final = args[pos + 3] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{4}}}"); if not params.final or params.final == "" then error("Parameter " .. tostring(pos + 3) .. " (final letter(s)) may not be empty.") end
		params.a = args[pos + 4] or (mw.title.getCurrentTitle().nsText == "Template" and "a"); if params.a ~= "a" and params.a ~= "ä" then error("Parameter " .. tostring(pos + 4) .. " must be \"a\" or \"ä\".") end
	elseif num == 4 then
		params.base = args[pos] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{1}}}"); if not params.base or params.base == "" then error("Parameter " .. tostring(pos) .. " (base stem) may not be empty.") end
		params.strong = args[pos + 1] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{2}}}"); if not params.strong then error("Parameter " .. tostring(pos + 1) .. " (nominative grade) may not be omitted.") end
		params.weak = args[pos + 2] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{3}}}"); if not params.weak then error("Parameter " .. tostring(pos + 2) .. " (genitive grade) may not be omitted.") end
		params.a = args[pos + 3] or (mw.title.getCurrentTitle().nsText == "Template" and "a"); if params.a ~= "a" and params.a ~= "ä" then error("Parameter " .. tostring(pos + 3) .. " must be \"a\" or \"ä\".") end
	elseif num == 2 then
		params.base = args[pos] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{1}}}"); if not params.base or params.base == "" then error("Parameter " .. tostring(pos) .. " (base stem) may not be empty.") end
		params.a = args[pos + 1] or (mw.title.getCurrentTitle().nsText == "Template" and "a"); if params.a ~= "a" and params.a ~= "ä" then error("Parameter " .. tostring(pos + 1) .. " must be \"a\" or \"ä\".") end
	elseif num == 1 then
		params.base = args[pos] or ""
	end
	
	-- Swap the grades
	if invert_grades then
		params.strong, params.weak = params.weak, params.strong
	end
	
	if params.a then
		params.o = params.a == "ä" and "ö" or "o"
		params.u = params.a == "ä" and "y" or "u"
	end
	
	argobj.pos = argobj.pos + num
	return params	
end

function get_extra_arg(argobj, wdata, name)
	return argobj.args[name .. wdata.num] or argobj.args[name]
end

local make_weak = require("Module:fi-utilities").make_weak

--[=[
	Inflection functions
]=]--

local stem_endings = {}

stem_endings["nom_sg"] = {
	["nom_sg"] = "",
}

stem_endings["sg"] = {
	["ess_sg"] = "na",
}

stem_endings["sg_weak"] = {
	["gen_sg"] = "n",
	["ine_sg"] = "ssa",
	["ela_sg"] = "sta",
	["ade_sg"] = "lla",
	["abl_sg"] = "lta",
	["all_sg"] = "lle",
	["tra_sg"] = "ksi",
	["ins_sg"] = "n",
	["abe_sg"] = "tta",
	["nom_pl"] = "t",
}

stem_endings["par_sg"] = {
	["par_sg"] = "a",
}

stem_endings["ill_sg"] = {
	["ill_sg"] = "Vn",
}

stem_endings["pl"] = {
	["ess_pl"] = "na",
	["com_pl"] = "ne",
}

stem_endings["pl_weak"] = {
	["ine_pl"] = "ssa",
	["ela_pl"] = "sta",
	["ade_pl"] = "lla",
	["abl_pl"] = "lta",
	["all_pl"] = "lle",
	["tra_pl"] = "ksi",
	["ins_pl"] = "n",
	["abe_pl"] = "tta",
}

stem_endings["par_pl"] = {
	["par_pl"] = "a",
}

stem_endings["gen_pl"] = {
	["gen_pl"] = "en",
}

stem_endings["ill_pl"] = {
	["ill_pl"] = "Vn",
}

-- data for generating possessive forms
-- suffixes per person
local poss_forms = {["1s"] = "ni",
					["2s"] = "si",
					["3s"] = "nsa",
					["1p"] = "mme",
					["2p"] = "nne"}
local poss_forms_optimized = {
					["00"] = "",
					["3s"] = "nsa"}
local poss_alt = {  ["00"] = false,
					["1s"] = false,
					["2s"] = false,
					["3s"] = true, -- shorter form -Vn
					["1p"] = false,
					["2p"] = false}
-- which forms allow -nsa > -Vn?
local forms_alt_ok = {
	["gen_sg"] = false, ["gen_pl"] = false,
	["par_sg"] = false, ["par_pl"] = true,
	["ine_sg"] = true, ["ine_pl"] = true,
	["ela_sg"] = true, ["ela_pl"] = true,
	["ill_sg"] = false, ["ill_pl"] = false,
	["ade_sg"] = true, ["ade_pl"] = true,
	["abl_sg"] = true, ["abl_pl"] = true,
	["all_sg"] = true, ["all_pl"] = true,
	["ess_sg"] = true, ["ess_pl"] = true,
	["tra_sg"] = true, ["tra_pl"] = true,
	["ins_sg"] = false, ["ins_pl"] = false,
	["abe_sg"] = true, ["abe_pl"] = true,
	["com_sg"] = true, ["com_pl"] = true,
}
-- which forms end in -n?
-- (in which case it is dropped before the possessive suffix)
local forms_gen_ok = {
	["gen_sg"] = true, ["gen_pl"] = true,
	["ill_sg"] = true, ["ill_pl"] = true,
	["ins_sg"] = true, ["ins_pl"] = true,
}

-- Make a copy of the endings, with front vowels
stem_endings = {["a"] = stem_endings, ["ä"] = mw.clone(stem_endings)}

for stem_key, endings in pairs(stem_endings["ä"]) do
	for key, ending in pairs(endings) do
		endings[key] = mw.ustring.gsub(endings[key], "([aou])", {["a"] = "ä", ["o"] = "ö", ["u"] = "y"})
	end
end

-- Create any stems that were not given
local function make_stems(data, stems)
	if not stems["nom_sg"] and stems["sg"] then
		stems["nom_sg"] = mw.clone(stems["sg"])
	end
	
	if not stems["par_sg"] and stems["sg"] then
		stems["par_sg"] = mw.clone(stems["sg"])
	end
	
	if not stems["ill_sg"] and stems["sg"] then
		stems["ill_sg"] = {}
		
		for _, stem in ipairs(stems["sg"]) do
			-- If the stem ends in a long vowel or diphthong, then add -h
			if mw.ustring.find(stem, "([aeiouyäö])%1$") or mw.ustring.find(stem, "[aeiouyäö][iyü]$") then
				table.insert(stems["ill_sg"], stem .. "h")
			else
				table.insert(stems["ill_sg"], stem)
			end
		end
	end
	
	if not stems["par_pl"] and stems["pl"] then
		stems["par_pl"] = {}
		
		for _, stem in ipairs(stems["pl"]) do
			table.insert(stems["par_pl"], stem)
		end
	end
	
	if not stems["gen_pl"] and stems["par_pl"] then
		stems["gen_pl"] = {}
		
		for _, stem in ipairs(stems["par_pl"]) do
			-- If the partitive plural stem ends in -it, then replace the t with d or tt
			if mw.ustring.find(stem, "it$") then
				table.insert(stems["gen_pl"], (mw.ustring.gsub(stem, "t$", "d")))
				table.insert(stems["gen_pl"], stem .. "t")
			else
				table.insert(stems["gen_pl"], stem)
			end
		end
	end
	
	if not stems["ill_pl"] and stems["pl"] then
		stems["ill_pl"] = {}
		
		for _, stem in ipairs(stems["pl"]) do
			table.insert(stems["ill_pl"], stem)
		end
	end
end

-- Create forms based on each stem, by adding endings to it
local function process_stems(data, stems, vh)
	if not stems["sg_weak"] and stems["sg"] then
		stems["sg_weak"] = mw.clone(stems["sg"])
	end
	
	if not stems["pl_weak"] and stems["pl"] then
		stems["pl_weak"] = mw.clone(stems["pl"])
	end
	
	-- Go through each of the stems given
	for stem_key, substems in pairs(stems) do
		for _, stem in ipairs(substems) do
			-- Attach the endings to the stem
			for form_key, ending in pairs(stem_endings[vh][stem_key]) do
				if not data.forms[form_key] then
					data.forms[form_key] = {}
				end
				
				-- "V" is a copy of the last vowel in the stem
				if mw.ustring.find(ending, "V") then
					local vowel = mw.ustring.match(stem, "([aeiouyäö])[^aeiouyäö]*$")
					ending = mw.ustring.gsub(ending, "V", vowel or "?")
				end
				
				table.insert(data.forms[form_key], stem .. ending)
			end
		end
	end
	
	data["stems"] = stems
	data["vh"] = vh
end


local function merge_stems(stems_a, stems_b)
	local stems_m = {}
	-- implying same keys for both stems
	for stem_key, substems in pairs(stems_a) do
		stems_m[stem_key] = mw.clone(substems)
		for _, bstem in pairs(stems_b[stem_key] or {}) do
			table.insert(stems_m[stem_key], bstem)
		end
	end
	return stems_m
end


inflections["valo"] = function(args, data)
	data.title = "[[Kotus]] type 1/[[Appendix:Finnish nominal inflection/valo|valo]]"
	table.insert(data.categories, "Finnish valo-type nominals")
	
	local params = get_params(args, 5)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local wk_sg = params.weak
	local wk_pl = params.weak
	
	if mw.ustring.sub(params.base, -1) == params.final then
		if wk_sg == "" and (mw.ustring.find(params.base, "[aeiouyäö][iuy]$") or mw.ustring.find(params.base, "[iuy][eoö]$")) then
			wk_sg = "’"
		end
		
		if wk_pl == "" then
			wk_pl = "’"
		end
	end
	
	local stems = {}
	stems["sg"]      = {params.base .. params.strong .. params.final}
	stems["sg_weak"] = {params.base .. wk_sg .. params.final}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["pl_weak"] = {params.base .. wk_pl .. params.final .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. params.final .. "j"}
	stems["ill_pl"]  = {params.base .. params.strong .. params.final .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["palvelu"] = function(args, data)
	data.title = "[[Kotus]] type 2/[[Appendix:Finnish nominal inflection/palvelu|palvelu]], no gradation"
	table.insert(data.categories, "Finnish palvelu-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["sg"]      = {params.base}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "j", params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["valtio"] = function(args, data)
	data.title = "[[Kotus]] type 3/[[Appendix:Finnish nominal inflection/valtio|valtio]], no gradation"
	table.insert(data.categories, "Finnish valtio-type nominals")
	
	local params = get_params(args, 2)
	local final = mw.ustring.sub(params.base, -1)
	
	local stems = {}
	stems["sg"]      = {params.base}
	stems["par_sg"]  = {params.base .. "t"}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["laatikko"] = function(args, data)
	data.title = "[[Kotus]] type 4/[[Appendix:Finnish nominal inflection/laatikko|laatikko]]"
	table.insert(data.categories, "Finnish laatikko-type nominals")
	
	local params = get_params(args, 5, false, "kk", "k", "o")
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems = {}
	stems["sg"]      = {params.base .. params.strong .. params.final}
	stems["sg_weak"] = {params.base .. params.weak .. params.final}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["pl_weak"] = {params.base .. params.weak .. params.final .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. params.final .. "j", params.base .. params.weak .. params.final .. "it"}
	stems["ill_pl"]  = {params.base .. params.strong .. params.final .. "ih", params.base .. params.weak .. params.final .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["risti"] = function(args, data)
	data.title = "[[Kotus]] type 5/[[Appendix:Finnish nominal inflection/risti|risti]]"
	table.insert(data.categories, "Finnish risti-type nominals")
	
	local params = get_params(args, 4)
	local i = get_extra_arg(args, data, "i"); if i == "0" then i = "" else i = "i" end
	
	make_weak(params.base, params.strong, "i", params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.strong .. i}
	stems["sg"]      = {params.base .. params.strong .. "i"}
	stems["sg_weak"] = {params.base .. params.weak .. "i"}
	stems["pl"]      = {params.base .. params.strong .. "ei"}
	stems["pl_weak"] = {params.base .. params.weak .. "ei"}
	stems["gen_pl"]  = {params.base .. params.strong .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. "ej"}
	stems["ill_pl"]  = {params.base .. params.strong .. "eih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["paperi"] = function(args, data)
	data.title = "[[Kotus]] type 6/[[Appendix:Finnish nominal inflection/paperi|paperi]], no gradation"
	table.insert(data.categories, "Finnish paperi-type nominals")
	
	local params = get_params(args, 2)
	local i = get_extra_arg(args, data, "i"); if i == "0" then i = "" else i = "i" end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. i}
	stems["sg"]      = {params.base .. "i"}
	stems["pl"]      = {params.base .. "ei"}
	stems["par_pl"]  = {params.base .. "eit", params.base .. "ej"}
	stems["gen_pl"]  = {params.base .. "i", params.base .. "eid", params.base .. "eitt"}
	stems["ill_pl"]  = {params.base .. "eih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["ovi"] = function(args, data)
	data.title = "[[Kotus]] type 7/[[Appendix:Finnish nominal inflection/ovi|ovi]]"
	table.insert(data.categories, "Finnish ovi-type nominals")
	
	local params = get_params(args, 4)
	local nom_sg = get_extra_arg(args, data, "nom_sg"); if nom_sg == "" then nom_sg = nil end
	
	make_weak(params.base, params.strong, "e", params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local wk_pl = params.weak
	if mw.ustring.sub(params.base, -1) == "i" and params.strong == "k" and params.weak == "" then
		wk_pl = "’"
	end

	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base .. params.strong .. "i"}
	stems["sg"]      = {params.base .. params.strong .. "e"}
	stems["sg_weak"] = {params.base .. params.weak .. "e"}
	stems["pl"]      = {params.base .. params.strong .. "i"}
	stems["pl_weak"] = {params.base .. wk_pl .. "i"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["nalle"] = function(args, data)
	data.title = "[[Kotus]] type 8/[[Appendix:Finnish nominal inflection/nalle|nalle]]"
	table.insert(data.categories, "Finnish nalle-type nominals")
	
	local params = get_params(args, 4)
	
	make_weak(params.base, params.strong, "e", params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems = {}
	stems["sg"]      = {params.base .. params.strong .. "e"}
	stems["sg_weak"] = {params.base .. params.weak .. "e"}
	stems["pl"]      = {params.base .. params.strong .. "ei"}
	stems["pl_weak"] = {params.base .. params.weak .. "ei"}
	stems["par_pl"]  = {params.base .. params.strong .. "ej"}
	stems["ill_pl"]  = {params.base .. params.strong .. "eih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. params.strong .. "ein"}
end

inflections["kala"] = function(args, data)
	data.title = "[[Kotus]] type 9/[[Appendix:Finnish nominal inflection/kala|kala]]"
	table.insert(data.categories, "Finnish kala-type nominals")
	
	local params = get_params(args, 4)
	
	make_weak(params.base, params.strong, params.a, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local wk_sg = params.weak
	
	if wk_sg == "" and mw.ustring.sub(params.base, -2) == params.a .. params.a then
		wk_sg = "’"
	end
	
	local stems = {}
	stems["sg"]      = {params.base .. params.strong .. params.a}
	stems["sg_weak"] = {params.base .. wk_sg .. params.a}
	stems["pl"]      = {params.base .. params.strong .. params.o .. "i"}
	stems["pl_weak"] = {params.base .. params.weak .. params.o .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. params.o .. "j"}
	stems["ill_pl"]  = {params.base .. params.strong .. params.o .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. params.strong .. params.a .. "in"}
end

inflections["koira"] = function(args, data)
	data.title = "[[Kotus]] type 10/[[Appendix:Finnish nominal inflection/koira|koira]]"
	table.insert(data.categories, "Finnish koira-type nominals")
	
	local params = get_params(args, 4)
	local nom_sg = get_extra_arg(args, data, "nom_sg"); if nom_sg == "" then nom_sg = nil end
	
	make_weak(params.base, params.strong, params.a, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local wk_sg = params.weak
	local wk_pl = params.weak
	
	if wk_sg == "" and mw.ustring.sub(params.base, -2) == params.a .. params.a then
		wk_sg = "’"
	end
	
	if wk_pl == "" and mw.ustring.sub(params.base, -1) == "i" then
		wk_pl = "’"
	end
	
	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base .. params.strong .. params.a}
	stems["sg"]      = {params.base .. params.strong .. params.a}
	stems["sg_weak"] = {params.base .. wk_sg .. params.a}
	stems["pl"]      = {params.base .. params.strong .. "i"}
	stems["pl_weak"] = {params.base .. wk_pl .. "i"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. params.strong .. params.a .. "in"}
end

inflections["omena"] = function(args, data)
	data.title = "[[Kotus]] type 11/[[Appendix:Finnish nominal inflection/omena|omena]], no gradation"
	table.insert(data.categories, "Finnish omena-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["sg"]      = {params.base .. params.a}
	stems["pl"]      = {params.base .. params.o .. "i", params.base .. "i"}
	stems["par_pl"]  = {params.base .. "i", params.base .. params.o .. "it"}
	stems["ill_pl"]  = {params.base .. "i", params.base .. params.o .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. params.o .. "jen", params.base .. params.a .. "in"}
	data.forms["par_pl"].rare = {params.base .. params.o .. "j" .. params.a}
end

inflections["kulkija"] = function(args, data)
	data.title = "[[Kotus]] type 12/[[Appendix:Finnish nominal inflection/kulkija|kulkija]], no gradation"
	table.insert(data.categories, "Finnish kulkija-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["sg"]      = {params.base .. params.a}
	stems["pl"]      = {params.base .. params.o .. "i"}
	stems["par_pl"]  = {params.base .. params.o .. "it"}
	stems["ill_pl"]  = {params.base .. params.o .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. params.a .. "in"}
end

inflections["katiska"] = function(args, data)
	data.title = "[[Kotus]] type 13/[[Appendix:Finnish nominal inflection/katiska|katiska]], no gradation"
	table.insert(data.categories, "Finnish katiska-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["sg"]      = {params.base .. params.a}
	stems["pl"]      = {params.base .. params.o .. "i"}
	stems["par_pl"]  = {params.base .. params.o .. "it", params.base .. params.o .. "j"}
	stems["ill_pl"]  = {params.base .. params.o .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. params.a .. "in"}
end

inflections["solakka"] = function(args, data)
	data.title = "[[Kotus]] type 14/[[Appendix:Finnish nominal inflection/solakka|solakka]]"
	table.insert(data.categories, "Finnish solakka-type nominals")
	
	local params = get_params(args, 4)
	
	make_weak(params.base, params.strong, params.a, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems = {}
	stems["sg"]      = {params.base .. params.strong .. params.a}
	stems["sg_weak"] = {params.base .. params.weak .. params.a}
	stems["pl"]      = {params.base .. params.strong .. params.o .. "i"}
	stems["pl_weak"] = {params.base .. params.weak .. params.o .. "i"}
	stems["par_pl"]  = {params.base .. params.weak .. params.o .. "it", params.base .. params.strong .. params.o .. "j"}
	stems["ill_pl"]  = {params.base .. params.weak .. params.o .. "ih", params.base .. params.strong .. params.o .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. params.strong .. params.a .. "in"}
end

inflections["korkea"] = function(args, data)
	data.title = "[[Kotus]] type 15/[[Appendix:Finnish nominal inflection/korkea|korkea]], no gradation"
	table.insert(data.categories, "Finnish korkea-type nominals")
	
	local params = get_params(args, 2)
	local final = mw.ustring.sub(params.base, -1)
	
	local stems = {}
	stems["sg"]      = {params.base .. params.a}
	stems["par_sg"]  = {params.base .. params.a, params.base .. params.a .. "t"}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "isi", params.base .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. params.a .. "in"}
end

inflections["vanhempi"] = function(args, data)
	data.title = "[[Kotus]] type 16/[[Appendix:Finnish nominal inflection/vanhempi|vanhempi]], ''mp-mm'' gradation"
	table.insert(data.categories, "Finnish vanhempi-type nominals")
	data.gradtype = kotus_grad_type["mp-mm"]
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "mpi"}
	stems["sg"]      = {params.base .. "mp" .. params.a}
	stems["sg_weak"] = {params.base .. "mm" .. params.a}
	stems["pl"]      = {params.base .. "mpi"}
	stems["pl_weak"] = {params.base .. "mmi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. "mp" .. params.a .. "in"}
end

inflections["vapaa"] = function(args, data)
	data.title = "[[Kotus]] type 17/[[Appendix:Finnish nominal inflection/vapaa|vapaa]], no gradation"
	table.insert(data.categories, "Finnish vapaa-type nominals")
	
	local params = get_params(args, 2)
	local final = mw.ustring.sub(params.base, -1)
	
	local stems = {}
	stems["sg"]      = {params.base .. final}
	stems["par_sg"]  = {params.base .. final .. "t"}
	stems["ill_sg"]  = {params.base .. final .. "se"}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "isi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["ill_pl"].rare = {params.base .. "ihin"}
end

inflections["maa"] = function(args, data)
	data.title = "[[Kotus]] type 18/[[Appendix:Finnish nominal inflection/maa|maa]], no gradation"
	table.insert(data.categories, "Finnish maa-type nominals")
	
	local params = get_params(args, 2)
	local nom_sg = get_extra_arg(args, data, "nom_sg"); if nom_sg == "" then nom_sg = nil end
	
	local pl_stem = mw.ustring.sub(params.base, 1, -2)
	
	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base}
	stems["sg"]      = {params.base}
	stems["par_sg"]  = {params.base .. "t"}
	stems["pl"]      = {pl_stem .. "i"}
	stems["par_pl"]  = {pl_stem .. "it"}
	stems["ill_pl"]  = {pl_stem .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["suo"] = function(args, data)
	data.title = "[[Kotus]] type 19/[[Appendix:Finnish nominal inflection/suo|suo]], no gradation"
	table.insert(data.categories, "Finnish suo-type nominals")
	
	local params = get_params(args, 2)
	local final = mw.ustring.sub(params.base, -1)
	local stem = mw.ustring.sub(params.base, 1, -3)
	local plural
	if mw.ustring.sub(stem, -1) == final then
		plural = stem .. "-" .. final
	else
		plural = stem .. final
	end
	
	local stems = {}
	stems["sg"]      = {params.base}
	stems["par_sg"]  = {params.base .. "t"}
	stems["ill_sg"]  = {params.base .. "h"}
	stems["pl"]      = {plural .. "i"}
	stems["par_pl"]  = {plural .. "it"}
	stems["ill_pl"]  = {plural .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["filee"] = function(args, data)
	data.title = "[[Kotus]] type 20/[[Appendix:Finnish nominal inflection/filee|filee]], no gradation"
	table.insert(data.categories, "Finnish filee-type nominals")
	
	local params = get_params(args, 2)
	local nom_sg = get_extra_arg(args, data, "nom_sg"); if nom_sg == "" then nom_sg = nil end
	local pl_stem = mw.ustring.sub(params.base, 1, -2)
	
	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base}
	stems["sg"]      = {params.base}
	stems["par_sg"]  = {params.base .. "t"}
	stems["ill_sg"]  = {params.base .. "h", params.base .. "se"}
	stems["pl"]      = {pl_stem .. "i"}
	stems["par_pl"]  = {pl_stem .. "it"}
	stems["ill_pl"]  = {pl_stem .. "ih", pl_stem .. "isi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["rosé"] = function(args, data)
	data.title = "[[Kotus]] type 21/[[Appendix:Finnish nominal inflection/rosé|rosé]], no gradation"
	table.insert(data.categories, "Finnish rosé-type nominals")
	
	local params = get_params(args, 2)
	local ill_sg_vowel = get_extra_arg(args, data, "ill_sg_vowel"); if ill_sg_vowel == "" then error("Parameter \"ill_sg_vowel=\" cannot be empty.") end
	local ill_sg_vowel2 = get_extra_arg(args, data, "ill_sg_vowel2"); if ill_sg_vowel2 == "" then error("Parameter \"ill_sg_vowel2=\" cannot be empty.") end
	
	local stems = {}
	stems["sg"]      = {params.base}
	stems["par_sg"]  = {params.base .. "t"}
	stems["ill_sg"]  = {params.base .. "h"}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	if ill_sg_vowel then
		data.forms["ill_sg"] = {params.base .. "h" .. ill_sg_vowel .. "n"}
	end
	
	if ill_sg_vowel2 then
		table.insert(data.forms["ill_sg"], params.base .. "h" .. ill_sg_vowel2 .. "n")
	end
end

inflections["parfait"] = function(args, data)
	data.title = "[[Kotus]] type 22/[[Appendix:Finnish nominal inflection/parfait|parfait]], no gradation"
	table.insert(data.categories, "Finnish parfait-type nominals")
	
	local params = get_params(args, 2)
	local ill_sg_vowel = get_extra_arg(args, data, "ill_sg_vowel") or (mw.title.getCurrentTitle().nsText == "Template" and "e"); if not ill_sg_vowel or ill_sg_vowel == "" then error("Parameter \"ill_sg_vowel=\" is missing.") end
	local ill_sg_vowel2 = get_extra_arg(args, data, "ill_sg_vowel2"); if ill_sg_vowel2 == "" then error("Parameter \"ill_sg_vowel2=\" cannot be empty.") end
	
	local stems = {}
	stems["nom_sg"]  = {params.base}
	stems["sg"]      = {params.base .. "’"}
	stems["par_sg"]  = {params.base .. "’t"}
	stems["pl"]      = {params.base .. "’i"}
	stems["par_pl"]  = {params.base .. "’it"}
	stems["ill_pl"]  = {params.base .. "’ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["ill_sg"] = {params.base .. "’h" .. ill_sg_vowel .. "n"}
	
	if ill_sg_vowel2 then
		table.insert(data.forms["ill_sg"], params.base .. "h" .. ill_sg_vowel2 .. "n")
	end
end

inflections["tiili"] = function(args, data)
	data.title = "[[Kotus]] type 23/[[Appendix:Finnish nominal inflection/tiili|tiili]], no gradation"
	table.insert(data.categories, "Finnish tiili-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "i"}
	stems["sg"]      = {params.base .. "e"}
	stems["par_sg"]  = {params.base .. "t"}
	stems["pl"]      = {params.base .. "i"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["uni"] = function(args, data)
	data.title = "[[Kotus]] type 24/[[Appendix:Finnish nominal inflection/uni|uni]], no gradation"
	table.insert(data.categories, "Finnish uni-type nominals")
	
	local params = get_params(args, 2)
	local par_sg_a = get_extra_arg(args, data, "par_sg_a"); if par_sg_a and par_sg_a ~= "a" and par_sg_a ~= "ä" then error("Parameter \"par_sg_a=\" must be \"a\" or \"ä\".") end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "i"}
	stems["sg"]      = {params.base .. "e"}
	stems["par_sg"]  = {params.base .. "t"}
	stems["pl"]      = {params.base .. "i"}
	stems["gen_pl"]  = {params.base .. "i", params.base .. "t"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	if par_sg_a then
		data.forms["par_sg"] = {}
		
		for _, stem in ipairs(stems["par_sg"]) do
			table.insert(data.forms["par_sg"], stem .. par_sg_a)
		end
	end
end

inflections["toimi"] = function(args, data)
	data.title = "[[Kotus]] type 25/[[Appendix:Finnish nominal inflection/toimi|toimi]], no gradation"
	table.insert(data.categories, "Finnish toimi-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "mi"}
	stems["sg"]      = {params.base .. "me"}
	stems["par_sg"]  = {params.base .. "nt", params.base .. "me"}
	stems["pl"]      = {params.base .. "mi"}
	stems["gen_pl"]  = {params.base .. "mi", params.base .. "nt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["pieni"] = function(args, data)
	data.title = "[[Kotus]] type 26/[[Appendix:Finnish nominal inflection/pieni|pieni]], no gradation"
	table.insert(data.categories, "Finnish pieni-type nominals")
	
	local params = get_params(args, 2)
	local par_sg_a = get_extra_arg(args, data, "par_sg_a"); if par_sg_a and par_sg_a ~= "a" and par_sg_a ~= "ä" then error("Parameter \"par_sg_a=\" must be \"a\" or \"ä\".") end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "i"}
	stems["sg"]      = {params.base .. "e"}
	stems["par_sg"]  = {params.base .. "t"}
	stems["pl"]      = {params.base .. "i"}
	stems["gen_pl"]  = {params.base .. "t", params.base .. "i"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	if par_sg_a then
		data.forms["par_sg"] = {}
		
		for _, stem in ipairs(stems["par_sg"]) do
			table.insert(data.forms["par_sg"], stem .. par_sg_a)
		end
	end
end

inflections["käsi"] = function(args, data)
	data.title = "[[Kotus]] type 27/[[Appendix:Finnish nominal inflection/käsi|käsi]], ''t-d'' gradation"
	table.insert(data.categories, "Finnish käsi-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "si"}
	stems["sg"]      = {params.base .. "te"}
	stems["sg_weak"] = {params.base .. "de"}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["pl"]      = {params.base .. "si"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. "tten"}
end

inflections["kynsi"] = function(args, data)
	data.title = "[[Kotus]] type 28/[[Appendix:Finnish nominal inflection/kynsi|kynsi]]"
	table.insert(data.categories, "Finnish kynsi-type nominals")
	
	local params = get_params(args, 2, false, "n")
	local cons = mw.ustring.match(params.base, "([lnr]?)$")
	
	if mw.title.getCurrentTitle().nsText ~= "Template" and cons == "" then
		error("Stem must end in \"l\", \"n\" or \"r\".")
	end
	
	data.title = data.title .. ", ''" .. cons .. "t-" .. cons .. cons .. "'' gradation"
	data.gradtype = kotus_grad_type[cons .. "t-" .. cons .. cons]
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "si"}
	stems["sg"]      = {params.base .. "te"}
	stems["sg_weak"] = {params.base .. cons .. "e"}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["pl"]      = {params.base .. "si"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. "tten"}
end

inflections["lapsi"] = function(args, data)
	data.title = "[[Kotus]] type 29/[[Appendix:Finnish nominal inflection/lapsi|lapsi]], no gradation"
	table.insert(data.categories, "Finnish lapsi-type nominals")
	
	local params = get_params(args, 2, false, "p")
	local syncopated_stem, cons = mw.ustring.match(params.base, "^(.-)([kp]?)$")
	
	if mw.title.getCurrentTitle().nsText ~= "Template" and cons == "" then
		error("Stem must end in \"k\" or \"p\".")
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "si"}
	stems["sg"]      = {params.base .. "se"}
	stems["par_sg"]  = {syncopated_stem .. "st"}
	stems["pl"]      = {params.base .. "si"}
	stems["gen_pl"]  = {params.base .. "si", syncopated_stem .. "st"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["veitsi"] = function(args, data)
	data.title = "[[Kotus]] type 30/[[Appendix:Finnish nominal inflection/veitsi|veitsi]], no gradation"
	table.insert(data.categories, "Finnish veitsi-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "tsi"}
	stems["sg"]      = {params.base .. "tse"}
	stems["par_sg"]  = {params.base .. "st"}
	stems["pl"]      = {params.base .. "tsi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. "sten"}
end

inflections["kaksi"] = function(args, data)
	data.title = "[[Kotus]] type 31/[[Appendix:Finnish nominal inflection/kaksi|kaksi]], ''t-d'' gradation"
	table.insert(data.categories, "Finnish kaksi-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "ksi"}
	stems["sg"]      = {params.base .. "hte"}
	stems["sg_weak"] = {params.base .. "hde"}
	stems["par_sg"]  = {params.base .. "ht"}
	stems["pl"]      = {params.base .. "ksi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["sisar"] = function(args, data)
	data.title = "[[Kotus]] type 32/[[Appendix:Finnish nominal inflection/sisar|sisar]]"
	table.insert(data.categories, "Finnish sisar-type nominals")
	
	local params = get_params(args, 5, true)
	local nom_sg = get_extra_arg(args, data, "nom_sg"); if nom_sg == "" then nom_sg = nil end
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base .. params.weak .. params.final}
	stems["sg"]      = {params.base .. params.strong .. params.final .. "e"}
	stems["par_sg"]  = {params.base .. params.weak .. params.final .. "t"}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["gen_pl"]  = {params.base .. params.strong .. params.final .. "i", params.base .. params.weak .. params.final .. "t"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["kytkin"] = function(args, data)
	data.title = "[[Kotus]] type 33/[[Appendix:Finnish nominal inflection/kytkin|kytkin]]"
	table.insert(data.categories, "Finnish kytkin-type nominals")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.weak .. params.final .. "n"}
	stems["sg"]      = {params.base .. params.strong .. params.final .. "me"}
	stems["par_sg"]  = {params.base .. params.weak .. params.final .. "nt"}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "mi"}
	stems["gen_pl"]  = {params.base .. params.strong .. params.final .. "mi", params.base .. params.weak .. params.final .. "nt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["onneton"] = function(args, data)
	local no_gradation = get_extra_arg(args, data, "no_tt") == "1"
	local strong
	if no_gradation then
		strong = "t"
		data.title = "[[Kotus]] type 34/[[Appendix:Finnish nominal inflection/onneton|onneton]], no gradation"
	else
		strong = "tt"
		data.title = "[[Kotus]] type 34/[[Appendix:Finnish nominal inflection/onneton|onneton]], ''tt-t'' gradation"
		data.gradtype = kotus_grad_type["tt-t"]
	end
	table.insert(data.categories, "Finnish onneton-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "t" .. params.o .. "n"}
	stems["sg"]      = {params.base .. strong .. params.o .. "m" .. params.a}
	stems["par_sg"]  = {params.base .. "t" .. params.o .. "nt"}
	stems["pl"]      = {params.base .. strong .. params.o .. "mi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. "t" .. params.o .. "nten"}
end

inflections["lämmin"] = function(args, data)
	data.title = "[[Kotus]] type 35/[[Appendix:Finnish nominal inflection/lämmin|lämmin]]"
	table.insert(data.categories, "Finnish lämmin-type nominals")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.weak .. params.final .. "n"}
	stems["sg"]      = {params.base .. params.strong .. params.final .. "m" .. params.a}
	stems["par_sg"]  = {params.base .. params.weak .. params.final .. "nt"}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "mi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. params.strong .. params.final .. "m" .. params.a .. "in"}
end

inflections["sisin"] = function(args, data)
	data.title = "[[Kotus]] type 36/[[Appendix:Finnish nominal inflection/sisin|sisin]], ''mp-mm'' gradation"
	table.insert(data.categories, "Finnish sisin-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "in"}
	stems["sg"]      = {params.base .. "imp" .. params.a}
	stems["sg_weak"] = {params.base .. "imm" .. params.a}
	stems["par_sg"]  = {params.base .. "int"}
	stems["pl"]      = {params.base .. "impi"}
	stems["pl_weak"] = {params.base .. "immi"}
	stems["gen_pl"]  = {params.base .. "impi", params.base .. "int"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. "imp" .. params.a .. "in"}
end

inflections["vasen"] = function(args, data)
	data.title = "[[Kotus]] type 37/[[Appendix:Finnish nominal inflection/vasen|vasen]], ''mp-mm'' gradation"
	table.insert(data.categories, "Finnish vasen-type nominals")
	
	local params = get_params(args, 1)
	params.base = params.base .. "vase"
	params.a = "a"
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "n"}
	stems["sg"]      = {params.base .. "mp" .. params.a}
	stems["sg_weak"] = {params.base .. "mm" .. params.a}
	stems["par_sg"]  = {params.base .. "nt", params.base .. "mp" .. params.a}
	stems["pl"]      = {params.base .. "mpi"}
	stems["pl_weak"] = {params.base .. "mmi"}
	stems["gen_pl"]  = {params.base .. "mpi", params.base .. "nt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. "mp" .. params.a .. "in"}
end

inflections["nainen"] = function(args, data)
	data.title = "[[Kotus]] type 38/[[Appendix:Finnish nominal inflection/nainen|nainen]], no gradation"
	table.insert(data.categories, "Finnish nainen-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "nen"}
	stems["sg"]      = {params.base .. "se"}
	stems["par_sg"]  = {params.base .. "st"}
	stems["pl"]      = {params.base .. "si"}
	stems["gen_pl"]  = {params.base .. "st", params.base .. "si"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["vastaus"] = function(args, data)
	data.title = "[[Kotus]] type 39/[[Appendix:Finnish nominal inflection/vastaus|vastaus]], no gradation"
	table.insert(data.categories, "Finnish vastaus-type nominals")
	
	local params = get_params(args, 2)
	local nom_sg = get_extra_arg(args, data, "nom_sg"); if nom_sg == "" then nom_sg = nil end
	
	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base .. "s"}
	stems["sg"]      = {params.base .. "kse"}
	stems["par_sg"]  = {params.base .. "st"}
	stems["pl"]      = {params.base .. "ksi"}
	stems["gen_pl"]  = {params.base .. "st", params.base .. "ksi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["kalleus"] = function(args, data)
	data.title = "[[Kotus]] type 40/[[Appendix:Finnish nominal inflection/kalleus|kalleus]], ''t-d'' gradation"
	table.insert(data.categories, "Finnish kalleus-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "s"}
	stems["sg"]      = {params.base .. "te"}
	stems["sg_weak"] = {params.base .. "de"}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["pl"]      = {params.base .. "ksi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["vieras"] = function(args, data)
	data.title = "[[Kotus]] type 41/[[Appendix:Finnish nominal inflection/vieras|vieras]]"
	table.insert(data.categories, "Finnish vieras-type nominals")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.weak .. params.final .. "s"}
	stems["sg"]      = {params.base .. params.strong .. params.final .. params.final}
	stems["par_sg"]  = {params.base .. params.weak .. params.final .. "st"}
	stems["ill_sg"]  = {params.base .. params.strong .. params.final .. params.final .. "se"}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. params.final .. "it"}
	stems["ill_pl"]  = {params.base .. params.strong .. params.final .. "isi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["ill_pl"].rare = {params.base .. params.strong .. params.final .. "ihin"}
end

inflections["mies"] = function(args, data)
	data.title = "[[Kotus]] type 42/[[Appendix:Finnish nominal inflection/mies|mies]], no gradation"
	table.insert(data.categories, "Finnish mies-type nominals")
	
	local params = get_params(args, 1)
	params.base = params.base .. "mie"
	params.a = "ä"
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "s"}
	stems["sg"]      = {params.base .. "he"}
	stems["par_sg"]  = {params.base .. "st"}
	stems["pl"]      = {params.base .. "hi"}
	stems["gen_pl"]  = {params.base .. "st", params.base .. "hi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["ohut"] = function(args, data)
	data.title = "[[Kotus]] type 43/[[Appendix:Finnish nominal inflection/ohut|ohut]]"
	table.insert(data.categories, "Finnish ohut-type nominals")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.weak .. params.final .. "t"}
	stems["sg"]      = {params.base .. params.strong .. params.final .. "e"}
	stems["par_sg"]  = {params.base .. params.weak .. params.final .. "tt"}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. params.final .. "it"}
	stems["ill_pl"]  = {params.base .. params.strong .. params.final .. "isi", params.base .. params.strong .. params.final .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["kevät"] = function(args, data)
	data.title = "[[Kotus]] type 44/[[Appendix:Finnish nominal inflection/kevät|kevät]], no gradation"
	table.insert(data.categories, "Finnish kevät-type nominals")
	
	local params = get_params(args, 2)
	local vowel = mw.ustring.sub(params.base, -1)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "t"}
	stems["sg"]      = {params.base .. vowel}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["ill_sg"]  = {params.base .. vowel .. "se"}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "isi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["ill_pl"].rare = {params.base .. "ihin"}
end

inflections["kahdeksas"] = function(args, data)
	data.title = "[[Kotus]] type 45/[[Appendix:Finnish nominal inflection/kahdeksas|kahdeksas]], ''nt-nn'' gradation"
	table.insert(data.categories, "Finnish kahdeksas-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "s"}
	stems["sg"]      = {params.base .. "nte"}
	stems["sg_weak"] = {params.base .. "nne"}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["pl"]      = {params.base .. "nsi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["tuhat"] = function(args, data)
	data.title = "[[Kotus]] type 46/[[Appendix:Finnish nominal inflection/tuhat|tuhat]], ''nt-nn'' gradation"
	table.insert(data.categories, "Finnish tuhat-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "t"}
	stems["sg"]      = {params.base .. "nte"}
	stems["sg_weak"] = {params.base .. "nne"}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["pl"]      = {params.base .. "nsi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["gen_pl"].rare = {params.base .. "nten"}
end

inflections["kuollut"] = function(args, data)
	data.title = "[[Kotus]] type 47/[[Appendix:Finnish nominal inflection/kuollut|kuollut]], no gradation"
	table.insert(data.categories, "Finnish kuollut-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.u .. "t"}
	stems["sg"]      = {params.base .. "ee"}
	stems["par_sg"]  = {params.base .. params.u .. "tt"}
	stems["ill_sg"]  = {params.base .. "eese"}
	stems["pl"]      = {params.base .. "ei"}
	stems["par_pl"]  = {params.base .. "eit"}
	stems["ill_pl"]  = {params.base .. "eisi", params.base .. "eih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["hame"] = function(args, data)
	data.title = "[[Kotus]] type 48/[[Appendix:Finnish nominal inflection/hame|hame]]"
	table.insert(data.categories, "Finnish hame-type nominals")
	
	local params = get_params(args, 4, true)
	local stem_vowel = get_extra_arg(args, data, "stem_vowel"); if stem_vowel == "" then stem_vowel = nil end
	stem_vowel = stem_vowel or "e"
	
	make_weak(params.base, params.strong, stem_vowel, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.weak .. stem_vowel}
	stems["sg"]      = {params.base .. params.strong .. stem_vowel .. stem_vowel}
	stems["par_sg"]  = {params.base .. params.weak .. stem_vowel .. "tt"}
	stems["ill_sg"]  = {params.base .. params.strong .. stem_vowel .. stem_vowel .. "se"}
	stems["pl"]      = {params.base .. params.strong .. stem_vowel .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. stem_vowel .. "it"}
	stems["ill_pl"]  = {params.base .. params.strong .. stem_vowel .. "isi", params.base .. params.strong .. stem_vowel .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["askel"] = function(args, data)
	data.title = "[[Kotus]] type 49/[[Appendix:Finnish nominal inflection/askel|askel]]"
	table.insert(data.categories, "Finnish askel-type nominals")
	
	local params = get_params(args, 5, true)
	local prefer_hame = get_extra_arg(args, data, "e") == "1"

	make_weak(params.base, params.strong, "", params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
		data.gradtype = kotus_grad_type[params.strong .. "-" .. params.weak]
	end
	
	local stems_sisar = {}
	stems_sisar["nom_sg"]  = {nom_sg or params.base .. params.weak .. params.final}
	stems_sisar["sg"]      = {params.base .. params.strong .. params.final .. "e"}
	stems_sisar["par_sg"]  = {params.base .. params.weak .. params.final .. "t"}
	stems_sisar["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems_sisar["gen_pl"]  = {params.base .. params.strong .. params.final .. "i", params.base .. params.weak .. params.final .. "t"}
	make_stems(data, stems_sisar)

	local stems_hame = {}
	stems_hame["nom_sg"]  = {params.base .. params.strong .. params.final .. "e"}
	stems_hame["sg"]      = {params.base .. params.strong .. params.final .. "ee"}
	stems_hame["par_sg"]  = {params.base .. params.strong .. params.final .. "ett"}
	stems_hame["ill_sg"]  = {params.base .. params.strong .. params.final .. "eese"}
	stems_hame["pl"]      = {params.base .. params.strong .. params.final .. "ei"}
	stems_hame["par_pl"]  = {params.base .. params.strong .. params.final .. "eit"}
	stems_hame["ill_pl"]  = {params.base .. params.strong .. params.final .. "eisi", params.base .. params.strong .. params.final .. "eih"}
	make_stems(data, stems_hame)
	
	if prefer_hame then
		process_stems(data, stems_hame, params.a)
		process_stems(data, stems_sisar, params.a)
		data["stems"] = merge_stems(stems_hame, stems_sisar)
	else
		process_stems(data, stems_sisar, params.a)
		process_stems(data, stems_hame, params.a)
		data["stems"] = merge_stems(stems_sisar, stems_hame)
	end
end

-- Helper functions

-- joins data.words[...].forms to data.forms
function export.join_words(data, sep_supplier)
	local reorganized = {}
	local classes = {}
	
	-- reorganize from words[n].forms[case](.rare) to forms[case],words[n](.rare)
	for windex, word in ipairs(data.words) do
		table.insert(classes, word.class)
		for case, forms in pairs(word.forms) do
			if reorganized[case] == nil then
				reorganized[case] = {}
			end
			reorganized[case][windex] = {}
			for _, form in ipairs(forms) do
				table.insert(reorganized[case][windex], form)
			end
			if word.forms[case].rare then
				reorganized[case][windex].rare = {}
				for _, form in ipairs(word.forms[case].rare) do
					table.insert(reorganized[case][windex].rare, form)
				end
			end
		end
	end
	
	-- merge the forms with a Cartesian product to produce all possible combinations
	data.forms = {}
	for case, words in pairs(reorganized) do
		data.forms[case] = forms_cart_product(words, case, sep_supplier, classes)
	end

	if #data.words < 2 then
		-- use title and categories of the sole word if there is only one
		data.title = data.words[1].title
		data.categories = data.words[1].categories
	else
		-- if there are multiple words, force nuoripari type
		data.title = "[[Kotus]] type 51/[[Appendix:Finnish nominal inflection/nuoripari|nuoripari]]"
		data.categories = {"Finnish nuoripari-type nominals"}
	end
	data.words = nil
end

-- computes the Cartesian product of tables
function cart_product(words, depth)
	depth = depth or 1
	local prod = {}
	
	for _, val in ipairs(words[depth]) do
		if depth < #words then
			-- go over the next list
			for _, res in ipairs(cart_product(words, depth + 1)) do
				table.insert(prod, { val, unpack(res) })
			end
		else
			-- end of list, simply return the original
			table.insert(prod, { val })
		end
	end
	
	return prod
end

local function supplied_concat(list, sep_supplier)
	local result = ""
	local n = #list
	if n >= 1 then
		for i = 1, n - 1 do
			result = result .. list[i] .. sep_supplier(i)
		end
		result = result .. list[n]
	end
	return result
end

-- computes the Cartesian product of tables, also concats
function cart_product_concat(words, sep_supplier)
	local res = {}

	for _, combination in ipairs(cart_product(words)) do
		table.insert(res, supplied_concat(combination, sep_supplier))
	end

	return res
end

-- returns a bit mask (!) or nil
function get_rhyming_pattern(word, case, class)
	if class == "askel" then
		return nil
	end
	if case == "gen_pl" then
		if mw.ustring.match(word, "tten$") then
			return 2
		elseif mw.ustring.match(word, "ten$") then
			return 3
		else
			return 1
		end
	elseif case == "ill_sg" then
		if mw.ustring.match(word, "seen$") then
			return 1
		elseif mw.ustring.match(word, "hen$") then
			return 2
		end
	elseif case == "ill_pl" then
		if mw.ustring.match(word, "siin$") then
			return 1
		elseif mw.ustring.match(word, "hin$") then
			return 2
		end
	end
	return nil -- not applicable
end

function is_nonrhyming(form, case, classes)
	local expected = m_bit32.bnot(0) -- -1
	
	for i, word in ipairs(form) do
		local got = get_rhyming_pattern(word, case, classes[i])
		if got then
			expected = m_bit32.band(expected, got)
		end
		if expected == 0 then
			return true
		end
	end

	return false
end

-- computes the Cartesian product of tables, also concats
-- returns non-rhyming combinations as rare
function cart_product_concat_nonrhyming_rare(words, case, sep_supplier, classes)
	local res = {}
	local rare = {}
	local multichoice = 0
	local allow_pruning = false

	for _, position in ipairs(words) do
		if #position > 1 then
			multichoice = multichoice + 1
		end
	end

	allow_pruning = multichoice > 1

	for _, combination in ipairs(cart_product(words)) do
		local item = supplied_concat(combination, sep_supplier)
		if is_nonrhyming(combination, case, classes) then
			table.insert(rare, item)
		else
			table.insert(res, item)
		end
	end

	if #res < 1 then
		rare.rare = {}
		return rare
	end

	res.rare = rare
	return res
end

-- converts a list of words to extract the rare forms for ipairs
-- the number is interpreted bit-by-bit to decide which combination
-- to choose
function prepare_rare_tables(words, code)
	local result = {}
	
	for _, forms in ipairs(words) do
		-- replace with rare if bit is 1
		if m_bit32.band(code, 1) == 1 then
			table.insert(result, forms.rare or {})
		else
			table.insert(result, forms)
		end
		
		-- shift right to test next bit
		code = m_bit32.rshift(code, 1)
	end
	
	return result
end

-- copies all entries of source and inserts them to target
function merge_table(target, source)
	for _, value in ipairs(source) do
		table.insert(target, value)
	end
end

function merge_table_rare(target, source)
	for _, value in ipairs(source) do
		table.insert(target, value)
	end
	target.rare = source.rare
end

-- the Cartesian product of possible forms
function forms_cart_product(words, case, sep_supplier, classes)
	local result = {}
	result.rare = {}
	
	-- merge possible non-rare forms
	merge_table_rare(result, cart_product_concat_nonrhyming_rare(words, case, sep_supplier, classes))
	
	-- merge possible rare forms
	-- for example, with two words:
	--        1 = rare A, common B
	--        2 = common A, rare B
	--        3 = rare A, rare B
	-- (2 ^ #words) - 1 == m_bit32.lshift(1,#words)-1
	-- (prepare_rare_tables actually takes out the rare forms)
	for i = 1,m_bit32.lshift(1,#words)-1 do
		merge_table(result.rare, cart_product_concat(prepare_rare_tables(words, i), sep_supplier))
	end
	
	-- if no rare forms, remove the table completely
	if #result.rare < 1 then
		result.rare = nil
	end
	return result
end

function make_word_possessive(args, data, poss, always_add)
	local pos = get_extra_arg(args, data, "pos"); if not pos or pos == "" then pos = "noun" end
	local suffix = get_extra_arg(args, data, "suffix"); if not suffix then suffix = "" end
	local par_nom_sg = get_extra_arg(args, data, "par_nom_sg") == "1"

	-- "no possessive forms exist" sentinel value
	if poss == "-" then
		return data.forms
	end

	if always_add or pos == "noun" then
		-- add possessive suffix
		if poss == "3" or poss == "3p" then
			poss = "3s" -- 3rd person forms are identical
		end
		if not poss_forms[poss] then
			error("Invalid poss value: '" .. p .. "'")
		end
		return make_poss_with_suffix(data.forms, data.stems, poss_forms[poss], suffix, poss_alt[poss], par_nom_sg)
	end
	return data.forms
end

function postprocess_word(args, data, always_add)
	local pos = get_extra_arg(args, data, "pos"); if not pos or pos == "" then pos = "noun" end
	
	if args.args["poss"] then
		data.forms = make_word_possessive(args, data, args.args["poss"], always_add)
	elseif pos == "noun" and data.forms["com_pl"] then
		-- Add the possessive suffix to the comitative plural, if the word is a noun
		for key, subform in ipairs(data.forms["com_pl"]) do
			data.forms["com_pl"][key] = subform .. "en"
		end
	end
	
	if get_extra_arg(args, data, "gen_nom_sg") == "1" then
		data.forms["nom_sg"] = data.forms["gen_sg"]
	elseif get_extra_arg(args, data, "par_nom_sg") == "1" then
		data.forms["nom_sg"] = data.forms["par_sg"]
	end
	
	if data.gradtype then
		data.title = mw.ustring.gsub(data.title, "([0-9]+)/", "%1*" .. data.gradtype .. "/")
	end
end

function postprocess(args, data)
	local pos = args["pos"]; if not pos or pos == "" then pos = "noun" end
	local nosg = args["nosg"]; if nosg == "" then nosg = nil end
	local nopl = args["nopl"]; if nopl == "" then nopl = nil end
	local n = args["n"]; if n == "" then n = nil end
	local suffix = args["suffix"]; if suffix == "" then suffix = nil end
	local appendix = args["appendix"]; if appendix == "" then appendix = nil end
	local has_ins_sg = args["has_ins_sg"]; if has_ins_sg == "" then has_ins_sg = nil end
	local has_no_nom = args["has_no_nom"]; if has_no_nom == "" then has_no_nom = nil end
	
	-- Add the possessive suffix to the comitative plural, if the word is a noun
	-- now done per word; see postprocess_word
	
	if nosg or n == "pl" then
		table.insert(data.categories, "Finnish pluralia tantum")
	end
	
	-- TODO: This says "nouns", but this module is also used for adjectives!
	if nopl or n == "sg" then
		table.insert(data.categories, "Finnish uncountable nouns")
	end
	
	if n == "csg" then          -- "chiefly singular"
		data.rare_plural = true
	end
	
	if not has_ins_sg then
		data.forms["ins_sg"] = nil
	end
	
	for key, form in pairs(data.forms) do
		-- Add suffix to forms
		for i, subform in ipairs(form) do
			subform = subform .. (suffix or "")
			form[i] = subform
		end
		
		if form.rare then
			for i, subform in ipairs(form.rare) do
				subform = subform .. (suffix or "")
				form.rare[i] = subform
			end
		end
		
		-- Do not show singular or plural forms for nominals that don't have them
		if ((nosg or n == "pl") and key:find("_sg$")) or ((nopl or n == "sg") and key:find("_pl$")) then
			form = nil
		end
		
		data.forms[key] = form
	end
	
	-- Check if the lemma form matches the page name
	if not appendix and lang:makeEntryName(data.forms[(nosg or n == "pl") and "nom_pl" or "nom_sg"][1]) ~= mw.title.getCurrentTitle().text then
		table.insert(data.categories, "Finnish entries with inflection not matching pagename")
	end
	
	if has_no_nom then
		data.forms["nom_sg"] = nil
		data.forms["nom_pl"] = nil
	end
end

function make_possessive_table(args, data, pos, infl_type)
	local nosg = args["nosg"]; if nosg == "" then nosg = nil end
	local nopl = args["nopl"]; if nopl == "" then nopl = nil end
	local n = args["n"]; if n == "" then n = nil end
	local note = nil

	local base_form = "nom_sg"
	if nosg or n == "pl" then
		base_form = "nom_pl"
	end

	if pos == "adj" then
		note = not args["hideadjnote"] and "'''Rare'''. Only used with [[substantive adjective]]s." or ""
	elseif pos ~= "noun" then
		return ""
	end

	-- make compact table
	local compacted = {}
	for poss, components in pairs(data) do
		local words = {}
		if #components == 1 then
			-- one component only, just allow all forms
			compacted[poss] = components[1][base_form]
		else
			-- more than one, only take first form
			-- maybe later this would also use some Cartesian product stuff too
			for i, word in ipairs(components) do
				-- pick first valid form, since that is what we would display
				table.insert(words, word[base_form][1])
			end
			compacted[poss] = { table.concat(words, args["space"] or " ") }
		end
	end

	return "\n" .. make_possessive_table_internal(args, compacted, infl_type, note)
end

-- Make the table
function make_table(data, vh)
	local rare_plural = data.rare_plural
	local note = rare_plural and "Plural forms of this word are not commonly used, but might be found in figurative uses, in some set phrases or in colloquial language." or nil

	local function show_form(forms, code, no_rare)
		local form = forms[code]
		if not form then
			return "&mdash;"
		elseif type(form) ~= "table" then
			error("a non-table value was given in the list of inflected forms.")
		end
		
		local ret = {}
		local accel

		if rare_plural and code:find("_pl$") then
			-- plural is marginal
			for key, subform in ipairs(form) do
				table.insert(ret, "(''" .. m_links.full_link({
					lang = lang,
					term = subform
				}) .. "'')")
			end
			
			if not no_rare and form.rare then
				for key, subform in ipairs(form.rare) do
					table.insert(ret, "(''" .. m_links.full_link({
						lang = lang,
						term = subform
					}) .. "''<sup>rare</sup>)")
				end
			end

			return table.concat(ret, "<br/>")
		end

		-- See [[Module talk:fi-nominals]].
		if code == "nom_sg" then
			accel = nil
		elseif code == "nom_pl" then
			accel = { form = "nom//acc|p" }
		elseif not code:find("^com_") then
			accel = {
				form = code:gsub("%f[^_](%a%a)$", {sg = "s", pl = "p"}):gsub("ins", "ist"):gsub("_", "|"),
			}
		elseif code == "com_pl" and vh ~= nil then
			-- add vowel harmony vowel (a/ä) for comitative
			accel = {
				form = "com-pl-" .. vh,
			}
		end
		
		for key, subform in ipairs(form) do
			table.insert(ret, m_links.full_link({
				lang = lang,
				term = subform,
				accel = accel,
			}))
		end
		
		if not no_rare and form.rare then
			if accel then
				accel.form = 'rare-' .. accel.form
			end

			for key, subform in ipairs(form.rare) do
				table.insert(ret, m_links.full_link({
					lang = lang,
					term = subform,
					accel = accel,
				}) .. "<sup>rare</sup>")
			end
		end
		
		return table.concat(ret, "<br/>")
	end
	
	local function repl(param)
		if param == "lemma" then
			return m_links.full_link({lang = lang, alt = mw.title.getCurrentTitle().text}, "term")
		elseif param == "info" then
			return data.title and " (" .. data.title .. ")" or ""
		elseif param == "maybenote" then
			if note then
				return [=[
|- class="vsHide"
| colspan="4" style="width:100px" | ]=] .. note .. "\n"
			else
				return ""
			end
		else
			local param2 = mw.ustring.match(param, "^(.-):c$")
			
			if param2 then
				return show_form(data.forms, param2, true)
			else
				return show_form(data.forms, param)
			end
		end
	end
	
	local wikicode = [=[
{| class="inflection-table fi-decl vsSwitcher" data-toggle-category="inflection"
|-
! class="vsToggleElement" colspan="4" | Inflection of {{{lemma}}}{{{info}}}
|- class="vsShow"
! class="case-column" colspan="2" | nominative
| class="number-column" | {{{nom_sg:c}}}
| class="number-column" | {{{nom_pl:c}}}
|- class="vsShow"
! colspan="2" | genitive
| {{{gen_sg:c}}}
| {{{gen_pl:c}}}
|- class="vsShow"
! colspan="2" | partitive
| {{{par_sg:c}}}
| {{{par_pl:c}}}
|- class="vsShow"
! colspan="2" | illative
| {{{ill_sg:c}}}
| {{{ill_pl:c}}}
|- class="vsHide"
! class="case-column" colspan="2" |
! class="number-column" | singular
! class="number-column" | plural
|- class="vsHide"
! colspan="2" | nominative
| {{{nom_sg}}}
| {{{nom_pl}}}
|- class="vsHide"
! rowspan="2" | accusative
! nom.<sup title="The nominative accusative is used, for example, as the object of certain passives and imperatives."></sup>
| {{{nom_sg}}}
| rowspan="2" | {{{nom_pl}}}
|- class="vsHide"
! gen.
| {{{gen_sg}}}
|- class="vsHide"
! colspan="2" | genitive
| {{{gen_sg}}}
| {{{gen_pl}}}
|- class="vsHide"
! colspan="2" | partitive
| {{{par_sg}}}
| {{{par_pl}}}
|- class="vsHide"
! colspan="2" | inessive
| {{{ine_sg}}}
| {{{ine_pl}}}
|- class="vsHide"
! colspan="2" | elative
| {{{ela_sg}}}
| {{{ela_pl}}}
|- class="vsHide"
! colspan="2" | illative
| {{{ill_sg}}}
| {{{ill_pl}}}
|- class="vsHide"
! colspan="2" | adessive
| {{{ade_sg}}}
| {{{ade_pl}}}
|- class="vsHide"
! colspan="2" | ablative
| {{{abl_sg}}}
| {{{abl_pl}}}
|- class="vsHide"
! colspan="2" | allative
| {{{all_sg}}}
| {{{all_pl}}}
|- class="vsHide"
! colspan="2" | essive
| {{{ess_sg}}}
| {{{ess_pl}}}
|- class="vsHide"
! colspan="2" | translative
| {{{tra_sg}}}
| {{{tra_pl}}}
|- class="vsHide"
! colspan="2" | instructive
| {{{ins_sg}}}
| {{{ins_pl}}}
|- class="vsHide"
! colspan="2" | abessive
| {{{abe_sg}}}
| {{{abe_pl}}}
|- class="vsHide"
! colspan="2" | comitative
| {{{com_sg}}}
| {{{com_pl}}}
{{{maybenote}}}|}]=]
	return mw.ustring.gsub(wikicode, "{{{([a-z0-9_:]+)}}}", repl)
end

------------------------------------------
-- POSSESSIVE FORM GENERATION & DISPLAY --
------------------------------------------

local function prepare_possessive_list(forms)
	local res = {}
	for _, v in ipairs(forms) do
		table.insert(res, v)
	end
	if forms["rare"] then
		for _, v in ipairs(forms["rare"]) do
			table.insert(res, v)
			res[v] = "rare"
		end
	end
	return res
end

local function wrap_rare_forms(forms)
	local newforms = {}
	for case, subforms in pairs(forms) do
		local common = {}
		local rare = {}
		for _, v in ipairs(subforms) do
			if subforms[v] == "rare" then
				table.insert(rare, v)
			else
				table.insert(common, v)
			end
		end
		common.rare = rare
		newforms[case] = common
	end
	return newforms
end

local function make_possessives_from_stems(stems, suffix, extra_suffix)
	local pforms = {}
	for _, stem in pairs(stems) do
		table.insert(pforms, stem .. suffix .. extra_suffix)
	end
	return pforms
end

function make_poss_with_suffix(forms, stems, poss_suffix, extra_suffix, allow_alt, par_nom_sg)
	local result = {}
	local par_sg_a = false
	if poss_suffix:find("a") and mw.ustring.sub(forms["ine_sg"][1], -1) == "ä" then
		poss_suffix = mw.ustring.gsub(poss_suffix, "a", "ä")
	end
	if mw.ustring.sub(forms["ine_sg"][1], -1) ~= mw.ustring.sub(forms["par_sg"][1], -1) then
		par_sg_a = true
	end
	for k, v in pairs(forms_alt_ok) do
		if forms[k] then
			local suffix = poss_suffix
			if k == "par_sg" and par_sg_a and mw.ustring.find(suffix, "ä$") then
				suffix = mw.ustring.gsub(poss_suffix, "ä", "a")
			end
			result[k] = {}
			if k == "par_sg" and allow_alt then
				-- par_sg is a bit of an exception: it allows
				-- alt form if it doesn't end in two "aa"/"ää"
				local prepared = prepare_possessive_list(forms[k])
				for _, form in ipairs(prepared) do
					local modform = form
					if mw.ustring.sub(modform, -2, -2) ~= mw.ustring.sub(modform, -1) then
						local final = modform .. mw.ustring.sub(modform, -1) .. "n"
						table.insert(result[k], final)
						result[k][final] = prepared[form]
					end
				end
			elseif forms_alt_ok[k] and allow_alt then
				local prepared = prepare_possessive_list(forms[k])
				for _, form in ipairs(prepared) do
					local modform = form
					if k == "tra_sg" or k == "tra_pl" then
						modform = mw.ustring.sub(form, 1, -2) .. "e"
					end
					local final = modform .. mw.ustring.sub(modform, -1) .. "n"
					table.insert(result[k], final)
					result[k][final] = prepared[form]
				end
			end
			if k == "gen_sg" or k == "ins_sg" then
				result[k] = make_possessives_from_stems(stems["sg"], suffix, extra_suffix)
			elseif k == "ins_pl" then
				result[k] = make_possessives_from_stems(stems["pl"], suffix, extra_suffix)
			elseif forms_gen_ok[k] then
				local prepared = prepare_possessive_list(forms[k])
				for _, form in ipairs(prepared) do
					local tmp = form
					tmp = mw.ustring.sub(tmp, 1, -2)
					local final = tmp .. suffix .. extra_suffix
					table.insert(result[k], final)
					result[k][final] = prepared[form]
				end
			else
				local prepared = prepare_possessive_list(forms[k])
				for _, form in ipairs(prepared) do
					local modform = form
					if k == "tra_sg" or k == "tra_pl" then
						modform = mw.ustring.sub(form, 1, -2) .. "e"
					end
					local final = modform .. suffix .. extra_suffix
					table.insert(result[k], final)
					result[k][final] = prepared[form]
				end
			end
		end
	end
	-- nominative forms are (usually) identical to genitive singular
	if par_nom_sg then
		result["nom_sg"] = result["par_sg"]
	else
		result["nom_sg"] = result["gen_sg"]
	end
	result["nom_pl"] = result["gen_sg"]
	return wrap_rare_forms(result)
end

function generate_possessive_forms(result, args, data, always_add)
	for poss, sufx in pairs(poss_forms) do
		result[poss] = result[poss] or {}
		table.insert(result[poss], make_word_possessive(args, data, poss, always_add))
	end
end

local function serialize_args(args)
	local items = {}
	local entries = {}
	local max_number = 0

	for key, value in pairs(args) do
		if type(key) == "number" and key > 0 and key == math.floor(key) then
			items[key] = value
			max_number = math.max(key, max_number)
		else
			table.insert(entries, key .. "=" .. value)
		end
	end

	for i = 1,max_number,1 do
		items[i] = items[i] or ""
	end
	-- entries before items
	for i, v in ipairs(entries) do
		table.insert(items, i, v)
	end
	return table.concat(items, "|")
end

function make_possessive_table_internal(args, data, infl_type, note)
	local function show_form(forms, code, no_rare)
		local subforms = forms[code]
		if not subforms or #subforms < 1 then
			return "&mdash;"
		end

		local ret = {}

		for _, subform in ipairs(subforms) do
			-- there might be a better way to pass extra parameters, since this is not a good way to do that
			table.insert(ret, m_links.full_link({
				lang = lang,
				term = subform,
				accel = {
					form = "possessive|" .. code .. "|" .. infl_type .. "|" .. require("Module:base64").encode(serialize_args(args))
				},
			}))
		end
		
		return table.concat(ret, "<br/>")
	end
	
	local function repl(param)
		if param == "lemma" then
			return m_links.full_link({lang = lang, alt = mw.title.getCurrentTitle().text}, "term")
		elseif param == "info" then
			if infl_type:match("%-") then
				return " (type ''nuoripari'')"
			else
				return " (type ''" .. infl_type .. "'')"
			end
		elseif param == "maybenote" then
			if note then
				return [=[
|- class="vsHide"
| colspan="3" | ]=] .. note .. "\n"
			else
				return ""
			end
		else
			return show_form(data, param)
		end
	end
	
	local wikicode = [=[
{| class="inflection-table vsSwitcher" data-toggle-category="inflection" style="color: rgb(0%,0%,30%); border: solid 1px rgb(80%,80%,100%); text-align: center;" cellspacing="1" cellpadding="2"
|- style="background: #e2f6e2;"
! class="vsToggleElement" style="min-width: 30em; text-align: left;" colspan="3" | [[Appendix:Finnish possessive suffixes|Possessive forms]] of {{{lemma}}}{{{info}}}
{{{maybenote}}}|- class="vsHide"
! style="min-width: 11em; background:#c0e4c0" | possessor
! style="min-width: 10em; background:#c0e4c0" | singular
! style="min-width: 10em; background:#c0e4c0" | plural
|- class="vsHide" style="background:rgb(95%,95%,100%)"
! style="background:#e2f6e2" | 1st person
| {{{1s}}}
| {{{1p}}}
|- class="vsHide" style="background:rgb(95%,95%,100%)"
! style="background:#e2f6e2" | 2nd person
| {{{2s}}}
| {{{2p}}}
|- class="vsHide" style="background:rgb(95%,95%,100%)"
! style="background:#e2f6e2" | 3rd person
| colspan="2" | {{{3s}}}
|}]=]
	return mw.ustring.gsub(wikicode, "{{{([a-z0-9_:]+)}}}", repl)
end

export.inflections = inflections
return export
