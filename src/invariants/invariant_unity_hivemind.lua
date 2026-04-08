-- Unity / Hive Mind invariant

local pattern = require("src.core.lh_pattern_lang")

local invariant = {}

invariant.id = "UNITY_HIVEMIND"
invariant.label = "Unity / Hive Mind"
invariant.description = "Forced or coercive unity that suppresses dissent and diversity."

local unity_terms = {
  "unity", "one mind", "single will", "collective", "harmony",
  "united forever", "speak as one"
}

local suppression_terms = {
  "traitor", "heretic", "enemy of the people", "purge",
  "cleansing", "eradicate", "silence"
}

function invariant.scan(doc_ctx)
  local tokens = doc_ctx.tokens
  local evidence = {}
  local score = 0

  for s_idx, sent in ipairs(tokens.sentences or {}) do
    for t_idx, tok in ipairs(sent.tokens or {}) do
      if pattern.contains_phrase(sent, unity_terms) then
        if pattern.near(sent.tokens, t_idx, suppression_terms, 8) then
          score = score + 2
          table.insert(evidence, {
            sentence_index = s_idx,
            text = table.concat(sent.tokens, " ")
          })
          break
        else
          score = score + 1
        end
      end
    end
  end

  -- Scale score by narrative context (e.g., high weight in climax/aftermath)
  if doc_ctx.narrative and doc_ctx.narrative.segments then
    for _, seg in ipairs(doc_ctx.narrative.segments) do
      if seg.role == "climax" or seg.role == "aftermath" then
        -- naive scaling: if many evidence sentences in these segments, boost
        for _, ev in ipairs(evidence) do
          if ev.sentence_index >= seg.start_sentence
            and ev.sentence_index <= seg.end_sentence then
            score = score + 1
          end
        end
      end
    end
  end

  return {
    id = invariant.id,
    label = invariant.label,
    score = score,
    evidence = evidence
  }
end

return invariant
