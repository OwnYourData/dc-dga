document.addEventListener("DOMContentLoaded", function () {
  const modalEl = document.getElementById("eventModal");
  if (!modalEl) return;

  modalEl.addEventListener("show.bs.modal", function (ev) {
    const button = ev.relatedTarget;
    const url = button?.getAttribute("data-url");
    const title = button?.getAttribute("data-title") || "Log details";
    const codeEl = modalEl.querySelector("#event-modal-code");
    const titleEl = modalEl.querySelector(".modal-title");

    titleEl.textContent = title;
    codeEl.textContent = "Load …";

    if (!url) {
      codeEl.textContent = "No URL available for details.";
      return;
    }

    fetch(url, { headers: { "Accept": "application/json" } })
      .then((r) => r.json())
      .then((data) => {
        codeEl.textContent = JSON.stringify(data, null, 2);
      })
      .catch((err) => {
        codeEl.textContent = `Error: ${err}`;
      });
  });
});