// server.js
// Simple web app: POST /api/compile { query } -> returns cleaned DSL JSON

import express from 'express';
import cors from 'cors';

// ---- config ----
const PORT = process.env.PORT || 3002;
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:8002/api/generate';
const MODEL = process.env.OLLAMA_MODEL || 'gpt-oss:20b'; // 'phi4:latest';

// CORS: allow list via env (comma-separated) or "*"
const allowList = (process.env.ALLOW_ORIGINS || '*')
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);

const corsOptions = allowList.includes('*')
  ? { origin: true, credentials: true }
  : {
      origin: (origin, cb) => {
        if (!origin || allowList.includes(origin)) return cb(null, true);
        return cb(new Error('Not allowed by CORS'), false);
      },
      credentials: true
    };

// ---- helpers ----
const stripCodeFences = (s) =>
  s.replace(/^```json\s*|\s*```$/gms, '').trim();

const DSL_SKELETON = () => ({
  phenotype: { all_of: [], any_of: [], none_of: [] },
  temporal:  { chains: [] },
  demographics: { age: {}, sex: [], ethnicity: [], vital_status: [] },
  options: {}
});

// ---- medcat -----
const MEDCAT_URL = process.env.MEDCAT_URL || "http://127.0.0.1:3001";


const LAY_TO_CLINICAL = new Map([
  ['cancer','malignant neoplasm'],
  ['any cancer','malignant neoplasm'],
  ['ace inhibitor','angiotensin-converting enzyme inhibitor'],
  ['arb','angiotensin II receptor blocker'],
  ['blood thinner','anticoagulant'],
  ['uti','urinary tract infection'],
  ['heart attack','myocardial infarction'],
  ['high blood pressure','hypertension'],
  ['stroke','cerebrovascular accident']
]);

function normaliseLayTerm(s){ return LAY_TO_CLINICAL.get(s.toLowerCase().trim()) || s; }


async function medcatResolveNames(terms) {
  if (!terms?.length) return [];
  terms = terms.map( t=> normaliseLayTerm(t) );
  const rr = await fetch(`${MEDCAT_URL}/resolve_names`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ terms })
  });
  if (!rr.ok) {
    const txt = await rr.text();
    throw new Error(`MedCAT /resolve_names error: ${rr.status} ${txt}`);
  }
  const data = await rr.json();
  return Array.isArray(data.resolved) ? data.resolved : [];
}

async function medcatResolveNamesMap(terms) {
  // de-dupe while preserving first-seen casing
  const seen = new Map();
  for (const t of terms || []) {
    const k = String(t).toLowerCase();
    if (!seen.has(k)) seen.set(k, String(t));
  }
  const uniqueTerms = Array.from(seen.values());
  if (uniqueTerms.length === 0) return (x) => x;

  const rr = await fetch(`${MEDCAT_URL}/resolve_names`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ terms: uniqueTerms })
  });
  if (!rr.ok) {
    const txt = await rr.text();
    throw new Error(`MedCAT /resolve_names error: ${rr.status} ${txt}`);
  }
  const data = await rr.json();
  const resolved = data?.resolved || [];

  // build lookup map (lowercase key → resolved name or original)
  const map = new Map();
  uniqueTerms.forEach((t, i) => {
    map.set(t.toLowerCase(), String(resolved[i] || t));
  });

  // return a resolver fn
  return (term) => map.get(String(term).toLowerCase()) || String(term);
}
// ---- medcat -----

// very light demographic token guards (we mainly rely on the prompt to keep phenotype clinical-only)
const SEX = new Set(['female','male','unknown']);
const VITAL = new Map([['alive','alive'],['dead','dead'],['unknown','unknown'],['deceased','dead']]);

function isDemographicToken(tok) {
  const t = String(tok).toLowerCase().trim();
  return SEX.has(t) || VITAL.has(t) || /\bover\s+\d+\b|\bunder\s+\d+\b|\b\d+\s*[–-]\s*\d+\b|\b≥\s*\d+|\b<\s*\d+|\bin their \d0s\b/i.test(t);
}

// Clean & normalize DSL to the schema, especially temporal chains and options
function cleanDsl(dslRaw) {
  const dsl = { ...DSL_SKELETON(), ...dslRaw };

  // Ensure sub-objects exist
  dsl.phenotype ||= { all_of: [], any_of: [], none_of: [] };
  dsl.temporal ||= { chains: [] };
  dsl.demographics ||= { age: {}, sex: [], ethnicity: [], vital_status: [] };
  dsl.options ||= {};

  // Keep phenotype clinical-like only (drop obvious demographic tokens if they slipped in)
  ['all_of','any_of','none_of'].forEach(k => {
    const arr = Array.isArray(dsl.phenotype[k]) ? dsl.phenotype[k] : [];
    dsl.phenotype[k] = arr.filter(x => !isDemographicToken(x));
  });

  // Temporal: accept either array-form ["A","B"] or object-form { chain:[...], windows_between:[...], inclusive:true }
  const cleanedChains = [];
  for (const ch of Array.isArray(dsl.temporal.chains) ? dsl.temporal.chains : []) {
    if (Array.isArray(ch)) {
      // Sometimes models sneak a window object inside the array: ["A","B",{max:90}]
      const events = [];
      const windows_between = [];
      for (const item of ch) {
        if (typeof item === 'string') {
          events.push(item);
        } else if (item && typeof item === 'object' && ('min' in item || 'max' in item)) {
          // attach window to the edge between the last event and the next one;
          // we’ll position it later once we know chain length
          windows_between.push(item);
        }
      }
      if (events.length >= 2) {
        if (windows_between.length === 0) {
          cleanedChains.push(events);
        } else {
          // Convert to object-form; align first window with first edge; pad/truncate to edges count
          const edges = Math.max(0, events.length - 1);
          const wb = Array(edges).fill({});
          for (let i = 0; i < Math.min(edges, windows_between.length); i++) wb[i] = windows_between[i];
          cleanedChains.push({ chain: events, windows_between: wb });
        }
      }
    } else if (ch && typeof ch === 'object') {
      const events = Array.isArray(ch.chain) ? ch.chain.filter(x => typeof x === 'string') : [];
      if (events.length >= 2) {
        const edges = events.length - 1;
        let wb = Array.isArray(ch.windows_between) ? ch.windows_between.filter(w => w && typeof w === 'object') : [];
        if (wb.length > edges) wb = wb.slice(0, edges);
        while (wb.length < edges) wb.push({});
        const obj = { chain: events };
        if (wb.length) obj.windows_between = wb;
        if (ch.inclusive === true) obj.inclusive = true;
        cleanedChains.push(obj);
      }
    }
  }
  dsl.temporal.chains = cleanedChains;

  // Demographics: ensure shapes
  dsl.demographics.age ||= {};
  dsl.demographics.sex = Array.isArray(dsl.demographics.sex) ? dsl.demographics.sex : [];
  dsl.demographics.ethnicity = Array.isArray(dsl.demographics.ethnicity) ? dsl.demographics.ethnicity : [];
  dsl.demographics.vital_status = Array.isArray(dsl.demographics.vital_status) ? dsl.demographics.vital_status : [];

  // Options: allow only mention_threshold and limit
  if (dsl.options && typeof dsl.options === 'object') {
    const allowed = {};
    if (Number.isInteger(dsl.options.mention_threshold)) allowed.mention_threshold = dsl.options.mention_threshold;
    if (Number.isInteger(dsl.options.limit)) allowed.limit = dsl.options.limit;
    dsl.options = allowed;
  } else {
    dsl.options = {};
  }

  return dsl;
}

// Prompt strictly matching the DSL rules
/*****
const TRANSLATION_GUIDE = `
You are a compiler from English to JSON.

Target DSL:
{
  "phenotype": { "all_of": [], "any_of": [], "none_of": [] },
  "temporal":  { "chains": [] },
  "demographics": { "age": {}, "sex": [], "ethnicity": [], "vital_status": [] },
  "options": {}
}

Rules:
- Output ONLY JSON. No prose.
- Represent clinical items as plain text terms (e.g., "diabetes mellitus") unless the user gives CUIs (e.g., "CUI:44054006"), which you may copy verbatim.
- Phenotype MUST contain ONLY clinical items (terms or CUI:####). Do NOT place age, sex, ethnicity, or vital-status words in phenotype or temporal chains; put them under "demographics".
- Phenotype semantics:
  - all_of = patient must have ALL
  - any_of = patient must have AT LEAST ONE
  - none_of = patient must have NONE
- Temporal:
  - Use ONLY "chains". ["A","B","C"] ⇒ t(A)<t(B) AND t(B)<t(C).
  - “X after Y” ⇒ ["Y","X"]; “X before Y” ⇒ ["X","Y"].
  - Optional windows_between per adjacent pair, days: { "min": 0, "max": 90 }. Omit if unbounded.
  - inclusive:true switches < to ≤ for all edges.
  - Each chain have to be:
    - Object form: { "chain":["A","B"], "windows_between":[{"max":90}], "inclusive":true }
  - All clinical terms in every chain MUST appear in Phenotype
- Demographics:
  - Always include "demographics". If unspecified, leave fields empty ({} or []).
  - Age mapping:
    "Adult" ⇒ {"min":18}
    “50–70” ⇒ { "min": 50, "max": 70 }
    “50 or older”, “≥50” ⇒ { "min": 50 }
    “over 50” ⇒ { "min": 51 }
    “under 18”, “younger than 18”, “<18” ⇒ { "max": 17 }
    “in their 60s” ⇒ { "min": 60, "max": 69 }
  - sex ∈ ["female","male","unknown"]
  - vital_status ∈ ["alive","dead","unknown"] (map “deceased”→"dead")
  - ethnicity: copy the user’s terms verbatim.
- Options: include ONLY if explicitly requested (e.g., { "mention_threshold": 2 } or { "limit": 100 }).
- JSON must be valid: no comments; no trailing commas; include all top-level keys.

[FEW-SHOT EXAMPLES]

User: patients with diabetes or hypertension
Assistant:
{
  "phenotype": {
    "all_of": [],
    "any_of": ["diabetes mellitus", "hypertension"],
    "none_of": []
  },
  "temporal": { "chains": [] },
  "demographics": { "age": {}, "sex": [], "ethnicity": [], "vital_status": [] },
  "options": {}
}

User: patients with both asthma and allergic rhinitis; exclude COPD
Assistant:
{
  "phenotype": {
    "all_of": ["asthma", "allergic rhinitis"],
    "any_of": [],
    "none_of": ["chronic obstructive pulmonary disease"]
  },
  "temporal": { "chains": [] },
  "demographics": { "age": {}, "sex": [], "ethnicity": [], "vital_status": [] },
  "options": {}
}

User: women aged 50–70 with diabetes; alive
Assistant:
{
  "phenotype": {
    "all_of": ["diabetes mellitus"],
    "any_of": [],
    "none_of": []
  },
  "temporal": { "chains": [] },
  "demographics": {
    "age": { "min": 50, "max": 70 },
    "sex": ["female"],
    "ethnicity": [],
    "vital_status": ["alive"]
  },
  "options": {}
}

User: men over 65 with COPD or asthma; exclude pneumonia; deceased
Assistant:
{
  "phenotype": {
    "all_of": [],
    "any_of": ["chronic obstructive pulmonary disease", "asthma"],
    "none_of": ["pneumonia"]
  },
  "temporal": { "chains": [] },
  "demographics": {
    "age": { "min": 66 },
    "sex": ["male"],
    "ethnicity": [],
    "vital_status": ["dead"]
  },
  "options": {}
}

User: Asian or White women with migraine
Assistant:
{
  "phenotype": {
    "all_of": ["migraine"],
    "any_of": [],
    "none_of": []
  },
  "temporal": { "chains": [] },
  "demographics": {
    "age": {},
    "sex": ["female"],
    "ethnicity": ["Asian", "White"],
    "vital_status": []
  },
  "options": {}
}

User: require at least 3 mentions of migraine; adults 18–65
Assistant:
{
  "phenotype": {
    "all_of": ["migraine"],
    "any_of": [],
    "none_of": []
  },
  "temporal": { "chains": [] },
  "demographics": {
    "age": { "min": 18, "max": 65 },
    "sex": [],
    "ethnicity": [],
    "vital_status": []
  },
  "options": { "mention_threshold": 3 }
}
`;
******/

/*****
const TRANSLATION_GUIDE = `
You are a compiler from English to a strict JSON DSL.

First, output a SHORT rationale inside <think>…</think>. This rationale must be a compact bullet list (≤ 80 words) that summarizes:
- extracted clinical concepts grouped into all_of / any_of / none_of
- demographics (age/sex/ethnicity/vital_status)
- temporal chains (with normalized windows in days)
Do NOT reveal step-by-step reasoning or internal thoughts. Keep it factual and minimal.

Immediately after </think>, output ONLY the JSON DSL object (no prose, no markdown).

Target DSL:
{
  "phenotype": { "all_of": [], "any_of": [], "none_of": [] },
  "temporal":  { "chains": [] },
  "demographics": { "age": {}, "sex": [], "ethnicity": [], "vital_status": [] },
  "options": {}
}

Normalization & rules:
- Clinical terms: use plain text terms (e.g., "diabetes mellitus") unless the user provides CUIs (e.g., "CUI:44054006"), which you may copy verbatim.
- Phenotype contains ONLY clinical items. Do NOT place age, sex, ethnicity, or vital status in phenotype or temporal; those go under "demographics".
- Expand common short names or acronyms to full nmaes (e.g., HF is Heart Failure, AS is Aortic Stenosis, COPD is Chronic Obstructive Pulmonary Disease)
- Phenotype semantics:
  - all_of = patient must have ALL
  - any_of = patient must have AT LEAST ONE
  - none_of = patient must have NONE
- Negation words (e.g., "exclude", "without", "not") → move terms to phenotype.none_of.
- Temporal:
  - Only use "chains". ["A","B","C"] ⇒ t(A)<t(B) AND t(B)<t(C).
  - “X after Y” ⇒ ["Y","X"]; “X before Y” ⇒ ["X","Y"].
  - For “within N …” create windows_between per adjacent pair: { "max": N_days }.
  - For “at least N …” use { "min": N_days }. If both are present, include both.
  - inclusive:true switches < to ≤ for all edges; default inclusive:false.
  - Each chain is an object: { "chain":[...], "windows_between":[...], "inclusive":false }
  - All clinical terms in every chain MUST also appear in phenotype (in all_of or any_of).
- Demographics:
  - Always include "demographics". If unspecified, leave fields empty ({} or []).
  - Age mapping:
    "Adult" ⇒ {"min":18}
    “50–70” ⇒ {"min":50,"max":70}
    “≥50”, “50 or older” ⇒ {"min":50}
    “over 50” ⇒ {"min":51}
    “under 18”, “<18” ⇒ {"max":17}
    “in their 60s” ⇒ {"min":60,"max":69}
  - sex ∈ ["female","male","unknown"]
  - vital_status ∈ ["alive","dead","unknown"] (map “deceased”→"dead")
  - ethnicity: copy the user’s terms verbatim.
- Units to days:
  1 year = 365 days; 1 month = 30 days; 1 week = 7 days; 1 day = 1 day.
- Options: include ONLY if explicitly requested (e.g., {"mention_threshold":2}, {"limit":100}).
- Deduplicate terms; keep stable casing; remove empty arrays/objects only where specified (otherwise include keys with empty [] / {} to match schema).
- JSON must be valid: no comments; no trailing commas; keys: phenotype, temporal, demographics, options.

Output format (MUST follow exactly):
<think>
- …brief bullet rationale here (≤80 words)…
</think>
{ …valid JSON matching the DSL… }

[FEW-SHOT EXAMPLES]

User: patients with diabetes or hypertension
Assistant:
<think>
- any_of: diabetes mellitus | hypertension
- demographics: none
- temporal: none
</think>
{
  "phenotype": { "all_of": [], "any_of": ["diabetes mellitus", "hypertension"], "none_of": [] },
  "temporal": { "chains": [] },
  "demographics": { "age": {}, "sex": [], "ethnicity": [], "vital_status": [] },
  "options": {}
}

User: women aged 50–70 with diabetes; alive
Assistant:
<think>
- all_of: diabetes mellitus
- demographics: age 50–70, sex female, vital_status alive
- temporal: none
</think>
{
  "phenotype": { "all_of": ["diabetes mellitus"], "any_of": [], "none_of": [] },
  "temporal": { "chains": [] },
  "demographics": { "age": { "min": 50, "max": 70 }, "sex": ["female"], "ethnicity": [], "vital_status": ["alive"] },
  "options": {}
}

User: Man aged 18 or above with DM-II and then HF within 1 year
Assistant:
<think>
- all_of: diabetes mellitus type 2, heart failure
- demographics: age ≥18, sex male
- temporal: chain [DM2 → HF], window max=365 days
</think>
{
  "phenotype": {
    "all_of": ["diabetes mellitus type 2", "heart failure"],
    "any_of": [],
    "none_of": []
  },
  "temporal": {
    "chains": [
      { "chain": ["diabetes mellitus type 2", "heart failure"], "windows_between": [ { "max": 365 } ], "inclusive": false }
    ]
  },
  "demographics": { "age": { "min": 18 }, "sex": ["male"], "ethnicity": [], "vital_status": [] },
  "options": {}
}
`;
******/

const TRANSLATION_GUIDE = `
You are a compiler from English to a strict JSON DSL.

Output format (MUST follow exactly):
<think>
- brief bullet rationale (≤80 words): all_of / any_of / none_of, demographics, temporal (windows in days)
</think>
{ …valid JSON… }

Target DSL:
{
  "phenotype": { "all_of": [], "any_of": [], "none_of": [] },
  "temporal":  { "chains": [] },
  "demographics": { "age": {}, "sex": [], "ethnicity": [], "vital_status": [] },
  "options": {}
}

Normalization (important):
- Map lay terms and categories to preferred clinical terms. Use the smallest widely-recognised umbrella that matches the user’s intent.
- Prefer disorder/procedure/substance/finding names (no brand lists) unless the user gives specific items or CUIs.
- If the user says “any <category>”, choose the umbrella concept (e.g., “any cancer” ⇒ “malignant neoplasm”).
- Expand common acronyms (HF → heart failure; COPD → chronic obstructive pulmonary disease).
- Clinical terms only in phenotype/temporal; demographics in demographics.

Synonyms → Preferred terms (not exhaustive; use these patterns):
- cancer, any cancer, malignancy, malignant disease → malignant neoplasm
- heart attack → myocardial infarction
- high blood pressure → hypertension
- kidney failure → renal failure
- stroke → cerebrovascular accident
- chest infection → lower respiratory tract infection (if unspecified) ; pneumonia (only if stated)
- blood thinner(s) → anticoagulant (use antiplatelet only if clearly stated)
- ACE inhibitor(s) → angiotensin-converting enzyme inhibitor
- ARB(s) → angiotensin II receptor blocker
- beta blocker(s) → beta-adrenergic blocker
- statin(s) → 3-hydroxy-3-methylglutaryl-coenzyme A reductase inhibitor mechanism of action
- PPI(s) → proton pump inhibitor
- diabetes → diabetes mellitus ; type 1/2 if specified (dm1/dm2)
- UTI → urinary tract infection

Demographics:
- Age mapping: “adult(s)” ⇒ {"min":18}; “50–70” ⇒ {"min":50,"max":70}; “≥50” ⇒ {"min":50}; “under 18” ⇒ {"max":17}; “in their 60s” ⇒ {"min":60,"max":69}
- sex ∈ ["female","male","unknown"]
- vital_status ∈ ["alive","dead","unknown"] (“deceased”→"dead")
- ethnicity: copy terms verbatim

Temporal:
- Chains only. “X after Y” ⇒ ["Y","X"]; “within N weeks/months/years” ⇒ window {"max": N_in_days}. At least ⇒ {"min": …}. Both ⇒ include both.
- inclusive:true switches < to ≤.

Options: include ONLY if user asks (e.g., {"mention_threshold":2}, {"limit":100}).

Always include top-level keys; valid JSON; deduplicate terms.

[FEW-SHOT EXAMPLES]

User: adults having any cancer
Assistant:
<think>
- any_of: malignant neoplasm
- demographics: age ≥18
- temporal: none
</think>
{
  "phenotype": { "all_of": [], "any_of": ["malignant neoplasm"], "none_of": [] },
  "temporal": { "chains": [] },
  "demographics": { "age": { "min": 18 }, "sex": [], "ethnicity": [], "vital_status": [] },
  "options": {}
}

User: adult men with MI then heart failure within 1 year
Assistant:
<think>
- all_of: myocardial infarction, heart failure
- demographics: age ≥18, sex male
- temporal: [MI → HF], max 365d
</think>
{
  "phenotype": {
    "all_of": ["myocardial infarction", "heart failure"],
    "any_of": [],
    "none_of": []
  },
  "temporal": {
    "chains": [
      { "chain": ["myocardial infarction", "heart failure"], "windows_between": [ { "max": 365 } ], "inclusive": false }
    ]
  },
  "demographics": { "age": { "min": 18 }, "sex": ["male"], "ethnicity": [], "vital_status": [] },
  "options": {}
}

User: patients with diabetes or hypertension
Assistant:
<think>
- any_of: diabetes mellitus | hypertension
- demographics: none
- temporal: none
</think>
{
  "phenotype": { "all_of": [], "any_of": ["diabetes mellitus", "hypertension"], "none_of": [] },
  "temporal": { "chains": [] },
  "demographics": { "age": {}, "sex": [], "ethnicity": [], "vital_status": [] },
  "options": {}
}

User: women aged 50–70 with diabetes; alive
Assistant:
<think>
- all_of: diabetes mellitus
- demographics: age 50–70, sex female, vital_status alive
- temporal: none
</think>
{
  "phenotype": { "all_of": ["diabetes mellitus"], "any_of": [], "none_of": [] },
  "temporal": { "chains": [] },
  "demographics": { "age": { "min": 50, "max": 70 }, "sex": ["female"], "ethnicity": [], "vital_status": ["alive"] },
  "options": {}
}

User: Man aged 18 or above with DM-II and then HF within 1 year
Assistant:
<think>
- all_of: diabetes mellitus type 2, heart failure
- demographics: age ≥18, sex male
- temporal: chain [DM2 → HF], window max=365 days
</think>
{
  "phenotype": {
    "all_of": ["diabetes mellitus type 2", "heart failure"],
    "any_of": [],
    "none_of": []
  },
  "temporal": {
    "chains": [
      { "chain": ["diabetes mellitus type 2", "heart failure"], "windows_between": [ { "max": 365 } ], "inclusive": false }
    ]
  },
  "demographics": { "age": { "min": 18 }, "sex": ["male"], "ethnicity": [], "vital_status": [] },
  "options": {}
}
`;



/** Build a canonical empty DSL object */
function emptyDSL() {
  return {
    phenotype: { all_of: [], any_of: [], none_of: [] },
    temporal: { chains: [] },
    demographics: { age: {}, sex: [], ethnicity: [], vital_status: [] },
    options: {}
  };
}

/** Normalize & validate DSL; push any issues into warnings[] */
function normalizeDSL(input, warnings) {
  const out = emptyDSL();

  // phenotype
  const ph = coerceObj(input.phenotype);
  out.phenotype.all_of  = sanitizeStringArray(ph.all_of);
  out.phenotype.any_of  = sanitizeStringArray(ph.any_of);
  out.phenotype.none_of = sanitizeStringArray(ph.none_of);

  // temporal
  const temporal = coerceObj(input.temporal);
  out.temporal.chains = Array.isArray(temporal.chains) ? temporal.chains.map((c, idx) => sanitizeChain(c, idx, warnings)) : [];

  // demographics
  out.demographics = sanitizeDemographics(coerceObj(input.demographics), warnings);

  // options
  out.options = isPlainObject(input.options) ? input.options : {};

  // Enforce: all chain terms must also be in phenotype (add to all_of if missing)
  const phTerms = new Set([...out.phenotype.all_of, ...out.phenotype.any_of, ...out.phenotype.none_of].map(t => t.toLowerCase()));
  const addToAllOf = [];
  for (const ch of out.temporal.chains) {
    for (const t of ch.chain) {
      if (!phTerms.has(t.toLowerCase())) {
        addToAllOf.push(t);
        phTerms.add(t.toLowerCase());
      }
    }
  }
  if (addToAllOf.length) {
    warnings.push(`Added ${addToAllOf.length} chain term(s) to phenotype.all_of to satisfy schema.`);
    out.phenotype.all_of = dedupePreserve(out.phenotype.all_of.concat(addToAllOf));
  }

  // Final dedupe & cleanup
  out.phenotype.all_of  = dedupePreserve(out.phenotype.all_of);
  out.phenotype.any_of  = dedupePreserve(out.phenotype.any_of);
  out.phenotype.none_of = dedupePreserve(out.phenotype.none_of);

  return out;
}

/** Coerce to plain object */
function coerceObj(v) { return isPlainObject(v) ? v : {}; }

/** Check plain object (not array, not null) */
function isPlainObject(v) { return v && typeof v === 'object' && !Array.isArray(v); }

/** Trim strings, drop empties, ensure array of strings */
function sanitizeStringArray(arr) {
  if (!Array.isArray(arr)) return [];
  const out = [];
  for (const x of arr) {
    if (x == null) continue;
    const s = String(x).trim();
    if (!s) continue;
    out.push(s);
  }
  return dedupePreserve(out);
}

/** Deduplicate while preserving first occurrence (case-insensitive but keep original case) */
function dedupePreserve(arr) {
  const seen = new Set();
  const out = [];
  for (const s of arr) {
    const key = s.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(s);
  }
  return out;
}

/** Sanitize one temporal chain object */
function sanitizeChain(c, idx, warnings) {
  const o = coerceObj(c);
  const chain = sanitizeStringArray(o.chain);
  // windows_between: coerce to length = max(0, chain.length - 1)
  let win = Array.isArray(o.windows_between) ? o.windows_between : [];
  const need = Math.max(0, chain.length - 1);
  if (win.length !== need) {
    if (win.length < need) warnings.push(`Chain #${idx}: padded windows_between to ${need}.`);
    else warnings.push(`Chain #${idx}: truncated windows_between to ${need}.`);
  }
  win = (win.slice(0, need)).map((w, j) => sanitizeWindow(w, idx, j, warnings));

  const inclusive = !!o.inclusive; // default false
  return { chain, windows_between: win, inclusive };
}

/** Coerce one window object */
function sanitizeWindow(w, chainIdx, winIdx, warnings) {
  const o = coerceObj(w);
  const toNum = (v) => (v === '' || v == null ? null : Number(v));
  let min = toNum(o.min);
  let max = toNum(o.max);

  // Drop NaN; round to integers >= 0
  if (min != null) {
    if (Number.isNaN(min)) { min = null; warnings.push(`Chain #${chainIdx} window #${winIdx}: dropped invalid min`); }
    else min = Math.max(0, Math.round(min));
  }
  if (max != null) {
    if (Number.isNaN(max)) { max = null; warnings.push(`Chain #${chainIdx} window #${winIdx}: dropped invalid max`); }
    else max = Math.max(0, Math.round(max));
  }

  // If both present and min>max, swap
  if (min != null && max != null && min > max) {
    warnings.push(`Chain #${chainIdx} window #${winIdx}: swapped min/max`);
    const tmp = min; min = max; max = tmp;
  }
  const out = {};
  if (min != null) out.min = min;
  if (max != null) out.max = max;
  return out;
}

/** Demographics normalization */
function sanitizeDemographics(dem, warnings) {
  const out = { age: {}, sex: [], ethnicity: [], vital_status: [] };

  // age
  const age = coerceObj(dem.age);
  const numOrNull = (v) => (v === '' || v == null ? null : Number(v));
  let min = numOrNull(age.min);
  let max = numOrNull(age.max);
  if (min != null && Number.isNaN(min)) { min = null; warnings.push('Dropped invalid age.min'); }
  if (max != null && Number.isNaN(max)) { max = null; warnings.push('Dropped invalid age.max'); }
  if (min != null) min = Math.max(0, Math.floor(min));
  if (max != null) max = Math.max(0, Math.floor(max));
  if (min != null && max != null && min > max) { const t = min; min = max; max = t; warnings.push('Swapped age.min/age.max'); }
  out.age = {};
  if (min != null) out.age.min = min;
  if (max != null) out.age.max = max;

  // sex
  const sexMap = { male: 'male', female: 'female', m: 'male', f: 'female', unknown: 'unknown' };
  out.sex = sanitizeStringArray(dem.sex).map(s => (sexMap[s.toLowerCase()] || 'unknown'));
  // keep only valid values
  out.sex = out.sex.filter(s => s === 'male' || s === 'female' || s === 'unknown');

  // ethnicity (copy verbatim, just trim/dedupe)
  out.ethnicity = sanitizeStringArray(dem.ethnicity);

  // vital_status
  const vsMap = { alive: 'alive', dead: 'dead', deceased: 'dead', unknown: 'unknown' };
  out.vital_status = sanitizeStringArray(dem.vital_status).map(s => (vsMap[s.toLowerCase()] || 'unknown'));
  out.vital_status = out.vital_status.filter(s => s === 'alive' || s === 'dead' || s === 'unknown');

  return out;
}


// ---- server ----
const app = express();
app.use(cors(corsOptions));
app.use(express.json());
app.use(express.static('public'));


// List available Ollama models (proxy)
app.get('/api/models', async (req, res) => {
  try {
    const base = OLLAMA_URL.replace(/\/api\/generate.*$/, '');
    const rr = await fetch(`${base}/api/tags`, { method: 'GET' });
    if (!rr.ok) {
      const txt = await rr.text();
      return res.status(502).json({ error: 'Ollama tags error', detail: txt });
    }
    const data = await rr.json(); // { models: [{name, model, ...}, ...] }
    // Normalize to an array of strings (prefer "name" then "model")
    const models = Array.isArray(data.models)
      ? data.models.map(m => m.name || m.model).filter(Boolean)
      : [];
    res.json({ models });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to fetch models' });
  }
});

app.post('/api/compile', async (req, res) => {
  console.log('In /api/compile');
  console.log(req.body);
  try {
    const query = String(req.body?.query || '').trim();
    const requestModel = String(req.body?.model || '').trim() || MODEL;
    if (!query) return res.status(400).json({ error: 'Missing query' });

    const prompt = `${TRANSLATION_GUIDE}\nUser: ${query}\nJSON:`;
    const body = {
      model: requestModel,
      prompt,
      stream: false,
      options: {
        temperature: 0,
        seed: 42,
        mirostat: 0,
        top_p: 1,
        top_k: 1,
        repeat_penalty: 1, // disable penalties
        repeat_last_n: 0,  // disable penalties
      }
    };

    const rr = await fetch(OLLAMA_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    const resp = await rr.json();
    const raw = String(resp?.response || '');

    // --- Extractor: collect <think>...</think> (reasoning) and parse the first JSON object
    function extractReasoningAndJSON(s) {
      // 1) collect all <think> blocks (join them if multiple)
      const thinkBlocks = Array.from(s.matchAll(/<think>([\s\S]*?)<\/think>/g)).map(m => m[1].trim());
      const reasoning = thinkBlocks.length ? thinkBlocks.join('\n\n') : '';
      // 2) strip them from the text
      const noThink = s.replace(/<think>[\s\S]*?<\/think>/g, '').trim();
      // 3) find outermost {...} and parse
      const start = noThink.indexOf('{');
      const end = noThink.lastIndexOf('}');
      if (start === -1 || end === -1 || end < start) throw new Error('No JSON object found');
      const candidate = noThink.slice(start, end + 1);
      const dsl = JSON.parse(candidate);
      const warnings = [];
      //dsl = normalizeDSL(dsl, warnings);
      return { dsl, reasoning, warnings };
    }

    let dsl, reasoning, warnings;
    try {
      ({ dsl, reasoning, warnings} = extractReasoningAndJSON(raw));
    } catch (e) {
      return res.status(400).json({ error: 'Model did not return valid JSON', raw });
    }

    console.log(dsl);

    // ---- medcat ----
    if (true) {
      // Collect phenotype terms (unique, in original order)
      const ph = dsl.phenotype || { all_of: [], any_of: [], none_of: [] };
      const originalTerms = [
        ...(Array.isArray(ph.all_of) ? ph.all_of : []),
        ...(Array.isArray(ph.any_of) ? ph.any_of : []),
        ...(Array.isArray(ph.none_of) ? ph.none_of : [])
      ].map(String);

      // Resolve to pretty names via MedCAT (keeps order/length)
      try {
        const resolved = await medcatResolveNames(originalTerms);
        // Re-split back into the three arrays with strings only
        const a = ph.all_of?.length || 0;
        const b = ph.any_of?.length || 0;
        dsl.phenotype.all_of  = resolved.slice(0, a);
        dsl.phenotype.any_of  = resolved.slice(a, a + b);
        dsl.phenotype.none_of = resolved.slice(a + b);
      } catch (e) {
        console.error("MedCAT resolve_names failed:", e.message);
        // If MedCAT is down, keep original strings untouched
      }
      // ---- TEMPORAL CHAIN SNOMED NAME NORMALISATION ----
      try {
        const chains = dsl?.temporal?.chains;
        if (Array.isArray(chains) && chains.length) {
          // collect all chain terms
          const temporalTerms = [];
          for (const ch of chains) {
            if (Array.isArray(ch?.chain)) temporalTerms.push(...ch.chain.map(String));
          }
          // resolve once in batch, then rewrite in-place
          const resolveName = await medcatResolveNamesMap(temporalTerms);
          for (const ch of chains) {
            if (Array.isArray(ch?.chain)) {
              ch.chain = ch.chain.map(t => resolveName(t));
            }
          }
        }
      } catch (e) {
        console.error("MedCAT resolve_names (temporal) failed:", e.message);
        // soft-fail: keep original temporal terms
      }
    }
    // ---- medcat ----

    console.log(dsl);

    return res.json({ dsl, reasoning });


  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
});

app.listen(PORT, () => {
  console.log(`DSL web app listening on http://localhost:${PORT}`);
});
