local M = {}

local function fmt_invariant(inv)
  local lines = {}
  lines[#lines + 1] = "### " .. inv.name
  lines[#lines + 1] = ""
  lines[#lines + 1] = "- Raw score: " .. string.format("%.2f", inv.raw_score)
  lines[#lines + 1] = "- Normalized: " .. string.format("%.2f", inv.normalized)
  lines[#lines + 1] = "- Interpretation: " .. inv.interpretation
  lines[#lines + 1] = ""
  lines[#lines + 1] = "#### Evidence Snippets"
  lines[#lines + 1] = ""
  for i, e in ipairs(inv.evidence) do
    if i > 10 then
      lines[#lines + 1] = ""
      lines[#lines + 1] = "_(truncated)_"
      break
    end
    lines[#lines + 1] = "- (" .. e.doc_id .. ":" .. e.sentence_index .. ", score " .. e.score .. "): " .. e.text
  end
  lines[#lines + 1] = ""
  return table.concat(lines, "\n")
end

local function fmt_recommendations(block)
  local lines = {}
  lines[#lines + 1] = "## Institutional Design Recommendations"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Context: **" .. block.context.title .. "** (`" .. block.context.work_id .. "`)"
  lines[#lines + 1] = ""
  for _, r in ipairs(block.recommendations) do
    lines[#lines + 1] = "### For invariant `" .. r.invariant .. "`"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "- Priority: " .. r.priority
    lines[#lines + 1] = "- Summary: " .. r.summary
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Suggested measures:"
    for _, m in ipairs(r.measures) do
      lines[#lines + 1] = "- " .. m
    end
    lines[#lines + 1] = ""
  end
  return table.concat(lines, "\n")
end

function M.to_markdown(result)
  local spec = result.spec
  local lines = {}

  lines[#lines + 1] = "# LiteratureHero Invariant Analysis"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "- Work ID: `" .. spec.id .. "`"
  lines[#lines + 1] = "- Title: " .. spec.title
  lines[#lines + 1] = "- Tags: " .. table.concat(spec.tags or {}, ", ")
  lines[#lines + 1] = "- Overall risk score: " .. string.format("%.2f", result.risk_score)
  lines[#lines + 1] = "- Generated at: " .. result.meta.generated_at
  lines[#lines + 1] = ""
  lines[#lines + 1] = "## Invariant Scores"
  lines[#lines + 1] = ""

  table.sort(result.invariants, function(a, b)
    return a.normalized > b.normalized
  end)

  for _, inv in ipairs(result.invariants) do
    lines[#lines + 1] = fmt_invariant(inv)
  end

  lines[#lines + 1] = fmt_recommendations(result.institutional_design)

  return table.concat(lines, "\n")
end

return M
