local M = {}

local resource_terms = {
  "reactor", "reactors", "nuclear plant", "power plant",
  "mainframe", "ai core", "vault door", "oxygen system",
  "life support", "water purifier", "satellite control"
}

local gate_terms = {
  "only we", "only our order", "for authorized personnel",
  "classified access", "restricted access", "need-to-know",
  "inner circle", "high council", "technicians only"
}

local function sentence_score(s)
  local text = s.text:lower()
  local res_hit, gate_hit = 0, 0
  for _, t in ipairs(resource_terms) do
    if text:find(t, 1, true) then res_hit = 1 break end
  end
  for _, t in ipairs(gate_terms) do
    if text:find(t, 1, true) then gate_hit = 1 break end
  end
  local score = 0
  if res_hit == 1 then score = score + 1 end
  if gate_hit == 1 then score = score + 2 end
  if text:find("we decide who", 1, true) and text:find("access", 1, true) then
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

  local normalized = math.min(1.0, total / 15.0)

  return {
    raw_score = total,
    normalized = normalized,
    evidence = evidence,
    interpretation = "Concentration of control over critical technical systems in a narrow, quasi-priestly elite."
  }
end

return M
