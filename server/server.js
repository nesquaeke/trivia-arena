// ============================================================
// Trivia Arena: The Grand Stage — telefon kumandası sunucusu
//
// Ev partisi modu: oyun (Godot, tek ekran) bu sunucuya "sahne" olarak
// bağlanır ve 4 harfli bir oda kodu alır. Telefonlar QR ile /pad
// sayfasını açar, aynı koda "kumanda" olarak katılır. Sunucu yalnızca
// postacıdır: telefonun joystick/tuş girdisini sahneye, sahnenin kısa
// mesajlarını (rengin, elendin, soru geldi...) telefona iletir.
//
// Uçlar:
//   GET  /healthz            durum (uyanık tutma servisleri için)
//   GET  /pad?c=KOD          telefon kumandası sayfası
//   GET  /qr.png?text=...    QR kodu (oyun ekranında gösterilir)
//   WS   /ws                 sahne ve kumandaların bağlandığı kanal
//
// WS protokolü (JSON):
//   sahne → {t:"host", code?, key}          ← {t:"hosted", code}
//   kumanda → {t:"join", code, name, pid?}  ← {t:"joined", ok, pid, reason?}
//   kumanda → {t:"in", x, y, j, s}          → sahneye {t:"in", pid, x, y, j, s}
//   sahne → {t:"to", pid, msg}              → o kumandaya msg
//   sahne → {t:"all", msg}                  → bütün kumandalara msg
//   sahneye: {t:"pad_join", pid, name} / {t:"pad_left", pid}
//   kumandaya: {t:"host_left"}
// ============================================================

const express = require("express");
const http = require("http");
const path = require("path");
const crypto = require("crypto");
const compression = require("compression");
const QRCode = require("qrcode");
const { WebSocketServer } = require("ws");

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;
const STARTED_AT = Date.now();

const CODE_RE = /^[A-Z]{4}$/;
const LETTERS = "BCDFGHJKLMNPRSTVXZ";
const HOST_GRACE_MS = 30000;   // sahne kısa süre koparsa oda beklesin
const MAX_PADS = 8;

/** rooms[code] = { host: ws|null, key, pads: Map(pid -> ws), grace: Timeout|null } */
const rooms = new Map();

app.use(compression());
app.set("trust proxy", true);

app.get("/healthz", (req, res) => {
  res.set("Cache-Control", "no-store");
  res.json({ ok: true, uptime: Math.round((Date.now() - STARTED_AT) / 1000), rooms: rooms.size });
});

app.get("/pad", (req, res) => {
  res.set("Cache-Control", "no-cache");
  res.sendFile(path.join(__dirname, "public", "pad.html"));
});

app.get("/qr.png", async (req, res) => {
  const text = String(req.query.text || "").slice(0, 300);
  if (!text) return res.status(400).send("text gerekli");
  try {
    const buf = await QRCode.toBuffer(text, { errorCorrectionLevel: "M", margin: 2, scale: 10, color: { dark: "#1C0E08", light: "#F3E4C4" } });
    res.set("Content-Type", "image/png");
    res.set("Cache-Control", "public, max-age=3600");
    res.send(buf);
  } catch (e) {
    res.status(500).send("qr hatası");
  }
});

app.use(
  express.static(path.join(__dirname, "public"), {
    setHeaders(res, file) {
      if (file.endsWith(".html")) res.set("Cache-Control", "no-cache");
      else res.set("Cache-Control", "public, max-age=86400");
    },
  })
);

// ── WebSocket ────────────────────────────────────────────────
const wss = new WebSocketServer({ noServer: true, maxPayload: 16 * 1024 });

server.on("upgrade", (req, socket, head) => {
  const url = new URL(req.url, "http://x");
  if (url.pathname !== "/ws") {
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, head, (ws) => wss.emit("connection", ws, req));
});

function send(ws, obj) {
  if (ws && ws.readyState === 1) ws.send(JSON.stringify(obj));
}

function newCode() {
  let c;
  do {
    c = Array.from({ length: 4 }, () => LETTERS[crypto.randomInt(LETTERS.length)]).join("");
  } while (rooms.has(c));
  return c;
}

function closeRoom(code) {
  const room = rooms.get(code);
  if (!room) return;
  clearTimeout(room.grace);
  for (const pad of room.pads.values()) send(pad, { t: "host_left" });
  rooms.delete(code);
}

wss.on("connection", (ws) => {
  ws.role = null;
  ws.code = null;
  ws.pid = null;
  ws.isAlive = true;
  ws.on("pong", () => (ws.isAlive = true));

  ws.on("message", (raw) => {
    let m;
    try {
      m = JSON.parse(raw);
    } catch (e) {
      return;
    }
    if (!m || typeof m.t !== "string") return;

    if (m.t === "host") {
      const key = String(m.key || "");
      let code = String(m.code || "").toUpperCase();
      const existing = CODE_RE.test(code) ? rooms.get(code) : null;
      if (existing && existing.key === key) {
        // aynı sahne yeniden bağlandı: telefonlar kopmadan devam
        clearTimeout(existing.grace);
        existing.grace = null;
        existing.host = ws;
        for (const [pid, pad] of existing.pads) send(ws, { t: "pad_join", pid, name: pad.name });
      } else {
        code = newCode();
        rooms.set(code, { host: ws, key, pads: new Map(), grace: null });
      }
      ws.role = "host";
      ws.code = code;
      send(ws, { t: "hosted", code });
      return;
    }

    if (m.t === "join") {
      const code = String(m.code || "").toUpperCase().trim();
      const room = rooms.get(code);
      if (!room) return send(ws, { t: "joined", ok: false, reason: "stage" });
      let pid = String(m.pid || "");
      if (!/^p[a-z0-9]{4,12}$/.test(pid)) pid = "p" + crypto.randomBytes(4).toString("hex");
      if (!room.pads.has(pid) && room.pads.size >= MAX_PADS) return send(ws, { t: "joined", ok: false, reason: "full" });
      const old = room.pads.get(pid);
      if (old && old !== ws) old.close();
      ws.role = "pad";
      ws.code = code;
      ws.pid = pid;
      ws.name = String(m.name || "Oyuncu").slice(0, 14);
      room.pads.set(pid, ws);
      send(ws, { t: "joined", ok: true, pid });
      send(room.host, { t: "pad_join", pid, name: ws.name });
      return;
    }

    const room = ws.code ? rooms.get(ws.code) : null;
    if (!room) return;

    if (ws.role === "pad" && m.t === "in") {
      // girdi: sayıları sınırla, sahneye aynen ilet
      const clamp = (v) => Math.max(-1, Math.min(1, Number(v) || 0));
      send(room.host, { t: "in", pid: ws.pid, x: clamp(m.x), y: clamp(m.y), j: !!m.j, s: !!m.s });
      return;
    }
    if (ws.role === "host" && room.host === ws) {
      if (m.t === "to" && m.msg) send(room.pads.get(String(m.pid)), m.msg);
      else if (m.t === "all" && m.msg) for (const pad of room.pads.values()) send(pad, m.msg);
    }
  });

  ws.on("close", () => {
    const room = ws.code ? rooms.get(ws.code) : null;
    if (!room) return;
    if (ws.role === "pad" && room.pads.get(ws.pid) === ws) {
      room.pads.delete(ws.pid);
      send(room.host, { t: "pad_left", pid: ws.pid });
    } else if (ws.role === "host" && room.host === ws) {
      room.host = null;
      const code = ws.code;
      room.grace = setTimeout(() => {
        const r = rooms.get(code);
        if (r && !r.host) closeRoom(code);
      }, HOST_GRACE_MS);
    }
  });
});

// ölü bağlantıları temizle (telefon kilitlendi, ağ değişti…)
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) {
      ws.terminate();
      continue;
    }
    ws.isAlive = false;
    ws.ping();
  }
}, 20000).unref();

server.listen(PORT, () => {
  console.log(`Trivia Arena kumanda sunucusu ${PORT} portunda`);
});
