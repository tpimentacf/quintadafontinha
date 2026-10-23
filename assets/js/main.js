document.getElementById("year").textContent = new Date().getFullYear();

const toggle = document.querySelector(".nav-toggle");
const nav = document.querySelector(".nav");
toggle.addEventListener("click", () => {
  const open = nav.classList.toggle("open");
  toggle.setAttribute("aria-expanded", open);
});
nav.querySelectorAll("a").forEach((a) =>
  a.addEventListener("click", () => nav.classList.remove("open"))
);

// Sem backend: o formulário abre o cliente de email com os dados preenchidos.
document.getElementById("contact-form").addEventListener("submit", (e) => {
  e.preventDefault();
  const f = new FormData(e.target);
  const subject = encodeURIComponent(`${f.get("assunto")} - ${f.get("nome")}`);
  const body = encodeURIComponent(`${f.get("mensagem")}\n\n${f.get("nome")} <${f.get("email")}>`);
  window.location.href = `mailto:geral@quintadafontinha.pt?subject=${subject}&body=${body}`;
});
