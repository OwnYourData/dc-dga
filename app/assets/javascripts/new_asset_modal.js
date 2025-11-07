function currentTheme() {
  return document.documentElement.getAttribute('data-bs-theme') || 'light';
}

function withParam(url, k, v) {
  const u = new URL(url, window.location.origin); 
  u.searchParams.set(k, v); 
  return u.toString();
}

function sendThemeToIframe(theme) {
  const frame = document.getElementById('asset-wizard-iframe');
  frame?.contentWindow?.postMessage({ type: 'jsonforms-theme', theme }, SOYA_FORM_HOST);
}

function initAssetWizard() {
  const root = document.getElementById("asset-ui");
  if (!root) { console.warn("[asset_wizard] #asset-ui not found"); return; }

  const embedEndpoint = root.dataset.embedUrl;
  const modalEl    = document.getElementById("assetWizardModal");
  const modalTitle = document.getElementById("assetWizardTitle");
  const iframe     = document.getElementById("asset-wizard-iframe");

  if (!modalEl || !iframe) { console.warn("[asset_wizard] modal/iframe missing"); return; }
  document.addEventListener("click", (e) => {
    const link = e.target.closest("[data-asset-kind]");
    if (!link) return;
    if (!root.contains(link)) return;
    e.preventDefault();
    const kind  = link.getAttribute("data-asset-kind");
    const title = link.textContent.trim();
    fetch(`${embedEndpoint}?kind=${encodeURIComponent(kind)}`, {
      headers: { "Accept": "application/json" },
      credentials: "same-origin"
    })
      .then((r) => {
        return r.json();
      })
      .then((data) => {
        if (!data.url) throw new Error(data.error || "No URL from server");
        modalTitle.textContent = title;
        const theme = currentTheme();
        iframe.src = withParam(data.url, 'theme', theme);

        const metaInput = document.querySelector('#asset-meta, #asset_meta, input[name="meta"]');
        if (metaInput) metaInput.value = JSON.stringify({ schema: data.schema });

        const modal = window.bootstrap.Modal.getOrCreateInstance(modalEl);
        modal.show();
      })
      .catch((err) => {
        console.error("[asset_wizard] error", err);
        alert("Could not open wizard: " + err.message);
      });
  });
  document.addEventListener("click", (e) => {
    const btn = e.target.closest('button[data-bs-target="#assetWizardModal"][data-embed-url],a[data-bs-target="#assetWizardModal"][data-embed-url]');
    if (!btn) return;
    e.preventDefault();
    console.log('hello world');
    const url = btn.dataset.embedUrl;
    console.log(url);
    const title = btn.getAttribute("data-title");
    fetch(`${url}`, {
      headers: { "Accept": "application/json" },
      credentials: "same-origin"
    })
      .then((r) => {
        return r.json();
      })
      .then((data) => {
        if (!data.url) throw new Error(data.error || "No URL from server");
        modalTitle.textContent = title || "";
        const theme = currentTheme();
        iframe.src = withParam(data.url, 'theme', theme);

        const metaInput = document.querySelector('#asset-meta, #asset_meta, input[name="meta"]');
        if (metaInput) metaInput.value = JSON.stringify({ schema: data.schema, id: data.id });

        const modal = window.bootstrap.Modal.getOrCreateInstance(modalEl);
        modal.show();
      })
      .catch((err) => {
        console.error("[asset_wizard] error", err);
        alert("Could not open wizard: " + err.message);
      });
  });  
  modalEl.addEventListener("hidden.bs.modal", () => { iframe.src = ""; });
}

const obs = new MutationObserver(() => sendThemeToIframe(currentTheme()));
obs.observe(document.documentElement, { attributes: true, attributeFilter: ['data-bs-theme'] });
document.addEventListener("DOMContentLoaded", initAssetWizard);
document.addEventListener("DOMContentLoaded", autoOpenFromFlash);

function autoOpenFromFlash() {
  const marker = document.getElementById("autostart-modal");
  if (!marker) return;

  const kind    = marker.dataset.kind;
  const assetId = marker.dataset.assetId;
  const modal     = bootstrap.Modal.getOrCreateInstance(marker);
  modal.show();

}