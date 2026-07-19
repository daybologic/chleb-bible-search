import argparse
import json
import re
from typing import List, Dict, Any
from openai import OpenAI

# ------------- CONFIG -------------

INPUT_FILE = "bible_verses.json"
OUTPUT_FILE = "bible_verses_tagged.jsonl"  # one JSON verse per line
BATCH_SIZE = 25
MODEL = "gpt-4.1-mini"  # good quality & cheap; change if you like

# Define the labels you want
PRIMARY_EMOTIONS = [
    "joy", "hope", "peace", "fear", "grief", "anger",
    "confusion", "guilt", "shame", "neutral"
]

TONES = [
    "comfort", "encouragement", "lament", "rebuke", "warning",
    "praise", "thanksgiving", "confession", "trust", "perseverance", "instruction"
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

    if not _valid_tagged_list([verse], [obj]):
        raise ValueError(f"Invalid tag returned for verse {verse['id']}: {obj}")

    return obj


def _valid_tagged_list(batch: List[Dict[str, Any]], tagged_list: Any) -> bool:
    if not isinstance(tagged_list, list) or len(tagged_list) != len(batch):
        return False

    for verse, tags in zip(batch, tagged_list):
        if not isinstance(tags, dict) or tags.get("id") != verse.get("id"):
            return False
        if tags.get("primary_emotion") not in PRIMARY_EMOTIONS:
            return False
        tones = tags.get("tones")
        if not isinstance(tones, list) or len(tones) > 3:
            return False
        if any(tone not in TONES for tone in tones):
            return False

    return True


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

    if _valid_tagged_list(batch, tagged_list):
        return tagged_list

    # If mismatch, handle gracefully
    if isinstance(tagged_list, list):
        tagged_count = len(tagged_list)
    elif tagged_list is None:
        tagged_count = "parse error"
    else:
        tagged_count = "invalid JSON shape"
    print(
        f"Warning: expected {len(batch)} tags, got {tagged_count}; "
        "falling back to smaller batches."
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
