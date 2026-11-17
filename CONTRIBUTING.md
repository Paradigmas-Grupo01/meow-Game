# Guia de Contribuição: Meowdoku

Este documento estabelece o fluxo de trabalho, padrões de código e procedimentos de verificação para os integrantes do grupo.

---

## 1. Fluxo do Git e Branches

O repositório principal adota um fluxo baseado em branches curtas associadas às issues abertas:

- Branch principal: `main` (estável, sempre funcional e testada).
- Nomenclatura de branches:
  - Funcionalidades: `feat/<numero-da-issue>-descricao-curta` (ex.: `feat/1-regras-clpfd`)
  - Correções: `fix/<numero-da-issue>-descricao-curta` (ex.: `fix/5-decoder-json`)
  - Documentação: `docs/<numero-da-issue>-descricao-curta` (ex.: `docs/7-relatorio-secao10`)

### Passo a passo para contribuir:
1. Atualize sua branch `main` local:
   ```sh
   git checkout main
   git pull origin main
   ```
2. Crie uma nova branch a partir da `main`:
   ```sh
   git checkout -b feat/1-regras-clpfd
   ```
3. Realize suas alterações e faça commits atômicos no padrão Conventional Commits:
   - `feat: adiciona restricao de vizinhanca chebyshev em meowdoku.pl`
   - `test: adiciona casos de teste plunit para tabuleiros 6x6`
   - `fix: corrige decodificador de matriz de regioes em Api.elm`
4. Envie sua branch para o repositório remoto:
   ```sh
   git push -u origin feat/1-regras-clpfd
   ```
5. Abra um Pull Request (PR) no GitHub apontando para `main`.

---

## 2. Padrões de Código por Linguagem

### Prolog (SWI-Prolog)
- Mantenha predicados públicos declarados no cabeçalho do módulo `:- module(meowdoku, [...])`.
- Documente predicados no formato PlDoc (`%! nome(+Arg1, -Arg2) is det.`).
- Não utilize comandos imperativos com efeitos colaterais desnecessários no motor lógico.
- O código deve compilar no `swipl` sem nenhum aviso (*warning*).
- Formatação padrão com recuo de 4 espaços para cláusulas secundárias.

### Elm (0.19)
- Formatação obrigatória via `elm-format`:
  ```sh
  cd frontend
  npx elm-format src/ tests/ --yes
  ```
- O compilador não deve apresentar warnings de variáveis não utilizadas ou padrões redundantes.
- Todo novo tipo de dados deve seguir a modelagem por Custom Types, impedindo estados inválidos.
- Separe regras de negócio puras (sem dependências de Html ou Http) em submódulos de domínio.

### Python (FastAPI / Janus)
- Mantenha a camada Python restrita à integração (menos de 20% do volume total de linhas).
- Valide todas as entradas com modelos Pydantic tipados.
- Formatação no padrão PEP 8.

---

## 3. Checklist Obrigatório Antes de Abrir Pull Request

Antes de solicitar a revisão de outro membro da equipe, execute os seguintes passos localmente:

1. **Testes do Prolog:**
   ```sh
   swipl -g run_tests -t halt backend/prolog/test_meowdoku.pl
   ```
   Todos os testes devem passar com sucesso.

2. **Formatação do Elm:**
   ```sh
   cd frontend
   npx elm-format src/ --validate
   ```

3. **Verificação do Relatório Formal (se alterado):**
   ```sh
   python scripts/validar_entrega.py RELATORIO.md
   ```
   Deve retornar 0 erros.

---

## 4. Revisão de Código (Pull Requests)

- Pelo menos um outro integrante deve revisar e aprovar o PR antes do merge.
- O revisor deve verificar se o código roda localmente e se atende aos critérios de aceitação da issue relacionada.
- Use `Squash and merge` ou `Rebase and merge` para manter o histórico da branch `main` linear e organizado.

