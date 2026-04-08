-- src/analysis/hoax_detector.lua
--
-- Detects "hoax structures" in texts: Lenin-mushroom style
-- Authority Mask, Chain-of-Evidence, Edge-of-Believability,
-- and Reframe-Founding-Myth invariants.

local hoax_detector = {}

-- Simple helpers

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

local function count_any(text, terms)
  local t = lower(text)
  local c = 0
  for _, term in ipairs(terms) do
    local start = 1
    while true do
      local i, j = t:find(term, start, true)
      if not i then break end
      c = c + 1
      start = j + 1
    end
  end
  return c
end

----------------------------------------------------------------------
-- Invariant 1: Authority Mask
-- Deadpan expert performance: calm, precise, pseudo-scientific register.
----------------------------------------------------------------------

local authority_roles = {
  "professor", "doctor", "dr.", "researcher", "historian",
  "scientist", "archivist", "expert", "specialist", "investigator"
}

local authority_register_terms = {
  "according to our data",
  "our research indicates",
  "we can conclude that",
  "as you can see",
  "rigorous analysis",
  "evidence suggests",
  "statistical",
  "empirical",
  "laboratory",
  "field study"
}

local function score_authority_mask(sentences)
  local score = 0
  local evidence = {}

  for idx, s in ipairs(sentences) do
    local text = s.text or ""
    local t = lower(text)

    local has_role = contains_any(t, authority_roles)
    local has_reg = contains_any(t, authority_register_terms)

    if has_role or has_reg then
      local s_score = 0
      if has_role then s_score = s_score + 1 end
      if has_reg then s_score = s_score + 1 end

      if s_score > 0 then
        score = score + s_score
        evidence[#evidence + 1] = {
          sentence_index = idx,
          text = text,
          score = s_score
        }
      end
    end
  end

  local normalized = math.min(1.0, score / 10.0)

  return {
    id = "AUTHORITY_MASK",
    label = "Authority Mask",
    description = "Deadpan expert performance that frames an outlandish claim as serious investigation.",
    raw_score = score,
    normalized = normalized,
    evidence = evidence
  }
end

----------------------------------------------------------------------
-- Invariant 2: Chain-of-Evidence
-- Long sequence of weak "proofs": photos, letters, diagrams, etc.
----------------------------------------------------------------------

local weak_evidence_terms = {
  "photo", "photograph", "picture",
  "letter", "correspondence", "note",
  "diagram", "chart", "graph", "scheme",
  "archive", "archival", "document", "file",
  "we compared", "we cross-referenced",
  "as shown here", "as shown in this",
  "source", "sources", "report"
}

local function score_chain_of_evidence(sentences)
  local score = 0
  local evidence = {}

  for idx, s in ipairs(sentences) do
    local text = s.text or ""
    local hits = count_any(text, weak_evidence_terms)

    if hits > 0 then
      local s_score = math.min(3, hits)  -- cap per sentence
      score = score + s_score

      evidence[#evidence + 1] = {
        sentence_index = idx,
        text = text,
        score = s_score
      }
    end
  end

  local normalized = math.min(1.0, score / 15.0)

  return {
    id = "CHAIN_OF_EVIDENCE",
    label = "Chain of Evidence",
    description = "Accumulation of many weak proofs (photos, letters, diagrams) to create an illusion of rigor.",
    raw_score = score,
    normalized = normalized,
    evidence = evidence
  }
end

----------------------------------------------------------------------
-- Invariant 3: Edge-of-Believability
-- Claims tuned to sit just at the threshold of plausibility,
-- often in a context of trauma, revelation, or disillusionment.
----------------------------------------------------------------------

local trauma_context_terms = {
  "after the war",
  "after the great war",
  "collapse",
  "revolution",
  "purge",
  "famine",
  "censorship",
  "we were never told",
  "we finally know the truth",
  "hidden for decades",
  "classified",
  "declassified"
}

local borderline_claim_terms = {
  "secret experiment",
  "hidden influence",
  "unknown force",
  "guided everything",
  "controlled from the shadows",
  "nothing was as it seemed",
  "the real reason",
  "true cause",
  "behind it all"
}

local function score_edge_of_believability(sentences)
  local score = 0
  local evidence = {}

  for idx, s in ipairs(sentences) do
    local text = s.text or ""
    local t = lower(text)

    local trauma = contains_any(t, trauma_context_terms)
    local border = contains_any(t, borderline_claim_terms)

    if trauma or border then
      local s_score = 0
      if trauma then s_score = s_score + 1 end
      if border then s_score = s_score + 2 end

      if s_score > 0 then
        score = score + s_score
        evidence[#evidence + 1] = {
          sentence_index = idx,
          text = text,
          score = s_score
        }
      end
    end
  end

  local normalized = math.min(1.0, score / 12.0)

  return {
    id = "EDGE_OF_BELIEVABILITY",
    label = "Edge of Believability",
    description = "Claims calibrated to be just shocking enough for a disillusioned or traumatized audience to accept.",
    raw_score = score,
    normalized = normalized,
    evidence = evidence
  }
end

----------------------------------------------------------------------
-- Invariant 4: Reframe-Founding-Myth
-- Radical reinterpretation of a core founding event or hero.
----------------------------------------------------------------------

local founding_terms = {
  "revolution",
  "great war",
  "founding",
  "founders",
  "the beginning",
  "the first day",
  "year zero",
  "the uprising",
  "our liberation",
  "our salvation",
  "our prophet",
  "our leader"
}

local secret_control_terms = {
  "was actually controlled by",
  "was secretly led by",
  "because of a mushroom",
  "because of the machine",
  "because of the cult",
  "not by chance",
  "by design",
  "hidden hand",
  "secret order",
  "secret council",
  "ancient conspiracy"
}

local function score_reframe_founding_myth(sentences)
  local score = 0
  local evidence = {}

  for idx, s in ipairs(sentences) do
    local text = s.text or ""
    local t = lower(text)

    local has_founder = contains_any(t, founding_terms)
    local has_secret = contains_any(t, secret_control_terms)

    if has_founder or has_secret then
      local s_score = 0
      if has_founder then s_score = s_score + 1 end
      if has_secret then s_score = s_score + 2 end

      if s_score > 0 then
        score = score + s_score
        evidence[#evidence + 1] = {
          sentence_index = idx,
          text = text,
          score = s_score
        }
      end
    end
  end

  local normalized = math.min(1.0, score / 10.0)

  return {
    id = "REFRAME_FOUNDING_MYTH",
    label = "Reframe Founding Myth",
    description = "Reinterpretation of the core founding event as secretly guided by a hidden force.",
    raw_score = score,
    normalized = normalized,
    evidence = evidence
  }
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

-- doc_tokens: array of { doc_id, path, sentences = { {index, text, tokens, ...}, ... } }
-- spec: work spec (id, title, etc.) – unused here but kept for compatibility.
function hoax_detector.evaluate(doc_tokens, spec)
  local all_invariants = {}

  for _, doc in ipairs(doc_tokens or {}) do
    local sentences = doc.sentences or {}

    local auth = score_authority_mask(sentences)
    local chain = score_chain_of_evidence(sentences)
    local edge = score_edge_of_believability(sentences)
    local myth = score_reframe_founding_myth(sentences)

    all_invariants[#all_invariants + 1] = {
      doc_id = doc.doc_id,
      invariants = {
        auth,
        chain,
        edge,
        myth
      }
    }
  end

  return all_invariants
end

-- Optional convenience: collapse across documents into a single summary
function hoax_detector.summarize(all_results)
  local summary = {
    AUTHORITY_MASK = { id = "AUTHORITY_MASK", label = "Authority Mask", raw_score = 0, evidence = {} },
    CHAIN_OF_EVIDENCE = { id = "CHAIN_OF_EVIDENCE", label = "Chain of Evidence", raw_score = 0, evidence = {} },
    EDGE_OF_BELIEVABILITY = { id = "EDGE_OF_BELIEVABILITY", label = "Edge of Believability", raw_score = 0, evidence = {} },
    REFRAME_FOUNDING_MYTH = { id = "REFRAME_FOUNDING_MYTH", label = "Reframe Founding Myth", raw_score = 0, evidence = {} }
  }

  local function merge(inv)
    local tgt = summary[inv.id]
    if not tgt then return end
    tgt.raw_score = (tgt.raw_score or 0) + (inv.raw_score or 0)
    for _, ev in ipairs(inv.evidence or {}) do
      tgt.evidence[#tgt.evidence + 1] = ev
    end
  end

  for _, docres in ipairs(all_results or {}) do
    for _, inv in ipairs(docres.invariants or {}) do
      merge(inv)
    end
  end

  -- normalize after merging
  for _, inv in pairs(summary) do
    local max_raw
    if inv.id == "AUTHORITY_MASK" then
      max_raw = 10.0
    elseif inv.id == "CHAIN_OF_EVIDENCE" then
      max_raw = 15.0
    elseif inv.id == "EDGE_OF_BELIEVABILITY" then
      max_raw = 12.0
    elseif inv.id == "REFRAME_FOUNDING_MYTH" then
      max_raw = 10.0
    else
      max_raw = 10.0
    end
    inv.normalized = math.min(1.0, (inv.raw_score or 0) / max_raw)
  end

  return summary
end

return hoax_detector
