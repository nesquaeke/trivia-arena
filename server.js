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
// Socket.io olay yonlendirici
// ------------------------------------------------------------
io.on("connection", (socket) => {
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
