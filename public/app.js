const socket = io();

let myId = null;
let isHost = false;
let roomCode = null;
let timerInterval = null;

// ---------- Ekran yönetimi ----------
function showScreen(id) {
  document.querySelectorAll(".screen").forEach((s) => s.classList.remove("active"));
  document.getElementById(id).classList.add("active");
}

// ---------- Giriş ekranı ----------
document.getElementById("btn-create").onclick = () => {
  const name = document.getElementById("input-name").value.trim() || "Host";
  socket.emit("create_room", { name });
};

document.getElementById("btn-join").onclick = () => {
  const name = document.getElementById("input-name").value.trim() || "Oyuncu";
  const code = document.getElementById("input-code").value.trim().toUpperCase();
  if (!code) {
    document.getElementById("entry-error").textContent = "Lütfen oda kodunu girin.";
    return;
  }
  socket.emit("join_room", { roomCode: code, name });
};

socket.on("error_message", ({ message }) => {
  document.getElementById("entry-error").textContent = message;
});

socket.on("joined", (data) => {
  myId = data.yourId;
  isHost = data.isHost;
  roomCode = data.roomCode;
  document.getElementById("room-code-display").textContent = roomCode;
  showScreen("screen-lobby");
});

// ---------- Lobi ----------
document.getElementById("btn-start").onclick = () => socket.emit("start_game");

socket.on("room_update", (data) => {
  if (data.state === "LOBBY") {
    showScreen("screen-lobby");
    const list = document.getElementById("player-list");
    list.innerHTML = "";
    data.players.forEach((p) => {
      const li = document.createElement("li");
      li.innerHTML = `<span>${escapeHtml(p.name)}${p.id === data.hostId ? " 👑" : ""}</span>`;
      list.appendChild(li);
    });
    const startBtn = document.getElementById("btn-start");
    const waitMsg = document.getElementById("lobby-wait");
    if (myId === data.hostId) {
      startBtn.style.display = "block";
      waitMsg.style.display = "none";
    } else {
      startBtn.style.display = "none";
      waitMsg.style.display = "block";
    }
  }
});

// ---------- Soru ekranı ----------
let currentEndsAt = null;

socket.on("question", (data) => {
  showScreen("screen-question");
  document.getElementById("q-progress").textContent = `Soru ${data.index + 1} / ${data.total}`;
  document.getElementById("q-prompt").textContent = data.question.prompt;
  document.getElementById("q-status").textContent = "";

  const grid = document.getElementById("q-options");
  grid.innerHTML = "";
  data.question.options.forEach((opt, idx) => {
    const btn = document.createElement("button");
    btn.className = "option-btn";
    btn.textContent = opt;
    btn.onclick = () => selectAnswer(idx, btn);
    grid.appendChild(btn);
  });

  currentEndsAt = data.endsAt;
  clearInterval(timerInterval);
  const totalMs = data.timerSeconds * 1000;
  timerInterval = setInterval(() => {
    const remaining = Math.max(0, currentEndsAt - Date.now());
    const pct = (remaining / totalMs) * 100;
    document.getElementById("timer-fill").style.width = pct + "%";
    if (remaining <= 0) clearInterval(timerInterval);
  }, 100);
});

function selectAnswer(idx, btnEl) {
  document.querySelectorAll(".option-btn").forEach((b) => (b.disabled = true));
  btnEl.classList.add("selected");
  document.getElementById("q-status").textContent = "Cevap gönderildi, sonuç bekleniyor...";
  socket.emit("submit_answer", { optionIndex: idx });
}

// ---------- Sonuç ekranı ----------
document.getElementById("btn-next").onclick = () => socket.emit("next_question");

socket.on("question_resolved", (data) => {
  showScreen("screen-results");
  clearInterval(timerInterval);
  document.getElementById("correct-answer").textContent = data.correctText;

  const list = document.getElementById("results-list");
  list.innerHTML = "";
  const sorted = [...data.results].sort((a, b) => b.totalScore - a.totalScore);
  sorted.forEach((r) => {
    const li = document.createElement("li");
    const sign = r.correct ? `+${r.delta}` : "±0";
    li.innerHTML = `<span>${escapeHtml(r.name)} ${r.correct ? "✅" : "❌"}</span><span>${r.totalScore} (${sign})</span>`;
    list.appendChild(li);
  });

  const nextBtn = document.getElementById("btn-next");
  const waitMsg = document.getElementById("results-wait");
  if (isHost) {
    nextBtn.style.display = "block";
    waitMsg.style.display = "none";
  } else {
    nextBtn.style.display = "none";
    waitMsg.style.display = "block";
  }
});

// ---------- Oyun sonu ----------
socket.on("game_over", (data) => {
  showScreen("screen-gameover");
  const list = document.getElementById("final-list");
  list.innerHTML = "";
  data.players.forEach((p, i) => {
    const li = document.createElement("li");
    const medal = i === 0 ? "🥇" : i === 1 ? "🥈" : i === 2 ? "🥉" : `${i + 1}.`;
    li.innerHTML = `<span>${medal} ${escapeHtml(p.name)}</span><span>${p.score}</span>`;
    list.appendChild(li);
  });
});

document.getElementById("btn-restart").onclick = () => location.reload();

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}
