// ============================================================
// Trivia Arena - Tek dosyalık, bedava hosting'e uygun sunucu
// Express (statik dosyalari servis eder) + Socket.io (gercek zamanli oyun)
// ============================================================

const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const path = require("path");
const crypto = require("crypto");

const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.static(path.join(__dirname, "public")));

const PORT = process.env.PORT || 3000;

// ------------------------------------------------------------
// Soru bankasi - istediginiz kadar soru ekleyebilirsiniz.
// correctIndex ASLA client'a gonderilmez (asagida sanitize edilir).
// ------------------------------------------------------------
const QUESTIONS = [
  {
    prompt: "Türkiye'nin başkenti neresidir?",
    options: ["İstanbul", "Ankara", "İzmir", "Bursa"],
    correctIndex: 1,
  },
  {
    prompt: "Güneş sisteminde Dünya'ya en yakın gezegen hangisidir?",
    options: ["Mars", "Venüs", "Jüpiter", "Merkür"],
    correctIndex: 1,
  },
  {
    prompt: "Bir futbol takımı sahada kaç oyuncuyla oynar?",
    options: ["9", "10", "11", "12"],
    correctIndex: 2,
  },
  {
    prompt: "'Baldwin Kartalı' hangi oyunun karakteridir? (örnek soru, değiştirin)",
    options: ["Minecraft", "Fortnite", "Roblox", "Among Us"],
    correctIndex: 1,
  },
];

const QUESTION_TIMER_SECONDS = 12;

// ------------------------------------------------------------
// Oda durumu (bellek icinde - sunucu yeniden baslarsa sifirlanir)
// ------------------------------------------------------------
/** rooms[roomCode] = {
 *   hostSocketId, players: Map(socketId -> {name, score, answered}),
 *   state: 'LOBBY' | 'QUESTION' | 'RESULTS' | 'GAME_OVER',
 *   questionIndex, questionStartedAt, questionEndsAt, timer
 * } */
const rooms = new Map();

function makeRoomCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code;
  do {
    code = Array.from({ length: 4 }, () => chars[crypto.randomInt(chars.length)]).join("");
  } while (rooms.has(code));
  return code;
}

function sanitizeQuestion(q) {
  return { prompt: q.prompt, options: q.options }; // correctIndex ASLA gonderilmez
}

function publicPlayers(room) {
  return [...room.players.entries()].map(([id, p]) => ({
    id,
    name: p.name,
    score: p.score,
  }));
}

function broadcastRoom(roomCode) {
  const room = rooms.get(roomCode);
  if (!room) return;
  io.to(roomCode).emit("room_update", {
    state: room.state,
    players: publicPlayers(room),
    questionIndex: room.questionIndex,
    totalQuestions: QUESTIONS.length,
    hostId: room.hostSocketId,
  });
}

function startQuestion(roomCode) {
  const room = rooms.get(roomCode);
  if (!room) return;

  if (room.questionIndex >= QUESTIONS.length) {
    room.state = "GAME_OVER";
    broadcastRoom(roomCode);
    io.to(roomCode).emit("game_over", { players: publicPlayers(room).sort((a, b) => b.score - a.score) });
    return;
  }

  room.state = "QUESTION";
  for (const p of room.players.values()) p.answered = false;

  const q = QUESTIONS[room.questionIndex];
  room.questionStartedAt = Date.now();
  room.questionEndsAt = room.questionStartedAt + QUESTION_TIMER_SECONDS * 1000;

  io.to(roomCode).emit("question", {
    question: sanitizeQuestion(q),
    index: room.questionIndex,
    total: QUESTIONS.length,
    endsAt: room.questionEndsAt,
    timerSeconds: QUESTION_TIMER_SECONDS,
  });
  broadcastRoom(roomCode);

  clearTimeout(room.timer);
  room.timer = setTimeout(() => resolveQuestion(roomCode), QUESTION_TIMER_SECONDS * 1000 + 300);
}

function resolveQuestion(roomCode) {
  const room = rooms.get(roomCode);
  if (!room || room.state !== "QUESTION") return;

  const q = QUESTIONS[room.questionIndex];
  const results = [];

  for (const [id, p] of room.players.entries()) {
    const sub = p.pendingAnswer;
    const isCorrect = sub && sub.optionIndex === q.correctIndex;
    let delta = 0;
    if (isCorrect) {
      const secondsRemaining = Math.max(0, (room.questionEndsAt - sub.receivedAt) / 1000);
      delta = 1000 + Math.floor(secondsRemaining) * 50;
    }
    p.score += delta;
    p.pendingAnswer = null;
    results.push({ id, name: p.name, correct: !!isCorrect, delta, totalScore: p.score });
  }

  room.state = "RESULTS";
  room.questionIndex += 1;

  io.to(roomCode).emit("question_resolved", {
    correctIndex: q.correctIndex,
    correctText: q.options[q.correctIndex],
    results,
  });
  broadcastRoom(roomCode);
}

// ------------------------------------------------------------
// Sahne <-> telefon aktarimi (public/index.html bunu kullanir)
// Telefonlar sahneye dogrudan WebRTC ile baglanmaya calisinca farkli
// aglardaki cihazlar (mobil veri, baska Wi-Fi) cogu zaman bulusamiyordu.
// Artik mesajlar bu sunucu uzerinden aktariliyor: sahne (host) mesajlari
// odadaki tum telefonlara, telefon mesajlari yalnizca sahneye gider.
// ------------------------------------------------------------
const RELAY_CODE = /^[A-Z]{4}$/;
const RELAY_GRACE_MS = 30000; // sahnenin kisa kopmalarinda odayi tut
/** stages[code] = { hostId, key, graceTimer } */
const stages = new Map();
const relayRoom = (code) => "relay:" + code;

function relayPadCount(code) {
  const members = io.sockets.adapter.rooms.get(relayRoom(code));
  if (!members) return 0;
  const st = stages.get(code);
  return members.size - (st && members.has(st.hostId) ? 1 : 0);
}

function relayNotifyHost(code) {
  const st = stages.get(code);
  if (st && st.hostId) io.to(st.hostId).emit("relay_peers", { n: relayPadCount(code) });
}

function relayCloseStage(code) {
  const st = stages.get(code);
  if (!st) return;
  clearTimeout(st.graceTimer);
  stages.delete(code);
  io.to(relayRoom(code)).emit("relay_host_left");
}

/** Soketin onceki sahne/telefon kaydini birakir. */
function relayLeave(socket) {
  const r = socket.data.relay;
  if (!r) return;
  socket.data.relay = null;
  socket.leave(relayRoom(r.code));
  const st = stages.get(r.code);
  if (r.role === "host" && st && st.hostId === socket.id) relayCloseStage(r.code);
  else relayNotifyHost(r.code);
}

function registerRelay(socket) {
  socket.on("relay_host", (msg, ack) => {
    const reply = typeof ack === "function" ? ack : () => {};
    const code = String((msg && msg.code) || "").toUpperCase();
    const key = String((msg && msg.key) || "");
    if (!RELAY_CODE.test(code) || !key) return reply({ ok: false, reason: "badcode" });

    const st = stages.get(code);
    if (st && st.key !== key) return reply({ ok: false, reason: "taken" });

    const prev = socket.data.relay;
    if (prev && !(prev.role === "host" && prev.code === code)) relayLeave(socket);

    if (st) {
      clearTimeout(st.graceTimer);
      st.graceTimer = null;
      st.hostId = socket.id; // ayni sahne yeniden baglandi
    } else {
      stages.set(code, { hostId: socket.id, key, graceTimer: null });
    }
    socket.join(relayRoom(code));
    socket.data.relay = { code, role: "host" };
    reply({ ok: true, n: relayPadCount(code) });
  });

  socket.on("relay_join", (msg, ack) => {
    const reply = typeof ack === "function" ? ack : () => {};
    const code = String((msg && msg.code) || "").toUpperCase().trim();
    if (!RELAY_CODE.test(code) || !stages.has(code)) return reply({ ok: false, reason: "stage" });
    const prev = socket.data.relay;
    if (prev && !(prev.role === "pad" && prev.code === code)) relayLeave(socket);
    socket.join(relayRoom(code));
    socket.data.relay = { code, role: "pad" };
    reply({ ok: true });
    relayNotifyHost(code);
  });

  socket.on("relay_msg", (msg) => {
    const r = socket.data.relay;
    if (!r || !msg || typeof msg.topic !== "string") return;
    const wire = { topic: msg.topic, data: msg.data || {} };
    if (r.role === "host") {
      socket.to(relayRoom(r.code)).emit("relay_msg", wire);
    } else {
      const st = stages.get(r.code);
      if (st && st.hostId && st.hostId !== socket.id) io.to(st.hostId).emit("relay_msg", wire);
    }
  });

  socket.on("disconnect", () => {
    const r = socket.data.relay;
    if (!r) return;
    const st = stages.get(r.code);
    if (r.role === "host" && st && st.hostId === socket.id) {
      // sahne sayfasi yeniden baglanabilir; hemen kapatma
      st.hostId = null;
      st.graceTimer = setTimeout(() => {
        const cur = stages.get(r.code);
        if (cur === st && !cur.hostId) relayCloseStage(r.code);
      }, RELAY_GRACE_MS);
    } else {
      relayNotifyHost(r.code);
    }
  });
}

// ------------------------------------------------------------
// Socket.io olay yonlendirici
// ------------------------------------------------------------
io.on("connection", (socket) => {
  registerRelay(socket);

  socket.on("create_room", ({ name }) => {
    const roomCode = makeRoomCode();
    const room = {
      hostSocketId: socket.id,
      players: new Map(),
      state: "LOBBY",
      questionIndex: 0,
      questionStartedAt: null,
      questionEndsAt: null,
      timer: null,
    };
    room.players.set(socket.id, { name: name || "Host", score: 0, pendingAnswer: null });
    rooms.set(roomCode, room);

    socket.join(roomCode);
    socket.data.roomCode = roomCode;
    socket.emit("joined", { roomCode, isHost: true, yourId: socket.id });
    broadcastRoom(roomCode);
  });

  socket.on("join_room", ({ roomCode, name }) => {
    const code = (roomCode || "").toUpperCase().trim();
    const room = rooms.get(code);
    if (!room) {
      socket.emit("error_message", { message: "Oda bulunamadı. Kodu kontrol edin." });
      return;
    }
    if (room.state !== "LOBBY") {
      socket.emit("error_message", { message: "Bu oyun zaten başladı." });
      return;
    }
    room.players.set(socket.id, { name: name || "Oyuncu", score: 0, pendingAnswer: null });
    socket.join(code);
    socket.data.roomCode = code;
    socket.emit("joined", { roomCode: code, isHost: false, yourId: socket.id });
    broadcastRoom(code);
  });

  socket.on("start_game", () => {
    const code = socket.data.roomCode;
    const room = rooms.get(code);
    if (!room || room.hostSocketId !== socket.id || room.state !== "LOBBY") return;
    if (room.players.size < 1) return;
    startQuestion(code);
  });

  socket.on("submit_answer", ({ optionIndex }) => {
    const code = socket.data.roomCode;
    const room = rooms.get(code);
    if (!room || room.state !== "QUESTION") return;
    const player = room.players.get(socket.id);
    if (!player || player.pendingAnswer) return; // zaten cevap verdi

    const receivedAt = Date.now();
    if (room.questionEndsAt && receivedAt > room.questionEndsAt + 200) return; // gec kaldi

    player.pendingAnswer = { optionIndex, receivedAt };
    player.answered = true;
    broadcastRoom(code);

    // Herkes cevapladiysa erken sonuclandir
    const allAnswered = [...room.players.values()].every((p) => p.answered);
    if (allAnswered) {
      clearTimeout(room.timer);
      resolveQuestion(code);
    }
  });

  socket.on("next_question", () => {
    const code = socket.data.roomCode;
    const room = rooms.get(code);
    if (!room || room.hostSocketId !== socket.id || room.state !== "RESULTS") return;
    startQuestion(code);
  });

  socket.on("disconnect", () => {
    const code = socket.data.roomCode;
    const room = rooms.get(code);
    if (!room) return;
    room.players.delete(socket.id);
    if (room.players.size === 0) {
      clearTimeout(room.timer);
      rooms.delete(code);
      return;
    }
    if (room.hostSocketId === socket.id) {
      room.hostSocketId = [...room.players.keys()][0]; // hostluk devreder
    }
    broadcastRoom(code);
  });
});

server.listen(PORT, () => {
  console.log(`Trivia Arena sunucusu ${PORT} portunda çalışıyor`);
});
