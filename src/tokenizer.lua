local tokenizer = {}

local sentence_delims = "[%.%!%?]"
local word_pattern = "%w+['%w]*"

local function split_sentences(text)
  local sentences = {}
  local start = 1
  for i = 1, #text do
    local c = text:sub(i, i)
    if c:match(sentence_delims) then
      local seg = text:sub(start, i)
      seg = seg:gsub("^%s+", ""):gsub("%s+$", "")
      if #seg > 0 then
        sentences[#sentences + 1] = seg
      end
      start = i + 1
    end
  end
  -- trailing
  if start <= #text then
    local seg = text:sub(start)
    seg = seg:gsub("^%s+", ""):gsub("%s+$", "")
    if #seg > 0 then
      sentences[#sentences + 1] = seg
    end
  end
  return sentences
end

local function tokenize_sentence(sentence)
  local tokens = {}
  for w in sentence:gmatch(word_pattern) do
    tokens[#tokens + 1] = {
      raw = w,
      norm = w:lower()
    }
  end
  return tokens
end

-- phrase_patterns: array of {name="unity_merge", pattern="merger with the collective consciousness"}
local phrase_patterns = {
  {
    name = "unity_merge_collective",
    pattern = "merger with the collective consciousness"
  },
  {
    name = "sacred_purification_kill",
    pattern = "eliminate the unclean"
  }
}

local function detect_phrases(sentence_lower)
  local hits = {}
  for _, p in ipairs(phrase_patterns) do
    if sentence_lower:find(p.pattern, 1, true) then
      hits[#hits + 1] = p.name
    end
  end
  return hits
end

function tokenizer.tokenize_documents(docs)
  local all = {}
  for _, doc in ipairs(docs) do
    local sentences = split_sentences(doc.content)
    local s_items = {}
    for idx, s in ipairs(sentences) do
      local tokens = tokenize_sentence(s)
      local phrases = detect_phrases(s:lower())
      s_items[#s_items + 1] = {
        index = idx,
        text = s,
        tokens = tokens,
        phrases = phrases
      }
    end
    all[#all + 1] = {
      doc_id = doc.id,
      path = doc.path,
      sentences = s_items
    }
  end
  return all
end

return tokenizer
