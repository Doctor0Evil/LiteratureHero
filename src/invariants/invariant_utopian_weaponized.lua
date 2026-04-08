local M = {}

local virtue_terms = {
  "unity", "love", "modesty", "purity", "charity",
  "equality", "harmony", "peace", "selflessness"
}

local control_terms = {
  "expel", "purge", "reeducate", "corrective labor",
  "must obey", "absolute loyalty", "no deviation",
  "those who refuse will", "necessary sacrifices"
}

local function has_term(text, list)
  for _, t in ipairs(list) do
    if text:find(t, 1, true) then return true end
  end
  return false
end

local function sentence_score(s)
  local text = s.text:lower()
  local score = 0
  if has_term(text, virtue_terms) then score = score + 1 end
  if has_term(text, control_terms) then score = score + 2 end
  if text:find("for the greater good", 1, true) then
    score = score + 2
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

  local normalized = math.min(1.0, total / 18.0)

  return {
    raw_score = total,
    normalized = normalized,
    evidence = evidence,
    interpretation = "Benevolent or egalitarian values used as justification for coercive or totalizing control."
  }
end

return M
