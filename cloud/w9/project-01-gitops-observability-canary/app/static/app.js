async function refreshStatus() {
  const frontend = document.querySelector("#frontend-status");
  const backend = document.querySelector("#backend-status");
  const version = document.querySelector("#app-version");

  try {
    const response = await fetch("/api/status", { cache: "no-store" });
    const data = await response.json();

    frontend.textContent = data.frontend || "healthy";
    backend.textContent = response.ok ? data.backend : "degraded";
    version.textContent = data.version || "unknown";
    backend.classList.toggle("bad", !response.ok);
  } catch (error) {
    frontend.textContent = "available";
    backend.textContent = "unreachable";
    backend.classList.add("bad");
  }
}

refreshStatus();
setInterval(refreshStatus, 10000);
