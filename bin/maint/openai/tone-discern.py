import os
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

def load_verses(path: str) -> List[Dict[str, Any]]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def chunks(lst: List[Any], n: int):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


def build_user_prompt(batch: List[Dict[str, Any]]) -> str:
    """
    Build a prompt that asks the model to return JSON for a list of verses.
    We give the model our allowed labels so it stays constrained.
    """
    instructions = f"""
You are tagging Bible verses with emotional and pastoral labels.

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


def tag_single(verse: Dict[str, Any]) -> Dict[str, Any]:
    """
    Fallback: tag a single verse if batch parsing fails.
    """
    single_prompt = f"""
You are tagging ONE Bible verse with emotional and pastoral labels.

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
        model=MODEL,
        input=[{"role": "user", "content": single_prompt}]
    )

    output_text = response.output[0].content[0].text

    try:
        obj = extract_json(output_text)
    except json.JSONDecodeError as e:
        print("JSON parse error in single verse fallback, raw output was:")
        print(output_text)
        raise e

    return obj


def tag_batch(batch: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Call the OpenAI API for one batch of verses and return the tagged info.
    If the output length doesn't match the batch length, we automatically
    fall back to splitting the batch or tagging individually.
    """
    # Base case: small batch, try direct
    prompt = build_user_prompt(batch)
    response = client.responses.create(
        model=MODEL,
        input=[{"role": "user", "content": prompt}]
    )
    output_text = response.output[0].content[0].text

    try:
        tagged_list = extract_json(output_text)
    except json.JSONDecodeError:
        print("JSON parse error in batch; will fall back to smaller units.")
        tagged_list = None

    if tagged_list is not None and len(tagged_list) == len(batch):
        return tagged_list

    # If mismatch, handle gracefully
    print(
        f"Warning: expected {len(batch)} tags, got "
        f"{len(tagged_list) if tagged_list is not None else 'parse error'}; "
        "falling back to smaller batches."
    )

    # If batch has more than 1 verse, split it into halves and recurse
    if len(batch) > 1:
        mid = len(batch) // 2
        left = tag_batch(batch[:mid])
        right = tag_batch(batch[mid:])
        return left + right

    # If we’re down to a single verse, use single-verse fallback
    verse = batch[0]
    single_tag = tag_single(verse)
    return [single_tag]

# ------------- MAIN PIPELINE -------------

def main():
    verses = load_verses(INPUT_FILE)
    print(f"Loaded {len(verses)} verses")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as out_f:
        for i, batch in enumerate(chunks(verses, BATCH_SIZE), start=1):
            print(f"Processing batch {i} (size {len(batch)})...")

            tagged = tag_batch(batch)

            # Merge tags back into the verse records and write as JSONL
            for verse, tags in zip(batch, tagged):
                verse_out = dict(verse)  # copy
                verse_out["primary_emotion"] = tags.get("primary_emotion")
                verse_out["tones"] = tags.get("tones", [])

                out_f.write(json.dumps(verse_out, ensure_ascii=False) + "\n")

    print(f"Done. Tagged verses written to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
