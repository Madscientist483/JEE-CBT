import json
from typing import Any
from langchain_core.documents import Document
from langchain_core.prompts import ChatPromptTemplate
from langchain_ollama import ChatOllama
from .config import settings

class RAGQuestionChecker:
    def __init__(self):
        self.llm = ChatOllama(base_url=settings.ollama_base_url, model=settings.ollama_model, temperature=0)
        self.documents: list[Document] = []

    def add_reference(self, content: str, source: str, title: str | None = None) -> None:
        self.documents.append(Document(page_content=content, metadata={"source": source, "title": title or source}))

    def _retrieve(self, question: str, k: int = 4) -> list[Document]:
        if not self.documents:
            return []
        terms = {w.lower() for w in question.split() if len(w) > 3}
        scored = []
        for document in self.documents:
            content = document.page_content.lower()
            score = sum(1 for term in terms if term in content)
            if score:
                scored.append((score, document))
        scored.sort(key=lambda item: item[0], reverse=True)
        return [document for _, document in scored[:k]]

    async def verify(self, question: dict[str, Any]) -> dict[str, Any]:
        docs = self._retrieve(question["question_text"])
        context = "\n\n".join(
            f"Source: {d.metadata.get('source')}\n{d.page_content}" for d in docs
        ) or "No matching reference document was found. Perform independent mathematical/conceptual verification."

        prompt = ChatPromptTemplate.from_messages([
            ("system", """You are a JEE question verification expert.
Verify mathematical correctness, conceptual correctness, the supplied answer,
option uniqueness, distractor ambiguity, numerical uniqueness, and topic alignment.
Return ONLY JSON:
{"verified":true,"confidence":0.0,"errors":[],"explanation":"...","correct_option":"A"}
confidence is 0..1."""),
            ("human", "REFERENCE MATERIAL:\n{context}\n\nQUESTION:\n{question}")
        ])
        rendered = prompt.format(context=context, question=json.dumps(question, ensure_ascii=False))
        response = await self.llm.ainvoke(rendered)
        content = response.content
        if isinstance(content, list):
            content = "".join(str(x) for x in content)
        start, end = content.find("{"), content.rfind("}")
        if start == -1 or end == -1:
            return {"verified": False, "confidence": 0, "errors": ["Verifier returned invalid JSON"], "explanation": "", "correct_option": question.get("correct_option")}
        try:
            result = json.loads(content[start:end + 1])
        except json.JSONDecodeError:
            return {"verified": False, "confidence": 0, "errors": ["Unable to parse verifier output"], "explanation": "", "correct_option": question.get("correct_option")}
        result["confidence"] = max(0, min(1, float(result.get("confidence", 0))))
        result["verified"] = bool(result.get("verified", False) and result["confidence"] >= 0.80)
        return result

checker = RAGQuestionChecker()
