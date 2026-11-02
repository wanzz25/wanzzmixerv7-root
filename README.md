# WANZZMIXER V5 - PEARL 1024B (Roblox)

Script mixer lighting (Avolites Pearl 1024B style) untuk game sound horeg. Mengirim DMX lewat `UDP_DMXDATA` milik mobil pemain.

## Isi repo

```
public/WanzzMixer.lua   # script utama (yang di-loadstring)
public/index.html       # halaman yang menampilkan loadstring + deteksi domain otomatis
vercel.json             # konfigurasi deploy Vercel
```

## Deploy ke Vercel

1. Upload isi repo ini ke GitHub (file ada di root repo, bukan di dalam folder lagi).
2. Buka vercel.com/new, pilih repo ini, lalu klik Deploy. Tanpa build command; `vercel.json` sudah mengatur folder `public`.
3. Buka domain hasil deploy. Halaman langsung menampilkan loadstring dengan domain yang terdeteksi.

Atau lewat CLI: `npx vercel --prod` di folder ini.

Format loadstring:

```lua
loadstring(game:HttpGet("https://DOMAIN-KAMU.vercel.app/WanzzMixer.lua"))()
```

Cadangan lewat GitHub raw:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/wanzz25/wanzzmixerv6-root/main/public/WanzzMixer.lua"))()
```

## Fitur tambahan di versi ini

- Shape baru yang halus: Smooth Wave, Butterfly, Breathe Fan, Ripple, plus slider **Smooth** (peredaman gerakan).
- Tab **SAVE PARAM** (paling kanan di bar): Case 1-30 menyimpan semua parameter Program + Shape. Tap slot kosong = simpan, tap slot isi = panggil, Mode Hapus untuk menghapus.
- Fader Program gaya panel: Dimmer, Strobe, Pan, Tilt, XY Speed, Color, Gobo, Gobo Rot, Frost, Prism, Prism 2, Prism Rot, Focus. Channel tambahan baru terkirim setelah di-set lewat Auto-Scan (Set Color, Set Gobo, dst).
- Case khusus WANZ (Flyout Panggung) hanya tampil untuk UserId 10578263919.
- Case tersimpan di file executor (`wanzzmixer_v5_pearl.json`), jadi terpisah per pengguna.
