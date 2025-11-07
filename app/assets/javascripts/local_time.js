document.addEventListener("DOMContentLoaded", () => {
  const locale = document.documentElement.dataset.locale || navigator.language;

  document.querySelectorAll("time.js-local-time").forEach(el => {
    const dt = el.getAttribute("datetime");
    if (!dt) return;
    const d = new Date(dt);

    let text;

    if (locale.startsWith("de")) {
      const pad = n => String(n).padStart(2, "0");
      text = `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} ` +
             `${pad(d.getHours())}:${pad(d.getMinutes())}`;
    } else {
      const fmt = new Intl.DateTimeFormat("en-US", {
        year: "numeric",
        month: "long",
        day: "numeric",
        hour: "numeric",
        minute: "2-digit",
        hour12: true
      });
      const parts = fmt.formatToParts(d);
      const get = type => parts.find(p => p.type === type)?.value || "";
      text = `${get("month")} ${get("day")}, ${get("year")} ${get("hour")}:${get("minute")} ${get("dayPeriod")}`;
    }

    el.textContent = text;
  });
});