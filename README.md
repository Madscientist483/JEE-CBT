# JEE Mock Test AI Platform

## Included
- PostgreSQL schema and seeded JEE topics
- FastAPI backend
- SQLAlchemy ORM
- Ollama question generation
- LangChain RAG verification layer
- Flutter student application
- Tailwind CDN admin console
- `.env.example` and Python dependency file

## Backend

Create a PostgreSQL database named `jee_mock`.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

Copy `.env.example` to `.env` and edit it.

Ollama must be running with the configured model.

## Flutter

```bash
cd frontend_flutter
flutter pub get
flutter run
```

Android emulator uses `10.0.2.2` for the host computer. For a physical device, change `apiBaseUrl` in the Flutter screens to your computer's LAN IP.

## Admin

```bash
cd web_admin
python -m http.server 5500
```

Open `http://localhost:5500`.

## RAG references

Put reference material under `rag_data/`. The supplied verifier contains the retrieval interface; production ingestion should connect this directory/database to Chroma or PGVector and add deterministic mathematical validation.
