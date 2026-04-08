local M = {}

local doom_terms = {
  "prophecy", "the end is near", "the end is nigh",
  "inevitable collapse", "final judgment", "armageddon",
  "apocalypse", "divinely ordained", "the world will burn"
}

local sacred_terms = {
  "purify", "purification", "cleanse", "cleansing",
  "the unclean", "the impure", "sacred duty", "holy war"
}

local function has_term(text, list)
  for _, t in ipairs(list) do
    if text:find(t, 1, true) then return true end
  end
  return false
end

local function sentence_score(s)
  local text = s.text:lower()
  local doom = has_term(text, doom_terms)
  local sacred = has_term(text, sacred_terms)
  local score = 0
  if doom then score = score + 1 end
  if sacred then score = score + 1 end
  if doom and sacred then
    score = score + 3
  end
  return score
end

function M.evaluate(doc_tokens, spec)
  local total = 0
  local evidence = {}
  for _, doc in ipairs(doc_tokens) do
    for _, s in ipairs(doc.sentences) do
      local s_score = sentence_score(s)
      if s_score > 0 then
        total = total + s_score
        evidence[#evidence + 1] = {
          doc_id = doc.doc_id,
          sentence_index = s.index,
          text = s.text,
          score = s_score
        }
      end
    end
  end

  local normalized = math.min(1.0, total / 15.0)

  return {
    raw_score = total,
    normalized = normalized,
    evidence = evidence,
    interpretation = "Coupling of inevitable-doom narratives with sacralized violence as purification."
  }
end

return M
