const API_BASE = "http://localhost:8000";
const cohortSelect = document.getElementById("cohort");
const topicSelect = document.getElementById("topic");
const difficultySelect = document.getElementById("difficulty");
const countInput = document.getElementById("count");
const generateButton = document.getElementById("generate");
const refreshButton = document.getElementById("refresh");
const statusElement = document.getElementById("status");
const tableBody = document.getElementById("questionTable");
const statsElement = document.getElementById("stats");

async function api(path, options = {}) {
  const response = await fetch(`${API_BASE}${path}`, {headers: {"Content-Type": "application/json", ...(options.headers || {})}, ...options});
  if (!response.ok) throw new Error(await response.text() || `HTTP ${response.status}`);
  return response.json();
}
async function loadTopics() {
  topicSelect.innerHTML = "<option>Loading...</option>";
  try {
    const topics = await api(`/api/topics?class_level=${encodeURIComponent(cohortSelect.value)}`);
    topicSelect.innerHTML = "";
    topics.forEach(t => { const o = document.createElement("option"); o.value = t.id; o.textContent = `${t.subject} — ${t.topic_name}`; topicSelect.appendChild(o); });
  } catch (e) { topicSelect.innerHTML = "<option>Failed to load topics</option>"; setStatus(e.message, true); }
}
function setStatus(message, error = false) { statusElement.textContent = message; statusElement.className = error ? "text-sm text-red-600 mt-4" : "text-sm text-slate-500 mt-4"; }
async function generateTest() {
  if (!topicSelect.value) return setStatus("Select a topic first.", true);
  generateButton.disabled = true; generateButton.textContent = "Generating...";
  setStatus("Generating questions and running RAG verification...");
  try {
    const result = await api("/api/generate-test", {method: "POST", body: JSON.stringify({class_level: cohortSelect.value, topic_ids: [topicSelect.value], difficulty: difficultySelect.value, question_count: Number(countInput.value)})});
    setStatus(`Generated ${result.count} questions successfully.`); await loadQuestions();
  } catch (e) { setStatus(`Generation failed: ${e.message}`, true); }
  finally { generateButton.disabled = false; generateButton.textContent = "Generate & Verify"; }
}
function renderStats(qs) {
  const total = qs.length, verified = qs.filter(q => q.verified).length;
  const avg = total ? qs.reduce((s,q) => s + Number(q.confidence || 0), 0) / total : 0;
  statsElement.innerHTML = `<div class="bg-slate-50 rounded-lg p-4"><p class="text-slate-500 text-sm">Questions</p><p class="text-2xl font-bold mt-1">${total}</p></div><div class="bg-slate-50 rounded-lg p-4"><p class="text-slate-500 text-sm">Verified</p><p class="text-2xl font-bold mt-1">${verified}</p></div><div class="bg-slate-50 rounded-lg p-4"><p class="text-slate-500 text-sm">Avg. Confidence</p><p class="text-2xl font-bold mt-1">${(avg*100).toFixed(1)}%</p></div>`;
}
function escapeHtml(v) { return String(v ?? "").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#039;"); }
function renderQuestions(qs) {
  tableBody.innerHTML = "";
  qs.forEach(q => {
    const tr = document.createElement("tr"); tr.className = "border-t hover:bg-slate-50";
    tr.innerHTML = `<td class="p-4 max-w-xl"><div class="font-medium">${escapeHtml(q.question)}</div>${q.errors?.length ? `<div class="text-red-600 text-xs mt-2">${escapeHtml(q.errors.join(", "))}</div>` : ""}</td><td class="p-4">${escapeHtml(q.difficulty)}</td><td class="p-4">${(Number(q.confidence||0)*100).toFixed(1)}%</td><td class="p-4">${q.verified ? '<span class="px-2 py-1 rounded-full bg-green-100 text-green-700">Verified</span>' : '<span class="px-2 py-1 rounded-full bg-red-100 text-red-700">Rejected</span>'}</td>`;
    tableBody.appendChild(tr);
  });
  renderStats(qs);
}
async function loadQuestions() {
  try { renderQuestions(await api("/api/admin/questions")); }
  catch (e) { setStatus(`Could not load verification logs: ${e.message}`, true); }
}
cohortSelect.addEventListener("change", loadTopics);
generateButton.addEventListener("click", generateTest);
refreshButton.addEventListener("click", loadQuestions);
(async function init(){ await loadTopics(); await loadQuestions(); })();
