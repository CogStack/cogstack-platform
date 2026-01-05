from pydantic import BaseModel
from typing import List, Any, Dict, Optional
import zipfile, tempfile, os, traceback
from medcat.cat import CAT
from medcat.cdb import CDB
from medcat.vocab import Vocab
from medcat.config import Config
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

MODEL_PACK_PATH = os.environ.get(
    "MEDCAT_MODEL_PACK",
    "/app/models/medcat_model_pack.zip"  # path to model
)

app = FastAPI(title="MedCAT Annotator", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in os.getenv("ALLOW_ORIGINS", "*").split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

cat: Optional[CAT] = None

class TextIn(BaseModel):
    text: str

class BulkIn(BaseModel):
    items: List[TextIn]

def _cat_or_503() -> CAT:
    if cat is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return cat

def load_model() -> None:
    global cat
    print(f"Loading MedCAT model pack from: {MODEL_PACK_PATH}", flush=True)

    # Try normal pack load first
    try:
        _cat = CAT.load_model_pack(MODEL_PACK_PATH)

        # after: cat = _cat  (in both the pack and fallback branches)
        def _tune_short_names(c):
            try:
                # allow 2-char names like "HF"
                c.config.ner.min_name_len = int(os.getenv("MEDCAT_MIN_NAME_LEN", "2"))
                # keep default behavior for short lowercase words (set to 4 or lower if needed)
                c.config.ner.upper_case_limit_len = int(os.getenv("MEDCAT_UPPER_CASE_LIMIT", "4"))
                # leave case-insensitive unless needed case-aware distinctions
                c.config.ner.check_upper_case_names = False
                print(f"[MedCAT] NER min_name_len={c.config.ner.min_name_len}, "
                    f"upper_case_limit_len={c.config.ner.upper_case_limit_len}", flush=True)
            except Exception as e:
                print("WARN: could not tweak NER settings:", e, flush=True)

        _tune_short_names(cat)




        try:
            _cat.config.annotations.entity_output_mode = "list"
        except Exception:
            pass
        cat = _cat
        print("MedCAT model loaded via pack.", flush=True)
        return
    except Exception as e:
        print("Pack load failed, will try fallback (CDB+Vocab). Reason:", e, flush=True)
        traceback.print_exc()

    # Fallback: CDB/Vocab from the zip (no torch/sklearn)
    try:
        with zipfile.ZipFile(MODEL_PACK_PATH, "r") as zf, tempfile.TemporaryDirectory() as tmpd:
            zf.extractall(tmpd)

            def find_one(names):
                for n in names:
                    p = os.path.join(tmpd, n)
                    if os.path.exists(p):
                        return p
                return None

            cdb_path   = find_one(["cdb.dat","cdb.bin","cdb","cdb.pkl"])
            vocab_path = find_one(["vocab.dat","vocab.bin","vocab","vocab.pkl"])
            if not cdb_path or not vocab_path:
                raise RuntimeError(f"Could not find CDB/Vocab in pack (cdb={cdb_path}, vocab={vocab_path})")

            cdb = CDB.load(cdb_path)
            vocab = Vocab.load(vocab_path)

            cfg = Config()
            try:
                cfg.pipeline.tokenizer.nlp.modelname = "en_core_web_sm"
            except Exception:
                d = cfg.dict()
                d.setdefault("pipeline", {}).setdefault("tokenizer", {}).setdefault("nlp", {})["modelname"] = "en_core_web_sm"
                cfg = Config(**d)

            _cat = CAT(cdb=cdb, vocab=vocab, config=cfg)
            try:
                _cat.config.annotations.entity_output_mode = "list"
            except Exception:
                pass
            cat = _cat
            print("MedCAT model loaded via fallback (CDB+Vocab).", flush=True)
    except Exception as e:
        print("FALLBACK LOAD FAILED:", e, flush=True)
        traceback.print_exc()
        # Fail startup so we don't serve 503 later
        raise

@app.get("/health")
def health() -> Dict[str, Any]:
    ok = cat is not None
    return {
        "ok": ok,
        "model_pack": MODEL_PACK_PATH,
        "entity_output_mode": getattr(getattr(getattr(cat, "config", None), "annotations", None), "entity_output_mode", None) if ok else None,
    }


@app.post("/annotate")
def annotate(inp: TextIn) -> Dict[str, Any]:
    c = _cat_or_503()
    # get_entities returns a rich dict; many clients prefer a flat list
    ents = c.get_entities(inp.text)
    # Normalize to a simple list of spans with ids and names
    # If config already returns list mode, this will be just pass-through
    if isinstance(ents, dict) and "entities" in ents:
        entities_raw = ents["entities"]
        if isinstance(entities_raw, dict):
            # old-style dict → list
            entities = []
            for eid, e in entities_raw.items():
                entities.append({
                    "start": e.get("start"),
                    "end": e.get("end"),
                    "text": e.get("text"),
                    "cui": e.get("cui"),
                    "type_ids": e.get("type_ids"),
                    "pretty_name": e.get("pretty_name") or e.get("name"),
                    "acc": e.get("acc"),
                })
        else:
            entities = entities_raw
    else:
        entities = ents
    return {"entities": entities}


@app.post("/annotate_bulk")
def annotate_bulk(inp: BulkIn) -> Dict[str, Any]:
    c = _cat_or_503()
    out = []
    for item in inp.items:
        ents = c.get_entities(item.text)
        if isinstance(ents, dict) and "entities" in ents:
            entities_raw = ents["entities"]
            if isinstance(entities_raw, dict):
                entities = []
                for eid, e in entities_raw.items():
                    entities.append({
                        "start": e.get("start"),
                        "end": e.get("end"),
                        "text": e.get("text"),
                        "cui": e.get("cui"),
                        "type_ids": e.get("type_ids"),
                        "pretty_name": e.get("pretty_name") or e.get("name"),
                        "acc": e.get("acc"),
                    })
            else:
                entities = entities_raw
        else:
            entities = ents
        out.append({"entities": entities})
    return {"results": out}

@app.on_event("startup")
def _startup():
    load_model()


from pydantic import BaseModel
from typing import List, Dict, Any

class ResolveIn(BaseModel):
    terms: List[str]

def _best_entity_name(cat, term: str) -> str:
    """Return the best pretty name for the term or fall back to the original."""
    anns = cat.get_entities(term)
    # normalise to list of dicts
    candidates = []
    if isinstance(anns, dict) and "entities" in anns:
        ents = anns["entities"]
        candidates = list(ents.values()) if isinstance(ents, dict) else list(ents)
    elif isinstance(anns, list):
        candidates = anns

    best, best_score = None, -1.0
    for e in candidates or []:
        if not isinstance(e, dict):
            continue
        span_ok = (e.get("start") == 0 and e.get("end") == len(term))
        acc = float(e.get("acc") or 0.0)
        score = acc + (1.0 if span_ok else 0.0)
        if score > best_score:
            best, best_score = e, score

    if not best:
        return term  # no hit → keep original
    # This is the “pretty” label MedCAT exposes for the concept.
    return best.get("pretty_name") or best.get("name") or best.get("text") or term

@app.post("/resolve_names")
def resolve_names(inp: ResolveIn) -> Dict[str, Any]:
    c = _cat_or_503()
    out = []
    for t in inp.terms:
        r = _best_entity_name(c, t)
        out.append(r)
    return {"resolved": out}


@app.get("/debug/lookup/{name}")
def lookup(name: str):
    c = _cat_or_503()
    cuis = list(c.cdb.name2cui.get(name.lower(), set()))
    return {"name": name, "present": bool(cuis), "cuis": cuis}
