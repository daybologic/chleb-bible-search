#!/usr/bin/env python3
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  3. Neither the name of the project nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

import os
import argparse
import json
import re
from typing import List, Dict, Any
from openai import OpenAI

# ------------- CONFIG -------------

INPUT_FILE = "bible_verses.json"
OUTPUT_FILE = "bible_verses_tagged.jsonl"  # one JSON verse per line
BATCH_SIZE = 25
MODEL = "gpt-5.4-mini"  # current mini model for high-volume workloads

# Define the labels you want
PRIMARY_EMOTIONS = [
    "joy", "hope", "peace", "fear", "grief", "anger",
    "confusion", "guilt", "shame", "humility", "neutral"
]

TONES = [
    "comfort", "encouragement", "lament", "rebuke", "warning",
    "praise", "thanksgiving", "confession", "trust", "perseverance", "instruction", "challenge", "humility"
]

client = OpenAI()


# ------------- HELPERS -------------

def load_verses(path: str, translation: str) -> List[Dict[str, Any]]:
    with open(path, "r", encoding="utf-8") as f:
        raw = f.read()

    if path.lower().endswith(".json"):
        verses = json.loads(raw)
        if not isinstance(verses, list):
            raise ValueError(f"Expected a JSON array in {path}")
        return verses

    verses = []
    for line_number, line in enumerate(raw.splitlines(), start=1):
        if not line.strip():
            continue
        try:
            verse_key, text = line.split("::", 1)
            key_parts = verse_key.split(":", 3)
            if len(key_parts) != 4:
                raise ValueError
        except ValueError as error:
            raise ValueError(f"Invalid verse record on line {line_number} of {path}") from error

        reference = verse_key
        if translation.lower() == "pickthall" and key_parts[1].lower() == "quran":
            reference = f"Quran {key_parts[2]}:{key_parts[3]}"

        verses.append({
            "id": verse_key,
            "reference": reference,
            "text": text,
        })

    return verses


def chunks(lst: List[Any], n: int):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


def build_user_prompt(batch: List[Dict[str, Any]], translation: str) -> str:
    """
    Build a prompt that asks the model to return JSON for a list of verses.
    We give the model our allowed labels so it stays constrained.
    """
    source = "the Pickthall translation of the Quran" if translation.lower() == "pickthall" else f"the {translation} Bible translation"
    instructions = f"""
You are tagging verses from {source} with emotional and communicative labels.

For EACH verse, you must output an object with:
- "id": exactly the id of the verse I give you
- "primary_emotion": ONE item from this list (string only):
  {PRIMARY_EMOTIONS}
- "tones": a list of up to 3 items from this list:
  {TONES}

Rules:
- Only choose labels that clearly fit.
- If no strong emotion stands out, use "neutral".
- "challenge" is a tone, never a primary emotion.
- "tones" can be empty if nothing fits clearly.
- Do NOT invent new labels.

Return a single JSON array, and NOTHING else.
Each element of the array corresponds to one input verse, in the same order.
Do NOT wrap it in backticks or code fences.
Do NOT add any explanation or commentary.
"""

    verses_part = []
    for v in batch:
        # keep it minimal; the model only needs id, reference, text
        verses_part.append({
            "id": v["id"],
            "reference": v.get("reference"),
            "text": v["text"],
        })

    prompt = instructions + "\n\nHere are the verses to tag:\n" + json.dumps(verses_part, ensure_ascii=False, indent=2)
    return prompt


def extract_json(text: str):
    """
    Try to parse JSON from a model response that may contain
    code fences or extra text.
    """
    text = text.strip()

    # First, try direct
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Try to pull out a ```json ... ``` or ``` ... ``` block
    fence_match = re.search(r"```(?:json)?\s*(.*?)\s*```", text, re.DOTALL)
    if fence_match:
        inner = fence_match.group(1).strip()
        try:
            return json.loads(inner)
        except json.JSONDecodeError:
            pass

    # Last resort: look for the first { or [ and try from there
    for ch in ["[", "{"]:
        idx = text.find(ch)
        if idx != -1:
            candidate = text[idx:].strip()
            try:
                return json.loads(candidate)
            except json.JSONDecodeError:
                pass

    # If we get here, we really couldn't parse it
    raise json.JSONDecodeError("Could not extract JSON from model response", text, 0)


def tag_single(verse: Dict[str, Any], translation: str, model: str) -> Dict[str, Any]:
    """
    Fallback: tag a single verse if batch parsing fails.
    """
    source = "the Pickthall translation of the Quran" if translation.lower() == "pickthall" else f"the {translation} Bible translation"
    single_prompt = f"""
You are tagging ONE verse from {source} with emotional and communicative labels.

Return a single JSON object with:
- "id": exactly the id I give you
- "primary_emotion": ONE item from this list (string only):
  {PRIMARY_EMOTIONS}
- "tones": a list of up to 3 items from this list:
  {TONES}

Rules:
- Only choose labels that clearly fit.
- If no strong emotion stands out, use "neutral".
- "challenge" is a tone, never a primary emotion.
- "tones" can be empty if nothing fits clearly.
- Do NOT invent new labels.

Return ONLY the JSON object, and NOTHING else.
Do NOT wrap it in backticks or code fences.
Do NOT add any explanation or commentary.

Here is the verse:
{json.dumps({
    "id": verse["id"],
    "reference": verse.get("reference"),
    "text": verse["text"],
}, ensure_ascii=False, indent=2)}
"""

    response = client.responses.create(
        model=model,
        input=[{"role": "user", "content": single_prompt}]
    )

    output_text = response.output[0].content[0].text

    try:
        obj = extract_json(output_text)
    except json.JSONDecodeError as e:
        print("JSON parse error in single verse fallback, raw output was:")
        print(output_text)
        raise e

    obj = _discard_unknown_tones([obj])[0]
    if not _valid_tagged_list([verse], [obj]):
        raise ValueError(f"Invalid tag returned for verse {verse['id']}: {obj}")

    return obj


def _discard_unknown_tones(tagged_list: Any):
    """Remove unrecognised tones so they do not force an API retry."""
    if not isinstance(tagged_list, list):
        return tagged_list

    for tags in tagged_list:
        if isinstance(tags, dict) and isinstance(tags.get("tones"), list):
            tags["tones"] = [tone for tone in tags["tones"] if tone in TONES][:3]

    return tagged_list


def _tagged_list_error(batch: List[Dict[str, Any]], tagged_list: Any):
    if not isinstance(tagged_list, list) or len(tagged_list) != len(batch):
        return f"expected {len(batch)} items, got {len(tagged_list) if isinstance(tagged_list, list) else 'invalid JSON'}"

    for index, (verse, tags) in enumerate(zip(batch, tagged_list), start=1):
        if not isinstance(tags, dict) or tags.get("id") != verse.get("id"):
            return f"item {index} has an invalid id"
        if tags.get("primary_emotion") not in PRIMARY_EMOTIONS:
            return f"item {index} has unsupported primary emotion {tags.get('primary_emotion')!r}"
        tones = tags.get("tones")
        if not isinstance(tones, list) or len(tones) > 3:
            return f"item {index} has an invalid tones list"
        if any(tone not in TONES for tone in tones):
            return f"item {index} has an unsupported tone"

    return None


def _valid_tagged_list(batch: List[Dict[str, Any]], tagged_list: Any) -> bool:
    return _tagged_list_error(batch, tagged_list) is None


def tag_batch(batch: List[Dict[str, Any]], translation: str, model: str) -> List[Dict[str, Any]]:
    """
    Call the OpenAI API for one batch of verses and return the tagged info.
    If the output length doesn't match the batch length, we automatically
    fall back to splitting the batch or tagging individually.
    """
    # Base case: small batch, try direct
    prompt = build_user_prompt(batch, translation)
    response = client.responses.create(
        model=model,
        input=[{"role": "user", "content": prompt}]
    )
    output_text = response.output[0].content[0].text

    try:
        tagged_list = extract_json(output_text)
    except json.JSONDecodeError:
        print("JSON parse error in batch; will fall back to smaller units.")
        tagged_list = None

    tagged_list = _discard_unknown_tones(tagged_list)
    if _valid_tagged_list(batch, tagged_list):
        return tagged_list

    # If mismatch, handle gracefully
    if isinstance(tagged_list, list):
        tagged_count = len(tagged_list)
    elif tagged_list is None:
        tagged_count = "parse error"
    else:
        tagged_count = "invalid JSON shape"
    validation_error = _tagged_list_error(batch, tagged_list)
    print(
        f"Warning: expected {len(batch)} tags, got {tagged_count} "
        f"({validation_error}); falling back to smaller batches."
    )

    # If batch has more than 1 verse, split it into halves and recurse
    if len(batch) > 1:
        mid = len(batch) // 2
        left = tag_batch(batch[:mid], translation, model)
        right = tag_batch(batch[mid:], translation, model)
        return left + right

    # If we’re down to a single verse, use single-verse fallback
    verse = batch[0]
    single_tag = tag_single(verse, translation, model)
    return [single_tag]

# ------------- MAIN PIPELINE -------------

def parse_args():
    parser = argparse.ArgumentParser(description="Tag translation verses with emotional and communicative labels")
    parser.add_argument("--input", default=INPUT_FILE, help=f"JSON array or Chleb text input (default: {INPUT_FILE})")
    parser.add_argument("--output", default=OUTPUT_FILE, help=f"JSONL output path (default: {OUTPUT_FILE})")
    parser.add_argument("--translation", default="bible", help="Translation identifier, for example pickthall")
    parser.add_argument("--batch-size", type=int, default=BATCH_SIZE, help=f"Verses per API request (default: {BATCH_SIZE})")
    parser.add_argument("--model", default=MODEL, help=f"OpenAI model (default: {MODEL})")
    args = parser.parse_args()
    if args.batch_size < 1:
        parser.error("--batch-size must be positive")
    return args


def main():
    args = parse_args()
    verses = load_verses(args.input, args.translation)
    print(f"Loaded {len(verses)} verses")

    with open(args.output, "w", encoding="utf-8") as out_f:
        for i, batch in enumerate(chunks(verses, args.batch_size), start=1):
            print(f"Processing batch {i} (size {len(batch)})...")

            tagged = tag_batch(batch, args.translation, args.model)

            # Merge tags back into the verse records and write as JSONL
            for verse, tags in zip(batch, tagged):
                verse_out = dict(verse)  # copy
                verse_out["primary_emotion"] = tags.get("primary_emotion")
                verse_out["tones"] = tags.get("tones", [])

                out_f.write(json.dumps(verse_out, ensure_ascii=False) + "\n")

    print(f"Done. Tagged verses written to {args.output}")


if __name__ == "__main__":
    main()
