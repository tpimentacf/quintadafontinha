document.getElementById("year").textContent = new Date().getFullYear();

// Menu mobile
const toggle = document.querySelector(".nav-toggle");
const nav = document.querySelector(".nav");
toggle.addEventListener("click", () => {
  const open = nav.classList.toggle("open");
  toggle.setAttribute("aria-expanded", open);
});
nav.querySelectorAll("a").forEach((a) =>
  a.addEventListener("click", () => nav.classList.remove("open"))
);

// Botões "Pedir reserva" / "Pedir orçamento" pré-selecionam o assunto
document.querySelectorAll("[data-subject]").forEach((btn) =>
  btn.addEventListener("click", () => {
    document.getElementById("assunto").value = btn.dataset.subject;
  })
);

// Formulário: sem backend, abre o cliente de email com os dados preenchidos
document.getElementById("contact-form").addEventListener("submit", (e) => {
  e.preventDefault();
  const f = new FormData(e.target);
  const subject = encodeURIComponent(`${f.get("assunto")} - ${f.get("nome")}`);
  const body = encodeURIComponent(`${f.get("mensagem")}\n\n${f.get("nome")} <${f.get("email")}>`);
  window.location.href = `mailto:geral@quintadafontinha.pt?subject=${subject}&body=${body}`;
});

// Lightbox: agrupa as fotos por data-gallery (restaurante, casa-mae, bungalows, eventos)
(() => {
  const lb = document.getElementById("lightbox");
  const img = lb.querySelector("img");
  const cap = lb.querySelector("figcaption");
  const groups = {};
  let current = [], index = 0, lastFocus = null;

  document.querySelectorAll(".gallery a, a.split-media").forEach((a) => {
    const g = a.dataset.gallery || a.closest("[data-gallery]")?.dataset.gallery || "default";
    (groups[g] ||= []).push(a);
    a.addEventListener("click", (e) => {
      e.preventDefault();
      current = groups[g];
      open(current.indexOf(a));
    });
  });

  function show(i) {
    index = (i + current.length) % current.length;
    const a = current[index];
    img.src = a.getAttribute("href");
    img.alt = a.querySelector("img")?.alt || "";
    cap.textContent = `${a.dataset.caption || ""}  ·  ${index + 1}/${current.length}`;
    // pré-carregar a seguinte
    new Image().src = current[(index + 1) % current.length].getAttribute("href");
  }
  function open(i) {
    lastFocus = document.activeElement;
    lb.hidden = false;
    document.body.classList.add("lb-open");
    show(i);
    lb.querySelector(".lb-close").focus();
  }
  function close() {
    lb.hidden = true;
    document.body.classList.remove("lb-open");
    img.src = "";
    lastFocus?.focus();
  }

  lb.querySelector(".lb-close").addEventListener("click", close);
  lb.querySelector(".lb-prev").addEventListener("click", () => show(index - 1));
  lb.querySelector(".lb-next").addEventListener("click", () => show(index + 1));
  lb.addEventListener("click", (e) => { if (e.target === lb) close(); });
  document.addEventListener("keydown", (e) => {
    if (lb.hidden) return;
    if (e.key === "Escape") close();
    if (e.key === "ArrowLeft") show(index - 1);
    if (e.key === "ArrowRight") show(index + 1);
  });

  // Swipe em telemóvel
  let x0 = null;
  lb.addEventListener("touchstart", (e) => { x0 = e.touches[0].clientX; }, { passive: true });
  lb.addEventListener("touchend", (e) => {
    if (x0 === null) return;
    const dx = e.changedTouches[0].clientX - x0;
    if (Math.abs(dx) > 50) show(index + (dx < 0 ? 1 : -1));
    x0 = null;
  });
})();
