import json, re
from typing import Any
import httpx
from .config import settings

SYSTEM_PROMPT = """You are an expert JEE Main and JEE Advanced question setter.
Generate mathematically and scientifically rigorous questions.
Allowed subjects: Physics, Chemistry, Mathematics.
Allowed question types: single_choice, multiple_choice, numerical.
Difficulty: Easy, Medium, Hard.
Rules:
1. Questions must be self-contained.
2. Single-choice questions must have exactly one correct option.
3. Multiple-choice questions may have multiple correct options.
4. Numerical questions must have a unique numerical answer.
5. Distractors must be plausible but demonstrably incorrect.
6. Include a rigorous solution.
7. Respect the requested topic.
Return ONLY valid JSON."""

def _extract_json(text: str) -> dict[str, Any]:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?", "", text)
        text = re.sub(r"```$", "", text).strip()
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1:
        raise ValueError("LLM did not return JSON")
    return json.loads(text[start:end + 1])

async def _ollama(prompt: str) -> str:
    url = f"{settings.ollama_base_url.rstrip('/')}/api/chat"
    payload = {
        "model": settings.ollama_model,
        "stream": False,
        "format": "json",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
        "options": {"temperature": 0.15},
    }
    async with httpx.AsyncClient(timeout=180) as client:
        response = await client.post(url, json=payload)
        response.raise_for_status()
        return response.json()["message"]["content"]

async def generate_questions(topic: str, subject: str, difficulty: str, count: int = 10) -> list[dict[str, Any]]:
    prompt = f"""Generate exactly {count} JEE questions.
Subject: {subject}
Topic: {topic}
Difficulty: {difficulty}

Return:
{{"questions":[{{"question_text":"...","question_type":"single_choice",
"option_a":"...","option_b":"...","option_c":"...","option_d":"...",
"correct_option":"A","explanation":"..."}}]}}

For numerical questions, options may be null and correct_option is the numerical answer.
For multiple-choice, correct_option looks like "A,C".
Do not add Markdown."""
    parsed = _extract_json(await _ollama(prompt))
    questions = parsed.get("questions", [])
    if len(questions) != count:
        raise ValueError(f"Expected {count} questions, received {len(questions)}")
    return questions
