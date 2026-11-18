// Ponto de entrada JavaScript. O Vite começa por aqui (veja index.html).
// Escolha UM dos dois estilos (as classes são as mesmas nos dois):
//   style.css          visual completo: temas próprios, fontes, gradientes,
//                      animações e várias técnicas de CSS moderno
//   style-simples.css  visual minimalista, quase só com @apply do Tailwind;
//                      um ponto de partida mais fácil de entender e modificar
import "./style.css";
// import "./style-simples.css";
import "./meowdoku.css";

// O vite-plugin-elm permite importar um módulo Elm como se fosse JS: ele
// compila src/Main.elm e recompila a cada alteração (hot reload).
import { Elm } from "./Main.elm";

// Tema inicial: a última escolha do jogador (guardada no localStorage do
// navegador) ou, na primeira visita, a preferência do sistema operacional.
const THEME_KEY = "sudoku-theme";
const savedTheme = localStorage.getItem(THEME_KEY);
const systemIsDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
const darkTheme = savedTheme ? savedTheme === "dark" : systemIsDark;

if (darkTheme) {
  document.documentElement.setAttribute("data-theme", "dark");
  document.body.classList.add("dark-theme");
} else {
  document.documentElement.setAttribute("data-theme", "light");
  document.body.classList.remove("dark-theme");
}

// `flags` é entregue à função `init` do Elm (veja o tipo Flags em Main.elm).
Elm.Main.init({
  node: document.getElementById("app"),
  flags: { darkTheme },
});

document.addEventListener("click", (event) => {
  const btn = event.target.closest(".btn-theme");
  if (btn) {
    const choice = btn.getAttribute("data-theme-choice");
    if (choice) {
      const isDark = choice === "dark";
      localStorage.setItem(THEME_KEY, choice);
      document.documentElement.setAttribute("data-theme", choice);
      if (isDark) {
        document.body.classList.add("dark-theme");
      } else {
        document.body.classList.remove("dark-theme");
      }
    }
  }
});
