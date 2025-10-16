-- psalmtones.lua  (UTF-8)
-- Liber-style psalm-tone styling from syllables.

local psalmtones = {}

-- ===== Options =====
psalmtones.debug = false  -- set true to log syllables/lang IDs to .log

-- ===== LuaTeX handles =====
local node, lang, utf = node, lang, utf8
local N_GLY, N_DISC = node.id("glyph"), node.id("disc")

local function texmacro(name) return token.get_macro(name) or "" end

-- ===== Accent detection (orthographic mode uses this) =====
-- Precomposed acute vowels + combining acute U+0301 (\204\129)
local ACUTE_BYTES = "[\195\161\195\169\195\173\195\179\195\186\195\189\195\129\195\137\195\141\195\147\195\154\195\157\197\189\197\188\204\129]"
local function syl_has_orthographic_accent(s)
	return s:find(ACUTE_BYTES) ~= nil or s:find("%'%s*$") ~= nil
end

-- ===== Accent mode (positional | orthographic) =====
local ACCENT_POSITIONAL   = "positional"   -- default: accent = (#syl - post)
local ACCENT_ORTHOGRAPHIC = "orthographic" -- use acute/apostrophe; fallback to positional if none
local accent_mode = ACCENT_POSITIONAL

function psalmtones.set_accent_mode(mode)
	if mode == ACCENT_ORTHOGRAPHIC then accent_mode = ACCENT_ORTHOGRAPHIC
	else accent_mode = ACCENT_POSITIONAL end
end

-- ===== Language id (babel/polyglossia aware) =====
local function current_lang_id()
	local lname = token.get_macro("languagename")
	if lname and lname ~= "" then
		local cs = "l@" .. lname
		if token.is_defined and token.is_defined(cs) then
			local ok, id = pcall(tex.getcount, cs)
			if ok and type(id) == "number" then return id end
		end
	end
	return tex.language
end

-- ===== Build glyph nodelist for a UTF-8 word =====
local function string_to_glyphlist(str)
	local head, tail
	local f = font.current()
	local l = current_lang_id()
	if psalmtones.debug then
		texio.write_nl(string.format("[psalmtones] lang id = %s", tostring(l)))
	end
	for _, code in utf.codes(str) do
		local g = node.new("glyph")
		g.font, g.char, g.lang = f, code, l
		if not head then head, tail = g, g
		else tail.next, g.prev, tail = g, tail, g end
	end
	return head
end

-- ===== Tiny tokenizer: words vs separators (UTF-8 friendly) =====
-- Previous version used %a (ASCII-only). This version treats any non-space, non-ASCII punctuation
-- as a word character, while allowing apostrophes to stay attached (e.g., David's)
local function tokenize(line)
	local out = {}
	local i = 1
	local L = #line
	local function is_word_char(ch)
		-- %p is ASCII punctuation; keep apostrophe as part of words
		return not ch:match("[%s%p]") or ch == "'"
	end
	while i <= L do
		local a,b = line:find("[%z\1-\127\194-\244][\128-\191]*", i)
		if not a then break end
		local ch = line:sub(a,b)
		if is_word_char(ch) then
			local j = b + 1
			while j <= L do
				local a2,b2 = line:find("[%z\1-\127\194-\244][\128-\191]*", j)
				if not a2 then break end
				local c2 = line:sub(a2,b2)
				if is_word_char(c2) then j = b2 + 1 else break end
			end
			out[#out+1] = { kind = "word", text = line:sub(a, j-1) }
			i = j
		else
			out[#out+1] = { kind = "sep", text = ch }
			i = b + 1
		end
	end
	return out
end

-- ===== Improved Latin Syllabifier =====
local VCL = "[AEIOUYaeiouyÁÉÍÓÚÝáéíóúýÆŒæœ]"
local function is_vowel(ch) return ch:match(VCL) ~= nil end

local function latin_like_syllables(word)
	local chars = {}
	for _,c in utf.codes(word) do chars[#chars+1] = utf.char(c) end
	if #chars == 0 then return {} end

	local function is_diph(a,b)
		local pair = (a..b):lower()
		return pair=="ae" or pair=="oe" or pair=="au"
	end
	local keep_with_vowel = {
		pr=true, br=true, tr=true, dr=true, cr=true, gr=true, pl=true, bl=true,
		cl=true, gl=true, fr=true, fl=true, kr=true, vr=true, ph=true, th=true,
		ch=true, qu=true,
	}

	local out = {}
	local i = 1
	while i <= #chars do
		local onset = {}
		while i <= #chars and not is_vowel(chars[i]) do
			onset[#onset+1] = chars[i]; i = i + 1
		end
		local nucleus = {}
		if i <= #chars and is_vowel(chars[i]) then
			nucleus[#nucleus+1] = chars[i]
			if i+1 <= #chars and is_vowel(chars[i+1]) and is_diph(chars[i], chars[i+1]) then
				nucleus[#nucleus+1] = chars[i+1]; i = i + 1
			end
			i = i + 1
		else
			if #onset > 0 then out[#out+1] = table.concat(onset) end
			break
		end
		local cons = {}
		local j = i
		while j <= #chars and not is_vowel(chars[j]) do
			cons[#cons+1] = chars[j]; j = j + 1
		end
		local coda = {}
		if #cons >= 2 then
			local pair = (cons[1]..cons[2]):lower()
			if keep_with_vowel[pair] then
				-- leave cluster for next onset (V-CCV)
			else
				coda[#coda+1] = cons[1]
				table.remove(cons, 1)
			end
		elseif #cons == 1 then
			-- leave single consonant for next onset (V-CV)
		end
		local syl = table.concat(onset) .. table.concat(nucleus) .. table.concat(coda)
		out[#out+1] = syl
		if #cons > 0 then
			local rest = {}
			for k=1,#cons do rest[#rest+1] = cons[k] end
			for k=j,#chars do rest[#rest+1] = chars[k] end
			chars = rest
			i = 1
		else
			i = j
		end
	end
	
	-- Validation: ensure no consonant-only syllables and fix single-letter issues
	local valid_syllables = {}
	for _, syl in ipairs(out) do
		local has_vowel = false
		for _, ch in utf.codes(syl) do
			if is_vowel(utf.char(ch)) then
				has_vowel = true
				break
			end
		end
		
		if has_vowel then
			-- Valid syllable with vowel
			valid_syllables[#valid_syllables+1] = syl
		else
			-- Consonant-only syllable - attach to previous syllable
			if #valid_syllables > 0 then
				valid_syllables[#valid_syllables] = valid_syllables[#valid_syllables] .. syl
			else
				-- If this is the first syllable and it's consonant-only, keep it
				valid_syllables[#valid_syllables+1] = syl
			end
		end
	end
	
	-- Additional validation: merge single-letter syllables that aren't valid monosyllables
	local final_syllables = {}
	local valid_monosyllables = { "a", "e", "i", "o", "u", "y" }
	
	for i, syl in ipairs(valid_syllables) do
		if #syl == 1 then
			local is_valid_mono = false
			for _, valid in ipairs(valid_monosyllables) do
				if syl:lower() == valid then
					is_valid_mono = true
					break
				end
			end
			
			if is_valid_mono then
				final_syllables[#final_syllables+1] = syl
			else
				-- Single letter that's not a valid monosyllable - attach to previous or next
				if #final_syllables > 0 then
					final_syllables[#final_syllables] = final_syllables[#final_syllables] .. syl
				else
					-- First syllable - attach to next syllable if possible
					if i < #valid_syllables then
						-- Skip this one, it will be attached to the next
					else
						final_syllables[#final_syllables+1] = syl
					end
				end
			end
		else
			-- Multi-letter syllable - check if previous single letter needs to be attached
			if #final_syllables > 0 and #final_syllables[#final_syllables] == 1 then
				local prev_syl = final_syllables[#final_syllables]
				local is_prev_valid = false
				for _, valid in ipairs(valid_monosyllables) do
					if prev_syl:lower() == valid then
						is_prev_valid = true
						break
					end
				end
				if not is_prev_valid then
					-- Attach previous single letter to current syllable
					final_syllables[#final_syllables] = prev_syl .. syl
				else
					final_syllables[#final_syllables+1] = syl
				end
			else
				final_syllables[#final_syllables+1] = syl
			end
		end
	end
	
	return final_syllables
end

-- ===== Primary syllabification method =====
local function hyphen_syllables(word)
	-- Use improved Latin syllabifier as primary method
	local syllables = latin_like_syllables(word)
	
	if psalmtones.debug then
		texio.write_nl(("[psalmtones] word=%q syll=%s")
			:format(word, (#syllables>0 and table.concat(syllables,"|") or "<none>")))
	end
	
	return syllables
end

-- ===== Turn half-verse tokens into a sequence of syllables & separators =====
local function halfverse_syllables(tokens)
	local seq, join = {}, texmacro("PsalmJoiner")
	for _, t in ipairs(tokens) do
		if t.kind == "word" then
			local syls = hyphen_syllables(t.text)
			for k, s in ipairs(syls) do
				seq[#seq+1] = { kind = "syl", text = s }
				if k < #syls and join ~= "" then
					seq[#seq+1] = { kind = "sep", text = join }
				end
			end
		else
			seq[#seq+1] = t
		end
	end
	return seq
end

-- ===== Anchor & word-accent helpers =====
local function word_accent_index(syls)
	local n = #syls
	if n == 0 then return nil end
	if accent_mode == ACCENT_ORTHOGRAPHIC then
		for i = n, 1, -1 do
			if syl_has_orthographic_accent(syls[i]) then return i end
		end
	end
	return (n >= 2) and (n - 1) or 1 -- penult fallback
end

local function halfverse_model(tokens)
	local seq, words = {}, {}
	local join = texmacro("PsalmJoiner")
	local ord = 0 -- syllable ordinal within the half-verse
	for _, t in ipairs(tokens) do
		if t.kind == "word" then
			local syls = hyphen_syllables(t.text)
			local start_ord = ord + 1
			for k, s in ipairs(syls) do
				seq[#seq+1] = { kind = "syl", text = s }
				ord = ord + 1
				if k < #syls and join ~= "" then seq[#seq+1] = { kind = "sep", text = join } end
			end
			local nsyl = #syls
			local acc_rel = (nsyl > 0) and word_accent_index(syls) or nil
			local acc_abs = acc_rel and (start_ord + acc_rel - 1) or nil
			words[#words+1] = { nsyl = nsyl, start = start_ord, ["end"] = start_ord + nsyl - 1, acc_rel = acc_rel, acc_abs = acc_abs }
		else
			seq[#seq+1] = t
		end
	end
	return { seq = seq, words = words, syll_count = ord }
end

local function find_anchor(words, start_i)
	local i = start_i
	while i >= 1 and (words[i].nsyl or 0) == 0 do i = i - 1 end
	if i < 1 then return nil end
	local skipped_mono = false
	if words[i].nsyl == 1 then
		skipped_mono = true
		i = i - 1
		while i >= 1 and (words[i].nsyl or 0) == 0 do i = i - 1 end
		if i < 1 then
			-- Only a trailing monosyllable exists
			local mono = start_i
			return { ord = words[mono].start, word_i = mono }
		end
	end
	local w = words[i]
	local acc_rel = w.acc_rel or ((w.nsyl >= 2) and (w.nsyl - 1) or 1)
	if skipped_mono and w.nsyl >= 3 and acc_rel == (w.nsyl - 2) then
		acc_rel = w.nsyl -- antepenult -> ultima override
	end
	return { ord = w.start + acc_rel - 1, word_i = i }
end

-- forward decl for emitter used below
local style_emit

local function apply_cadence_model(model, prep, anchor_sel, use_second)
	local seq, words = model.seq, model.words
	local idx = {}
	for i, it in ipairs(seq) do if it.kind == "syl" then idx[#idx+1] = i end end
	if #idx == 0 then for _, it in ipairs(seq) do tex.sprint(it.text) end; return end

	local a1 = find_anchor(words, #words)
	local a2 = a1 and find_anchor(words, a1.word_i - 1) or nil

	local main_ord = (anchor_sel == "second" and a2 and a2.ord) or (a1 and a1.ord) or 1
	if main_ord < 1 then main_ord = 1 elseif main_ord > #idx then main_ord = #idx end

	local prep_set = {}
	local ps = math.max(1, main_ord - (prep or 0))
	for k = ps, main_ord - 1 do prep_set[k] = true end

	local sec_ord = (use_second and a2 and a2.ord) or nil

	local cur_ord = 0
	for i, it in ipairs(seq) do
		if it.kind == "syl" then
			cur_ord = cur_ord + 1
			if cur_ord == main_ord then
				style_emit("accent", it.text)
			elseif sec_ord and cur_ord == sec_ord then
				style_emit("secaccent", it.text)
			elseif prep_set[cur_ord] then
				style_emit("prep", it.text)
			else
				style_emit("other", it.text)
			end
		else
			tex.sprint(it.text)
		end
	end
end

-- ===== Tone config stack =====
--   divider: printed between halves (defaults to \PsalmHalfDivider or "*")
--   mediant_prep/post, termination_prep/post: integers
local default_cfg = {
	divider = nil,
	-- how many preps before the chosen anchor syllable
	mediant_prep = 1, mediant_post = 1, -- post kept for compatibility (unused by anchor logic)
	termination_prep = 1, termination_post = 1,
	-- which anchor to use for each cadence: "last" (default) or "second"
	mediant_anchor = "last",
	termination_anchor = "last",
	-- whether to actively mark the second accent as its own accent (not just prep)
	mediant_use_second = false,
	termination_use_second = false,
}
local stack = { default_cfg }

local function clone(tbl) local t = {}; for k,v in pairs(tbl) do t[k]=v end; return t end

local function parse_keyvals(s, base)
	local t = clone(base)
	for key, val in s:gmatch("([%a_]+)%s*=%s*([^,;]+)") do
		val = val:gsub("^%s+",""):gsub("%s+$","")
		local vlow = val:lower()
		if key == "divider" then
			t.divider = val
		elseif key == "mediant" or key == "termination" then
			local a,b = val:match("(%d+)%s*%+%s*(%d+)")
			if a and b then
				a, b = tonumber(a), tonumber(b)
				if key == "mediant" then
					t.mediant_prep, t.mediant_post = a, b
				else
					t.termination_prep, t.termination_post = a, b
				end
			end
		elseif key == "mediant_anchor" or key == "termination_anchor" then
			local choice = (vlow == "second") and "second" or "last"
			if key == "mediant_anchor" then t.mediant_anchor = choice else t.termination_anchor = choice end
		elseif key == "mediant_use_second" or key == "termination_use_second" then
			local truthy = (vlow == "1" or vlow == "true" or vlow == "yes" or vlow == "y")
			if key == "mediant_use_second" then t.mediant_use_second = truthy else t.termination_use_second = truthy end
		elseif t[key] ~= nil then
			t[key] = tonumber(val) or t[key]
		elseif key == "accent" then
			psalmtones.set_accent_mode(val)
		end
	end
	return t
end

function psalmtones.apply_setup(kv)   stack[1] = parse_keyvals(kv, default_cfg) end
function psalmtones.push_tone(kv)     stack[#stack+1] = parse_keyvals(kv, stack[#stack]) end
function psalmtones.pop_tone()        if #stack > 1 then stack[#stack] = nil end end

-- ===== Presets =====
psalmtones.presets = {
	-- New-style presets using anchor logic
	-- Defaults keep traditional behavior (accent = last, no explicit second accent)
	["1D"]   = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=true, termination_use_second=false },
	["1D2"]  = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=true, termination_use_second=false },
	["1f"]   = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=true, termination_use_second=false },
	["1g"]   = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=true, termination_use_second=false },
	["1g2"]  = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=true, termination_use_second=false },
	["1g3"]  = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=true, termination_use_second=false },
	["1a"]   = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=true, termination_use_second=false },
	["1a2"]  = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=true, termination_use_second=false },
	["1a3"]  = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=true, termination_use_second=false },

	["2"]    = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },

	["3b"]   = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["3a"]   = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["3a2"]  = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["3g"]   = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["3g2"]  = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },

	["4g"]   = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["4E"]   = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["4c"]   = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["4A"]   = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["4A-star"]  = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },

	["5"]    = { mediant_prep=2, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },

	["6"]    = { mediant_prep=1, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },

	["7a"]   = { mediant_prep=2, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["7b"]   = { mediant_prep=2, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["7c"]   = { mediant_prep=2, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["7c2"]  = { mediant_prep=2, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["7d"]   = { mediant_prep=2, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },

	["8G"]   = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["8G-star"] = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },
	["8c"]   = { mediant_prep=0, termination_prep=2, mediant_anchor="last", termination_anchor="last", mediant_use_second=false, termination_use_second=false },

	["peregrinus"] = { mediant_prep=2, termination_prep=2, mediant_anchor="last", termination_anchor="second", mediant_use_second=false, termination_use_second=true },
}

local function push_preset(name)
	local p = psalmtones.presets[name]
	if not p then return false end
	if p.mediant_prep then
		local kv = string.format(
			"mediant=%d+0, termination=%d+0, mediant_anchor=%s, termination_anchor=%s, mediant_use_second=%s, termination_use_second=%s",
			p.mediant_prep or 0,
			p.termination_prep or 0,
			p.mediant_anchor or "last",
			p.termination_anchor or "last",
			(p.mediant_use_second and "true" or "false"),
			(p.termination_use_second and "true" or "false")
		)
		psalmtones.push_tone(kv)
		return true
	end
	-- Back-compat (old 4-number form)
	local kv = string.format("mediant=%d+%d, termination=%d+%d",
		p[1] or 1, p[2] or 1, p[3] or 1, p[4] or 0)
	psalmtones.push_tone(kv)
	return true
end

-- ===== Styling emitters =====
local function strip_marker(s) return (s:gsub("%'%s*$","")) end

style_emit = function(kind, txt)
	local style
	if kind == "accent" then
		style = texmacro("PsalmStyleAccent")
	elseif kind == "secaccent" then
		style = texmacro("PsalmStyleSecondAccent")
		if style == "" then style = texmacro("PsalmStyleAccent") end
	elseif kind == "prep" then
		style = texmacro("PsalmStylePrep")
	else
		style = texmacro("PsalmStyleOther")
	end
	tex.sprint("{", style, strip_marker(txt), "}")
end
-- 	elseif kind == "prep" then
-- 		style = texmacro("PsalmStylePrep")
-- 	else
-- 		style = texmacro("PsalmStyleOther")
-- 	end
-- 	tex.sprint("{", style, strip_marker(txt), "}")
-- end

-- Compute accent position for a syllable-only index array
local function compute_accent_pos(seq, idx, post)
	if accent_mode == ACCENT_ORTHOGRAPHIC then
		local last = nil
		for pos, seq_i in ipairs(idx) do
			local syl = seq[seq_i].text
			if syl_has_orthographic_accent(syl) then last = pos end
		end
		if last then return last end  -- found one; use it
	end
	-- Positional fallback (Liber): accent is (#syl - post), clamped
	local n = #idx
	local pos = n - post
	if pos < 1 then pos = 1 elseif pos > n then pos = n end
	return pos
end

-- Apply cadence to a half-verse sequence
local function apply_cadence(seq, prep, post)
	local idx = {}
	for i, it in ipairs(seq) do if it.kind == "syl" then idx[#idx+1] = i end end
	local n = #idx
	if n == 0 then for _, it in ipairs(seq) do tex.sprint(it.text) end; return end

	local accent_pos = compute_accent_pos(seq, idx, post)
	local accent_i   = idx[accent_pos]

	local prep_start = math.max(1, accent_pos - prep)
	local prep_set = {}
	for p = prep_start, accent_pos - 1 do prep_set[idx[p]] = true end

	for i, it in ipairs(seq) do
		if it.kind == "syl" then
			if i == accent_i then      style_emit("accent", it.text)
			elseif prep_set[i] then    style_emit("prep",   it.text)
			else                       style_emit("other",  it.text)
			end
		else
			tex.sprint(it.text)
		end
	end
end

-- ===== Split a line at the first divider =====
local function split_halves(line, divider)
	local a, b = line:find(divider, 1, true)
	if a then return line:sub(1, a-1), line:sub(b+1) else return line, nil end
end

-- ===== Public: process one logical psalm line =====
local function to_seq(str) return halfverse_syllables(tokenize(str)) end

function psalmtones.process_line(line)
	local cfg = stack[#stack]
	local divider = cfg.divider or texmacro("PsalmHalfDivider")
	if divider == "" or not divider then divider = "*" end
	local left, right = split_halves(line, divider)

	local modelL = halfverse_model(tokenize(left))
	apply_cadence_model(modelL, cfg.mediant_prep, cfg.mediant_anchor, cfg.mediant_use_second)

	if right then
		tex.sprint(divider)
		local modelR = halfverse_model(tokenize(right))
		apply_cadence_model(modelR, cfg.termination_prep, cfg.termination_anchor, cfg.termination_use_second)
	end
	
	-- Ensure proper line ending to avoid underfull hbox warnings
	tex.sprint("\\par ")
end

-- ===== Process one line without syllabification =====
function psalmtones.process_line_no_syllabification(line)
	local cfg = stack[#stack]
	local divider = cfg.divider or texmacro("PsalmHalfDivider")
	if divider == "" or not divider then divider = "*" end
	local left, right = split_halves(line, divider)

	-- Just print the text without any syllabification or styling
	tex.sprint(left)
	if right then
		tex.sprint(divider)
		tex.sprint(right)
	end
	
	-- Ensure proper line ending to avoid underfull hbox warnings
	tex.sprint("\\par ")
end

-- ===== Process an entire psalm file =====
-- dir/num.ext is read; each text line is fed to process_line and followed by \par
function psalmtones.run_psalm(num, preset, dir, ext, accent_opt, verse_numbers, gloria_patri, suppress_syllabification)
	ext = (ext and ext ~= "") and ext or "txt"
	dir = (dir and dir ~= "") and dir or "psalms"
	if accent_opt and accent_opt ~= "" then psalmtones.set_accent_mode(accent_opt) end

	local pushed = false
	if preset and preset ~= "" then pushed = push_preset(preset) end

	-- Use kpsewhich to find the file in the TeX distribution
	local filename = string.format("%s/%s.%s", dir, num, ext)
	local path = kpse.find_file(filename)
	if not path then
		-- Fallback to relative path for backward compatibility
		path = filename
	end
	
	local fh = io.open(path, "r")
	if not fh then
		tex.error(string.format("psalmtones: cannot open %q (tried %s)", filename, path))
		if pushed then psalmtones.pop_tone() end
		return
	end
	
	-- Start enumerate environment if verse numbers are requested
	if verse_numbers == "true" then
		tex.sprint("\\begin{psalmverses}")
	end
	
	local verse_count = 0
	for line in fh:lines() do
		-- strip CR and trailing spaces only; keep leading/trailing punctuation and the '*' divider
		line = line:gsub("\r", ""):gsub("%s+$","")
		if line ~= "" then
			verse_count = verse_count + 1
			-- Add item for enumerate if verse numbers are requested
			if verse_numbers == "true" then
				tex.sprint("\\item ")
			end
			-- Process line with or without syllabification
			if suppress_syllabification == "true" then
				psalmtones.process_line_no_syllabification(line)
			else
				psalmtones.process_line(line)
			end
		else
			-- blank line -> paragraph break (only if not in enumerate)
			if verse_numbers ~= "true" then
				tex.sprint("\\par ")
			end
		end
	end
	fh:close()
	
	-- Add Gloria Patri if requested (before ending enumerate)
	if gloria_patri == "true" then
		-- Add item for enumerate if verse numbers are requested
		if verse_numbers == "true" then
			tex.sprint("\\item ")
		else
			tex.sprint("\\par\\vspace{0.5em}")
		end
		-- Process Gloria Patri with psalm tone styling
		if suppress_syllabification == "true" then
			psalmtones.process_line_no_syllabification("Glória Patri, et Fílio, * et Spirítui Sancto.")
		else
			psalmtones.process_line("Glória Patri, et Fílio, * et Spirítui Sancto.")
		end
		
		-- Add item for enumerate if verse numbers are requested
		if verse_numbers == "true" then
			tex.sprint("\\item ")
		else
			tex.sprint("\\par\\vspace{0.5em}")
		end
		-- Process second line of Gloria Patri with psalm tone styling
		if suppress_syllabification == "true" then
			psalmtones.process_line_no_syllabification("Sicut erat in princípio, et nunc, et semper, * et in sǽcula sæculórum. Amen.")
		else
			psalmtones.process_line("Sicut erat in princípio, et nunc, et semper, * et in sǽcula sæculórum. Amen.")
		end
	end
	
	-- End enumerate environment if verse numbers are requested
	if verse_numbers == "true" then
		tex.sprint("\\end{psalmverses}")
	end
	
	if pushed then psalmtones.pop_tone() end
end

return psalmtones

