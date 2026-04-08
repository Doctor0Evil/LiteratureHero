-- src/tools/random_hoax_generator.lua
--
-- Generate toy "hoax structures" for testing and illustration:
-- authority persona, weak evidence chain, and founding myth twist.

local gen = {}

----------------------------------------------------------------------
-- Utility: random pick from array
----------------------------------------------------------------------

local function pick(t)
  local n = #t
  if n == 0 then return nil end
  return t[math.random(1, n)]
end

----------------------------------------------------------------------
-- Data tables for hoax components
----------------------------------------------------------------------

local authorities = {
  "independent researcher",
  "renowned archivist",
  "senior historian",
  "field scientist",
  "military analyst",
  "lead investigator",
  "expert in symbolic linguistics"
}

local institutions = {
  "Central Archive of Revolutionary History",
  "Institute for Post-War Studies",
  "National Security Directorate",
  "Academy of Applied Mysticism",
  "Bureau of Technological Ethics",
  "Committee for Historical Truth"
}

local evidence_items = {
  "an old photograph with an indistinct shadow",
  "a partially burned letter mentioning an unnamed figure",
  "a technical diagram with unexplained annotations",
  "a declassified memo with several redacted lines",
  "a ritual sketch found in a confiscated notebook",
  "a maintenance log with recurring unexplained failures",
  "a witness report dismissed as 'delirium'"
}

local founding_events = {
  "the Great War armistice",
  "the First Collapse",
  "the October Uprising",
  "the Founding of the Republic",
  "the Day of Liberation",
  "the signing of the Peace Accords"
}

local hidden_forces = {
  "a clandestine technocratic order",
  "a cult of engineers living beneath the capital",
  "an AI core buried under the old parliament",
  "a circle of unregistered psychics",
  "a network of fungal intelligences",
  "a forgotten bunker council"
}

----------------------------------------------------------------------
-- Generators
----------------------------------------------------------------------

function gen.generate_authority_mask()
  local role = pick(authorities)
  local inst = pick(institutions)

  return {
    persona = "a " .. role .. " from the " .. inst,
    opening = "As " .. role .. " at the " .. inst .. ", I have spent years uncovering the truth that was hidden from the public.",
    style = "calm, precise, documentary"
  }
end

function gen.generate_chain_of_evidence(count)
  count = count or 4
  local chain = {}

  for i = 1, count do
    local item = pick(evidence_items)
    chain[#chain + 1] = item
  end

  return chain
end

function gen.generate_founding_myth_twist()
  local ev = pick(founding_events)
  local hidden = pick(hidden_forces)

  return {
    statement = "What we were taught about " .. ev .. " was incomplete. In reality, it was orchestrated by " .. hidden .. ".",
    event = ev,
    force = hidden
  }
end

----------------------------------------------------------------------
-- High-level convenience: full hoax skeleton
----------------------------------------------------------------------

function gen.generate_hoax_skeleton()
  local auth = gen.generate_authority_mask()
  local chain = gen.generate_chain_of_evidence()
  local myth = gen.generate_founding_myth_twist()

  return {
    authority = auth,
    evidence_chain = chain,
    founding_twist = myth
  }
end

return gen
