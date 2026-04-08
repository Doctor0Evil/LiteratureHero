-- Unity / Hive Mind invariant

local pattern = require("src.core.lh_pattern_lang")

local M = {}

M.id = "UNITY_HIVEMIND"
M.label = "Unity / Hive Mind"
M.description = "Forced or coercive unity that suppresses dissent and diversity."

-- Lexical cues for general unity rhetoric
local unity_terms = {
  "unity", "one mind", "single will", "collective", "harmony",
  "united forever", "speak as one"
}

-- Terms indicating suppression of dissent
local suppression_terms = {
  "traitor", "heretic", "enemy of the people", "purge",
  "cleansing", "eradicate", "silence"
}

-- Strong, highly specific hive-mind expressions
local key_phrases = {
  "hive mind",
  "hivemind",
  "collective consciousness",
  "unity of minds",
  "fusion of self",
  "merge with the collective",
  "our thoughts as one"
}

-- Sentence-level scoring using pre-tokenized sentence objects
local function sentence_score(sentence)
  local text = sentence.text:lower()
  local score = 0

  -- Strong phrases indicating literal or near-literal hive mind
  for _, phrase in ipairs(key_phrases) do
    if text:find(phrase, 1, true) then
      score = score + 2
    end
  end

  -- Phrase detector from tokenizer (e.g., "merger with the collective consciousness")
  for _, p in ipairs(sentence.phrases or {}) do
    if p == "unity_merge_collective" then
      score = score + 3
    end
  end

  -- Explicit link between dissent and treason/betrayal
  if text:find("dissent", 1, true) and text:find("treason", 1, true) then
    score = score + 2
  end

  return score
end

-- High-level evaluation API used by the engine when it has tokenized docs
-- doc_tokens: array of { doc_id, path, sentences = { {index, text, tokens, phrases}, ... } }
-- spec: work spec (id, title, etc.) – not used here but kept for consistency
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

  local normalized = math.min(1.0, total / 20.0)

  return {
    id = M.id,
    label = M.label,
    description = M.description,
    raw_score = total,
    normalized = normalized,
    evidence = evidence,
    interpretation = "Degree to which personalities are dissolved into a collective mind, and dissent is framed as betrayal."
  }
end

-- Optional: lower-level scanner that works on a doc_ctx with narrative segments
-- This is compatible with a richer context where tokens and narrative roles exist.
-- doc_ctx = {
--   tokens = { sentences = { { tokens = {...} }, ... } },
--   narrative = { segments = { {role, start_sentence, end_sentence}, ... } }
-- }
function M.scan(doc_ctx)
  local tokens = doc_ctx.tokens or {}
  local sentences = tokens.sentences or {}

  local evidence = {}
  local score = 0

  for s_idx, sent in ipairs(sentences) do
    -- Check for unity terms
    if pattern.contains_phrase(sent, unity_terms) then
      -- If unity appears near suppression terms, treat as stronger signal
      if pattern.near(sent.tokens or {}, nil, suppression_terms, 8) then
        score = score + 2
        table.insert(evidence, {
          sentence_index = s_idx,
          text = sent.text or table.concat(sent.tokens or {}, " ")
        })
      else
        score = score + 1
      end
    end
  end

  -- Optional narrative weighting: boost evidence appearing in climax/aftermath segments
  if doc_ctx.narrative and doc_ctx.narrative.segments then
    for _, seg in ipairs(doc_ctx.narrative.segments) do
      if seg.role == "climax" or seg.role == "aftermath" then
        for _, ev in ipairs(evidence) do
          if ev.sentence_index >= (seg.start_sentence or 0)
             and ev.sentence_index <= (seg.end_sentence or -1) then
            score = score + 1
          end
        end
      end
    end
  end

  return {
    id = M.id,
    label = M.label,
    score = score,
    evidence = evidence
  }
end

return M
