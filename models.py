import uuid
from datetime import datetime
from enum import Enum
from sqlalchemy import Boolean, DateTime, Enum as SAEnum, Float, ForeignKey, Integer, Text, String
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

class Base(DeclarativeBase): pass
class Cohort(str, Enum):
    ELEVEN = "11th"; TWELVE = "12th"; DROPPER = "dropper"
class Subject(str, Enum):
    PHYSICS = "Physics"; CHEMISTRY = "Chemistry"; MATHEMATICS = "Mathematics"
class Difficulty(str, Enum):
    EASY = "Easy"; MEDIUM = "Medium"; HARD = "Hard"

class User(Base):
    __tablename__ = "users"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(120))
    cohort: Mapped[Cohort] = mapped_column(SAEnum(Cohort, name="cohort_level"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    results = relationship("TestResult", back_populates="user")

class Topic(Base):
    __tablename__ = "topics"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    class_level: Mapped[Cohort] = mapped_column(SAEnum(Cohort, name="cohort_level"), nullable=False)
    subject: Mapped[Subject] = mapped_column(SAEnum(Subject, name="subject_type"), nullable=False)
    topic_name: Mapped[str] = mapped_column(String(200), nullable=False)
    questions = relationship("Question", back_populates="topic")

class Question(Base):
    __tablename__ = "questions"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    topic_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("topics.id", ondelete="CASCADE"), nullable=False)
    question_text: Mapped[str] = mapped_column(Text)
    option_a: Mapped[str | None] = mapped_column(Text)
    option_b: Mapped[str | None] = mapped_column(Text)
    option_c: Mapped[str | None] = mapped_column(Text)
    option_d: Mapped[str | None] = mapped_column(Text)
    correct_option: Mapped[str] = mapped_column(String(20))
    question_type: Mapped[str] = mapped_column(String(30), default="single_choice")
    difficulty: Mapped[Difficulty] = mapped_column(SAEnum(Difficulty, name="difficulty_level"))
    explanation: Mapped[str | None] = mapped_column(Text)
    rag_confidence: Mapped[float] = mapped_column(Float, default=0)
    rag_errors: Mapped[list] = mapped_column(JSONB, default=list)
    is_rag_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    topic = relationship("Topic", back_populates="questions")

class TestResult(Base):
    __tablename__ = "test_results"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"))
    score: Mapped[int] = mapped_column(Integer)
    time_taken: Mapped[int] = mapped_column(Integer)
    detailed_analysis_json: Mapped[dict] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    user = relationship("User", back_populates="results")
