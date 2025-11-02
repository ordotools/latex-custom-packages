-- psalmtones.lua  (UTF-8)
-- Liber-style psalm-tone styling from syllables.
-- -----------------------------------------------------------------------------
-- Copyright (C) 2025 Gregory R. Barnes
-- This work may be distributed and/or modified under the conditions of the
-- LaTeX Project Public License, version 1.3c or (at your option) any later
-- version. The latest version of this license is available at
-- https://www.latex-project.org/lppl/
-- This work has the LPPL maintenance status "maintained".
-- The Current Maintainer of this work is Gregory R. Barnes.
-- -----------------------------------------------------------------------------

local psalmtones = {}

-- ===== Options =====
psalmtones.debug = false  -- set true to log syllables/lang IDs to .log

-- ===== LuaTeX handles =====
local node, lang, utf = node, lang, utf8
local N_GLY, N_DISC = node.id("glyph"), node.id("disc")

local function texmacro(name) return token.get_macro(name) or "" end

-- ===== Accent detection (orthographic mode uses this) =====
-- Precomposed acute vowels: áéíóúý ÁÉÍÓÚÝ ǽǼ ǿ and combining acute U+0301
local function syl_has_orthographic_accent(s)
	-- Check for acute vowels (lowercase and uppercase)
	if s:find("á") or s:find("é") or s:find("í") or s:find("ó") or s:find("ú") or s:find("ý") then
		return true
	end
	if s:find("Á") or s:find("É") or s:find("Í") or s:find("Ó") or s:find("Ú") or s:find("Ý") then
		return true
	end
	-- Check for ae/oe ligatures with acute: ǽ Ǽ ǿ Ǿ
	if s:find("ǽ") or s:find("Ǽ") or s:find("ǿ") or s:find("Ǿ") then
		return true
	end
	-- Check for combining acute accent U+0301
	if s:find("\204\129") then
		return true
	end
	-- Check for trailing apostrophe (alternate notation)
	if s:find("%'%s*$") then
		return true
	end
	return false
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

-- ===== NEW Cadence Application Logic =====

-- Helper: is this word a monosyllable?
local function is_monosyllable(word_syls)
	return #word_syls == 1
end

-- Helper: get primary accent position in a word (1-indexed from start of word)
local function word_primary_accent_pos(word_syls)
	local n = #word_syls
	if n == 0 then return nil end
	
	-- Rule 5.a: Always check for orthographic accent first (regardless of mode)
	for i = n, 1, -1 do
		if syl_has_orthographic_accent(word_syls[i]) then
			return i
		end
	end
	
	-- If no orthographic accent found, use positional rules:
	
	-- Rule 5.b: Monosyllables are accented (return position 1)
	if n == 1 then return 1 end
	
	-- Rule 5.c: Two syllables -> penult (second-to-last, which is position 1)
	if n == 2 then return 1 end
	
	-- Rule 5.d: Three or more -> antepenult (third-to-last)
	return n - 2
end

-- Helper: get all accented syllable positions in a word (including secondary accents)
-- Returns array of positions (1-indexed from start of word)
local function word_all_accent_positions(word_syls)
	local positions = {}
	local primary = word_primary_accent_pos(word_syls)
	if not primary then return positions end
	
	positions[#positions + 1] = primary
	
	-- Rule 5.e: Syllables 2 away from primary accent can also be accented
	if primary >= 3 then
		positions[#positions + 1] = primary - 2
	end
	if primary + 2 <= #word_syls then
		positions[#positions + 1] = primary + 2
	end
	
	-- Sort positions
	table.sort(positions)
	return positions
end

-- Build enhanced word model with accent information
local function build_word_model(tokens)
	local words = {}
	local all_syls = {}
	local syl_to_word = {} -- maps absolute syllable index to word index
	
	for _, t in ipairs(tokens) do
		if t.kind == "word" then
			local word_syls = hyphen_syllables(t.text)
			local word_info = {
				syls = word_syls,
				start_syl = #all_syls + 1,
				end_syl = #all_syls + #word_syls,
				accent_positions = word_all_accent_positions(word_syls),
				is_mono = is_monosyllable(word_syls)
			}
			words[#words + 1] = word_info
			
			for i = 1, #word_syls do
				all_syls[#all_syls + 1] = word_syls[i]
				syl_to_word[#all_syls] = #words
			end
		end
	end
	
	return {
		words = words,
		all_syls = all_syls,
		syl_to_word = syl_to_word,
		total_syls = #all_syls
	}
end

-- Find Nth accent from the end (position=1 means last word's accent, position=2 means second-to-last word's accent)
-- Returns absolute syllable index, or nil
local function find_nth_accent_from_end(model, position)
	local word_count = 0
	for i = #model.words, 1, -1 do
		local w = model.words[i]
		if #w.accent_positions > 0 then
			word_count = word_count + 1
			if word_count == position then
				-- Return the primary (first) accent of this word
				local rel_pos = w.accent_positions[1]
				return w.start_syl + rel_pos - 1
			end
		end
	end
	return nil
end

-- ===== Styling emitters =====
local function strip_marker(s) return (s:gsub("%'%s*$","")) end

local function style_emit(kind, txt)
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

-- Apply a cadence spec to a half-verse
-- cadence_spec = { accents = { {position=N, extra_before=N, extra_after=N, pre=N, post=N}, ... } }
-- cadence_type = "flex" | "mediant" | "termination"
local function apply_new_cadence(tokens, cadence_spec, cadence_type)
	if not cadence_spec or not cadence_spec.accents then
		-- No spec, just output plain text
		for _, t in ipairs(tokens) do
			if t.kind == "word" then
				tex.sprint(t.text)
			else
				tex.sprint(t.text)
			end
		end
		return
	end
	
	local model = build_word_model(tokens)
	if model.total_syls == 0 then
		-- No syllables, just output
		for _, t in ipairs(tokens) do tex.sprint(t.text) end
		return
	end
	
	-- Build syllable styling map
	local syl_style = {} -- syl_style[i] = "accent" | "extra" | "prep" | "post_italic" | "other"
	for i = 1, model.total_syls do
		syl_style[i] = "other"
	end
	
	-- Process each accent in the spec
	for _, acc_spec in ipairs(cadence_spec.accents) do
		local accent_pos = find_nth_accent_from_end(model, acc_spec.position)
		
		if accent_pos then
			-- Rule 4: Check if we have enough post-syllables
			local syllables_after = model.total_syls - accent_pos
			if syllables_after >= acc_spec.post then
				-- We have enough syllables after this accent for the required post
				
				-- Mark the accent itself (unless it's a flex)
				if cadence_type ~= "flex" then
					syl_style[accent_pos] = "accent"
				end
				
				-- Calculate syllables before accent
				local syllables_before = accent_pos - 1
				
				-- Mark extra syllables after accent (only if we have enough beyond post requirement)
				-- Pattern: accent → extra_after → post
				if syllables_after >= acc_spec.post + acc_spec.extra_after then
					for i = 1, acc_spec.extra_after do
						local pos = accent_pos + i
						if pos <= model.total_syls and syl_style[pos] == "other" then
							syl_style[pos] = "extra"
						end
					end
				end
				
				-- Mark extra syllables before accent (only if we have enough beyond prep requirement)
				-- Pattern: prep → extra_before → accent
				if syllables_before >= acc_spec.pre + acc_spec.extra_before then
					for i = 1, acc_spec.extra_before do
						local pos = accent_pos - i
						if pos >= 1 and syl_style[pos] == "other" then
							syl_style[pos] = "extra"
						end
					end
				end
				
				-- Mark prep syllables (italic) before accent and extra_before
				for i = 1, acc_spec.pre do
					local pos = accent_pos - i - acc_spec.extra_before
					if pos >= 1 and syl_style[pos] == "other" then
						syl_style[pos] = "prep"
					end
				end
				
				-- Rule 6: For flex, italicize everything after accent
				if cadence_type == "flex" then
					for i = accent_pos + 1, model.total_syls do
						if syl_style[i] == "other" then
							syl_style[i] = "post_italic"
						end
					end
				end
			end
			-- If not enough post syllables, this accent is ignored and we try the next accent
		end
	end
	
	-- Now output the tokens with styling
	local syl_idx = 0
	for _, t in ipairs(tokens) do
		if t.kind == "word" then
			local word_syls = hyphen_syllables(t.text)
			local join = texmacro("PsalmJoiner")
			for k, s in ipairs(word_syls) do
				syl_idx = syl_idx + 1
				local style = syl_style[syl_idx]
				
				if style == "accent" or style == "extra" then
					style_emit("accent", s)
				elseif style == "prep" or style == "post_italic" then
					style_emit("prep", s)
				else
					style_emit("other", s)
				end
				
				if k < #word_syls and join ~= "" then
					tex.sprint(join)
				end
			end
		else
			tex.sprint(t.text)
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
-- New structure: each preset has flex, mediant, termination sub-tables
-- Each sub-table contains:
--   accents = array of accent specifications
--
-- Each accent spec has:
--   position      = which accent from the end (1=last, 2=second-to-last, etc.)
--   extra_before  = number of extra syllables before accent (styled bold)
--   extra_after   = number of extra syllables after accent (styled bold)
--   pre           = number of preparatory syllables before accent (styled italic)
--   post          = minimum syllables required after accent (not styled, just spacing)
--
-- Example with all features:
--   flex        = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} }
--   mediant     = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} }
--   termination = { accents = {
--                     { position=2, extra_before=0, extra_after=0, pre=0, post=0 },  -- second accent
--                     { position=1, extra_before=0, extra_after=2, pre=1, post=0 }   -- first accent
--                   }}
--

psalmtones.presets = {
	["1D"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {
			{ position=2, extra_before=0, extra_after=1, pre=0, post=1 },
			{ position=1, extra_before=0, extra_after=1, pre=0, post=1 }
		}
		},
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=2, post=0 }} }
	},
	["1D2"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {
			{ position=2, extra_before=0, extra_after=1, pre=0, post=1 },
			{ position=1, extra_before=0, extra_after=1, pre=0, post=1 }
		}
		},
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=2, post=0 }} }
	},
	["1f"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {
			{ position=2, extra_before=0, extra_after=1, pre=0, post=1 },
			{ position=1, extra_before=0, extra_after=1, pre=0, post=1 }
		}
		},
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=2, post=0 }} }
	},
	["1g"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {
			{ position=2, extra_before=0, extra_after=0, pre=0, post=1 },
			{ position=1, extra_before=0, extra_after=0, pre=0, post=1 }
		}
		},
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=2, post=0 }} }
	},
	["1g2"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {
			{ position=2, extra_before=0, extra_after=1, pre=0, post=1 },
			{ position=1, extra_before=0, extra_after=1, pre=0, post=1 }
		}
		},
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=2, post=0 }} }
	},
	["1g3"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {
			{ position=2, extra_before=0, extra_after=1, pre=0, post=1 },
			{ position=1, extra_before=0, extra_after=1, pre=0, post=1 }
		}
		},
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=2, post=0 }} }
	},
	["1a"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {
			{ position=2, extra_before=0, extra_after=1, pre=0, post=1 },
			{ position=1, extra_before=0, extra_after=1, pre=0, post=1 }
		}
		},
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=2, post=0 }} }
	},
	["1a2"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {
			{ position=2, extra_before=0, extra_after=1, pre=0, post=1 },
			{ position=1, extra_before=0, extra_after=1, pre=0, post=1 }
		}
		},
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=2, post=0 }} }
	},
	["1a3"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {
			{ position=2, extra_before=0, extra_after=1, pre=0, post=1 },
			{ position=1, extra_before=0, extra_after=1, pre=0, post=1 }
		}
		},
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=2, post=0 }} }
	},

	["2"]    = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=1, post=0 }} }
	},

	["3b"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=0, post=0 }} }
	},
	["3a"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=0, post=0 }} }
	},
	["3a2"]  = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=2, pre=0, post=0 }} }
	},
	["3g"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=2, pre=0, post=0 }} }
	},
	["3g2"]  = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=3, pre=0, post=0 }} }
	},

	["4g"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},
	["4E"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=1, pre=3, post=1 }} }
	},
	["4c"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},
	["4A"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},
	["4A-star"]  = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},

	["5"]    = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},

	["6"]    = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=1, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},

	["7a"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},
	["7b"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},
	["7c"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},
	["7c2"]  = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},
	["7d"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},

	["8G"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},
	["8G-star"] = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},
	["8c"]   = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=1 }} },
		termination = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }} }
	},

	["peregrinus"] = {
		flex = { accents = {{ position=1, extra_before=0, extra_after=0, pre=0, post=0 }} },
		mediant = { accents = {{ position=1, extra_before=0, extra_after=0, pre=2, post=1 }} },
		termination = {
			accents = {
				{ position=2, extra_before=0, extra_after=0, pre=0, post=0 },
				{ position=1, extra_before=0, extra_after=0, pre=2, post=0 }
			}
		}
	},
}

-- Store current preset (no longer uses push_tone - direct storage)
local current_preset = nil

local function push_preset(name)
	local p = psalmtones.presets[name]
	if not p then return false end
	current_preset = p
	return true
end

local function pop_preset()
	current_preset = nil
end

-- ===== Split a line at the first divider =====
local function split_halves(line, divider)
	local a, b = line:find(divider, 1, true)
	if a then return line:sub(1, a-1), line:sub(b+1) else return line, nil end
end

-- ===== Public: process one logical psalm line =====
-- Flex is indicated by a dagger (†) symbol
local function is_flex_line(line)
	return line:find("†") ~= nil or line:find("\\dag") ~= nil
end

function psalmtones.process_line(line)
	if not current_preset then
		-- Fallback: no preset, just output the line as-is
		tex.sprint(line)
		tex.sprint("\\par ")
		return
	end
	
	local divider = texmacro("PsalmHalfDivider")
	if divider == "" or not divider then divider = "*" end
	
	-- First, split at the asterisk to get left and right halves
	local left, right = split_halves(line, divider)
	
	-- Check if the left half contains a flex marker
	local has_flex = left:find("†") or left:find("\\dag")
	
	if has_flex then
		-- Split the left half at the flex marker
		local flex_marker = left:match("†") and "†" or "\\dag"
		local flex_pos = left:find(flex_marker, 1, true)
		local before_flex = left:sub(1, flex_pos - 1)
		local after_flex = left:sub(flex_pos + #flex_marker)
		
		-- Apply flex cadence to the part before the flex marker
		local tokens_before_flex = tokenize(before_flex)
		apply_new_cadence(tokens_before_flex, current_preset.flex, "flex")
		
		-- Output the flex marker
		tex.sprint(" " .. (left:match("†") or "\\dag") .. " ")
		
		-- Apply mediant cadence to the part after flex
		local tokens_after_flex = tokenize(after_flex)
		apply_new_cadence(tokens_after_flex, current_preset.mediant, "mediant")
	else
		-- Normal mediant (no flex)
		local tokensL = tokenize(left)
		apply_new_cadence(tokensL, current_preset.mediant, "mediant")
	end
	
	-- Output the divider and termination
	if right then
		tex.sprint(divider)
		local tokensR = tokenize(right)
		apply_new_cadence(tokensR, current_preset.termination, "termination")
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

-- ===== Process first line with dropcap =====
function psalmtones.process_line_with_dropcap(line, dropcap_lines, dropcap_lhang, dropcap_loversize, dropcap_lraise, suppress_syllabification)
	-- Strip BOM if present (UTF-8 BOM is EF BB BF)
	line = line:gsub("^\239\187\191", "")
	
	-- Extract first letter for dropcap
	local first_char = line:match("^[%z\1-\127\194-\244][\128-\191]*")
	if not first_char then
		-- Fallback: process normally if we can't extract first character
		if suppress_syllabification == "true" then
			psalmtones.process_line_no_syllabification(line)
		else
			psalmtones.process_line(line)
		end
		return
	end
	
	-- Rest of the line after first character
	local rest = line:sub(#first_char + 1)
	
	-- Extract first word (for lettrine's second argument - needs to be plain text)
	-- Match UTF-8 word characters (not spaces, colons, or asterisks)
	local first_word = rest:match("^([^%s:*]+)")
	if not first_word then first_word = "" end
	local after_first_word = rest:sub(#first_word + 1)
	
	-- Debug output
	if psalmtones.debug then
		texio.write_nl(string.format("[dropcap] first_char=%q first_word=%q", first_char, first_word))
	end
	
	-- Build lettrine command with parameters
	local lettrine_opts = string.format("lines=%s, lhang=%s, loversize=%s, lraise=%s", 
		dropcap_lines or "2", 
		dropcap_lhang or "0", 
		dropcap_loversize or "0", 
		dropcap_lraise or "0")
	
	-- Output lettrine command with first word as plain text
	tex.print(string.format("\\lettrine[%s]{%s}{%s}", lettrine_opts, first_char, first_word))
	
	-- Now process the rest of the line with psalm tone styling
	local divider = texmacro("PsalmHalfDivider")
	if divider == "" or not divider then divider = "*" end
	local left, right = split_halves(after_first_word, divider)
	
	if suppress_syllabification == "true" then
		-- Just print the text without syllabification
		tex.sprint(left)
		if right then
			tex.sprint(divider)
			tex.sprint(right)
		end
	else
		-- Process with new cadence system
		if current_preset then
			-- Check if the left half contains a flex marker
			local has_flex = left:find("†") or left:find("\\dag")
			
			if has_flex then
				-- Split the left half at the flex marker
				local flex_marker = left:match("†") and "†" or "\\dag"
				local flex_pos = left:find(flex_marker, 1, true)
				local before_flex = left:sub(1, flex_pos - 1)
				local after_flex = left:sub(flex_pos + #flex_marker)
				
				-- Apply flex cadence to the part before the flex marker
				local tokens_before_flex = tokenize(before_flex)
				apply_new_cadence(tokens_before_flex, current_preset.flex, "flex")
				
				-- Output the flex marker
				tex.sprint(" " .. (left:match("†") or "\\dag") .. " ")
				
				-- Apply mediant cadence to the part after flex
				local tokens_after_flex = tokenize(after_flex)
				apply_new_cadence(tokens_after_flex, current_preset.mediant, "mediant")
			else
				-- Normal mediant (no flex)
				local tokensL = tokenize(left)
				apply_new_cadence(tokensL, current_preset.mediant, "mediant")
			end
			
			-- Output the divider and termination
			if right then
				tex.sprint(divider)
				local tokensR = tokenize(right)
				apply_new_cadence(tokensR, current_preset.termination, "termination")
			end
		else
			-- No preset, just output
			tex.sprint(left)
			if right then
				tex.sprint(divider)
				tex.sprint(right)
			end
		end
	end
	
	-- Ensure proper line ending
	tex.sprint("\\par ")
end

-- ===== Process an entire psalm file =====
-- dir/num.ext is read; each text line is fed to process_line and followed by \par
function psalmtones.run_psalm(num, preset, dir, ext, accent_opt, verse_numbers, gloria_patri, suppress_syllabification, dropcap, dropcap_lines, dropcap_lhang, dropcap_loversize, dropcap_lraise)
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
		if pushed then pop_preset() end
		return
	end
	
	-- Start enumerate environment if verse numbers are requested
	if verse_numbers == "true" then
		-- If dropcap is enabled, start numbering from 2
		if dropcap == "true" then
			tex.sprint("\\begin{psalmverses}\\setcounter{psalmversesi}{1}")
		else
			tex.sprint("\\begin{psalmverses}")
		end
	end
	
	local verse_count = 0
	local is_first_verse = true
	for line in fh:lines() do
		-- strip CR and trailing spaces only; keep leading/trailing punctuation and the '*' divider
		line = line:gsub("\r", ""):gsub("%s+$","")
		if line ~= "" then
			verse_count = verse_count + 1
			
			-- Handle first verse with dropcap if requested
			if is_first_verse and dropcap == "true" then
				is_first_verse = false
				-- No \item for first verse when dropcap is enabled
				if verse_numbers ~= "true" then
					-- Process with dropcap outside of enumerate
					psalmtones.process_line_with_dropcap(line, dropcap_lines, dropcap_lhang, dropcap_loversize, dropcap_lraise, suppress_syllabification)
				else
					-- Process with dropcap inside enumerate but without numbering
					tex.sprint("\\item[] ")
					psalmtones.process_line_with_dropcap(line, dropcap_lines, dropcap_lhang, dropcap_loversize, dropcap_lraise, suppress_syllabification)
				end
			else
				-- Normal verse processing
				is_first_verse = false
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
	
	if pushed then pop_preset() end
end

return psalmtones
