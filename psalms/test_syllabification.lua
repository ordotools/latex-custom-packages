#!/usr/bin/env lua
-- test_syllabification.lua
-- Standalone testing tool for Latin syllabification
-- Extracted from psalmtones.lua for testing and debugging

local utf8 = require("utf8")

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

local function set_accent_mode(mode)
	if mode == ACCENT_ORTHOGRAPHIC then accent_mode = ACCENT_ORTHOGRAPHIC
	else accent_mode = ACCENT_POSITIONAL end
end

-- ===== Tiny tokenizer: words vs separators (UTF-8 friendly) =====
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

-- ===== Fallback syllabifier (Latin/English-ish) =====
local VCL = "[AEIOUYaeiouyÁÉÍÓÚÝáéíóúýÆŒæœ]"
local function is_vowel(ch) return ch:match(VCL) ~= nil end

local function latin_like_syllables(word)
	local chars = {}
	for _,c in utf8.codes(word) do chars[#chars+1] = utf8.char(c) end
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
	return out
end

-- ===== Improved Latin Syllabifier =====
local function improved_latin_syllables_simple(word)
	local chars = {}
	for _,c in utf8.codes(word) do chars[#chars+1] = utf8.char(c) end
	if #chars == 0 then return {} end

	-- Enhanced vowel detection including Latin diacritics
	local function is_vowel(ch)
		return ch:match("[AEIOUYaeiouyÁÉÍÓÚÝáéíóúýÆŒæœ]") ~= nil
	end

	-- Diphthongs in Latin
	local function is_diphthong(a, b)
		local pair = (a..b):lower()
		return pair == "ae" or pair == "oe" or pair == "au" or 
		       pair == "ei" or pair == "ui" or pair == "eu"
	end

	-- Consonant clusters that stay together (stop + liquid)
	local stop_liquid_clusters = {
		pr=true, br=true, tr=true, dr=true, cr=true, gr=true, fr=true, vr=true,
		pl=true, bl=true, cl=true, gl=true, fl=true, sl=true,
		ph=true, th=true, ch=true, qu=true, -- special cases
	}

	local syllables = {}
	local i = 1

	while i <= #chars do
		local syllable = {}
		
		-- Collect onset consonants
		while i <= #chars and not is_vowel(chars[i]) do
			syllable[#syllable+1] = chars[i]
			i = i + 1
		end
		
		-- Must have a vowel nucleus
		if i > #chars then
			-- No vowel found - attach remaining consonants to previous syllable
			if #syllables > 0 then
				for _, ch in ipairs(syllable) do
					syllables[#syllables] = syllables[#syllables] .. ch
				end
			else
				syllables[#syllables+1] = table.concat(syllable)
			end
			break
		end
		
		-- Collect vowel nucleus (including diphthongs)
		if is_vowel(chars[i]) then
			syllable[#syllable+1] = chars[i]
			i = i + 1
			
			-- Check for diphthong
			if i <= #chars and is_vowel(chars[i]) and is_diphthong(chars[i-1], chars[i]) then
				syllable[#syllable+1] = chars[i]
				i = i + 1
			end
		end
		
		-- Collect coda consonants (following traditional Latin rules)
		local coda = {}
		local j = i
		while j <= #chars and not is_vowel(chars[j]) do
			coda[#coda+1] = chars[j]
			j = j + 1
		end
		
		-- Apply consonant cluster rules
		if #coda >= 2 then
			local cluster = (coda[1]..coda[2]):lower()
			if stop_liquid_clusters[cluster] then
				-- Keep cluster together for next syllable onset (V-CCV)
				-- Don't add to coda
			else
				-- Split cluster: first consonant goes to coda, rest to next onset
				syllable[#syllable+1] = coda[1]
				-- Remove first consonant from coda for next iteration
				table.remove(coda, 1)
			end
		elseif #coda == 1 then
			-- Single consonant: leave for next syllable onset (V-CV rule)
			-- Don't add to coda
		end
		
		-- Add syllable if it has a vowel nucleus
		if #syllable > 0 then
			syllables[#syllables+1] = table.concat(syllable)
		end
		
		-- Update position for next iteration
		if #coda > 0 then
			-- Some consonants remain for next syllable
			chars = coda
			i = 1
		else
			i = j
		end
	end
	
	-- Validation: ensure no consonant-only syllables
	local valid_syllables = {}
	for _, syl in ipairs(syllables) do
		local has_vowel = false
		for _, ch in utf8.codes(syl) do
			if is_vowel(utf8.char(ch)) then
				has_vowel = true
				break
			end
		end
		if has_vowel then
			valid_syllables[#valid_syllables+1] = syl
		else
			-- Attach consonant-only syllable to previous one
			if #valid_syllables > 0 then
				valid_syllables[#valid_syllables] = valid_syllables[#valid_syllables] .. syl
			else
				valid_syllables[#valid_syllables+1] = syl
			end
		end
	end
	
	return valid_syllables
end

local function improved_latin_syllables(word)
	-- Use the original function but with better validation
	local syllables = latin_like_syllables(word)
	
	-- Enhanced vowel detection including Latin diacritics
	local function is_vowel(ch)
		return ch:match("[AEIOUYaeiouyÁÉÍÓÚÝáéíóúýÆŒæœ]") ~= nil
	end
	
	-- Validation: ensure no consonant-only syllables and fix single-letter issues
	local valid_syllables = {}
	for _, syl in ipairs(syllables) do
		local has_vowel = false
		for _, ch in utf8.codes(syl) do
			if is_vowel(utf8.char(ch)) then
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

-- ===== Testing Functions =====
local function test_word(word, method)
	local syllables
	if method == "original" then
		syllables = latin_like_syllables(word)
	else
		syllables = improved_latin_syllables(word)
	end
	
	local has_issues = false
	local issues = {}
	
	-- Check for single-letter syllables (except valid monosyllables)
	local valid_monosyllables = { "a", "e", "i", "o", "u", "y" }
	for _, syl in ipairs(syllables) do
		if #syl == 1 then
			local is_valid = false
			for _, valid in ipairs(valid_monosyllables) do
				if syl:lower() == valid then
					is_valid = true
					break
				end
			end
			if not is_valid then
				has_issues = true
				table.insert(issues, "single-letter syllable: '" .. syl .. "'")
			end
		end
	end
	
	-- Check for consonant-only syllables
	for _, syl in ipairs(syllables) do
		local has_vowel = false
		for _, ch in utf8.codes(syl) do
			if is_vowel(utf8.char(ch)) then
				has_vowel = true
				break
			end
		end
		if not has_vowel then
			has_issues = true
			table.insert(issues, "consonant-only syllable: '" .. syl .. "'")
		end
	end
	
	return syllables, has_issues, issues
end

local function process_psalm_file(filepath)
	local file = io.open(filepath, "r")
	if not file then
		return nil, "Could not open file: " .. filepath
	end
	
	local results = {
		filepath = filepath,
		words = {},
		total_words = 0,
		problematic_words = 0,
		original_issues = 0,
		improved_issues = 0
	}
	
	for line in file:lines() do
		line = line:gsub("\r", ""):gsub("%s+$", "")
		if line ~= "" then
			local tokens = tokenize(line)
			for _, token in ipairs(tokens) do
				if token.kind == "word" then
					results.total_words = results.total_words + 1
					
					local original_syls, orig_issues, orig_problems = test_word(token.text, "original")
					local improved_syls, impr_issues, impr_problems = test_word(token.text, "improved")
					
					local word_result = {
						word = token.text,
						original_syllables = original_syls,
						improved_syllables = improved_syls,
						original_has_issues = orig_issues,
						improved_has_issues = impr_issues,
						original_problems = orig_problems,
						improved_problems = impr_problems
					}
					
					results.words[#results.words+1] = word_result
					
					if orig_issues then
						results.original_issues = results.original_issues + 1
					end
					if impr_issues then
						results.improved_issues = results.improved_issues + 1
					end
					if orig_issues or impr_issues then
						results.problematic_words = results.problematic_words + 1
					end
				end
			end
		end
	end
	
	file:close()
	return results
end

local function generate_markdown_report(results, output_file)
	local file = io.open(output_file, "w")
	if not file then
		print("Error: Could not create output file: " .. output_file)
		return
	end
	
	file:write("# Syllabification Test Results\n\n")
	file:write("Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
	
	-- Summary statistics
	local total_files = #results
	local total_words = 0
	local total_original_issues = 0
	local total_improved_issues = 0
	local total_problematic_words = 0
	
	for _, result in ipairs(results) do
		total_words = total_words + result.total_words
		total_original_issues = total_original_issues + result.original_issues
		total_improved_issues = total_improved_issues + result.improved_issues
		total_problematic_words = total_problematic_words + result.problematic_words
	end
	
	file:write("## Summary\n\n")
	file:write("- **Total files processed:** " .. total_files .. "\n")
	file:write("- **Total words:** " .. total_words .. "\n")
	file:write("- **Words with original issues:** " .. total_original_issues .. "\n")
	file:write("- **Words with improved issues:** " .. total_improved_issues .. "\n")
	file:write("- **Improvement:** " .. (total_original_issues - total_improved_issues) .. " fewer issues\n\n")
	
	-- Detailed results per file
	for _, result in ipairs(results) do
		file:write("## " .. result.filepath .. "\n\n")
		file:write("- **Words:** " .. result.total_words .. "\n")
		file:write("- **Original issues:** " .. result.original_issues .. "\n")
		file:write("- **Improved issues:** " .. result.improved_issues .. "\n\n")
		
		-- Show problematic words
		local has_problems = false
		for _, word_result in ipairs(result.words) do
			if word_result.original_has_issues or word_result.improved_has_issues then
				if not has_problems then
					file:write("### Problematic Words\n\n")
					has_problems = true
				end
				
				file:write("**" .. word_result.word .. "**\n")
				file:write("- Original: `" .. table.concat(word_result.original_syllables, "|") .. "`")
				if word_result.original_has_issues then
					file:write(" ⚠️ " .. table.concat(word_result.original_problems, ", "))
				end
				file:write("\n")
				
				file:write("- Improved: `" .. table.concat(word_result.improved_syllables, "|") .. "`")
				if word_result.improved_has_issues then
					file:write(" ⚠️ " .. table.concat(word_result.improved_problems, ", "))
				end
				file:write("\n\n")
			end
		end
		
		if not has_problems then
			file:write("✅ No issues found\n\n")
		end
	end
	
	file:close()
	print("Report generated: " .. output_file)
end

-- ===== Main execution =====
local function main()
	local args = {}
	for i = 1, #arg do
		args[i] = arg[i]
	end
	
	if #args == 0 then
		print("Usage: lua test_syllabification.lua [word] | [psalm_directory]")
		print("  [word] - Test a single word")
		print("  [psalm_directory] - Test all files in directory")
		return
	end
	
	-- Check if argument is a directory
	local is_directory = false
	local handle = io.popen("test -d " .. args[1] .. " && echo 'yes' || echo 'no'")
	if handle then
		local result = handle:read("*l")
		handle:close()
		is_directory = (result == "yes")
	end
	
	if #args == 1 and not is_directory then
		-- Single word test
		local word = args[1]
		print("Testing word: " .. word)
		
		local original_syls, orig_issues, orig_problems = test_word(word, "original")
		local improved_syls, impr_issues, impr_problems = test_word(word, "improved")
		
		print("Original: " .. table.concat(original_syls, "|"))
		if orig_issues then
			print("  Issues: " .. table.concat(orig_problems, ", "))
		end
		
		print("Improved: " .. table.concat(improved_syls, "|"))
		if impr_issues then
			print("  Issues: " .. table.concat(impr_problems, ", "))
		end
	else
		-- Directory test
		local psalms_dir = args[1] or "psalms"
		print("Testing all files in: " .. psalms_dir)
		
		-- Check if directory exists
		local handle = io.popen("ls -la " .. psalms_dir .. " 2>/dev/null")
		if not handle then
			print("Directory " .. psalms_dir .. " does not exist")
			return
		end
		handle:close()
		
		local results = {}
		local files = {}
		
		-- Get list of .txt files
		local handle = io.popen("find " .. psalms_dir .. " -name '*.txt' | head -20")
		if handle then
			for file in handle:lines() do
				files[#files+1] = file
			end
			handle:close()
		end
		
		if #files == 0 then
			print("No .txt files found in " .. psalms_dir)
			return
		end
		
		print("Found " .. #files .. " files to process...")
		
		for _, filepath in ipairs(files) do
			print("Processing: " .. filepath)
			local result = process_psalm_file(filepath)
			if result then
				results[#results+1] = result
			end
		end
		
		-- Generate report
		generate_markdown_report(results, "syllabification_test_results.md")
	end
end

-- Run if called directly
if arg and arg[0] and arg[0]:match("test_syllabification%.lua$") then
	main()
end

-- Export functions for use as module
return {
	test_word = test_word,
	process_psalm_file = process_psalm_file,
	generate_markdown_report = generate_markdown_report,
	improved_latin_syllables = improved_latin_syllables,
	latin_like_syllables = latin_like_syllables
}
