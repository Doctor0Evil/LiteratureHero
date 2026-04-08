-- src/invariants/utopian_principles.lua
--
-- Detects "Utopian Principles Weaponized":
-- language of unity, love, charity, equality, peace, etc.
-- used alongside coercion, loyalty demands, or sacrifice rhetoric.

local M = {}

local function lower(s)
  return string.lower(s or "")
end

local function contains_any(text, terms)
  local t = lower(text)
  for _, term in ipairs(terms) do
    if t:find(term, 1, true) then
      return true
    end
  end
  return false
end

----------------------------------------------------------------------
-- Lexical fields
----------------------------------------------------------------------

local virtue_terms = {
  "unity",
  "love",
  "compassion",
  "mercy",
  "charity",
  "modesty",
  "humility",
  "equality",
  "justice",
  "harmony",
  "peace",
  "brotherhood",
  "sisterhood",
  "togetherness",
  "solidarity",
  "community",
  "serve the people",
  "help the poor",
  "feed the hungry"
}

local greater_good_terms = {
  "for the greater good",
  "for the common good",
  "for the sake of all",
  "for the future of humanity",
  "for the sake of the world",
  "for the good of the community",
  "for the good of our children"
}

local control_terms = {
  "absolute obedience",
  "absolute loyalty",
  "total obedience",
  "total loyalty",
  "must obey",
  "must submit",
  "no deviation",
  "no dissent",
  "no questions",
  "no questioning",
  "expel the traitors",
  "purge the impure",
  "reeducate",
  "corrective labor",
  "those who refuse will",
  "those who doubt will",
  "necessary sacrifices",
  "necessary sacrifice",
  "those who resist",
  "punish those who",
  "cleanse the ranks"
}

local exclusion_terms = {
  "true believers only",
  "only the faithful",
  "only the worthy",
  "only the pure",
  "unworthy",
  "unclean",
  "impure",
  "heretic",
  "heretics",
  "enemy within"
}

----------------------------------------------------------------------
-- Scoring logic
--
-- We treat "virtue language alone" as low risk.
-- Risk rises when virtue + control / exclusion / greater good appear
-- in the same sentence or nearby.
----------------------------------------------------------------------

local function sentence_score(text)
  local t = lower(text)

  local has_virtue = contains_any(t, virtue_terms)
  local has_good   = contains_any(t, greater_good_terms)
  local has_ctrl   = contains_any(t, control_terms)
  local has_excl   = contains_any(t, exclusion_terms)

  local score = 0

  -- Base: utopian / virtue language
  if has_virtue then
    score = score + 1
  end

  -- "Greater good" framing adds weight
  if has_good then
    score = score + 1
  end

  -- Coercive / control language
  if has_ctrl then
    score = score + 2
  end

  -- Exclusion / purity language
  if has_excl then
    score = score + 2
  end

  -- Bonus when virtue is explicitly coupled to control / exclusion
  if (has_virtue or has_good) and (has_ctrl or has_excl) then
    score = score + 2
  end

  return score, {
    has_virtue = has_virtue,
    has_good = has_good,
    has_ctrl = has_ctrl,
    has_excl = has_excl
  }
end

function M.evaluate(doc_tokens, spec)
  local total_score = 0
  local evidence = {}

  for _, doc in ipairs(doc_tokens or {}) do
    for _, s in ipairs(doc.sentences or {}) do
      local s_text = s.text or ""
      local s_score, flags = sentence_score(s_text)

      if s_score > 0 then
        total_score = total_score + s_score

        evidence[#evidence + 1] = {
          doc_id = doc.doc_id,
          sentence_index = s.index,
          text = s_text,
          score = s_score,
          flags = flags
        }
      end
    end
  end

  -- Normalize: assume 20+ indicates a very strong presence.
  local normalized = 0.0
  if total_score > 0 then
    normalized = math.min(1.0, total_score / 20.0)
  end

  return {
    name = "utopian_principles_weaponized",
    raw_score = total_score,
    normalized = normalized,
    interpretation = "Degree to which benevolent, utopian language (love, equality, charity) is coupled with coercion, exclusion, or 'greater good' sacrifice rhetoric.",
    evidence = evidence
  }
end

return M
