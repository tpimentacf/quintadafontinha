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

// Slideshows: um por secção (restaurante, casa-mae, bungalows, eventos)
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const slideshows = [...document.querySelectorAll(".slideshow")].map((root) => {
  const track = root.querySelector(".ss-track");
  const slides = [...root.querySelectorAll(".ss-slide")];
  const counter = root.querySelector(".ss-counter");
  const thumbsBox = root.querySelector(".ss-thumbs");
  const delay = parseInt(root.dataset.autoplay, 10) || 0;
  let index = 0, timer = null, visible = false, paused = false;

  // Miniaturas geradas a partir dos slides
  const thumbs = slides.map((slide, i) => {
    const img = slide.querySelector("img");
    const b = document.createElement("button");
    b.type = "button";
    b.setAttribute("role", "tab");
    b.setAttribute("aria-label", `Foto ${i + 1}: ${img.alt}`);
    b.innerHTML = `<img src="${img.getAttribute("src").replace(/\.webp$/, "-sm.webp")}" alt="" loading="lazy" width="600" height="400">`;
    b.addEventListener("click", () => { goTo(i); restart(); });
    thumbsBox.appendChild(b);
    return b;
  });

  function render() {
    counter.textContent = `${index + 1} / ${slides.length}`;
    thumbs.forEach((t, i) => t.setAttribute("aria-selected", i === index));
    const t = thumbs[index];
    thumbsBox.scrollTo({ left: t.offsetLeft - (thumbsBox.clientWidth - t.clientWidth) / 2 });
    // carregar já a foto atual e a seguinte
    [index, (index + 1) % slides.length].forEach((k) => { slides[k].querySelector("img").loading = "eager"; });
  }
  function goTo(i) {
    index = (i + slides.length) % slides.length;
    track.scrollTo({ left: index * track.clientWidth, behavior: reduceMotion ? "auto" : "smooth" });
    render();
  }
  // Sincronizar o índice quando o utilizador faz swipe/scroll
  let raf = null;
  track.addEventListener("scroll", () => {
    cancelAnimationFrame(raf);
    raf = requestAnimationFrame(() => {
      const i = Math.round(track.scrollLeft / track.clientWidth);
      if (i !== index && i >= 0 && i < slides.length) { index = i; render(); }
    });
  }, { passive: true });
  window.addEventListener("resize", () => { track.scrollTo({ left: index * track.clientWidth }); });

  root.querySelector(".ss-prev").addEventListener("click", () => { goTo(index - 1); restart(); });
  root.querySelector(".ss-next").addEventListener("click", () => { goTo(index + 1); restart(); });
  root.addEventListener("keydown", (e) => {
    if (e.key === "ArrowLeft") { e.preventDefault(); goTo(index - 1); restart(); }
    if (e.key === "ArrowRight") { e.preventDefault(); goTo(index + 1); restart(); }
  });

  // Autoplay: só quando visível, pausa com rato/foco/toque e respeita "reduzir movimento"
  function stop() { clearInterval(timer); timer = null; }
  function start() {
    stop();
    if (delay && !reduceMotion && visible && !paused && !document.hidden && !document.body.classList.contains("lb-open"))
      timer = setInterval(() => goTo(index + 1), delay);
  }
  function restart() { start(); }
  root.addEventListener("mouseenter", () => { paused = true; stop(); });
  root.addEventListener("mouseleave", () => { paused = false; start(); });
  root.addEventListener("focusin", () => { paused = true; stop(); });
  root.addEventListener("focusout", () => { paused = false; start(); });
  track.addEventListener("touchstart", () => { paused = true; stop(); }, { passive: true });
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; start(); }, { threshold: 0.4 }).observe(root);
  document.addEventListener("visibilitychange", start);

  render();
  return { root, slides, goTo, start, stop };
});

// Lightbox: abre a foto do slideshow em ecrã inteiro
(() => {
  const lb = document.getElementById("lightbox");
  const img = lb.querySelector("img");
  const cap = lb.querySelector("figcaption");
  let ss = null, links = [], index = 0, lastFocus = null;

  slideshows.forEach((s) => {
    const a = s.slides.map((sl) => sl.querySelector("a"));
    a.forEach((link, i) => link.addEventListener("click", (e) => {
      e.preventDefault();
      ss = s; links = a; open(i);
    }));
  });

  function show(i) {
    index = (i + links.length) % links.length;
    const a = links[index];
    img.src = a.getAttribute("href");
    img.alt = a.querySelector("img").alt;
    cap.textContent = `${a.dataset.caption || ""}  ·  ${index + 1}/${links.length}`;
    new Image().src = links[(index + 1) % links.length].getAttribute("href");
  }
  function open(i) {
    lastFocus = document.activeElement;
    slideshows.forEach((s) => s.stop());
    lb.hidden = false;
    document.body.classList.add("lb-open");
    show(i);
    lb.querySelector(".lb-close").focus();
  }
  function close() {
    lb.hidden = true;
    document.body.classList.remove("lb-open");
    img.src = "";
    ss?.goTo(index);           // o slideshow fica na última foto vista
    slideshows.forEach((s) => s.start());
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
  let x0 = null;
  lb.addEventListener("touchstart", (e) => { x0 = e.touches[0].clientX; }, { passive: true });
  lb.addEventListener("touchend", (e) => {
    if (x0 === null) return;
    const dx = e.changedTouches[0].clientX - x0;
    if (Math.abs(dx) > 50) show(index + (dx < 0 ? 1 : -1));
    x0 = null;
  });
})();
