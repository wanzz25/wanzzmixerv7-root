--[[
  WANZZMIXER V5 - PEARL 1024B EDITION (REAL ROBLOX RIG MAPPING FIX)
  + Gerakan halus (Smooth) & shape baru, fader Program gaya panel (13 parameter),
  + Tab SAVE PARAM (Case 1-30), case khusus WANZ (Flyout Panggung).
  Fix Berdasarkan Video Test:
  1. Di video terlihat saat Ch 1 digeser, kepala Beam mengangguk (Tilt), sedangkan Ch 3 tidak merespon.
     Artinya rig ini menggunakan 8-bit berurutan (Ch 1 & Ch 2 untuk Pan/Tilt, bukan Ch 1 & Ch 3!).
  2. Penghapusan nilai paksa (focus=255 / shutter=255) yang sebelumnya membuat lampu tertutup/gelap.
  3. Penambahan tombol "Tukar Pan <-> Tilt (Ch 1/2)" dan fitur "Auto-Scan 16 Channel" untuk melihat langsung fungsi tiap channel di mobil.
  4. Awal execute tetap POLOS KOSONGAN (0 Fixture, Shape OFF).
]]
if _G.WANZZMIXER and _G.WANZZMIXER.stop then pcall(_G.WANZZMIXER.stop) end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local floor, sin, cos, abs, asin, pi, random = math.floor, math.sin, math.cos, math.abs, math.asin, math.pi, math.random
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function round(v) return floor(v + 0.5) end

-- ============================================================
-- PROFIL CHANNEL CLARA S 14R (DISESUAIKAN DENGAN VIDEO RIG ROBLOX)
-- ============================================================
local BEAM_PROFILES = {
  ["R1"] = {
    label = "Rig Roblox A (Pan=Ch 1, Tilt=Ch 2, Dimmer=Ch 3/6/7/8)",
    -- Mengirim Dimmer ke Ch 3, 6, 7, 8 sekaligus agar pasti menyala di semua versi script lampu Roblox, sementara Pan=1 & Tilt=2 murni!
    map = {pan = 1, tilt = 2, dimmer = {3, 6, 7, 8}, strobe = 4, prisma = 5}
  },
  ["R2"] = {
    label = "Rig Roblox B [Tukar P/T] (Tilt=Ch 1, Pan=Ch 2, Dimmer=Ch 3/6/7/8)",
    -- Sesuai video detik 00:09 di mana Ch 1 menggerakkan kepala naik-turun (Tilt) dan Ch 2 kiri-kanan (Pan)
    map = {tilt = 1, pan = 2, dimmer = {3, 6, 7, 8}, strobe = 4, prisma = 5}
  },
  ["R3"] = {
    label = "Rig Roblox C (Dimmer=Ch 1, Pan=Ch 2, Tilt=Ch 3, Strobe=Ch 4)",
    map = {dimmer = 1, pan = 2, tilt = 3, strobe = 4, prisma = 5}
  },
  ["R4"] = {
    label = "Rig Standar 16Ch (Pan=Ch 1, Tilt=Ch 3, Dimmer=Ch 6, Shutter=Ch 7)",
    map = {pan = 1, tilt = 3, dimmer = 6, strobe = 7, prisma = 11}
  },
}

local MODELS = {
  {name = "Clara S 14R",   ch = 16, kind = "beam",    map = {}, fixed = {}},
  {name = "Strobe 1000W",  ch = 8,  kind = "strobe",  map = {dimmer = {1, 2, 3, 4, 5, 6, 7}, strobe = 8}, fixed = {}},
  {name = "3x1 Apple Led", ch = 12, kind = "led",     map = {dimmer = 1, r = 2, g = 3, b = 4, strobe = 5}, fixed = {}},
  {name = "Parled",        ch = 6,  kind = "par",     map = {dimmer = 1, r = 2, g = 3, b = 4, strobe = 5}, fixed = {}},
  {name = "Fogger 3000W",  ch = 1,  kind = "fog",     map = {dimmer = 1}, fixed = {}},
  {name = "Blinder 4x100", ch = 4,  kind = "blinder", map = {dimmer = {1, 2, 3, 4}}, fixed = {}},
  {name = "Flower 300W",   ch = 8,  kind = "led",     map = {dimmer = 1, r = 2, g = 3, b = 4, strobe = 5}, fixed = {}},
}

local FILE = "wanzzmixer_v5_pearl.json"
local SEND_HZ = 40
local MAX_CASES = 30
local WANZ_USER_ID = 10578263919 -- UserId unik per akun (username bisa diganti, ID tidak)
local IS_WANZ = (LP.UserId == WANZ_USER_ID)

-- ============================================================
-- STATE GLOBAL
-- ============================================================
local S = {
  master = 100, blackout = false, fade = 0,
  beamProfile = "R1",

  -- Pearl 1024B Pan/Tilt Shape Generator
  ptShape = "OFF",
  panCenter = 128,
  tiltCenter = 128,
  panSize = 75,
  tiltSize = 75,
  ptSpeed = 0.45,
  ptSpread = 25,
  ptRepeat = 0,
  ptDir = 1,
  mirrorPan = false,
  invertOddTilt = false,
  ptPhase = 0,

  -- Pearl 1024B Dimmer Shape Generator
  dimShape = "OFF",
  dimSpeed = 0.90,
  dimSpread = 60,
  dimRepeat = 2,
  dimSize = 255,
  dimPhase = 0,

  singleSelectPro = false,
  chaseSteps = {}, chasePlay = false, chaseBpm = 90, chaseCross = 50, chaseIdx = 1, chaseT = 0,
  cues = {}, cuePage = 1, cueSel = nil,
  pcases = {}, pcSel = nil, pcDel = false, ptSmooth = 50,
  model = 1, labelDmx = false, layoutMode = "2baris", scale = nil,
  test = {on = false, ch = 1, val = 255, autoScan = false, scanTimer = 0},
  car = false, running = true,
}

local fixtures = {}
local conns = {}
local UI = {}
local remote = nil
local activeSlider = nil
local lastBtnClick = 0

local function canClick()
  local now = os.clock()
  if now - lastBtnClick < 0.06 then return false end
  lastBtnClick = now
  return true
end

local function applyBeamProfile(profKey)
  local p = BEAM_PROFILES[profKey] or BEAM_PROFILES["R1"]
  S.beamProfile = profKey
  MODELS[1].map = {}
  for k, v in pairs(p.map) do MODELS[1].map[k] = v end
end
applyBeamProfile("R1")

-- Parameter tambahan (baru terkirim setelah channel-nya di-set lewat Auto-Scan > Set ...)
local EXTRA = {"color", "gobo", "gorot", "frost", "prism2", "prot", "focus", "xy"}
local EXTRA_SET = {}
for _, k in ipairs(EXTRA) do EXTRA_SET[k] = true end

local function newFixture(mi, dmx)
  local m = MODELS[mi]
  return {
    model = m, mi = mi, id = #fixtures + 1, dmx = dmx, sel = true,
    -- Default dimBase = 255 agar begitu di-patch lampu siap menyala dan langsung merespon slider Dimmer!
    panBase = 128, tiltBase = 128, dimBase = 255, strobeBase = 0, prismaBase = 0,
    r = 255, g = 255, b = 255,
    color = 0, gobo = 0, gorot = 0, frost = 0, prism2 = 0, prot = 0, focus = 0, xy = 0,
    pan = 128, tilt = 128, strobe = 0, prisma = 0, dimOut = 255, chase = nil
  }
end

local function clearFixtures()
  fixtures = {}
end

local function autoPatch()
  local addr = 1
  for _, f in ipairs(fixtures) do
    local n = f.model.ch
    local startU = floor((addr - 1) / 512)
    local endU = floor((addr + n - 2) / 512)
    if startU ~= endU then addr = (startU + 1) * 512 + 1 end
    f.dmx = addr
    addr = addr + n
  end
end

-- ============================================================
-- ENGINE SHAPE GENERATOR AVOLITES PEARL 1024B
-- ============================================================
local PEARL_PT_SHAPES = {
  "OFF",
  "Circle",
  "Figure 8",
  "Pan Saw",
  "Tilt Saw",
  "Pan Sin",
  "Tilt Sin",
  "Swing",
  "CanCan",
  "Line Diag",
  "Box Square",
  "Fan Spread",
  "Smooth Wave",
  "Butterfly",
  "Breathe Fan",
  "Ripple"
}
if IS_WANZ then table.insert(PEARL_PT_SHAPES, "Flyout") end

local PEARL_DIM_SHAPES = {
  "OFF",
  "Dim Spread",
  "Pulse 1:1",
  "Pulse 2:1",
  "Pulse 1:2",
  "Chase Odd/Even",
  "Random Flash"
}

local function triWave(rad)
  return (2 / pi) * asin(sin(rad))
end

local function sqWave(rad)
  return clamp(sin(rad) * 3.0, -1, 1)
end

local function calcPearlPTShape(shapeName, idx0, total, basePhase)
  local half = math.max(1, (total - 1) / 2)
  local norm = (total > 1) and ((idx0 - half) / half) or 0
  local isRightSide = (idx0 >= total / 2)
  local isOddFixture = ((idx0 % 2) == 1)

  local effIdx = idx0
  if S.ptRepeat and S.ptRepeat > 0 then
    effIdx = idx0 % S.ptRepeat
  end
  local phaseOffsetRad = (effIdx * S.ptSpread) * (pi / 180)
  local rad = basePhase + phaseOffsetRad

  local dx, dy = 0, 0

  if shapeName == "Circle" then
    dx = sin(rad)
    dy = cos(rad)
  elseif shapeName == "Figure 8" then
    dx = sin(rad)
    dy = sin(rad * 2)
  elseif shapeName == "Pan Saw" then
    dx = triWave(rad)
    dy = 0
  elseif shapeName == "Tilt Saw" then
    dx = 0
    dy = triWave(rad)
  elseif shapeName == "Pan Sin" then
    dx = sin(rad)
    dy = 0
  elseif shapeName == "Tilt Sin" then
    dx = 0
    dy = sin(rad)
  elseif shapeName == "Swing" then
    dx = sin(rad)
    dy = cos(rad * 2) * 0.6
  elseif shapeName == "CanCan" then
    dx = sin(rad * 0.5) * 0.35
    dy = sin(rad)
  elseif shapeName == "Line Diag" then
    dx = sin(rad)
    dy = sin(rad)
  elseif shapeName == "Box Square" then
    dx = sqWave(rad)
    dy = sqWave(rad + pi / 2)
  elseif shapeName == "Fan Spread" then
    dx = norm * sin(basePhase)
    dy = cos(rad)
  elseif shapeName == "Smooth Wave" then
    dx = sin(rad * 0.6)
    dy = sin(rad * 0.6 - 1.57) * 0.7
  elseif shapeName == "Butterfly" then
    dx = sin(rad * 0.8) * (0.5 + 0.5 * cos(rad * 0.4))
    dy = cos(rad * 0.8) * 0.8
  elseif shapeName == "Breathe Fan" then
    local b = 0.5 - 0.5 * cos(basePhase * 0.6)
    b = b * b * (3 - 2 * b)
    dx = norm * (0.3 + 0.7 * b)
    dy = (b - 0.5) * 1.4
  elseif shapeName == "Ripple" then
    dx = sin(basePhase - abs(norm) * 6)
    dy = cos(basePhase - abs(norm) * 6) * 0.8
  elseif shapeName == "Flyout" then
    local p = 0.5 - 0.5 * cos(rad * 0.8)
    p = p * p * (3 - 2 * p)
    dx = norm * p * 1.6
    dy = -p * 0.8
  end

  if S.mirrorPan and isRightSide then dx = -dx end
  if S.invertOddTilt and isOddFixture then dy = -dy end

  return dx * S.panSize, dy * S.tiltSize
end

local function calcPearlDimShape(shapeName, idx0, basePhase)
  if shapeName == "OFF" then return 1 end

  local effIdx = idx0
  if S.dimRepeat and S.dimRepeat > 0 then
    effIdx = idx0 % S.dimRepeat
  end
  local phaseOffsetRad = (effIdx * S.dimSpread) * (pi / 180)
  local rad = basePhase + phaseOffsetRad
  local cyc = (rad / (2 * pi)) % 1

  local mod = 1
  if shapeName == "Dim Spread" then
    mod = sin(rad) * 0.5 + 0.5
  elseif shapeName == "Pulse 1:1" then
    mod = (cyc < 0.5) and 1 or 0
  elseif shapeName == "Pulse 2:1" then
    mod = (cyc < 0.66) and 1 or 0
  elseif shapeName == "Pulse 1:2" then
    mod = (cyc < 0.33) and 1 or 0
  elseif shapeName == "Chase Odd/Even" then
    local isOdd = (idx0 % 2 == 0)
    local halfCyc = (basePhase / pi) % 2 < 1
    mod = (halfCyc == isOdd) and 1 or 0
  elseif shapeName == "Random Flash" then
    mod = (sin(basePhase * 7.3 + idx0 * 4.1) > 0.35) and 1 or 0
  end

  local depth = clamp(S.dimSize / 255, 0, 1)
  return 1 - depth * (1 - mod)
end

local function stepEffects(dt)
  if #fixtures == 0 then return end

  -- Auto-Scan Channel Finder (Berpindah channel tiap 1.2 detik jika aktif)
  if S.test.on and S.test.autoScan then
    S.test.scanTimer = S.test.scanTimer + dt
    if S.test.scanTimer >= 1.2 then
      S.test.scanTimer = 0
      S.test.ch = (S.test.ch % 16) + 1
      if UI.refreshTest then UI.refreshTest() end
    end
  end

  local dirf = S.ptDir
  if S.ptDir == 0 then dirf = (sin(S.ptPhase * 0.25) >= 0) and 1 or -1 end
  if S.ptShape ~= "OFF" then
    S.ptPhase = S.ptPhase + (S.ptSpeed * 2 * pi) * dirf * dt
  end

  if S.dimShape ~= "OFF" then
    S.dimPhase = S.dimPhase + (S.dimSpeed * 2 * pi) * dt
  end

  local selBeams = {}
  for _, f in ipairs(fixtures) do
    f.pan = f.panBase
    f.tilt = f.tiltBase
    f.strobe = f.strobeBase
    f.prisma = f.prismaBase
    if f.sel and f.model.kind == "beam" then
      selBeams[#selBeams + 1] = f
    end
  end

  if S.ptShape ~= "OFF" and #selBeams > 0 then
    local total = #selBeams
    for i, f in ipairs(selBeams) do
      local ox, oy = calcPearlPTShape(S.ptShape, i - 1, total, S.ptPhase)
      f.pan = clamp(round(f.panBase + ox), 0, 255)
      f.tilt = clamp(round(f.tiltBase + oy), 0, 255)
    end
  end

  local chaseOn = S.chasePlay and #S.chaseSteps > 0
  if chaseOn then
    local stepDur = 60 / math.max(1, S.chaseBpm)
    S.chaseT = S.chaseT + dt
    while S.chaseT >= stepDur do
      S.chaseT = S.chaseT - stepDur
      S.chaseIdx = S.chaseIdx % #S.chaseSteps + 1
    end
    local a = S.chaseSteps[S.chaseIdx]
    local b = S.chaseSteps[S.chaseIdx % #S.chaseSteps + 1]
    local cross = clamp(S.chaseCross / 100, 0, 1)
    local u = (cross <= 0) and 0 or clamp((S.chaseT / stepDur - (1 - cross)) / cross, 0, 1)
    for _, f in ipairs(fixtures) do
      local sa, sb = a[f.id], b[f.id]
      if sa and sb then
        f.pan = sa.pan + (sb.pan - sa.pan) * u
        f.tilt = sa.tilt + (sb.tilt - sa.tilt) * u
        f.strobe = sa.strobe + (sb.strobe - sa.strobe) * u
        f.prisma = sa.prisma + (sb.prisma - sa.prisma) * u
        f.chase = sa.dim + (sb.dim - sa.dim) * u
      end
    end
  else
    for _, f in ipairs(fixtures) do f.chase = nil end
  end

  -- Penghalus gerakan: pan/tilt mengikuti target dengan peredaman (0 = langsung/kasar)
  local sm = S.ptSmooth or 0
  local kf = (sm <= 0) and 1 or (1 - math.exp(-(45 - sm * 0.4) * dt))
  for _, f in ipairs(fixtures) do
    if f.sp == nil or kf >= 1 then f.sp = f.pan else f.sp = f.sp + (f.pan - f.sp) * kf end
    if f.st == nil or kf >= 1 then f.st = f.tilt else f.st = f.st + (f.tilt - f.st) * kf end
    f.pan = f.sp; f.tilt = f.st
  end

  local selIdx = 0
  for _, f in ipairs(fixtures) do
    local base = f.chase or f.dimBase
    local mult = 1
    if S.dimShape ~= "OFF" and f.sel and f.model.kind ~= "fog" then
      selIdx = selIdx + 1
      mult = calcPearlDimShape(S.dimShape, selIdx - 1, S.dimPhase)
    end
    local target = base * mult
    if S.blackout then
      f.dimOut = 0
    else
      f.dimOut = target
    end
  end
end

-- ============================================================
-- DMX OUTPUT MURNI (TANPA NILAI SAMPAH PENUTUP SHUTTER)
-- ============================================================
local function outVal(f, param)
  local effDim = S.blackout and 0 or clamp(round(f.dimOut * (S.master / 100)), 0, 255)
  if param == "dimmer" then
    return effDim
  elseif param == "pan" then
    return f.pan
  elseif param == "tilt" then
    return f.tilt
  elseif param == "strobe" then
    return f.strobe
  elseif param == "prisma" then
    return f.prisma
  elseif param == "r" then
    return f.r
  elseif param == "g" then
    return f.g
  elseif param == "b" then
    return f.b
  elseif EXTRA_SET[param] then
    return f[param]
  end
  return nil
end

local function buildFrame()
  local U = {}
  local function put(abs_, v)
    if abs_ < 1 or abs_ > 4096 then return end
    local u = floor((abs_ - 1) / 512) + 1
    local c = (abs_ - 1) % 512 + 1
    local t = U[u]
    if not t then t = {}; U[u] = t end
    t[c] = clamp(round(v), 0, 255)
  end

  for _, f in ipairs(fixtures) do
    local m = f.model
    for ch, val in pairs(m.fixed) do put(f.dmx + tonumber(ch) - 1, val) end
    for param, chs in pairs(m.map) do
      local v = outVal(f, param)
      if v ~= nil then
        if type(chs) == "table" then
          for _, c in ipairs(chs) do put(f.dmx + c - 1, v) end
        else
          put(f.dmx + chs - 1, v)
        end
      end
    end
    -- Jika mode Tes Channel aktif: kirim nilai tes secara eksklusif ke channel yang sedang diuji
    if S.test.on and f.sel and f.mi == S.model and S.test.ch <= m.ch then
      put(f.dmx + S.test.ch - 1, S.test.val)
    end
  end
  return U
end

local function findRemote()
  local ok, r = pcall(function()
    local v = workspace:FindFirstChild("Vehicles")
    local car = v and v:FindFirstChild(LP.Name .. "'s Car")
    return car and car:FindFirstChild("UDP_DMXDATA")
  end)
  if ok and r and r:IsA("RemoteEvent") then return r end
  return nil
end

local function sendFrame()
  if #fixtures == 0 then return end
  if not remote or not remote.Parent then return end
  local U = buildFrame()
  local payload = {}
  for u, t in pairs(U) do
    local b = buffer.create(512)
    for c, v in pairs(t) do buffer.writeu8(b, c - 1, v) end
    payload[u] = b
  end
  pcall(remote.FireServer, remote, payload)
end

-- ============================================================
-- SIMPAN / MUAT MANUAL
-- ============================================================
local saves = {}
local function snapshotAll()
  local fx = {}
  for _, f in ipairs(fixtures) do
    fx[#fx + 1] = {mi = f.mi, dmx = f.dmx, sel = f.sel, dimBase = f.dimBase, panBase = f.panBase, tiltBase = f.tiltBase}
  end
  local cuesOut = {}
  for k, v in pairs(S.cues) do cuesOut[tostring(k)] = v end
  return {
    fixtures = fx, cues = cuesOut, chase = S.chaseSteps,
    beamMap = MODELS[1].map,
    set = {
      master = S.master, beamProfile = S.beamProfile,
      ptShape = S.ptShape, panCenter = S.panCenter, tiltCenter = S.tiltCenter,
      panSize = S.panSize, tiltSize = S.tiltSize, ptSpeed = S.ptSpeed,
      ptSpread = S.ptSpread, ptRepeat = S.ptRepeat, ptDir = S.ptDir,
      mirrorPan = S.mirrorPan, invertOddTilt = S.invertOddTilt,
      dimShape = S.dimShape, dimSpeed = S.dimSpeed, dimSpread = S.dimSpread, dimRepeat = S.dimRepeat, dimSize = S.dimSize
    }
  }
end

local function applySnapshot(d)
  if type(d) ~= "table" then return end
  if type(d.set) == "table" and d.set.beamProfile then
    applyBeamProfile(d.set.beamProfile)
  end
  if type(d.beamMap) == "table" then
    MODELS[1].map = d.beamMap
  end
  if type(d.fixtures) == "table" then
    fixtures = {}
    for _, x in ipairs(d.fixtures) do
      local mi = tonumber(x.mi)
      if mi and MODELS[mi] then
        local f = newFixture(mi, tonumber(x.dmx) or 1)
        f.sel = x.sel and true or false
        f.dimBase = tonumber(x.dimBase) or 255
        f.panBase = tonumber(x.panBase) or 128
        f.tiltBase = tonumber(x.tiltBase) or 128
        f.dimOut = f.dimBase
        fixtures[#fixtures + 1] = f
      end
    end
  end
  if type(d.cues) == "table" then
    S.cues = {}
    for k, v in pairs(d.cues) do S.cues[tonumber(k) or k] = v end
  end
  if type(d.chase) == "table" then
    S.chaseSteps = {}
    for _, st in ipairs(d.chase) do
      local o = {}
      for k, v in pairs(st) do o[tonumber(k) or k] = v end
      S.chaseSteps[#S.chaseSteps + 1] = o
    end
  end
  if type(d.set) == "table" then
    local st = d.set
    S.master = tonumber(st.master) or S.master
    S.ptShape = st.ptShape or "OFF"
    S.panCenter = tonumber(st.panCenter) or 128
    S.tiltCenter = tonumber(st.tiltCenter) or 128
    S.panSize = tonumber(st.panSize) or 75
    S.tiltSize = tonumber(st.tiltSize) or 75
    S.ptSpeed = tonumber(st.ptSpeed) or 0.45
    S.ptSpread = tonumber(st.ptSpread) or 25
    S.ptRepeat = tonumber(st.ptRepeat) or 0
    S.ptDir = tonumber(st.ptDir) or 1
    S.mirrorPan = st.mirrorPan and true or false
    S.invertOddTilt = st.invertOddTilt and true or false
    S.dimShape = st.dimShape or "OFF"
    S.dimSpeed = tonumber(st.dimSpeed) or 0.90
    S.dimSpread = tonumber(st.dimSpread) or 60
    S.dimRepeat = tonumber(st.dimRepeat) or 2
    S.dimSize = tonumber(st.dimSize) or 255
  end
end

local function fileOk() return type(writefile) == "function" and type(readfile) == "function" end
local function writeSavesOnly()
  if not fileOk() then return false end
  local pc = {}
  for k, v in pairs(S.pcases) do pc[tostring(k)] = v end
  return pcall(function() writefile(FILE, HttpService:JSONEncode({saves = saves, pcases = pc})) end)
end
local function readSavesListOnly()
  if not fileOk() then return end
  local ok, data = pcall(function()
    if isfile and not isfile(FILE) then return nil end
    return HttpService:JSONDecode(readfile(FILE))
  end)
  if ok and type(data) == "table" and type(data.saves) == "table" then saves = data.saves end
  if ok and type(data) == "table" and type(data.pcases) == "table" then
    for k, v in pairs(data.pcases) do
      local n = tonumber(k)
      if n and n >= 1 and n <= MAX_CASES and type(v) == "table" then S.pcases[n] = v end
    end
  end
end

-- ============================================================
-- UI HELPER
-- ============================================================
local C = {
  main = Color3.fromRGB(16, 16, 20), panel = Color3.fromRGB(24, 24, 30), card = Color3.fromRGB(32, 32, 40),
  input = Color3.fromRGB(12, 12, 16), border = Color3.fromRGB(72, 72, 82), text = Color3.fromRGB(244, 244, 245),
  muted = Color3.fromRGB(161, 161, 170), white = Color3.fromRGB(255, 255, 255), black = Color3.fromRGB(0, 0, 0),
  red = Color3.fromRGB(239, 68, 68), green = Color3.fromRGB(34, 197, 94)
}
local dyn = false
local function track(c) if not dyn then conns[#conns + 1] = c end; return c end
local function dynamic(fn) dyn = true; local ok, e = pcall(fn); dyn = false; if not ok then error(e, 0) end end
local function new(cls, props, parent)
  local o = Instance.new(cls)
  for k, v in pairs(props or {}) do o[k] = v end
  if parent then o.Parent = parent end
  return o
end
local function stroke(o, th)
  return new("UIStroke", {Color = C.border, Thickness = th or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
end
local function pad(o, p) return new("UIPadding", {PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p), PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p)}, o) end
local function label(parent, text, props)
  local p = {BackgroundTransparency = 1, Text = text, TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), TextWrapped = true}
  for k, v in pairs(props or {}) do p[k] = v end
  return new("TextLabel", p, parent)
end
local function setActive(b, on)
  if not b then return end
  b.BackgroundColor3 = on and C.white or C.card
  b.TextColor3 = on and C.black or C.text
end
local function button(parent, text, cb, props)
  local p = {BackgroundColor3 = C.card, TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 11, Text = text,
    AutoButtonColor = true, Size = UDim2.new(0, 84, 0, 28), BorderSizePixel = 0, TextWrapped = true}
  for k, v in pairs(props or {}) do p[k] = v end
  local b = new("TextButton", p, parent)
  stroke(b)
  if cb then
    track(b.Activated:Connect(function()
      if activeSlider ~= nil then return end
      if not canClick() then return end
      cb(b)
    end))
  end
  return b
end
local function mkInput(parent, text, w, cb, ph)
  local b = new("TextBox", {Size = UDim2.new(0, w, 0, 28), BackgroundColor3 = C.input, TextColor3 = C.text, PlaceholderText = ph or "",
    PlaceholderColor3 = C.muted, Text = text, Font = Enum.Font.Code, TextSize = 11, ClearTextOnFocus = false, BorderSizePixel = 0}, parent)
  stroke(b)
  track(b.FocusLost:Connect(function() if cb then cb(b.Text, b) end end))
  return b
end
local function row(parent, h, gap)
  local r = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h or 0), AutomaticSize = h and Enum.AutomaticSize.None or Enum.AutomaticSize.Y}, parent)
  new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap or 8), Wraps = true,
    VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, r)
  return r
end
local function grid(parent, cols, cellH, gap)
  local g = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, parent)
  local gp = gap or 7
  new("UIGridLayout", {CellSize = UDim2.new(1 / cols, -gp, 0, cellH), CellPadding = UDim2.new(0, gp, 0, gp), SortOrder = Enum.SortOrder.LayoutOrder}, g)
  return g
end
local function box(parent, title, spacing)
  local b = new("Frame", {BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0}, parent)
  stroke(b); pad(b, 10)
  new("UIListLayout", {Padding = UDim.new(0, spacing or 10), SortOrder = Enum.SortOrder.LayoutOrder}, b)
  if title then
    label(b, " " .. title .. " ", {TextColor3 = C.black, BackgroundTransparency = 0, BackgroundColor3 = C.white, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 20), Font = Enum.Font.Code, TextSize = 11, TextWrapped = false})
  end
  return b
end

local function mkSlider(parent, min, max, init, cb, size)
  local f = new("Frame", {BackgroundTransparency = 1, Size = size or UDim2.new(1, 0, 0, 30), Active = true}, parent)
  local tr = new("Frame", {Size = UDim2.new(1, -12, 0, 12), Position = UDim2.new(0, 6, 0.5, -6), BackgroundColor3 = C.input, BorderSizePixel = 0}, f)
  stroke(tr, 1.5)
  local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.white, BorderSizePixel = 0}, tr)
  local knob = new("Frame", {Size = UDim2.new(0, 14, 0, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = C.white, BorderSizePixel = 0}, tr)
  stroke(knob, 1.5)
  local obj = {value = init, frame = f}
  local function vis(v)
    local r = (max > min) and ((v - min) / (max - min)) or 0
    r = clamp(r, 0, 1)
    fill.Size = UDim2.new(r, 0, 1, 0); knob.Position = UDim2.new(r, 0, 0.5, 0)
  end
  function obj.set(v) obj.value = v; vis(v) end
  local function upd(x)
    local w = tr.AbsoluteSize.X
    if w <= 0 then return end
    local r = clamp((x - tr.AbsolutePosition.X) / w, 0, 1)
    local v = min + r * (max - min)
    if (max - min) >= 10 then v = round(v) else v = floor(v * 100 + 0.5) / 100 end
    obj.value = v; vis(v)
    if cb then cb(v) end
  end
  track(f.InputBegan:Connect(function(i)
    if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and activeSlider == nil then
      activeSlider = obj
      upd(i.Position.X)
    end
  end))
  track(UIS.InputChanged:Connect(function(i)
    if activeSlider == obj and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
      upd(i.Position.X)
    end
  end))
  track(UIS.InputEnded:Connect(function(i)
    if activeSlider == obj and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
      activeSlider = nil
    end
  end))
  vis(init)
  return obj
end

local function slideRowAdv(parent, name, min, max, init, step, fmt, cb)
  local r = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32)}, parent)
  label(r, name, {Size = UDim2.new(0, 96, 1, 0), TextSize = 11})
  local valLbl = label(r, fmt(init), {Size = UDim2.new(0, 68, 1, 0), Position = UDim2.new(1, -68, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 11})
  local o = {}
  local sl = mkSlider(r, min, max, init, function(v)
    valLbl.Text = fmt(v)
    cb(v)
  end, UDim2.new(1, -238, 1, 0))
  sl.frame.Position = UDim2.new(0, 100, 0, 0)

  button(r, "-", function()
    local nv = clamp(sl.value - step, min, max)
    sl.set(nv); valLbl.Text = fmt(nv); cb(nv)
  end, {Position = UDim2.new(1, -132, 0.5, -13), Size = UDim2.new(0, 28, 0, 26)})

  button(r, "+", function()
    local nv = clamp(sl.value + step, min, max)
    sl.set(nv); valLbl.Text = fmt(nv); cb(nv)
  end, {Position = UDim2.new(1, -100, 0.5, -13), Size = UDim2.new(0, 28, 0, 26)})

  function o.set(v) sl.set(v); valLbl.Text = fmt(v) end
  return o
end

-- ============================================================
-- WINDOW UTAMA
-- ============================================================
local function guiParent()
  local ok, h = pcall(function() return gethui and gethui() end)
  if ok and h then return h end
  local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
  if ok2 and cg then return cg end
  return LP:WaitForChild("PlayerGui")
end
local gui = new("ScreenGui", {Name = "WANZZMIXER", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999})
local okParent = pcall(function() gui.Parent = guiParent() end)
if not okParent then gui.Parent = LP:WaitForChild("PlayerGui") end

local WIN_W, WIN_H = 570, 660
local win = new("Frame", {Size = UDim2.new(0, WIN_W, 0, WIN_H), Position = UDim2.new(0, 20, 0, 20), BackgroundColor3 = C.main, BorderSizePixel = 0, Active = true}, gui)
stroke(win, 2)
local uiscale = new("UIScale", {Scale = 1}, win)
do
  local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
  local sc = 1
  if vp then sc = clamp(math.min((vp.X * 0.96) / WIN_W, (vp.Y * 0.94) / WIN_H), 0.55, 1) end
  S.scale = sc; uiscale.Scale = sc
end

-- Title Bar
local title = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true}, win)
label(title, "PEARL 1024B // WANZZMIXER V5 (RIG FIX)", {Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0, 320, 1, 0), Font = Enum.Font.Code, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left})
local ctl = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(0, 220, 1, 0), Position = UDim2.new(1, -226, 0, 0)}, title)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center}, ctl)
local function setScale(v) S.scale = clamp(v, 0.4, 1.5); uiscale.Scale = S.scale; if UI.refreshFooter then UI.refreshFooter() end end
button(ctl, "A-", function() setScale(S.scale - 0.1) end, {Size = UDim2.new(0, 32, 0, 26)})
button(ctl, "A+", function() setScale(S.scale + 0.1) end, {Size = UDim2.new(0, 32, 0, 26)})
local dotBtn = button(ctl, "", nil, {Size = UDim2.new(0, 30, 0, 26)})
local dot = new("Frame", {Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0.5, -5, 0.5, -5), BackgroundColor3 = C.red, BorderSizePixel = 0}, dotBtn)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, dot)
local body = new("Frame", {Size = UDim2.new(1, 0, 1, -40), Position = UDim2.new(0, 0, 0, 40), BackgroundTransparency = 1, ClipsDescendants = true}, win)
button(ctl, "-", function(b) body.Visible = not body.Visible; win.Size = body.Visible and UDim2.new(0, WIN_W, 0, WIN_H) or UDim2.new(0, WIN_W, 0, 40); b.Text = body.Visible and "-" or "+" end, {Size = UDim2.new(0, 32, 0, 26)})
local closeBtn = button(ctl, "X", nil, {Size = UDim2.new(0, 32, 0, 26), BackgroundColor3 = C.red})

-- Drag Window
do
  local dragging, dStart, sPos = false, nil, nil
  track(title.InputBegan:Connect(function(i)
    if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and activeSlider == nil then
      dragging = true; dStart = i.Position; sPos = win.Position
    end
  end))
  track(UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
      local d = i.Position - dStart
      win.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)
    end
  end))
  track(UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
  end))
end

-- Master Bar
local master = new("Frame", {Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.panel, BorderSizePixel = 0}, body)
local masterLbl = label(master, "Master 100%", {Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(0, 86, 1, 0), Font = Enum.Font.Code, TextSize = 11})
local masterSl = mkSlider(master, 0, 100, 100, function(v) S.master = v; masterLbl.Text = "Master " .. v .. "%" end, UDim2.new(0, 175, 0, 26))
masterSl.frame.Position = UDim2.new(0, 96, 0.5, -13)
local boBtn = button(master, "Blackout", function() S.blackout = not S.blackout; UI.refreshFooter() end, {Position = UDim2.new(0, 278, 0.5, -13), Size = UDim2.new(0, 68, 0, 26)})
button(master, "Locate/ON", function()
  S.blackout = false
  for _, f in ipairs(fixtures) do
    if f.sel then
      f.dimBase = 255; f.dimOut = 255
      f.panBase = S.panCenter; f.tiltBase = S.tiltCenter
    end
  end
  if UI.syncProgramSliders then UI.syncProgramSliders() end
  UI.refreshFooter()
end, {Position = UDim2.new(0, 352, 0.5, -13), Size = UDim2.new(0, 78, 0, 26)})
button(master, "Off Semua", function() UI.offAll() end, {Position = UDim2.new(0, 436, 0.5, -13), Size = UDim2.new(0, 74, 0, 26)})

-- Navigation Tabs
local TABS = {"Fixture", "Layout", "Program", "Shape", "Chase", "Cue", "Save", "Save Param"}
local tabBar = new("Frame", {Size = UDim2.new(1, 0, 0, 42), Position = UDim2.new(0, 0, 0, 42), BackgroundTransparency = 1}, body)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center}, tabBar)
pad(tabBar, 6)
local tabBtns, tabFrames = {}, {}
local stripBar = new("Frame", {Size = UDim2.new(1, 0, 0, 42), Position = UDim2.new(0, 0, 0, 84), BackgroundColor3 = C.panel, BorderSizePixel = 0, Visible = false}, body)
local CONTENT_Y_STRIP, CONTENT_Y_NOSTRIP = 130, 88

local function switchTab(name)
  S.tab = name
  for n, f in pairs(tabFrames) do f.Visible = (n == name) end
  for n, b in pairs(tabBtns) do setActive(b, n == name) end
  local strip = (name == "Layout" or name == "Program" or name == "Shape")
  stripBar.Visible = strip
  local y = strip and CONTENT_Y_STRIP or CONTENT_Y_NOSTRIP
  for _, f in pairs(tabFrames) do
    f.Position = UDim2.new(0, 10, 0, y)
    f.Size = UDim2.new(1, -20, 1, -(y + 30))
  end
end

for _, n in ipairs(TABS) do
  tabBtns[n] = button(tabBar, string.upper(n), function() switchTab(n) end, {Size = UDim2.new(1 / #TABS, -4, 0, 30), TextSize = 9})
  local sf = new("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Size = UDim2.new(1, -20, 1, -160), Position = UDim2.new(0, 10, 0, CONTENT_Y_STRIP)}, body)
  new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, sf)
  tabFrames[n] = sf
end

-- Footer
local footer = new("Frame", {Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -26), BackgroundColor3 = C.panel, BorderSizePixel = 0}, body)
local footL = label(footer, "", {Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(0.65, 0, 1, 0), TextColor3 = C.muted, TextSize = 11})
local footR = label(footer, "", {Position = UDim2.new(0.65, 0, 0, 0), Size = UDim2.new(0.35, -8, 1, 0), TextColor3 = C.muted, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right})
function UI.refreshFooter()
  local clara, par = 0, 0
  for _, f in ipairs(fixtures) do
    if f.model.kind == "beam" then clara = clara + 1 elseif f.model.kind == "par" then par = par + 1 end
  end
  footL.Text = #fixtures .. " FIXTURE (BEAM: " .. clara .. ", PAR: " .. par .. ") | MOBIL: " .. (S.car and "TERHUBUNG" or "BELUM ADA")
  footR.Text = "PEARL V5 | SKALA: " .. round(S.scale * 100) .. "%"
  dot.BackgroundColor3 = S.car and C.green or C.red
  setActive(boBtn, S.blackout)
end

-- ============================================================
-- STRIP BAR ATAS
-- ============================================================
local stripScroll = new("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, Size = UDim2.new(0, 325, 1, 0), Position = UDim2.new(0, 68, 0, 0),
  CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X}, stripBar)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center}, stripScroll)
local stripBtns = {}
button(stripBar, "<", function() stripScroll.CanvasPosition = Vector2.new(math.max(0, stripScroll.CanvasPosition.X - 140), 0) end, {Position = UDim2.new(0, 6, 0.5, -14), Size = UDim2.new(0, 26, 0, 28)})
button(stripBar, ">", function() stripScroll.CanvasPosition = Vector2.new(stripScroll.CanvasPosition.X + 140, 0) end, {Position = UDim2.new(0, 36, 0.5, -14), Size = UDim2.new(0, 26, 0, 28)})

local function selectGroup(kind)
  for i, f in ipairs(fixtures) do
    if kind == "semua" then f.sel = true
    elseif kind == "ganjil" then f.sel = (i % 2 ~= 0)
    elseif kind == "genap" then f.sel = (i % 2 == 0) end
  end
  UI.refreshSel()
end
button(stripBar, "Semua", function() selectGroup("semua") end, {Position = UDim2.new(0, 398, 0.5, -14), Size = UDim2.new(0, 50, 0, 28)})
button(stripBar, "Ganjil", function() selectGroup("ganjil") end, {Position = UDim2.new(0, 452, 0.5, -14), Size = UDim2.new(0, 50, 0, 28)})
button(stripBar, "Genap", function() selectGroup("genap") end, {Position = UDim2.new(0, 506, 0.5, -14), Size = UDim2.new(0, 50, 0, 28)})

function UI.rebuildStrip()
  for _, b in ipairs(stripBtns) do b:Destroy() end
  stripBtns = {}
  dynamic(function()
    for i, f in ipairs(fixtures) do
      local b = button(stripScroll, tostring(i), function()
        if S.tab == "Program" and S.singleSelectPro then
          for _, fx in ipairs(fixtures) do fx.sel = false end
          f.sel = true
        else
          f.sel = not f.sel
        end
        UI.refreshSel()
        if UI.syncProgramSliders then UI.syncProgramSliders() end
      end, {Size = UDim2.new(0, 34, 0, 30), TextSize = 12, LayoutOrder = i})
      stripBtns[i] = b
    end
  end)
end

-- ============================================================
-- TAB 1: FIXTURE
-- ============================================================
local tFix = tabFrames["Fixture"]

local profBox = box(tFix, "PROFIL CHANNEL BEAM CLARA S 14R (PILIH SESUAI GERAKAN RIG)", 6)
local profGrid = grid(profBox, 1, 28, 5)
local profBtns = {}
for _, k in ipairs({"R1", "R2", "R3", "R4"}) do
  local p = BEAM_PROFILES[k]
  profBtns[k] = button(profGrid, p.label, function()
    applyBeamProfile(k)
    for pk, pb in pairs(profBtns) do setActive(pb, pk == k) end
    if UI.refreshTest then UI.refreshTest() end
  end, {Size = UDim2.new(1, 0, 1, 0), TextSize = 10})
end
setActive(profBtns["R1"], true)

local patchBox = box(tFix, "PATCHING FIXTURE BARU", 8)
local modelRow = row(patchBox, nil, 6)
local modelBtns = {}
for i, m in ipairs(MODELS) do
  modelBtns[i] = button(modelRow, m.name .. " (" .. m.ch .. "ch)", function()
    S.model = i
    for j, b in ipairs(modelBtns) do setActive(b, j == i) end
  end, {Size = UDim2.new(0, 165, 0, 28)})
end
setActive(modelBtns[1], true)

local addRow = row(patchBox, nil, 6)
label(addRow, "Jumlah:", {Size = UDim2.new(0, 52, 0, 28)})
local qtyBox = mkInput(addRow, "1", 48)
label(addRow, "DMX Mulai:", {Size = UDim2.new(0, 76, 0, 28)})
local startBox = mkInput(addRow, "", 80, nil, "auto / 1-512")

button(addRow, "+ Tambah", function()
  local qty = clamp(floor(tonumber(qtyBox.Text) or 1), 1, 100)
  local custom = tonumber(startBox.Text)
  for i = 1, qty do
    local nextDmx = 1
    if custom and i == 1 then nextDmx = floor(custom)
    elseif #fixtures > 0 then local l = fixtures[#fixtures]; nextDmx = l.dmx + l.model.ch end
    fixtures[#fixtures + 1] = newFixture(S.model, nextDmx)
  end
  UI.rebuildAll()
end, {Size = UDim2.new(0, 84, 0, 28)})

local quickRow = row(patchBox, nil, 6)
button(quickRow, "+ Patch 28 Beam (Jangkah +16)", function()
  for i = 1, 28 do
    local nextDmx = (#fixtures > 0) and (fixtures[#fixtures].dmx + fixtures[#fixtures].model.ch) or (1 + (i - 1) * 16)
    fixtures[#fixtures + 1] = newFixture(1, nextDmx)
  end
  UI.rebuildAll()
end, {Size = UDim2.new(0, 215, 0, 28)})
button(quickRow, "Auto Patch", function() autoPatch(); UI.rebuildAll() end, {Size = UDim2.new(0, 95, 0, 28)})
button(quickRow, "Hapus Semua", function()
  clearFixtures(); S.ptShape = "OFF"; S.dimShape = "OFF"; UI.rebuildAll(); UI.refreshShape()
end, {Size = UDim2.new(0, 115, 0, 28)})

local fixList
local function renderFixtureList()
  if fixList then fixList:Destroy() end
  dyn = true
  fixList = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 10}, tFix)
  new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, fixList)
  if #fixtures == 0 then
    label(fixList, "-- Kosong (Belum ada lampu di-patch) --", {Size = UDim2.new(1, 0, 0, 28), TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center})
  else
    for i, f in ipairs(fixtures) do
      local r = new("Frame", {BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, LayoutOrder = i}, fixList)
      stroke(r)
      label(r, "#" .. i .. " " .. f.model.name, {Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(0.5, 0, 1, 0)})
      local u = floor((f.dmx - 1) / 512) + 1
      label(r, "U" .. u .. " DMX", {Position = UDim2.new(1, -176, 0, 0), Size = UDim2.new(0, 60, 1, 0), TextColor3 = C.muted})
      local inp = mkInput(r, tostring(f.dmx), 64, function(t, b)
        local v = tonumber(t); if v then f.dmx = clamp(floor(v), 1, 4096) end
        b.Text = tostring(f.dmx); UI.refreshLayout()
      end)
      inp.Position = UDim2.new(1, -110, 0.5, -14)
      button(r, "X", function()
        table.remove(fixtures, i)
        for k, x in ipairs(fixtures) do x.id = k end
        UI.rebuildAll()
      end, {Position = UDim2.new(1, -38, 0.5, -14), Size = UDim2.new(0, 30, 0, 28)})
    end
  end
  dyn = false
end

-- ============================================================
-- TAB 2: LAYOUT
-- ============================================================
local tLay = tabFrames["Layout"]
local layRow = row(tLay, nil, 6)
local stage = new("Frame", {BackgroundColor3 = Color3.fromRGB(9, 9, 11), Size = UDim2.new(1, 0, 0, 315), BorderSizePixel = 0, LayoutOrder = 5, ClipsDescendants = true}, tLay)
stroke(stage, 2)
label(stage, "BELAKANG / RIGGING", {Position = UDim2.new(0.5, -80, 0, 4), Size = UDim2.new(0, 160, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.muted, TextSize = 10})
label(stage, "DEPAN / PENONTON", {Position = UDim2.new(0.5, -80, 1, -18), Size = UDim2.new(0, 160, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.muted, TextSize = 10})
local nodes = {}
function UI.refreshLayout()
  for _, n in ipairs(nodes) do n:Destroy() end
  nodes = {}
  dyn = true
  local mode = S.layoutMode
  for i, f in ipairs(fixtures) do
    local i0 = i - 1
    local x, y = 20, 40
    if mode == "baris" then x = 14 + (i0 % 14) * 35; y = 120 + floor(i0 / 14) * 44
    elseif mode == "2baris" then x = 14 + (i0 % 14) * 35; y = 40 + floor(i0 / 14) * 85
    elseif mode == "busur" then local a = (pi / (#fixtures + 1)) * i; x = 250 - cos(a) * 215; y = 40 + sin(a) * 190
    elseif mode == "grid" then x = 55 + (i0 % 7) * 58; y = 30 + floor(i0 / 7) * 50
    else
      local isPar = f.model.kind ~= "beam"
      x = 14 + (i0 % 14) * 35; y = isPar and 250 or (40 + floor(i0 / 14) * 65)
    end
    local sub = S.labelDmx and ("U" .. (floor((f.dmx - 1) / 512) + 1) .. ":" .. f.dmx) or string.sub(f.model.name, 1, 5)
    local n = button(stage, i .. "\n" .. sub, function() f.sel = not f.sel; UI.refreshSel() end,
      {Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, 33, 0, 35), TextSize = 8, TextWrapped = false})
    n.BackgroundColor3 = f.sel and C.white or C.card
    n.TextColor3 = f.sel and C.black or C.text
    nodes[#nodes + 1] = n
  end
  dyn = false
end
for _, m in ipairs({{"Baris", "baris"}, {"2 Baris", "2baris"}, {"Busur", "busur"}, {"Grid", "grid"}, {"Per tipe", "pertype"}}) do
  button(layRow, m[1], function() S.layoutMode = m[2]; UI.refreshLayout() end, {Size = UDim2.new(0, 68, 0, 28)})
end
button(layRow, "Label: Nama", function(b) S.labelDmx = not S.labelDmx; b.Text = S.labelDmx and "Label: DMX" or "Label: Nama"; UI.refreshLayout() end, {Size = UDim2.new(0, 100, 0, 28)})

-- ============================================================
-- TAB 3: PROGRAM (DENGAN TUKAR PAN/TILT & AUTO-SCAN CHANNEL)
-- ============================================================
local tPro = tabFrames["Program"]

local proQuickBox = box(tPro, "KONTROL CEPAT DIMMER & TUKAR SUMBU PAN/TILT", 8)
local pqRow = row(proQuickBox, nil, 6)
local slDim, slPan, slTilt, slStrobe, slPrisma

button(pqRow, "DIMMER ON (255)", function()
  for _, f in ipairs(fixtures) do if f.sel then f.dimBase = 255; f.dimOut = 255 end end
  if slDim then slDim.set(255) end
end, {Size = UDim2.new(0, 120, 0, 30)})

button(pqRow, "DIMMER OFF (0)", function()
  for _, f in ipairs(fixtures) do if f.sel then f.dimBase = 0; f.dimOut = 0 end end
  if slDim then slDim.set(0) end
end, {Size = UDim2.new(0, 115, 0, 30)})

-- Tombol instan tukar Pan <-> Tilt jika Ch 1 di mobil adalah Tilt dan Ch 2 adalah Pan
button(pqRow, "Tukar Pan <-> Tilt", function()
  local m = MODELS[1].map
  local tmp = m.pan
  m.pan = m.tilt
  m.tilt = tmp
  if UI.refreshTest then UI.refreshTest() end
end, {Size = UDim2.new(0, 140, 0, 30)})

button(pqRow, "Pilih 1 Eks.", function(b)
  S.singleSelectPro = not S.singleSelectPro
  b.Text = S.singleSelectPro and "1 Lampu: ON" or "Pilih 1 Eks."
  setActive(b, S.singleSelectPro)
end, {Size = UDim2.new(0, 110, 0, 30)})

local pbox = box(tPro, "FADER MANUAL FIXTURE TERPILIH (JARAK LEGA & PRESISI)", 10)
local function setSel(field, v)
  for _, f in ipairs(fixtures) do
    if f.sel then
      f[field] = v
      if field == "dimBase" then f.dimOut = v end
    end
  end
end

local vf = {}
do
  -- Fader vertikal: drag relatif (aman terhadap perbedaan koordinat inset), scroll dikunci saat drag
  local function mkVSlider(parent, init, cb, size)
    local f = new("Frame", {BackgroundTransparency = 1, Size = size, Active = true}, parent)
    local tr = new("Frame", {Size = UDim2.new(0, 10, 1, -10), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 5), BackgroundColor3 = C.input, BorderSizePixel = 0}, f)
    stroke(tr, 1.5)
    local fill = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = C.white, BorderSizePixel = 0}, tr)
    local knob = new("Frame", {Size = UDim2.new(0, 26, 0, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = C.white, BorderSizePixel = 0}, tr)
    stroke(knob, 1.5)
    local obj = {value = init, frame = f}
    local function vis(v)
      local r = clamp(v / 255, 0, 1)
      fill.Size = UDim2.new(1, 0, r, 0); knob.Position = UDim2.new(0.5, 0, 1 - r, 0)
    end
    function obj.set(v) obj.value = v; vis(v) end
    local sY, sV, lockSf
    track(f.InputBegan:Connect(function(i)
      if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and activeSlider == nil then
        activeSlider = obj; sY = i.Position.Y; sV = obj.value
        lockSf = f:FindFirstAncestorWhichIsA("ScrollingFrame")
        if lockSf then lockSf.ScrollingEnabled = false end
      end
    end))
    track(UIS.InputChanged:Connect(function(i)
      if activeSlider == obj and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local h = tr.AbsoluteSize.Y
        if h <= 0 then return end
        local v = round(clamp(sV - (i.Position.Y - sY) / h * 255, 0, 255))
        obj.value = v; vis(v)
        if cb then cb(v) end
      end
    end))
    track(UIS.InputEnded:Connect(function(i)
      if activeSlider == obj and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
        activeSlider = nil
        if lockSf then lockSf.ScrollingEnabled = true; lockSf = nil end
      end
    end))
    vis(init)
    return obj
  end

  -- {nama, field fixture, default, skala derajat (opsional)}
  local VF_DEFS = {
    {"Dimmer", "dimBase", 255}, {"Strobe", "strobeBase", 0}, {"Pan", "panBase", 128, 540}, {"Tilt", "tiltBase", 128, 270},
    {"XY Speed", "xy", 0}, {"Color", "color", 0}, {"Gobo", "gobo", 0}, {"Gobo Rot", "gorot", 0}, {"Frost", "frost", 0},
    {"Prism", "prismaBase", 0}, {"Prism 2", "prism2", 0}, {"Prism Rot", "prot", 0}, {"Focus", "focus", 0},
  }
  local bank = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 230)}, pbox)
  new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, bank)
  for idx, d in ipairs(VF_DEFS) do
    local col = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1 / #VF_DEFS, -2, 1, 0), LayoutOrder = idx}, bank)
    label(col, d[1], {Size = UDim2.new(1, 0, 0, 26), TextSize = 8, TextXAlignment = Enum.TextXAlignment.Center})
    local function fmt(v) return d[4] and (round(v / 255 * d[4]) .. "°") or tostring(round(v)) end
    local val = label(col, fmt(d[3]), {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center})
    local key = d[2]
    local o = mkVSlider(col, d[3], function(v)
      val.Text = fmt(v)
      if key == "panBase" then S.panCenter = v elseif key == "tiltBase" then S.tiltCenter = v end
      setSel(key, v)
    end, UDim2.new(1, 0, 1, -42))
    o.frame.Position = UDim2.new(0, 0, 0, 26)
    local rawSet = o.set
    o.set = function(v) rawSet(v); val.Text = fmt(v) end
    vf[key] = o
  end
end
label(pbox, "Color/Gobo/Frost/Prism 2/Prism Rot/Focus/XY baru terkirim setelah channel-nya di-set di Auto-Scan (Set Color, Set Gobo, dst).", {Size = UDim2.new(1, 0, 0, 28), TextColor3 = C.muted, TextSize = 9})
slDim = vf.dimBase; slPan = vf.panBase; slTilt = vf.tiltBase; slPrisma = vf.prismaBase; slStrobe = vf.strobeBase
-- Tombol cepat Fokus & Prisma (ke lampu terpilih, fader ikut bergerak)
for _, q in ipairs({{"FOKUS BAWAH", "focus", 0}, {"FOKUS ATAS", "focus", 255}, {"PRISMA ON", "prismaBase", 128}, {"PRISMA OFF", "prismaBase", 0}}) do
  button(pqRow, q[1], function() setSel(q[2], q[3]); vf[q[2]].set(q[3]) end, {Size = UDim2.new(0, 104, 0, 30), TextSize = 10})
end
slideRowAdv(pbox, "Merah (R)",   0, 255, 255, 5, function(v) return tostring(round(v)) end, function(v) setSel("r", v) end)
slideRowAdv(pbox, "Hijau (G)",   0, 255, 255, 5, function(v) return tostring(round(v)) end, function(v) setSel("g", v) end)
slideRowAdv(pbox, "Biru (B)",    0, 255, 255, 5, function(v) return tostring(round(v)) end, function(v) setSel("b", v) end)

function UI.syncProgramSliders()
  for _, f in ipairs(fixtures) do
    if f.sel then
      slDim.set(f.dimBase)
      slPan.set(f.panBase)
      slTilt.set(f.tiltBase)
      slPrisma.set(f.prismaBase)
      slStrobe.set(f.strobeBase)
      for _, k in ipairs(EXTRA) do if vf[k] then vf[k].set(f[k] or 0) end end
      break
    end
  end
end

-- Kotak Tes & Auto-Scan Channel
local tbox = box(tPro, "AUTO-SCAN & TES CHANNEL (CARI CHANNEL DIMMER/TILT ASLI)", 8)
label(tbox, "Klik 'Auto-Scan CH 1-16' lalu perhatikan lampu di mobil: saat lampu menyala terang atau bergerak, lihat nomor CH di bawah lalu klik 'Set Dimmer' / 'Set Tilt'!", {Size = UDim2.new(1, 0, 0, 32), TextColor3 = C.muted, TextSize = 10})
local tRow = row(tbox, nil, 6)
local tChLbl = label(tRow, "CH 1", {Size = UDim2.new(0, 60, 0, 28), TextSize = 14})
local function testModel()
  for _, f in ipairs(fixtures) do if f.sel then return f.model, f.mi end end
  return MODELS[S.model], S.model
end
function UI.refreshTest()
  local m, mi = testModel()
  S.test.ch = clamp(S.test.ch, 1, m.ch); S.model = mi
  tChLbl.Text = "CH " .. S.test.ch
  if UI.mapInfo then
    local parts = {}
    for k, v in pairs(m.map) do parts[#parts + 1] = k .. "=" .. (type(v) == "table" and table.concat(v, ",") or tostring(v)) end
    table.sort(parts)
    UI.mapInfo.Text = m.name .. " Map Aktif: " .. table.concat(parts, " | ")
  end
end
button(tRow, "- CH", function() S.test.ch = S.test.ch - 1; UI.refreshTest() end, {Size = UDim2.new(0, 48, 0, 28)})
button(tRow, "+ CH", function() S.test.ch = S.test.ch + 1; UI.refreshTest() end, {Size = UDim2.new(0, 48, 0, 28)})
local testBtn = button(tRow, "Tes: OFF", function(b)
  S.test.on = not S.test.on
  if not S.test.on then S.test.autoScan = false end
  b.Text = S.test.on and "Tes: ON" or "Tes: OFF"
  setActive(b, S.test.on)
end, {Size = UDim2.new(0, 80, 0, 28)})

local scanBtn = button(tRow, "Auto-Scan CH 1-16: OFF", function(b)
  S.test.autoScan = not S.test.autoScan
  if S.test.autoScan then
    S.test.on = true; testBtn.Text = "Tes: ON"; setActive(testBtn, true)
  end
  b.Text = S.test.autoScan and "Auto-Scan: JALAN" or "Auto-Scan CH 1-16: OFF"
  setActive(b, S.test.autoScan)
end, {Size = UDim2.new(0, 175, 0, 28)})

slideRowAdv(tbox, "Nilai Tes", 0, 255, 255, 5, function(v) return tostring(round(v)) end, function(v) S.test.val = round(v) end)
local aRow = row(tbox, nil, 6)
for _, p in ipairs({{"Set Pan", "pan"}, {"Set Tilt", "tilt"}, {"Set Dimmer", "dimmer"}, {"Set Strobe", "strobe"}, {"Set Prisma", "prisma"}}) do
  button(aRow, p[1], function()
    local m = testModel()
    m.map[p[2]] = S.test.ch
    UI.refreshTest()
  end, {Size = UDim2.new(0, 92, 0, 28)})
end
do
  local aRow2 = row(tbox, nil, 6)
  for _, p in ipairs({{"Set Color", "color"}, {"Set Gobo", "gobo"}, {"Set Gobo Rot", "gorot"}, {"Set Frost", "frost"},
    {"Set Prism 2", "prism2"}, {"Set Prism Rot", "prot"}, {"Set Focus", "focus"}, {"Set XY Spd", "xy"}}) do
    button(aRow2, p[1], function()
      local m = testModel()
      m.map[p[2]] = S.test.ch
      UI.refreshTest()
    end, {Size = UDim2.new(0, 92, 0, 28), TextSize = 10})
  end
end
UI.mapInfo = label(tbox, "", {Size = UDim2.new(1, 0, 0, 24), TextColor3 = C.muted, TextSize = 10})

-- ============================================================
-- TAB 4: SHAPE (AVOLITES PEARL 1024B SHAPE GENERATOR + ADVANCE)
-- ============================================================
local tShp = tabFrames["Shape"]

local ptBox = box(tShp, "1. PEARL 1024B PAN/TILT SHAPE GENERATOR", 8)
local ptGrid = grid(ptBox, 4, 30, 7)
local ptBtns = {}
for _, name in ipairs(PEARL_PT_SHAPES) do
  ptBtns[name] = button(ptGrid, name, function()
    S.ptShape = name
    if name ~= "OFF" then
      for _, f in ipairs(fixtures) do
        if f.sel and f.dimBase == 0 then f.dimBase = 255; f.dimOut = 255 end
      end
      if UI.syncProgramSliders then UI.syncProgramSliders() end
    end
    UI.refreshShape()
  end, {Size = UDim2.new(1, 0, 1, 0), TextSize = 10})
end

local advPtBox = box(tShp, "2. ADVANCE PARAMETER SHAPE PAN/TILT (WHEEL PEARL)", 9)
local slPanSz  = slideRowAdv(advPtBox, "Pan Size",     0, 127, S.panSize,   2, function(v) return round(v) .. " (" .. round(v/127*100) .. "%)" end, function(v) S.panSize = v end)
local slTiltSz = slideRowAdv(advPtBox, "Tilt Size",    0, 127, S.tiltSize,  2, function(v) return round(v) .. " (" .. round(v/127*100) .. "%)" end, function(v) S.tiltSize = v end)
local slPtSpd  = slideRowAdv(advPtBox, "Shape Speed",  5, 200, S.ptSpeed*100, 5, function(v) return string.format("%.2f Hz", v/100) end, function(v) S.ptSpeed = v/100 end)
local slPtSpr  = slideRowAdv(advPtBox, "Phase Spread", 0, 180, S.ptSpread,  5, function(v) return round(v) .. " deg" end, function(v) S.ptSpread = v end)
local slPtRep  = slideRowAdv(advPtBox, "Repeat Grup",  0, 14,  S.ptRepeat,  1, function(v) return (v == 0) and "Semua" or (round(v) .. " Lampu") end, function(v) S.ptRepeat = round(v) end)

local slPtSmooth = slideRowAdv(advPtBox, "Smooth", 0, 100, S.ptSmooth, 5, function(v) return round(v) .. "%" end, function(v) S.ptSmooth = v end)

local spreadQuickRow = row(advPtBox, nil, 6)
label(spreadQuickRow, "Quick Spread:", {Size = UDim2.new(0, 95, 0, 26), TextColor3 = C.muted, TextSize = 10})
for _, sp in ipairs({
  {"Even (Rata)", -1, 0},
  {"Sync (Bareng)", 0, 0},
  {"2 Grup (Odd/Ev)", 180, 2},
  {"4 Grup", 90, 4},
}) do
  button(spreadQuickRow, sp[1], function()
    local sp2 = sp[2]
    if sp2 < 0 then
      local n = 0
      for _, f in ipairs(fixtures) do if f.sel and f.model.kind == "beam" then n = n + 1 end end
      sp2 = clamp(floor(360 / math.max(n, 1)), 0, 180)
    end
    S.ptSpread = sp2; S.ptRepeat = sp[3]
    slPtSpr.set(S.ptSpread); slPtRep.set(S.ptRepeat)
  end, {Size = UDim2.new(0, 96, 0, 26), TextSize = 9})
end

local symRow = row(advPtBox, nil, 8)
local mirBtn = button(symRow, "Mirror Kiri/Kanan: OFF", function(b)
  S.mirrorPan = not S.mirrorPan
  b.Text = S.mirrorPan and "Mirror Kiri/Kanan: ON" or "Mirror Kiri/Kanan: OFF"
  setActive(b, S.mirrorPan)
end, {Size = UDim2.new(0, 165, 0, 28), TextSize = 10})

local invTiltBtn = button(symRow, "Invert Tilt Ganjil: OFF", function(b)
  S.invertOddTilt = not S.invertOddTilt
  b.Text = S.invertOddTilt and "Invert Tilt Ganjil: ON" or "Invert Tilt Ganjil: OFF"
  setActive(b, S.invertOddTilt)
end, {Size = UDim2.new(0, 165, 0, 28), TextSize = 10})

local dirBtns = {}
for _, d in ipairs({{"CW", 1}, {"CCW", -1}, {"Bounce", 0}}) do
  dirBtns[d[2]] = button(symRow, d[1], function() S.ptDir = d[2]; UI.refreshShape() end, {Size = UDim2.new(0, 52, 0, 28), TextSize = 10})
end

local dimBox = box(tShp, "3. PEARL 1024B DIMMER SHAPE GENERATOR (KELAP-KELIP)", 8)
local dimGrid = grid(dimBox, 4, 28, 6)
local dimBtns = {}
for _, name in ipairs(PEARL_DIM_SHAPES) do
  dimBtns[name] = button(dimGrid, name, function()
    S.dimShape = name
    if name ~= "OFF" then
      for _, f in ipairs(fixtures) do
        if f.sel and f.dimBase == 0 then f.dimBase = 255; f.dimOut = 255 end
      end
      if UI.syncProgramSliders then UI.syncProgramSliders() end
    end
    UI.refreshShape()
  end, {Size = UDim2.new(1, 0, 1, 0), TextSize = 9})
end
local slDimSpd = slideRowAdv(dimBox, "Dim Speed",  10, 300, S.dimSpeed*100, 10, function(v) return string.format("%.2f Hz", v/100) end, function(v) S.dimSpeed = v/100 end)
local slDimSpr = slideRowAdv(dimBox, "Dim Spread", 0,  180, S.dimSpread,    15, function(v) return round(v) .. " deg" end, function(v) S.dimSpread = v end)
local slDimRep = slideRowAdv(dimBox, "Dim Repeat", 0,  14,  S.dimRepeat,    1,  function(v) return (v == 0) and "Wave" or (round(v) .. " Grup") end, function(v) S.dimRepeat = round(v) end)

local monbox = box(tShp, "4. MONITOR LIVE & XY PREVIEW", 8)
local prevRow = row(monbox, nil, 10)
local xy = new("Frame", {BackgroundColor3 = Color3.fromRGB(9, 9, 11), Size = UDim2.new(0, 90, 0, 70), BorderSizePixel = 0}, prevRow)
stroke(xy)
local xyDot = new("Frame", {Size = UDim2.new(0, 8, 0, 8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = C.white, BorderSizePixel = 0}, xy)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, xyDot)
local liveTxt = label(prevRow, "Pan = 128 | Tilt = 128 | Dim = 255", {Size = UDim2.new(0, 380, 0, 60), TextSize = 11})

local monGrid = grid(monbox, 14, 24, 4)
local monBars = {}
local function rebuildMonitor()
  for _, c in ipairs(monGrid:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
  monBars = {}
  for i, _ in ipairs(fixtures) do
    local m = new("Frame", {BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = i}, monGrid)
    stroke(m, 1)
    label(m, tostring(i), {Size = UDim2.new(1, 0, 1, -4), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 9})
    monBars[i] = new("Frame", {BackgroundColor3 = C.white, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(0, 0, 0, 3)}, m)
  end
end

function UI.refreshShape()
  for n, b in pairs(ptBtns) do setActive(b, n == S.ptShape) end
  for n, b in pairs(dimBtns) do setActive(b, n == S.dimShape) end
  for n, b in pairs(dirBtns) do setActive(b, n == S.ptDir) end
  setActive(mirBtn, S.mirrorPan)
  setActive(invTiltBtn, S.invertOddTilt)
  slPanSz.set(S.panSize); slTiltSz.set(S.tiltSize)
  slPtSpd.set(S.ptSpeed * 100); slPtSpr.set(S.ptSpread); slPtRep.set(S.ptRepeat)
  slDimSpd.set(S.dimSpeed * 100); slDimSpr.set(S.dimSpread); slDimRep.set(S.dimRepeat)
  slPtSmooth.set(S.ptSmooth)
end

-- ============================================================
-- TAB 5: CHASE
-- ============================================================
local tCh = tabFrames["Chase"]
label(tCh, "Atur posisi/warna di tab Program, tekan + Step. Ulangi untuk posisi berikutnya. Play = jalan berurutan.", {Size = UDim2.new(1, 0, 0, 28), TextColor3 = C.muted, TextSize = 11})
local chCount = label(tCh, "", {Size = UDim2.new(1, 0, 0, 18), TextSize = 12})
local cRow = row(tCh, nil, 8)
local function snapshotStep()
  local st = {}
  for _, f in ipairs(fixtures) do st[f.id] = {pan = f.pan, tilt = f.tilt, strobe = f.strobe, prisma = f.prisma, dim = f.dimBase} end
  return st
end
function UI.refreshChase()
  chCount.Text = #S.chaseSteps .. " step" .. (#S.chaseSteps == 0 and " - belum ada step tersimpan." or (" - " .. (S.chasePlay and "PLAY (step " .. S.chaseIdx .. ")" or "berhenti")))
end
button(cRow, "+ Step", function() S.chaseSteps[#S.chaseSteps + 1] = snapshotStep(); UI.refreshChase() end, {Size = UDim2.new(0, 76, 0, 28)})
button(cRow, "Hapus step", function() S.chaseSteps[#S.chaseSteps] = nil; S.chaseIdx = 1; UI.refreshChase() end, {Size = UDim2.new(0, 96, 0, 28)})
button(cRow, "Kosongkan", function() S.chaseSteps = {}; S.chasePlay = false; S.chaseIdx = 1; UI.refreshChase() end, {Size = UDim2.new(0, 96, 0, 28)})
button(cRow, "Play", function(b) S.chasePlay = not S.chasePlay; S.chaseT = 0; b.Text = S.chasePlay and "Stop" or "Play"; setActive(b, S.chasePlay); UI.refreshChase() end, {Size = UDim2.new(0, 76, 0, 28)})
local cbox = box(tCh, "KONTROL CHASE", 10)
slideRowAdv(cbox, "Rate (BPM)", 10, 300, S.chaseBpm, 5, function(v) return round(v) .. " BPM" end, function(v) S.chaseBpm = v end)
slideRowAdv(cbox, "Crossfade",  0,  100, S.chaseCross, 5, function(v) return round(v) .. "%" end, function(v) S.chaseCross = v end)

-- ============================================================
-- TAB 6: CUE
-- ============================================================
local tCue = tabFrames["Cue"]
local cueRow1 = row(tCue, nil, 8)
local cueGridF
local cuePageLbl
local function currentLook()
  return {
    ptShape = S.ptShape, panSize = S.panSize, tiltSize = S.tiltSize,
    ptSpeed = S.ptSpeed, ptSpread = S.ptSpread, ptRepeat = S.ptRepeat,
    ptDir = S.ptDir, mirrorPan = S.mirrorPan, invertOddTilt = S.invertOddTilt,
    dimShape = S.dimShape, dimSpeed = S.dimSpeed, dimSpread = S.dimSpread, dimRepeat = S.dimRepeat,
    ptSmooth = S.ptSmooth
  }
end
local function applyLook(l)
  if type(l) ~= "table" then return end
  S.ptShape = l.ptShape or "OFF"
  S.panSize = tonumber(l.panSize) or S.panSize
  S.tiltSize = tonumber(l.tiltSize) or S.tiltSize
  S.ptSpeed = tonumber(l.ptSpeed) or S.ptSpeed
  S.ptSpread = tonumber(l.ptSpread) or S.ptSpread
  S.ptRepeat = tonumber(l.ptRepeat) or S.ptRepeat
  S.ptDir = tonumber(l.ptDir) or S.ptDir
  S.mirrorPan = l.mirrorPan and true or false
  S.invertOddTilt = l.invertOddTilt and true or false
  S.dimShape = l.dimShape or "OFF"
  S.dimSpeed = tonumber(l.dimSpeed) or S.dimSpeed
  S.dimSpread = tonumber(l.dimSpread) or S.dimSpread
  S.dimRepeat = tonumber(l.dimRepeat) or S.dimRepeat
  S.ptSmooth = tonumber(l.ptSmooth) or S.ptSmooth
  UI.refreshShape()
end
function UI.refreshCue()
  if cueGridF then cueGridF:Destroy() end
  dyn = true
  cueGridF = grid(tCue, 6, 46, 6); cueGridF.LayoutOrder = 20
  local s0 = (S.cuePage - 1) * 24 + 1
  cuePageLbl.Text = "Hal " .. S.cuePage .. "/8 (" .. s0 .. "-" .. (s0 + 23) .. ")"
  for i = s0, s0 + 23 do
    local cue = S.cues[i]
    local labelCue = cue and (cue.ptShape .. "\n" .. (cue.dimShape ~= "OFF" and cue.dimShape or "")) or "kosong"
    local b = button(cueGridF, "CUE " .. i .. "\n" .. labelCue, function()
      S.cueSel = i
      if S.cues[i] then applyLook(S.cues[i]) end
      UI.refreshCue()
    end, {Size = UDim2.new(1, 0, 1, 0), TextSize = 9, LayoutOrder = i})
    setActive(b, S.cueSel == i)
    if cue and S.cueSel ~= i then b.BackgroundColor3 = Color3.fromRGB(42, 42, 50) end
  end
  dyn = false
end
button(cueRow1, "Store Cue", function() if S.cueSel then S.cues[S.cueSel] = currentLook(); UI.refreshCue() end end, {Size = UDim2.new(0, 90, 0, 28)})
button(cueRow1, "Hapus Cue", function() if S.cueSel then S.cues[S.cueSel] = nil; UI.refreshCue() end end, {Size = UDim2.new(0, 90, 0, 28)})
button(cueRow1, "Off Semua", function() UI.offAll() end, {Size = UDim2.new(0, 90, 0, 28)})
local cueNav = row(tCue, nil, 8)
button(cueNav, "<", function() S.cuePage = S.cuePage - 1; if S.cuePage < 1 then S.cuePage = 8 end; UI.refreshCue() end, {Size = UDim2.new(0, 40, 0, 28)})
cuePageLbl = label(cueNav, "", {Size = UDim2.new(0, 150, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12})
button(cueNav, ">", function() S.cuePage = S.cuePage + 1; if S.cuePage > 8 then S.cuePage = 1 end; UI.refreshCue() end, {Size = UDim2.new(0, 40, 0, 28)})

-- ============================================================
-- TAB 7: SAVE
-- ============================================================
local tSave = tabFrames["Save"]
local sRow = row(tSave, nil, 8)
local saveName = mkInput(sRow, "", 330, nil, "Nama project (cth: Pearl_Show_Wanzz)")
local saveList
local saveInfo = label(tSave, "", {Size = UDim2.new(1, 0, 0, 18), TextColor3 = C.muted, TextSize = 11})
function UI.refreshSaves()
  if saveList then saveList:Destroy() end
  dyn = true
  saveList = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 20}, tSave)
  new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, saveList)
  local names = {}
  for n in pairs(saves) do names[#names + 1] = n end
  table.sort(names)
  saveInfo.Text = fileOk() and ("File Save: " .. FILE) or "Executor tidak mendukung file."
  for i, n in ipairs(names) do
    local r = new("Frame", {BackgroundColor3 = C.card, Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, LayoutOrder = i}, saveList)
    stroke(r)
    label(r, n, {Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -150, 1, 0)})
    button(r, "Load", function()
      applySnapshot(saves[n])
      for pk, pb in pairs(profBtns) do setActive(pb, pk == S.beamProfile) end
      UI.rebuildAll(); UI.refreshShape(); UI.refreshCue(); UI.refreshChase(); UI.syncProgramSliders()
    end, {Position = UDim2.new(1, -140, 0.5, -14), Size = UDim2.new(0, 56, 0, 28)})
    button(r, "Delete", function() saves[n] = nil; writeSavesOnly(); UI.refreshSaves() end, {Position = UDim2.new(1, -78, 0.5, -14), Size = UDim2.new(0, 62, 0, 28)})
  end
  dyn = false
end
button(sRow, "Save", function()
  local n = saveName.Text:gsub("^%s+", ""):gsub("%s+$", "")
  if n == "" then n = "Pearl_Show" end
  saves[n] = snapshotAll(); writeSavesOnly(); saveName.Text = ""; UI.refreshSaves()
end, {Size = UDim2.new(0, 76, 0, 28)})
local sRow2 = row(tSave, nil, 8)
button(sRow2, "Reset Polos Kosongan", function()
  clearFixtures(); applyBeamProfile("R1"); S.ptShape = "OFF"; S.dimShape = "OFF"; S.cues = {}; S.chaseSteps = {}
  UI.rebuildAll(); UI.refreshShape(); UI.refreshCue(); UI.refreshChase()
end, {Size = UDim2.new(0, 180, 0, 28)})

-- ============================================================
-- TAB 8: SAVE PARAM (CASE 1-30 + CASE KHUSUS WANZ)
-- ============================================================
do
  local tPar = tabFrames["Save Param"]
  label(tPar, "SAVE PARAMETER: simpan semua parameter Program (dimmer/pan/tilt/prisma/dll) + Shape ke Case 1-" .. MAX_CASES .. ". Tap slot kosong = SIMPAN, tap slot isi = PANGGIL.", {Size = UDim2.new(1, 0, 0, 40), TextColor3 = C.muted, TextSize = 10, LayoutOrder = 1})
  local info = label(tPar, "", {Size = UDim2.new(1, 0, 0, 18), TextSize = 11, LayoutOrder = 2})
  local pRow = row(tPar, nil, 6)
  pRow.LayoutOrder = 3
  local gridF

  local function snapParam()
    local fx = {}
    for i, f in ipairs(fixtures) do
      local o = {dim = f.dimBase, pan = f.panBase, tilt = f.tiltBase, strobe = f.strobeBase, prisma = f.prismaBase, r = f.r, g = f.g, b = f.b}
      for _, k in ipairs(EXTRA) do o[k] = f[k] end
      fx[i] = o
    end
    return {look = currentLook(), fx = fx, master = S.master, panCenter = S.panCenter, tiltCenter = S.tiltCenter}
  end

  local function applyParam(c)
    if type(c) ~= "table" then return end
    applyLook(c.look)
    S.master = tonumber(c.master) or S.master
    S.panCenter = tonumber(c.panCenter) or S.panCenter
    S.tiltCenter = tonumber(c.tiltCenter) or S.tiltCenter
    masterSl.set(S.master); masterLbl.Text = "Master " .. round(S.master) .. "%"
    if type(c.fx) == "table" then
      for i, o in ipairs(c.fx) do
        local f = fixtures[i]
        if f and type(o) == "table" then
          f.dimBase = tonumber(o.dim) or f.dimBase; f.dimOut = f.dimBase
          f.panBase = tonumber(o.pan) or f.panBase
          f.tiltBase = tonumber(o.tilt) or f.tiltBase
          f.strobeBase = tonumber(o.strobe) or f.strobeBase
          f.prismaBase = tonumber(o.prisma) or f.prismaBase
          f.r = tonumber(o.r) or f.r; f.g = tonumber(o.g) or f.g; f.b = tonumber(o.b) or f.b
          for _, k in ipairs(EXTRA) do f[k] = tonumber(o[k]) or f[k] end
        end
      end
    end
    UI.syncProgramSliders()
  end

  function UI.refreshPCases()
    if gridF then gridF:Destroy() end
    dyn = true
    gridF = grid(tPar, 6, 46, 6)
    gridF.LayoutOrder = 10
    local used = 0
    for i = 1, MAX_CASES do
      local c = S.pcases[i]
      if c then used = used + 1 end
      local b = button(gridF, "CASE " .. i .. "\n" .. (c and ((c.look and c.look.ptShape) or "-") or "kosong"), function()
        if S.pcases[i] then
          if S.pcDel then
            S.pcases[i] = nil; writeSavesOnly()
          else
            S.pcSel = i; applyParam(S.pcases[i])
          end
        else
          S.pcases[i] = snapParam(); S.pcSel = i; writeSavesOnly()
        end
        UI.refreshPCases()
      end, {Size = UDim2.new(1, 0, 1, 0), TextSize = 9, LayoutOrder = i})
      setActive(b, S.pcSel == i)
      if c and S.pcSel ~= i then b.BackgroundColor3 = Color3.fromRGB(42, 42, 50) end
    end
    info.Text = used .. "/" .. MAX_CASES .. " case terpakai" .. (fileOk() and "" or " (executor tanpa file: hilang saat keluar)")
    dyn = false
  end

  button(pRow, "+ Simpan Case Baru", function()
    for i = 1, MAX_CASES do
      if not S.pcases[i] then
        S.pcases[i] = snapParam(); S.pcSel = i; writeSavesOnly()
        UI.refreshPCases()
        return
      end
    end
    info.Text = "CASE PENUH (maks " .. MAX_CASES .. "), hapus dulu salah satu"
  end, {Size = UDim2.new(0, 150, 0, 28)})
  button(pRow, "Mode Hapus: OFF", function(b)
    S.pcDel = not S.pcDel
    b.Text = S.pcDel and "Mode Hapus: ON" or "Mode Hapus: OFF"
    setActive(b, S.pcDel)
  end, {Size = UDim2.new(0, 135, 0, 28)})

  -- Case khusus WANZ (hanya tampil untuk UserId 10578263919)
  if IS_WANZ then
    -- Parameter dari video tutorial Pearl 1024B: Repeat 0, Spread even, Direction "<-" (balik)
    -- Size Pearl 0-255 -> panSize 0-127 (setengah), Speed Pearl 0-255 -> Hz (speed/255)
    local WANZ_LOOKS = {
      {"FLYOUT PANGGUNG", {ptShape = "Flyout", panSize = 20, tiltSize = 20, ptSpeed = 0.20, ptSpread = "even", ptRepeat = 0, ptDir = -1, mirrorPan = false, invertOddTilt = false, dimShape = "OFF", ptSmooth = 60}},
      {"FLYOUT BESAR", {ptShape = "Flyout", panSize = 127, tiltSize = 90, ptSpeed = 0.25, ptSpread = "even", ptRepeat = 0, ptDir = -1, mirrorPan = false, invertOddTilt = false, dimShape = "OFF", ptSmooth = 60}},
    }
    local wb = box(tPar, "KHUSUS WANZ (hanya tampil di akun wanzzmanusia)", 8)
    wb.LayoutOrder = 5
    local wr = row(wb, nil, 6)
    for _, w in ipairs(WANZ_LOOKS) do
      button(wr, w[1], function()
        local look = {}
        for k, v in pairs(w[2]) do look[k] = v end
        if look.ptSpread == "even" then
          local n = 0
          for _, f in ipairs(fixtures) do if f.sel and f.model.kind == "beam" then n = n + 1 end end
          look.ptSpread = clamp(floor(360 / math.max(n, 1)), 0, 180)
        end
        applyLook(look)
        for _, f in ipairs(fixtures) do
          if f.sel and f.dimBase == 0 then f.dimBase = 255; f.dimOut = 255 end
        end
        UI.syncProgramSliders()
      end, {Size = UDim2.new(0, 160, 0, 30), TextSize = 10})
    end
  end
end

-- ============================================================
-- REFRESH & INISIALISASI
-- ============================================================
function UI.refreshSel()
  for i, f in ipairs(fixtures) do
    if stripBtns[i] then setActive(stripBtns[i], f.sel) end
  end
  UI.refreshLayout()
  UI.refreshTest()
end
function UI.rebuildAll()
  UI.rebuildStrip(); UI.refreshSel(); renderFixtureList(); rebuildMonitor(); UI.refreshFooter()
end
function UI.offAll()
  S.ptShape = "OFF"; S.dimShape = "OFF"; S.chasePlay = false
  for _, f in ipairs(fixtures) do
    f.dimBase = 0; f.dimOut = 0
    f.panBase = S.panCenter; f.tiltBase = S.tiltCenter
  end
  S.cueSel = nil
  UI.refreshShape(); UI.refreshCue(); UI.refreshChase(); UI.syncProgramSliders()
end

readSavesListOnly()
UI.rebuildAll(); UI.refreshShape(); UI.refreshCue(); UI.refreshChase(); UI.refreshSaves(); UI.refreshPCases()
masterSl.set(S.master); masterLbl.Text = "Master " .. round(S.master) .. "%"
switchTab("Fixture")
UI.refreshTest()

-- ============================================================
-- LOOP UTAMA
-- ============================================================
local acc, uiAcc, carAcc = 0, 0, 0
track(RunService.Heartbeat:Connect(function(dt)
  if not S.running then return end
  stepEffects(dt)
  acc = acc + dt
  if acc >= 1 / SEND_HZ then acc = 0; sendFrame() end
  uiAcc = uiAcc + dt
  if uiAcc >= 0.08 then
    uiAcc = 0
    local first
    for _, f in ipairs(fixtures) do if f.sel then first = f; break end end
    first = first or fixtures[1]
    if first then
      xyDot.Position = UDim2.new(clamp(first.pan / 255, 0.05, 0.95), 0, clamp(first.tilt / 255, 0.05, 0.95), 0)
      liveTxt.Text = string.format("Shape P/T: %s  |  Dim Shape: %s\nPan = %d  |  Tilt = %d  |  Dimmer = %d",
        S.ptShape, S.dimShape, round(first.pan), round(first.tilt), round(first.dimOut))
    else
      liveTxt.Text = "Belum ada fixture (Patch dulu di tab Fixture)"
    end
    if S.tab == "Shape" then
      for i, f in ipairs(fixtures) do
        local bar = monBars[i]
        if bar then
          local ratio = clamp((S.blackout and 0 or f.dimOut) / 255, 0, 1)
          bar.Size = UDim2.new(ratio, 0, 0, 3)
        end
      end
    end
  end
  carAcc = carAcc + dt
  if carAcc >= 1 then
    carAcc = 0
    remote = findRemote()
    local now = remote ~= nil
    if now ~= S.car then S.car = now; UI.refreshFooter() end
  end
end))

local function stop()
  S.running = false
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  pcall(function() gui:Destroy() end)
  if _G.WANZZMIXER and _G.WANZZMIXER.id == S.id then _G.WANZZMIXER = nil end
end
S.id = tostring(os.clock()) .. tostring(random(1, 1e6))
track(closeBtn.Activated:Connect(stop))
_G.WANZZMIXER = {stop = stop, id = S.id}
print("[WANZZMIXER V5 - PEARL 1024B EDITION] Siap!")