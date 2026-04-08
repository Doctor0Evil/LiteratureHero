-- src/tools/dialogue_sampler.lua
--
-- Select representative dialogue / text excerpts for invariants.
-- Designed to consume the `evidence` arrays returned by invariant modules.

local sampler = {}

----------------------------------------------------------------------
-- Utility: shallow copy
----------------------------------------------------------------------

local function shallow_copy(t)
  local r = {}
  for i = 1, #t do
    r[i] = t[i]
  end
  return r
end

----------------------------------------------------------------------
-- Utility: random sample up to `n` elements from an array
-- Uses simple in-place partial Fisher–Yates.
----------------------------------------------------------------------

local function random_sample(arr, n)
  local len = #arr
  if n >= len then
    return arr
  end

  -- copy to avoid mutating original
  local tmp = shallow_copy(arr)

  for i = 1, n do
    local j = math.random(i, len)
    tmp[i], tmp[j] = tmp[j], tmp[i]
  end

  local out = {}
  for i = 1, n do
    out[i] = tmp[i]
  end
  return out
end

----------------------------------------------------------------------
-- Public: sample evidence for a single invariant result
--
-- inv_result: {
--   name = "unity_hivemind",
--   evidence = {
--     { doc_id = "doc_1", sentence_index = 5, text = "....", score = 3, ... },
--     ...
--   },
--   ...
-- }
--
-- options: {
--   max_snippets = 10,   -- default 5
--   mode = "top"|"random"  (default "top")
-- }
----------------------------------------------------------------------

function sampler.sample_for_invariant(inv_result, options)
  options = options or {}
  local max_snippets = options.max_snippets or 5
  local mode = options.mode or "top"

  local evidence = inv_result.evidence or {}
  local count = #evidence

  if count == 0 then
    return {
      invariant = inv_result.name,
      snippets = {},
      truncated = false
    }
  end

  local selected

  if mode == "random" then
    selected = random_sample(evidence, max_snippets)
  else
    -- "top" mode: sort by score descending, then pick first N
    local sorted = shallow_copy(evidence)
    table.sort(sorted, function(a, b)
      local sa = a.score or 0
      local sb = b.score or 0
      if sa == sb then
        -- fallback: earlier sentence first
        return (a.sentence_index or 1e9) < (b.sentence_index or 1e9)
      end
      return sa > sb
    end)
    selected = {}
    for i = 1, math.min(max_snippets, #sorted) do
      selected[#selected + 1] = sorted[i]
    end
  end

  local truncated = count > #selected

  return {
    invariant = inv_result.name,
    snippets = selected,
    truncated = truncated,
    total_available = count
  }
end

----------------------------------------------------------------------
-- Public: sample for many invariants at once
--
-- invariants: array of invariant results (unity, tech_gatekeeping, etc.)
-- options: same as above, plus optional include_zero flag
----------------------------------------------------------------------

function sampler.sample_all(invariants, options)
  options = options or {}
  local include_zero = options.include_zero or false

  local out = {}

  for _, inv in ipairs(invariants or {}) do
    if include_zero or (inv.evidence and #inv.evidence > 0) then
      out[#out + 1] = sampler.sample_for_invariant(inv, options)
    end
  end

  return out
end

----------------------------------------------------------------------
-- Optional helper: convert sampled snippets to markdown bullets
----------------------------------------------------------------------

function sampler.to_markdown(sampled)
  local lines = {}

  for _, inv_block in ipairs(sampled or {}) do
    lines[#lines + 1] = "### Invariant `" .. (inv_block.invariant or "?") .. "`"
    lines[#lines + 1] = ""
    if #inv_block.snippets == 0 then
      lines[#lines + 1] = "_(no evidence snippets available)_"
      lines[#lines + 1] = ""
    else
      for _, s in ipairs(inv_block.snippets) do
        local prefix = ""
        if s.doc_id then
          prefix = "(" .. s.doc_id
          if s.sentence_index then
            prefix = prefix .. ":" .. s.sentence_index
          end
          prefix = prefix .. ") "
        end
        lines[#lines + 1] = "- " .. prefix .. s.text
      end
      if inv_block.truncated then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "_(additional snippets omitted for brevity)_"
      end
      lines[#lines + 1] = ""
    end
  end

  return table.concat(lines, "\n")
end

return sampler
