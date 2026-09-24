// ============================================================
// Trivia Arena - sunucu
// Express: public/index.html'i (tum oyun tek dosya) sikistirarak sunar.
// Socket.io: sahne (TV/PC) ile telefonlar arasindaki mesajlari aktarir.
// Oyun mantigi tamamen tarayicida; sunucu yalnizca postaci.
// ============================================================

const express = require("express");
const http = require("http");
const path = require("path");
const compression = require("compression");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  // telefonlar uykudan uyaninca baglanti hemen geri gelsin
  pingInterval: 20000,
  pingTimeout: 25000,
});

const PORT = process.env.PORT || 3000;
const STARTED_AT = Date.now();

// index.html ~1,1 MB; gzip ile ~5'te birine iner, telefonda acilis hizlanir
app.use(compression());

// Uyanik tutma / durum kontrolu (UptimeRobot, cron-job.org vb. bunu yoklar)
app.get("/healthz", (req, res) => {
  res.set("Cache-Control", "no-store");
  res.json({ ok: true, uptime: Math.round((Date.now() - STARTED_AT) / 1000), stages: stages.size });
});

app.use(
  express.static(path.join(__dirname, "public"), {
    setHeaders(res, file) {
      // html her zaman tazelensin ki guncelleme hemen gorunsun
      if (file.endsWith(".html")) res.set("Cache-Control", "no-cache");
      else res.set("Cache-Control", "public, max-age=86400");
    },
  })
);

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
// Socket.io
// ------------------------------------------------------------
io.on("connection", (socket) => {
  registerRelay(socket);
});

server.listen(PORT, () => {
  console.log(`Trivia Arena sunucusu ${PORT} portunda çalışıyor`);
});
