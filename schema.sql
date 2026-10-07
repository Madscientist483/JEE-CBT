CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'cohort_level') THEN
        CREATE TYPE cohort_level AS ENUM ('11th', '12th', 'dropper');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subject_type') THEN
        CREATE TYPE subject_type AS ENUM ('Physics', 'Chemistry', 'Mathematics');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'difficulty_level') THEN
        CREATE TYPE difficulty_level AS ENUM ('Easy', 'Medium', 'Hard');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(120) NOT NULL,
    cohort cohort_level NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_level cohort_level NOT NULL,
    subject subject_type NOT NULL,
    topic_name VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(class_level, subject, topic_name)
);

CREATE TABLE IF NOT EXISTS questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    option_a TEXT,
    option_b TEXT,
    option_c TEXT,
    option_d TEXT,
    correct_option VARCHAR(20) NOT NULL,
    question_type VARCHAR(30) NOT NULL DEFAULT 'single_choice',
    difficulty difficulty_level NOT NULL,
    explanation TEXT,
    rag_confidence DOUBLE PRECISION DEFAULT 0,
    rag_errors JSONB DEFAULT '[]'::jsonb,
    is_rag_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS test_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    score INTEGER NOT NULL,
    time_taken INTEGER NOT NULL,
    detailed_analysis_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rag_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source VARCHAR(500) NOT NULL,
    title VARCHAR(500),
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_topics_class ON topics(class_level);
CREATE INDEX IF NOT EXISTS idx_topics_subject ON topics(subject);
CREATE INDEX IF NOT EXISTS idx_questions_topic ON questions(topic_id);
CREATE INDEX IF NOT EXISTS idx_questions_verified ON questions(is_rag_verified);

INSERT INTO topics (class_level, subject, topic_name) VALUES
('11th','Physics','Units and Measurements'),('11th','Physics','Kinematics'),
('11th','Physics','Laws of Motion'),('11th','Physics','Work, Energy and Power'),
('11th','Physics','Rotational Motion'),('11th','Physics','Gravitation'),
('11th','Physics','Properties of Solids and Liquids'),('11th','Physics','Thermodynamics'),
('11th','Physics','Kinetic Theory'),('11th','Physics','Oscillations'),('11th','Physics','Waves'),
('11th','Chemistry','Some Basic Concepts of Chemistry'),('11th','Chemistry','Atomic Structure'),
('11th','Chemistry','Chemical Bonding'),('11th','Chemistry','Thermodynamics'),
('11th','Chemistry','Equilibrium'),('11th','Chemistry','Redox Reactions'),
('11th','Chemistry','Organic Chemistry Basics'),('11th','Chemistry','Hydrocarbons'),
('11th','Mathematics','Sets and Relations'),('11th','Mathematics','Quadratic Equations'),
('11th','Mathematics','Sequences and Series'),('11th','Mathematics','Trigonometry'),
('11th','Mathematics','Straight Lines'),('11th','Mathematics','Conic Sections'),
('11th','Mathematics','Permutations and Combinations'),('11th','Mathematics','Binomial Theorem'),
('11th','Mathematics','Limits and Derivatives'),
('12th','Physics','Electrostatics'),('12th','Physics','Current Electricity'),
('12th','Physics','Magnetic Effects of Current'),('12th','Physics','Electromagnetic Induction'),
('12th','Physics','Alternating Current'),('12th','Physics','Electromagnetic Waves'),
('12th','Physics','Ray Optics'),('12th','Physics','Wave Optics'),
('12th','Physics','Dual Nature of Matter'),('12th','Physics','Atoms and Nuclei'),
('12th','Physics','Semiconductor Electronics'),('12th','Chemistry','Solutions'),
('12th','Chemistry','Electrochemistry'),('12th','Chemistry','Chemical Kinetics'),
('12th','Chemistry','Surface Chemistry'),('12th','Chemistry','Coordination Compounds'),
('12th','Chemistry','Haloalkanes and Haloarenes'),('12th','Chemistry','Alcohols Phenols and Ethers'),
('12th','Chemistry','Aldehydes Ketones and Carboxylic Acids'),('12th','Chemistry','Amines'),
('12th','Chemistry','Biomolecules'),('12th','Mathematics','Relations and Functions'),
('12th','Mathematics','Matrices and Determinants'),('12th','Mathematics','Continuity and Differentiability'),
('12th','Mathematics','Applications of Derivatives'),('12th','Mathematics','Integrals'),
('12th','Mathematics','Applications of Integrals'),('12th','Mathematics','Differential Equations'),
('12th','Mathematics','Vector Algebra'),('12th','Mathematics','Three Dimensional Geometry'),
('12th','Mathematics','Probability')
ON CONFLICT (class_level, subject, topic_name) DO NOTHING;
