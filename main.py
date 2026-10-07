import uuid
from contextlib import asynccontextmanager
from typing import Literal
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from .ai_extractor import generate_questions
from .config import settings
from .models import Base, Cohort, Difficulty, Question, TestResult, Topic
from .rag_checker import checker

engine = create_engine(settings.database_url, pool_pre_ping=True, pool_size=10, max_overflow=20)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield

app = FastAPI(title="JEE Mock Test & AI Question Engine", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware,
    allow_origins=["*"] if settings.cors_origins == "*" else settings.cors_origins.split(","),
    allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class GenerateTestRequest(BaseModel):
    class_level: Literal["11th", "12th", "dropper"]
    topic_ids: list[uuid.UUID]
    difficulty: Literal["Easy", "Medium", "Hard"] = "Medium"
    question_count: int = Field(default=10, ge=1, le=50)

class SubmitAnswer(BaseModel):
    question_id: uuid.UUID
    selected_option: str | None = None

class SubmitTestRequest(BaseModel):
    user_id: uuid.UUID | None = None
    answers: list[SubmitAnswer]
    time_taken: int = Field(ge=0)

@app.get("/health")
def health():
    return {"status": "ok", "service": settings.app_name}

@app.get("/api/topics")
def get_topics(class_level: Literal["11th", "12th", "dropper"], db: Session = Depends(get_db)):
    levels = [Cohort.ELEVEN, Cohort.TWELVE] if class_level == "dropper" else [Cohort(class_level)]
    topics = db.scalars(select(Topic).where(Topic.class_level.in_(levels)).order_by(Topic.subject, Topic.topic_name)).all()
    return [{"id": str(t.id), "class_level": t.class_level.value, "subject": t.subject.value, "topic_name": t.topic_name} for t in topics]

@app.post("/api/generate-test")
async def generate_test(request: GenerateTestRequest, db: Session = Depends(get_db)):
    topics = db.scalars(select(Topic).where(Topic.id.in_(request.topic_ids))).all()
    if not topics:
        raise HTTPException(status_code=400, detail="No valid topics supplied")
    generated = []
    base_count, remainder = divmod(request.question_count, len(topics))
    for index, topic in enumerate(topics):
        count = base_count + (1 if index < remainder else 0)
        if count == 0:
            continue
        questions = await generate_questions(topic.topic_name, topic.subject.value, request.difficulty, count)
        for raw in questions:
            verification = await checker.verify(raw)
            q = Question(
                topic_id=topic.id,
                question_text=raw["question_text"],
                option_a=raw.get("option_a"), option_b=raw.get("option_b"),
                option_c=raw.get("option_c"), option_d=raw.get("option_d"),
                correct_option=raw["correct_option"],
                question_type=raw.get("question_type", "single_choice"),
                difficulty=Difficulty(request.difficulty),
                explanation=verification.get("explanation") or raw.get("explanation"),
                rag_confidence=verification.get("confidence", 0),
                rag_errors=verification.get("errors", []),
                is_rag_verified=verification.get("verified", False),
            )
            db.add(q)
            db.flush()
            generated.append({
                "id": str(q.id), "topic_id": str(topic.id), "topic": topic.topic_name,
                "subject": topic.subject.value, "question_text": q.question_text,
                "question_type": q.question_type,
                "options": {"A": q.option_a, "B": q.option_b, "C": q.option_c, "D": q.option_d},
                "difficulty": q.difficulty.value,
                "rag_verified": q.is_rag_verified,
                "rag_confidence": q.rag_confidence,
            })
    db.commit()
    return {"count": len(generated), "questions": generated}

@app.post("/api/submit-test")
def submit_test(request: SubmitTestRequest, db: Session = Depends(get_db)):
    ids = [a.question_id for a in request.answers]
    questions = db.scalars(select(Question).where(Question.id.in_(ids))).all()
    qmap = {q.id: q for q in questions}
    score = correct = wrong = unanswered = 0
    details = []
    for answer in request.answers:
        q = qmap.get(answer.question_id)
        if not q:
            continue
        selected = (answer.selected_option or "").strip().upper()
        expected = q.correct_option.upper()
        if not selected:
            unanswered += 1
            status = "unanswered"
        elif q.question_type == "multiple_choice":
            if {x.strip() for x in selected.split(",")} == {x.strip() for x in expected.split(",")}:
                score += 4; correct += 1; status = "correct"
            else:
                score -= 1; wrong += 1; status = "wrong"
        elif selected == expected:
            score += 4; correct += 1; status = "correct"
        else:
            score -= 1; wrong += 1; status = "wrong"
        details.append({"question_id": str(q.id), "selected": selected or None, "status": status})
    result = TestResult(
        user_id=request.user_id, score=score, time_taken=request.time_taken,
        detailed_analysis_json={"correct": correct, "wrong": wrong, "unanswered": unanswered, "answers": details},
    )
    db.add(result)
    db.commit()
    return {"result_id": str(result.id), "score": score, "correct": correct, "wrong": wrong, "unanswered": unanswered, "time_taken": request.time_taken, "analysis": details}

@app.get("/api/admin/questions")
def admin_questions(db: Session = Depends(get_db)):
    questions = db.scalars(select(Question).order_by(Question.created_at.desc()).limit(100)).all()
    return [{"id": str(q.id), "question": q.question_text, "difficulty": q.difficulty.value,
             "verified": q.is_rag_verified, "confidence": q.rag_confidence,
             "errors": q.rag_errors, "explanation": q.explanation} for q in questions]
