# Guia de Distribuição e Execução: Meowdoku (7 Integrantes)
**Disciplina:** Paradigmas de Programação (UnB/FGA)  
**Projeto:** Trabalho Final em Grupo (34% da Nota)  
**Classificação de Escopo:** *Remix Original* ($\Delta = +0{,}5$ bônus)

---

## 1. Distribuição de Papéis para os 7 Integrantes

Esta tabela deve ser transposta para a **Seção 10 do `RELATORIO.md`**. Cada integrante possui propriedade clara de arquivos e código, o que blinda o grupo na **avaliação 360 graus** e na **arguição oral individual** do professor:

| Integrante | Papel no Projeto | Arquivos Principais | O que defender na apresentação oral? |
| :--- | :--- | :--- | :--- |
| **Membro 1** | *Motor de Restrições CLP(FD)* | `backend/prolog/meowdoku.pl`<br>`backend/prolog/test_meowdoku.pl` | Explicar como as variáveis binárias `0..1` são criadas, como a restrição de não-adjacência $A + B \le 1$ modela a distância de Chebyshev e como funciona o `labeling/2`. |
| **Membro 2** | *Algoritmo de Dicas & Unicidade* | `backend/prolog/meowdoku.pl`<br>(seções de `hint` e `generate`) | Explicar como a dedução do Smart Hint identifica a causa da restrição e como o `findall/3` com limite 2 garante que o puzzle gerado tem solução única. |
| **Membro 3** | *Arquiteto da Ponte Python/Janus* | `backend/app/meowdoku_prolog.py`<br>`backend/app/main.py`<br>`backend/tests/` | Explicar como o `janus` embute o SWI-Prolog no processo Python, como os tipos de dados são mapeados entre Python e Prolog e por que o Python não tem lógica de jogo. |
| **Membro 4** | *Engenheiro de Domínio Elm* | `frontend/src/Meowdoku.elm` | Explicar os Custom Types (`CellMark`, `Cell`, `Board`), a imutabilidade do modelo e como a função pura `checkConflicts` detecta erros instantaneamente. |
| **Membro 5** | *Engenheiro de API & HTTP Elm* | `frontend/src/Api.elm`<br>`frontend/src/Main.elm` (update) | Explicar o ciclo de comandos assíncronos (`Cmd Msg`), decodificadores JSON (`meowdokuPuzzleDecoder`, `meowdokuHintDecoder`) e tratamento de erros do `Http.Error`. |
| **Membro 6** | *Designer de UI/UX & Interações* | `frontend/src/Main.elm` (view)<br>`frontend/src/style.css` | Explicar a renderização da grade em CSS Grid/SVG, paleta de cores pastéis para regiões, animações de feedback visual e ciclo de cliques do mouse. |
| **Membro 7** | *QA, Validador & Relatório* | `RELATORIO.md`<br>`scripts/validar_entrega.py`<br>`frontend/tests/` | Explicar a suite de testes automatizados, conformidade formal do relatório no validador e síntese comparativa dos dois paradigmas (Seção 13). |

---

## 2. Como Rodar o Ponto de Partida

### Terminal 1: Backend (FastAPI + SWI-Prolog)
```sh
cd backend
# Se tiver o uv instalado:
uv sync
uv run fastapi dev app/main.py

# Ou com Python padrão:
python -m venv .venv
# Ativar venv (.venv\Scripts\activate no Windows ou source .venv/bin/activate no Linux)
pip install fastapi uvicorn pydantic janus-swi
python -m uvicorn app.main:app --reload --port 8000
```
* Swagger da API disponível em: **http://localhost:8000/docs**
* Teste da rota Meowdoku: `GET http://localhost:8000/api/meowdoku/example`

### Terminal 2: Frontend (Vite + Elm)
```sh
cd frontend
npm install
npm run dev
```
* O jogo abre em: **http://localhost:5173**
* O Vite repassa chamadas `/api/...` diretamente para o backend na porta 8000.

### Terminal 3: Testes de Prolog (plunit)
```sh
swipl -g run_tests -t halt backend/prolog/test_meowdoku.pl
```

---

## 3. Antes de Entregar: Validador Obrigatório

Na raiz do repositório, rode:
```sh
python scripts/validar_entrega.py RELATORIO.md
```
Ele garante que:
- Não sobraram comentários `<!-- ... -->` de instrução.
- Nenhum colchete `[...]` ficou sem preenchimento.
- Todas as 13 seções e subseções estão presentes e válidas.
- Todos os 7 integrantes constam na tabela da Seção 1 e Seção 10.
