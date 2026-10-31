// Katib Landing Page Script

// 1. Fetch Latest Release Info from GitHub
async function fetchLatestRelease() {
  const downloadBtn = document.getElementById("downloadBtn");
  const downloadBtnText = document.getElementById("downloadBtnText");

  try {
    const res = await fetch("https://api.github.com/repos/linrol/katib/releases/latest");
    if (!res.ok) return;
    const data = await res.json();

    if (data.tag_name) {
      const version = data.tag_name;
      downloadBtnText.textContent = `下载 Katib ${version} (macOS)`;

      // Look for .dmg in assets
      const dmgAsset = data.assets?.find(a => a.name.endsWith(".dmg"));
      if (dmgAsset && dmgAsset.browser_download_url) {
        downloadBtn.href = dmgAsset.browser_download_url;
      }
    }
  } catch (e) {
    // Fallback to releases page
    console.warn("Could not fetch latest release info:", e);
  }
}

// 2. Copy Homebrew Command
function copyBrewCommand() {
  const cmd = "brew install --cask katib";
  navigator.clipboard.writeText(cmd).then(() => {
    const tip = document.getElementById("copyTip");
    tip.textContent = "已复制到剪贴板！";
    tip.style.color = "#10b981";
    setTimeout(() => {
      tip.textContent = "点击复制";
      tip.style.color = "";
    }, 2000);
  });
}

// 3. Audio Waveform Simulator
const waveformBar = document.getElementById("waveformBar");
const BAR_COUNT = 48;
const bars = [];

function initWaveform() {
  if (!waveformBar) return;
  waveformBar.innerHTML = "";
  for (let i = 0; i < BAR_COUNT; i++) {
    const col = document.createElement("div");
    col.className = "wave-column";
    waveformBar.appendChild(col);
    bars.push(col);
  }
}

let waveAnimId = null;
function animateWaveform(active = true) {
  if (!bars.length) return;
  
  bars.forEach((bar, index) => {
    if (!active) {
      bar.style.height = "6px";
      bar.style.opacity = "0.3";
      return;
    }

    const t = Date.now() / 200;
    const base = Math.sin(t + index * 0.25) * 0.5 + 0.5;
    const h = Math.max(6, Math.floor(base * 30 * (0.4 + Math.random() * 0.6)));
    bar.style.height = `${h}px`;
    bar.style.opacity = `${0.4 + (h / 30) * 0.6}`;

    // Color gradient between Cyan and Indigo
    if (index % 2 === 0) {
      bar.style.background = "#38bdf8";
    } else {
      bar.style.background = "#818cf8";
    }
  });

  if (active) {
    waveAnimId = requestAnimationFrame(() => animateWaveform(true));
  }
}

// 4. Interactive Dialogue Simulation
const dialogueSteps = [
  { source: "remote", tag: "[Remote]", text: "Could you explain how Katib captures audio without virtual sound cards?" },
  { source: "local", tag: "[Local]", text: "Katib uses ScreenCaptureKit to intercept system output directly at the OS level." },
  { source: "remote", tag: "[Remote]", text: "And the transcription latency is really under 100 milliseconds?" },
  { source: "local", tag: "[Local]", text: "Yes! SenseVoice runs fully on Apple Silicon Neural Engine without cloud hops." }
];

let demoIndex = 0;
let isDemoRunning = false;
let demoTimer = null;

function toggleDemoSimulation() {
  const btnLabel = document.getElementById("demoBtnLabel");
  const stream = document.getElementById("subtitlesStream");

  if (isDemoRunning) {
    isDemoRunning = false;
    btnLabel.textContent = "播放模拟会议对话";
    clearTimeout(demoTimer);
    if (waveAnimId) cancelAnimationFrame(waveAnimId);
    animateWaveform(false);
    return;
  }

  isDemoRunning = true;
  btnLabel.textContent = "暂停模拟演示";
  animateWaveform(true);

  // Clear stream and play step-by-step
  stream.innerHTML = "";
  demoIndex = 0;

  function nextStep() {
    if (!isDemoRunning) return;

    if (demoIndex >= dialogueSteps.length) {
      demoIndex = 0;
    }

    const item = dialogueSteps[demoIndex];
    const el = document.createElement("div");
    el.className = `sentence-item ${item.source} active`;
    el.innerHTML = `
      <span class="tag tag-${item.source}">${item.tag}</span>
      <span class="text">${item.text}</span>
      <span class="cursor-blink"></span>
    `;

    // Remove active cursor from previous children
    const prevs = stream.querySelectorAll(".sentence-item.active");
    prevs.forEach(p => {
      p.classList.remove("active");
      const blink = p.querySelector(".cursor-blink");
      if (blink) blink.remove();
    });

    stream.appendChild(el);
    stream.scrollTop = stream.scrollHeight;

    demoIndex++;
    demoTimer = setTimeout(nextStep, 2400);
  }

  nextStep();
}

// Initialize on Load
document.addEventListener("DOMContentLoaded", () => {
  fetchLatestRelease();
  initWaveform();
  animateWaveform(false);
});

