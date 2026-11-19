#!/usr/bin/env python3
"""
Generate synthetic OpenSearch/Elasticsearch bulk NDJSON for CogStack demos.

This generator produces synthetic data shaped like a small subset of the
MIMIC-IV dataset schema (MIMIC-IV Clinical Database Demo v2.2):
https://physionet.org/content/mimic-iv-demo/2.2/

The *schemas/field shapes* are retained for realism, but the generated content
is synthetic: it does not include any MIMIC-IV data, and it does not embed
dataset-derived enumerations/value sets.

This writes a single .ndjson file in the bulk API format:
  {"index":{"_index":"<index>","_id":"<id>"}}
  {"field": "...", ...}

It generates N documents for each of 6 indices:
  admissions, drgcodes, emar, icustays, patients, poe

No third-party dependencies (built-in Python only).
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Optional, Sequence, Tuple


INDEX_ORDER: Tuple[str, ...] = (
    "admissions",
    "drgcodes",
    "emar",
    "icustays",
    "patients",
    "poe",
    "discharge",
    "discharge_annotations",
)


# Note on value lists:
# Keep these lists generic and non-derivative. They are intended as plausible *synthetic*
# categories, not as extracted value sets from any dataset.

# Use OMOP-like visit concepts (high level) for admissions.
ADMISSION_TYPES: Tuple[str, ...] = (
    "Inpatient Visit",
    "Emergency Room Visit",
    "Outpatient Visit",
    "Observation Visit",
)

# Generic sources / admitting contexts (avoid hospital-specific phrasing).
ADMISSION_LOCATIONS: Tuple[str, ...] = (
    "Home",
    "Clinic",
    "Emergency Department",
    "Another Facility",
    "Unknown",
)

DISCHARGE_LOCATIONS: Tuple[str, ...] = (
    "Home",
    "Rehabilitation Facility",
    "Long-term Care Facility",
    "Died",
)

# Generic payer categories (avoid copying any particular dataset’s value sets).
INSURANCE: Tuple[str, ...] = (
    "Public",
    "Private",
    "Self Pay",
    "Other",
)

LANGUAGES: Tuple[str, ...] = (
    "English",
    "Spanish",
    "Portuguese",
    "French",
)

MARITAL_STATUS: Tuple[str, ...] = (
    "SINGLE",
    "MARRIED",
    "DIVORCED",
    "WIDOWED",
)

RACE: Tuple[str, ...] = (
    "Race_A",
    "Race_B",
    "Race_C",
    "Race_D",
    "Unknown",
)

CAREUNITS: Tuple[str, ...] = (
    "Intensive Care Unit",
    "Surgical ICU",
    "Medical ICU",
    "Step-down Unit",
    "Cardiac Care Unit",
)

ORDER_TYPES: Tuple[str, ...] = (
    "General Care",
    "IV therapy",
    "Medications",
    "Radiology",
    "Consults",
)

ORDER_SUBTYPES: Dict[str, Tuple[str, ...]] = {
    "General Care": ("Other", "Tubes/Drains"),
    "IV therapy": ("IV fluids",),
    "Radiology": ("General Xray",),
    "Consults": ("Physical Therapy",),
}

TRANSACTION_TYPES: Tuple[str, ...] = (
    "New",
    "D/C",
    "Change",
)

ORDER_STATUS: Tuple[str, ...] = (
    "Inactive",
    "Active",
)

EMAR_EVENT_TXT: Tuple[str, ...] = (
    "Administered",
    "Flushed",
    "Not Given",
)

MEDICATIONS: Tuple[str, ...] = (
    "Furosemide",
    "Sodium Chloride 0.9%  Flush",
    "Influenza Vaccine Quadrivalent",
    "Folic Acid",
    "Midodrine",
    "Multivitamins",
    "Pantoprazole",
    "Insulin",
    "Acetaminophen",
    "Heparin",
)

DRG_TYPES: Tuple[str, ...] = (
    "APR",
    "HCFA",
)

# Avoid long, dataset-specific DRG descriptions; keep neutral synthetic labels.
DRG_DESCRIPTIONS: Tuple[str, ...] = (
    "Cardiology (general)",
    "Heart failure (general)",
    "Renal care (general)",
    "Orthopedics (general)",
    "Neurology (general)",
    "Respiratory care (general)",
    "Gastroenterology (general)",
    "Infectious disease (general)",
    "General medicine (general)",
)


def fmt_dt(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def fmt_dt_with_seconds(dt: datetime) -> str:
    # Matches icustays `outtime` examples that include seconds.
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def choose(rng: random.Random, items: Sequence[str]) -> str:
    return items[rng.randrange(len(items))]


def rand_upper_alnum(rng: random.Random, length: int) -> str:
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return "".join(alphabet[rng.randrange(len(alphabet))] for _ in range(length))


def provider_id(idx: int) -> str:
    # Deterministic provider identifier (string-typed).
    return f"P{idx}"


def bounded_int(rng: random.Random, lo: int, hi: int) -> int:
    return lo + rng.randrange(hi - lo + 1)


def maybe(rng: random.Random, probability: float) -> bool:
    return rng.random() < probability


def rand_datetime(
    rng: random.Random,
    start: datetime,
    end: datetime,
    *,
    resolution_seconds: int = 60,
) -> datetime:
    if end <= start:
        return start
    span_seconds = int((end - start).total_seconds())
    steps = max(1, span_seconds // resolution_seconds)
    offset_steps = rng.randrange(steps + 1)
    return start + timedelta(seconds=offset_steps * resolution_seconds)


@dataclass(frozen=True)
class Patient:
    subject_id: int
    gender: str
    anchor_age: int
    anchor_year: int
    anchor_year_group: str
    dod: Optional[str]


@dataclass(frozen=True)
class Admission:
    subject_id: int
    hadm_id: int
    admittime: datetime
    dischtime: datetime
    hospital_expire_flag: int
    deathtime: Optional[datetime]
    admission_type: str
    admit_provider_id: str
    admission_location: str
    discharge_location: str
    insurance: str
    language: str
    marital_status: str
    race: str
    edregtime: Optional[datetime]
    edouttime: Optional[datetime]


@dataclass(frozen=True)
class IcuStay:
    subject_id: int
    hadm_id: int
    stay_id: int
    first_careunit: str
    last_careunit: str
    intime: datetime
    outtime: datetime
    los: float


@dataclass(frozen=True)
class PoeOrder:
    poe_seq: int
    subject_id: int
    hadm_id: int
    ordertime: datetime
    order_type: str
    order_subtype: Optional[str]
    transaction_type: str
    discontinue_of_poe_seq: Optional[int]
    discontinued_by_poe_seq: Optional[int]
    order_provider_id: str
    order_status: str

    @property
    def poe_id(self) -> str:
        return f"{self.subject_id}-{self.poe_seq}"

    def poe_id_for_seq(self, seq: int) -> str:
        return f"{self.subject_id}-{seq}"


@dataclass(frozen=True)
class EmarEvent:
    emar_seq: int
    subject_id: int
    hadm_id: int
    poe_id: str
    pharmacy_id: Optional[int]
    enter_provider_id: str
    charttime: datetime
    medication: str
    event_txt: str
    scheduletime: datetime
    storetime: datetime

    @property
    def emar_id(self) -> str:
        return f"{self.subject_id}-{self.emar_seq}"


@dataclass(frozen=True)
class DischargeNote:
    note_id: str
    subject_id: int
    hadm_id: int
    note_type: str
    note_seq: int
    charttime: datetime
    storetime: datetime
    text: str


def make_discharge_notes(rng: random.Random, admissions: Sequence[Admission]) -> List[DischargeNote]:
    notes: List[DischargeNote] = []
    for adm in admissions:
        note_type = "DS"
        note_seq = bounded_int(rng, 1, 20)
        note_id = f"{adm.subject_id}-{note_type}-{note_seq}"

        charttime = rand_datetime(rng, adm.admittime, adm.dischtime, resolution_seconds=60)
        storetime = min(adm.dischtime, charttime + timedelta(hours=bounded_int(rng, 0, 24), minutes=bounded_int(rng, 0, 59)))

        # Synthetic discharge-note-like template (non-derivative, intentionally generic).
        problems = (
            "Chest pain",
            "Shortness of breath",
            "Abdominal pain",
            "Dizziness",
            "Headache",
            "Fever",
            "Fatigue",
        )
        services = ("MEDICINE", "SURGERY", "CARDIOLOGY", "NEUROLOGY", "RESPIRATORY", "RENAL")
        meds = ("acetaminophen", "heparin", "pantoprazole", "insulin", "furosemide", "saline flush")
        diag = choose(rng, problems)
        service = choose(rng, services)
        discharge_to = adm.discharge_location
        med_list = ", ".join(rng.sample(meds, k=bounded_int(rng, 2, 4)))

        text = (
            "\n"
            "Discharge Summary\n"
            "=================\n"
            f"Subject: {adm.subject_id}\n"
            f"Admission ID: {adm.hadm_id}\n"
            f"Service: {service}\n"
            "\n"
            "Chief Complaint:\n"
            f"{diag}\n"
            "\n"
            "Hospital Course:\n"
            "The patient was evaluated and treated during this admission. Symptoms improved with supportive care.\n"
            "Vital signs remained stable. No acute complications were documented.\n"
            "\n"
            "Discharge Diagnoses:\n"
            f"- {diag}\n"
            "\n"
            "Discharge Medications:\n"
            f"- {med_list}\n"
            "\n"
            "Follow-up:\n"
            "- Primary care follow-up in 1-2 weeks.\n"
            "- Return to care if symptoms worsen.\n"
            "\n"
            "Disposition:\n"
            f"{discharge_to}\n"
            "\n"
        )

        notes.append(
            DischargeNote(
                note_id=note_id,
                subject_id=adm.subject_id,
                hadm_id=adm.hadm_id,
                note_type=note_type,
                note_seq=note_seq,
                charttime=charttime,
                storetime=storetime,
                text=text,
            )
        )
    return notes


def discharge_doc(n: DischargeNote) -> Dict[str, object]:
    return {
        "note_id": n.note_id,
        "subject_id": n.subject_id,
        "hadm_id": n.hadm_id,
        "note_type": n.note_type,
        "note_seq": n.note_seq,
        "charttime": fmt_dt(n.charttime),
        "storetime": fmt_dt(n.storetime),
        "text": n.text,
    }


def _rand_timestamp_utc_iso(rng: random.Random, base: datetime) -> str:
    # Example: 2024-04-13T16:17:02.103+00:00
    dt = base + timedelta(seconds=bounded_int(rng, -3600 * 24 * 30, 3600 * 24 * 30))
    ms = bounded_int(rng, 0, 999)
    return dt.strftime("%Y-%m-%dT%H:%M:%S") + f".{ms:03d}+00:00"


def make_discharge_annotations(rng: random.Random, notes: Sequence[DischargeNote]) -> List[Dict[str, object]]:
    ann: List[Dict[str, object]] = []
    pretty_names = (
        "Usage",
        "Dose",
        "Route",
        "Frequency",
        "Condition",
        "Procedure",
        "Symptom",
    )
    detected_terms = (
        "use",
        "dose",
        "oral",
        "daily",
        "pain",
        "fever",
        "follow-up",
        "medication",
    )
    # Keep ontology/model identifiers generic (avoid licensed/sensitive names).
    ontologies = (
        "ONTOLOGY_A",
        "ONTOLOGY_B",
        "ONTOLOGY_C",
        "ONTOLOGY_D",
    )
    service_models = ("demo_model_a", "demo_model_b", "demo_model_c")
    service_versions = ("1.10.2", "1.11.0", "2.0.0")

    for n in notes:
        # Seeded random 1–20 annotations per note.
        per_note = bounded_int(rng, 1, 20)
        text_len = len(n.text)
        for _ in range(per_note):
            # Pick a safe span inside the text.
            if text_len < 10:
                start = 0
                end = text_len
            else:
                start = bounded_int(rng, 0, max(0, text_len - 2))
                span = bounded_int(rng, 1, min(25, max(1, text_len - start)))
                end = min(text_len, start + span)
                if end <= start:
                    end = min(text_len, start + 1)

            detected = choose(rng, detected_terms)
            pretty = choose(rng, pretty_names)
            cui = str(bounded_int(rng, 100_000_000, 999_999_999))

            doc: Dict[str, object] = {
                "nlp.cui": cui,
                "enrich_top_level_concept": bounded_int(rng, 100_000, 999_999_999),
                "nlp.pretty_name": pretty,
                "nlp.end": end,
                "nlp.types": [""],
                "nlp.detected_name": detected,
                "nlp.meta_anns": {
                    "Presence": {
                        "confidence": rng.random(),
                        "name": "Presence",
                        "value": choose(rng, ("Present", "Absent", "Hypothetical")),
                    },
                    "Time": {
                        "confidence": rng.random(),
                        "name": "Time",
                        "value": choose(rng, ("Recent", "Historical", "Planned")),
                    },
                    "Subject": {
                        "confidence": rng.random(),
                        "name": "Subject",
                        "value": choose(rng, ("Patient", "Family", "Clinician")),
                    },
                },
                "service_version": choose(rng, service_versions),
                "nlp.start": start,
                "nlp.source_value": detected,
                "nlp.id": bounded_int(rng, 1, 10_000),
                "meta.note_id": n.note_id,
                "service_model": choose(rng, service_models),
                "meta.subject_id": str(n.subject_id),
                "nlp.icd10": [],
                "nlp.snomed": [],
                "nlp.acc": rng.random(),
                "nlp.type_ids": [str(bounded_int(rng, 1_000_000, 99_999_999))],
                "nlp.context_similarity": rng.random(),
                "nlp.ontologies": [choose(rng, ontologies)],
                "timestamp": _rand_timestamp_utc_iso(rng, n.storetime),
            }
            ann.append(doc)

    return ann


def make_patients(rng: random.Random, n: int) -> List[Patient]:
    patients: List[Patient] = []
    for subject_id in range(n):

        gender = choose(rng, ("F", "M"))
        anchor_age = bounded_int(rng, 18, 90)
        anchor_year = bounded_int(rng, 2100, 2190)
        anchor_year_group = choose(
            rng,
            (
                "2008 - 2010",
                "2011 - 2013",
                "2014 - 2016",
                "2017 - 2019",
                "2020 - 2022",
            ),
        )

        dod: Optional[str] = None
        if maybe(rng, 0.15):
            dod_year = min(2199, anchor_year + bounded_int(rng, 0, 5))
            dod_dt = datetime(dod_year, bounded_int(rng, 1, 12), bounded_int(rng, 1, 28))
            dod = dod_dt.strftime("%Y-%m-%d")

        patients.append(
            Patient(
                subject_id=subject_id,
                gender=gender,
                anchor_age=anchor_age,
                anchor_year=anchor_year,
                anchor_year_group=anchor_year_group,
                dod=dod,
            )
        )

    return patients


def make_admissions(rng: random.Random, patients: Sequence[Patient]) -> List[Admission]:
    admissions: List[Admission] = []
    start = datetime(2110, 1, 1, 0, 0, 0)
    end = datetime(2190, 12, 31, 23, 59, 0)

    for hadm_id, p in enumerate(patients):

        admittime = rand_datetime(rng, start, end, resolution_seconds=60)
        stay_hours = bounded_int(rng, 6, 24 * 21)
        dischtime = admittime + timedelta(hours=stay_hours)

        admission_type = choose(rng, ADMISSION_TYPES)
        admission_location = choose(rng, ADMISSION_LOCATIONS)
        insurance = choose(rng, INSURANCE)
        language = choose(rng, LANGUAGES)
        marital_status = choose(rng, MARITAL_STATUS)
        race = choose(rng, RACE)

        expire = 1 if maybe(rng, 0.2) else 0
        if expire:
            discharge_location = "DIED"
            deathtime = dischtime
        else:
            discharge_location = choose(rng, tuple(x for x in DISCHARGE_LOCATIONS if x != "DIED"))
            deathtime = None

        # ED times are optional in example.
        if maybe(rng, 0.8):
            edregtime = admittime - timedelta(hours=bounded_int(rng, 0, 6))
            edouttime = admittime + timedelta(hours=bounded_int(rng, 0, 6))
        else:
            edregtime = None
            edouttime = None

        admissions.append(
            Admission(
                subject_id=p.subject_id,
                hadm_id=hadm_id,
                admittime=admittime,
                dischtime=dischtime,
                hospital_expire_flag=expire,
                deathtime=deathtime,
                admission_type=admission_type,
                admit_provider_id=provider_id(hadm_id),
                admission_location=admission_location,
                discharge_location=discharge_location,
                insurance=insurance,
                language=language,
                marital_status=marital_status,
                race=race,
                edregtime=edregtime,
                edouttime=edouttime,
            )
        )

    return admissions


def make_icustays(rng: random.Random, admissions: Sequence[Admission]) -> List[IcuStay]:
    icustays: List[IcuStay] = []
    for stay_id, adm in enumerate(admissions):

        first_careunit = choose(rng, CAREUNITS)
        last_careunit = choose(rng, CAREUNITS)
        intime = adm.admittime + timedelta(hours=bounded_int(rng, 0, 36), minutes=bounded_int(rng, 0, 59))
        max_out = min(adm.dischtime, intime + timedelta(days=bounded_int(rng, 0, 10), hours=bounded_int(rng, 1, 20)))
        outtime = rand_datetime(rng, intime + timedelta(hours=1), max_out, resolution_seconds=1)

        los_days = (outtime - intime).total_seconds() / 86400.0
        icustays.append(
            IcuStay(
                subject_id=adm.subject_id,
                hadm_id=adm.hadm_id,
                stay_id=stay_id,
                first_careunit=first_careunit,
                last_careunit=last_careunit,
                intime=intime,
                outtime=outtime,
                los=round(los_days, 7),
            )
        )

    return icustays


def make_poe_orders(rng: random.Random, admissions: Sequence[Admission]) -> List[PoeOrder]:
    orders: List[PoeOrder] = []

    n = len(admissions)
    for poe_seq, adm in enumerate(admissions):
        ordertime = rand_datetime(rng, adm.admittime, adm.dischtime, resolution_seconds=1)
        order_type = choose(rng, ORDER_TYPES)
        order_subtype = None
        if order_type in ORDER_SUBTYPES and maybe(rng, 0.85):
            order_subtype = choose(rng, ORDER_SUBTYPES[order_type])

        transaction_type = choose(rng, TRANSACTION_TYPES)

        # Optional link fields in the example depend on transaction type.
        discontinue_of_seq: Optional[int] = None
        discontinued_by_seq: Optional[int] = None
        if transaction_type == "D/C":
            discontinue_of_seq = max(0, poe_seq - bounded_int(rng, 1, 30))
        elif transaction_type == "Change":
            discontinue_of_seq = max(0, poe_seq - bounded_int(rng, 1, 30))
            discontinued_by_seq = poe_seq + 1 if poe_seq + 1 < n else None
        elif transaction_type == "New" and maybe(rng, 0.15):
            discontinued_by_seq = poe_seq + 1 if poe_seq + 1 < n else None

        orders.append(
            PoeOrder(
                poe_seq=poe_seq,
                subject_id=adm.subject_id,
                hadm_id=adm.hadm_id,
                ordertime=ordertime,
                order_type=order_type,
                order_subtype=order_subtype,
                transaction_type=transaction_type,
                discontinue_of_poe_seq=discontinue_of_seq,
                discontinued_by_poe_seq=discontinued_by_seq,
                order_provider_id=provider_id(poe_seq),
                order_status=choose(rng, ORDER_STATUS),
            )
        )

    return orders


def make_emar_events(rng: random.Random, admissions: Sequence[Admission], poe_orders: Sequence[PoeOrder]) -> List[EmarEvent]:
    events: List[EmarEvent] = []

    # For each admission, pick a POE order to reference.
    poe_by_hadm: Dict[int, PoeOrder] = {o.hadm_id: o for o in poe_orders}

    for emar_seq, adm in enumerate(admissions):
        poe = poe_by_hadm.get(adm.hadm_id)
        if poe is None:
            # Shouldn't happen with our generation strategy.
            poe_id = f"{adm.subject_id}-{bounded_int(rng, 1, 999)}"
        else:
            poe_id = poe.poe_id

        charttime = rand_datetime(rng, adm.admittime, adm.dischtime, resolution_seconds=60)
        scheduletime = charttime + timedelta(minutes=bounded_int(rng, -30, 30))
        storetime = charttime + timedelta(minutes=bounded_int(rng, 0, 10))

        event_txt = choose(rng, EMAR_EVENT_TXT)
        medication = choose(rng, MEDICATIONS)

        pharmacy_id: Optional[int] = None
        if maybe(rng, 0.8):
            pharmacy_id = 10_000_000 + emar_seq

        events.append(
            EmarEvent(
                emar_seq=emar_seq,
                subject_id=adm.subject_id,
                hadm_id=adm.hadm_id,
                poe_id=poe_id,
                pharmacy_id=pharmacy_id,
                enter_provider_id=provider_id(emar_seq),
                charttime=charttime,
                medication=medication,
                event_txt=event_txt,
                scheduletime=scheduletime,
                storetime=storetime,
            )
        )

    return events


def make_drgcodes(rng: random.Random, admissions: Sequence[Admission]) -> List[dict]:
    docs: List[dict] = []
    for adm in admissions:
        drg_type = choose(rng, DRG_TYPES)
        drg_code = bounded_int(rng, 100, 800)
        description = choose(rng, DRG_DESCRIPTIONS)

        doc: Dict[str, object] = {
            "subject_id": adm.subject_id,
            "hadm_id": adm.hadm_id,
            "drg_type": drg_type,
            "drg_code": drg_code,
            "description": description,
        }

        # Example shows APR often has severity/mortality; HCFA often omits them.
        if drg_type == "APR" and maybe(rng, 0.85):
            doc["drg_severity"] = bounded_int(rng, 1, 4)
            doc["drg_mortality"] = bounded_int(rng, 1, 4)

        docs.append(doc)
    return docs


def admission_doc(a: Admission) -> Dict[str, object]:
    doc: Dict[str, object] = {
        "subject_id": a.subject_id,
        "hadm_id": a.hadm_id,
        "admittime": fmt_dt(a.admittime),
        "dischtime": fmt_dt(a.dischtime),
        "admission_type": a.admission_type,
        "admit_provider_id": a.admit_provider_id,
        "admission_location": a.admission_location,
        "discharge_location": a.discharge_location,
        "insurance": a.insurance,
        "language": a.language,
        "marital_status": a.marital_status,
        "race": a.race,
        "hospital_expire_flag": a.hospital_expire_flag,
    }
    if a.deathtime is not None:
        doc["deathtime"] = fmt_dt(a.deathtime)
    if a.edregtime is not None:
        doc["edregtime"] = fmt_dt(a.edregtime)
    if a.edouttime is not None:
        doc["edouttime"] = fmt_dt(a.edouttime)
    return doc


def patient_doc(p: Patient) -> Dict[str, object]:
    doc: Dict[str, object] = {
        "subject_id": p.subject_id,
        "gender": p.gender,
        "anchor_age": p.anchor_age,
        "anchor_year": p.anchor_year,
        "anchor_year_group": p.anchor_year_group,
    }
    if p.dod is not None:
        doc["dod"] = p.dod
    return doc


def icustay_doc(s: IcuStay) -> Dict[str, object]:
    return {
        "subject_id": s.subject_id,
        "hadm_id": s.hadm_id,
        "stay_id": s.stay_id,
        "first_careunit": s.first_careunit,
        "last_careunit": s.last_careunit,
        "intime": fmt_dt(s.intime),
        "outtime": fmt_dt_with_seconds(s.outtime),
        "los": s.los,
    }


def poe_doc(o: PoeOrder) -> Dict[str, object]:
    doc: Dict[str, object] = {
        "poe_id": o.poe_id,
        "poe_seq": o.poe_seq,
        "subject_id": o.subject_id,
        "hadm_id": o.hadm_id,
        "ordertime": o.ordertime.strftime("%Y-%m-%d %H:%M:%S"),
        "order_type": o.order_type,
        "transaction_type": o.transaction_type,
        "order_provider_id": o.order_provider_id,
        "order_status": o.order_status,
    }
    if o.order_subtype is not None:
        doc["order_subtype"] = o.order_subtype
    if o.discontinue_of_poe_seq is not None:
        doc["discontinue_of_poe_id"] = o.poe_id_for_seq(o.discontinue_of_poe_seq)
    if o.discontinued_by_poe_seq is not None:
        doc["discontinued_by_poe_id"] = o.poe_id_for_seq(o.discontinued_by_poe_seq)
    return doc


def emar_doc(e: EmarEvent) -> Dict[str, object]:
    doc: Dict[str, object] = {
        "subject_id": e.subject_id,
        "hadm_id": e.hadm_id,
        "emar_id": e.emar_id,
        "emar_seq": e.emar_seq,
        "poe_id": e.poe_id,
        "enter_provider_id": e.enter_provider_id,
        "charttime": fmt_dt(e.charttime),
        "medication": e.medication,
        "event_txt": e.event_txt,
        "scheduletime": fmt_dt(e.scheduletime),
        "storetime": fmt_dt(e.storetime),
    }
    if e.pharmacy_id is not None:
        doc["pharmacy_id"] = e.pharmacy_id
    return doc


Row = Tuple[str, str, Dict[str, object]]


def iter_bulk_rows(
    *,
    admissions: Sequence[Admission],
    drgcodes: Sequence[dict],
    emar: Sequence[EmarEvent],
    icustays: Sequence[IcuStay],
    patients: Sequence[Patient],
    poe: Sequence[PoeOrder],
    discharge: Sequence[DischargeNote],
    discharge_annotations: Sequence[Dict[str, object]],
) -> Iterator[Row]:
    # Deterministic order by index, with _id 1..N per index.
    for i, a in enumerate(admissions, start=1):
        yield ("admissions", str(i), admission_doc(a))
    for i, d in enumerate(drgcodes, start=1):
        yield ("drgcodes", str(i), d)
    for i, e in enumerate(emar, start=1):
        yield ("emar", str(i), emar_doc(e))
    for i, s in enumerate(icustays, start=1):
        yield ("icustays", str(i), icustay_doc(s))
    for i, p in enumerate(patients, start=1):
        yield ("patients", str(i), patient_doc(p))
    for i, o in enumerate(poe, start=1):
        yield ("poe", str(i), poe_doc(o))
    for i, n in enumerate(discharge, start=1):
        yield ("discharge", str(i), discharge_doc(n))
    for i, d in enumerate(discharge_annotations, start=1):
        yield ("discharge_annotations", str(i), d)


def write_bulk_ndjson(path: Path, rows: Iterable[Row]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for index_name, doc_id, doc in rows:
            meta = {"index": {"_index": index_name, "_id": doc_id}}
            f.write(json.dumps(meta, ensure_ascii=False) + "\n")
            f.write(json.dumps(doc, ensure_ascii=False) + "\n")


def validate_bulk_ndjson(path: Path, expected_counts: Dict[str, int]) -> None:
    # Lightweight structural validation: alternating meta/doc, correct index names, correct counts.
    expected_lines = 2 * sum(expected_counts.values())
    index_counts: Dict[str, int] = {idx: 0 for idx in expected_counts.keys()}

    with path.open("r", encoding="utf-8") as f:
        lines = f.readlines()

    if len(lines) != expected_lines:
        raise SystemExit(f"Validation failed: expected {expected_lines} lines, got {len(lines)}")

    for i in range(0, len(lines), 2):
        meta = json.loads(lines[i])
        doc = json.loads(lines[i + 1])
        if "index" not in meta or "_index" not in meta["index"] or "_id" not in meta["index"]:
            raise SystemExit(f"Validation failed: bad meta line at {i+1}")
        idx = meta["index"]["_index"]
        if idx not in index_counts:
            raise SystemExit(f"Validation failed: unexpected index '{idx}' at line {i+1}")
        if not isinstance(doc, dict):
            raise SystemExit(f"Validation failed: doc is not an object at line {i+2}")
        index_counts[idx] += 1

    for idx, expected in expected_counts.items():
        got = index_counts.get(idx, 0)
        if got != expected:
            raise SystemExit(f"Validation failed: index '{idx}' expected {expected} docs, got {got}")


def build_dataset(
    rng: random.Random, n: int
) -> Tuple[
    List[Patient],
    List[Admission],
    List[IcuStay],
    List[PoeOrder],
    List[EmarEvent],
    List[dict],
    List[DischargeNote],
    List[Dict[str, object]],
]:
    patients = make_patients(rng, n)
    admissions = make_admissions(rng, patients)
    icustays = make_icustays(rng, admissions)
    poe_orders = make_poe_orders(rng, admissions)
    emar_events = make_emar_events(rng, admissions, poe_orders)
    drg_docs = make_drgcodes(rng, admissions)
    discharge_notes = make_discharge_notes(rng, admissions)
    discharge_anns = make_discharge_annotations(rng, discharge_notes)
    return patients, admissions, icustays, poe_orders, emar_events, drg_docs, discharge_notes, discharge_anns


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate synthetic bulk NDJSON for Cogstack Opensearch dashboard.")
    p.add_argument("--n", type=int, required=True, help="Number of documents per index.")
    p.add_argument("--seed", type=int, default=0, help="Random seed (default: 0).")
    p.add_argument(
        "--out",
        type=Path,
        default=Path("synthetic_opensearch_ducuments_bulk_payload.ndjson"),
        help="Output NDJSON file path (default: synthetic_opensearch_ducuments_bulk_payload.ndjson).",
    )
    p.add_argument("--validate", action="store_true", help="Validate output structure after writing.")
    return p.parse_args(list(argv))


def main(argv: Sequence[str]) -> int:
    print(f"Generating synthetic data for Cogstack Opensearch dashboards")
    args = parse_args(argv)
    if args.n <= 0:
        raise SystemExit("--n must be > 0")

    rng = random.Random(args.seed)
    patients, admissions, icustays, poe_orders, emar_events, drg_docs, discharge_notes, discharge_anns = build_dataset(rng, args.n)

    rows = iter_bulk_rows(
        admissions=admissions,
        drgcodes=drg_docs,
        emar=emar_events,
        icustays=icustays,
        patients=patients,
        poe=poe_orders,
        discharge=discharge_notes,
        discharge_annotations=discharge_anns,
    )
    write_bulk_ndjson(args.out, rows)

    if args.validate:
        expected_counts: Dict[str, int] = {
            "admissions": args.n,
            "drgcodes": args.n,
            "emar": args.n,
            "icustays": args.n,
            "patients": args.n,
            "poe": args.n,
            "discharge": len(discharge_notes),
            "discharge_annotations": len(discharge_anns),
        }
        validate_bulk_ndjson(args.out, expected_counts)

    print(f"Completed synthetic data genration. File written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
