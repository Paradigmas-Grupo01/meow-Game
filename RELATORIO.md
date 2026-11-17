# Meowdoku

## 1. Identificação

| Nome completo | Matrícula | Turma (14h/16h) | Usuário GitHub |
|---------------|-----------|-----------------|----------------|
| Gabriel Santos Monteiro | 221021975 | 16h | @GabrielSMonteiro |
| Ana Luíza Fernandes | 221000002 | 16h | @analufernanndess |
| Cayo Alencar | 221000003 | 16h | @Cayoalencar |
| Gabriel Marques de Souza | 221000004 | 16h | @GabrielMS00 |
| Paola Nascimento | 221000005 | 16h | @paolaalim |
| Renata Quadros Kurzawa | 211063013 | 16h | @RenataKurzawa |
| Tales R. G. | 221000007 | 16h | @TalesRG |

- **Nome do projeto:** Meowdoku
- **Nome do grupo:** Grupo 01 - Meowdoku
- **Repositório:** https://github.com/Paradigmas-Grupo01/meow-Game
- **Commit ou tag entregue:** `543cf33`
- **Ponto de partida:** remix original
- **Slides da apresentação oral:** não há

## 2. Resumo

O Meowdoku adapta a mecânica de jogos lógicos como Star Battle e Queens para um tema felino. O jogador recebe um tabuleiro quadrado dividido em regiões coloridas e precisa posicionar uma quantidade determinada de gatos em cada linha, coluna e território, com a condição obrigatória de que nenhum gato toque outro, nem mesmo pelas diagonais. Todas as regras de posicionamento, a resolução do tabuleiro e as deduções de dicas foram desenvolvidas em SWI-Prolog utilizando programação lógica por restrições com CLP(FD), enquanto a interface visual e a resposta às interações do usuário foram implementadas em Elm.

![Captura de tela do sistema](docs/captura.png)

## 3. Como executar

**Requisitos** (com as versões que o grupo usou):

- SWI-Prolog 9.x ou 10.x
- Node.js 20.x
- Python 3.11 ou superior com FastAPI e Uvicorn

**Instalação e execução:**

```sh
# Terminal 1: Backend FastAPI com SWI-Prolog
cd backend
python -m venv .venv
# Ativação do ambiente: .venv\Scripts\activate no Windows ou source .venv/bin/activate no Linux/macOS
pip install fastapi uvicorn pydantic janus-swi
python -m uvicorn app.main:app --reload --port 8000

# Terminal 2: Frontend Elm com Vite
cd frontend
npm install
npm run dev
```

A interface web pode ser acessada no navegador pelo endereço `http://localhost:5173`. A documentação interativa das rotas da API pode ser consultada em `http://localhost:8000/docs`.

**Testes:**

```sh
# Testes em Prolog com plunit
swipl -g run_tests -t halt backend/prolog/test_meowdoku.pl

# Testes de integração em Python com pytest
pytest backend/tests/test_api.py
```

**Testado em:** Windows 11 e Linux Ubuntu 22.04, Google Chrome

## 4. Arquitetura

A aplicação é dividida em três camadas com papéis bem definidos. No navegador, o frontend em Elm renderiza o tabuleiro e gerencia as ações do usuário. Quando é necessário iniciar uma partida, pedir uma dica dedutiva ou calcular a solução completa, o frontend envia requisições HTTP para a API em FastAPI. O módulo em Python atua como intermediário sem lógica própria de jogo, repassando os dados via biblioteca Janus diretamente para o SWI-Prolog, onde as restrições lógicas são avaliadas.

```
[Elm (Frontend)] --HTTP/JSON--> [FastAPI (Python)] --janus--> [SWI-Prolog (CLP/FD)]
```

| Parte | Responsabilidade | Arquivos principais |
|---|---|---|
| Prolog | Modela o problema com CLP(FD), resolve o tabuleiro via labeling, valida partidas completas e deduz dicas de jogada | `backend/prolog/meowdoku.pl`, `backend/prolog/test_meowdoku.pl` |
| Elm | Renderiza a grade no padrão TEA, controla cliques nas células, atualiza o estado e calcula conflitos locais imediatos | `frontend/src/Meowdoku.elm`, `frontend/src/Main.elm`, `frontend/src/Api.elm` |
| Python | Fornece as rotas REST em FastAPI, valida tipos com Pydantic e se comunica em memória com o SWI-Prolog pelo Janus | `backend/app/main.py`, `backend/app/meowdoku_prolog.py` |

## 5. Parte em Prolog

### 5.1 Predicados principais

| Predicado | Local | O que faz |
|---|---|---|
| `solve(+Regions, +CatsPerUnit, -Solution)` | `backend/prolog/meowdoku.pl:15` | Recebe a matriz de regiões e a quantidade de gatos por unidade, devolvendo uma matriz binária com as posições dos gatos que respeitam todas as restrições. |
| `valid_solution(+Regions, +Board, +CatsPerUnit)` | `backend/prolog/meowdoku.pl:83` | Confere deterministicamente se um tabuleiro preenchido cumpre todas as regras do jogo, sem disparar busca por rotulação. |
| `enforce_no_touch(+Grid)` | `backend/prolog/meowdoku.pl:55` | Percorre a grade por recursão e impõe a inequação `A + B #=< 1` entre todas as células vizinhas ortogonais e diagonais. |
| `hint(+Regions, +Board, +CatsPerUnit, -Hint)` | `backend/prolog/meowdoku.pl:118` | Analisa a situação atual da partida e sugere uma jogada fundamentada, retornando a posição, o valor e uma explicação textual. |
| `has_unique_solution(+Regions, +CatsPerUnit)` | `backend/prolog/meowdoku.pl:115` | Testa se um mapa possui uma única solução possível, buscando no máximo duas respostas com `findall/3`. |
| `example_puzzle(+Name, -Size, -CatsPerUnit, -Regions)` | `backend/prolog/meowdoku.pl:170` | Contém tabuleiros de teste prontos para os tamanhos 6x6 e 8x8 no modo clássico e 8x8 no modo com dois gatos por região. |

### 5.2 Conceitos do paradigma lógico utilizados

- [x] Fatos e regras como base de conhecimento: banco de tabuleiros pré-configurados e regras de dedução textual de dicas em `backend/prolog/meowdoku.pl:170-199`.
- [x] Unificação e casamento de padrões: desestruturação de listas de coordenadas e termos compostos em `backend/prolog/meowdoku.pl:48-53`.
- [x] Recursão (inclusive sobre listas): percurso sistemático da grade por meio de `enforce_rows/4` e `enforce_cols/4` em `backend/prolog/meowdoku.pl:60-68`.
- [x] Backtracking e múltiplas soluções: busca com rotulação `labeling([ff, bisect], Cells)` para encontrar atribuições válidas em `backend/prolog/meowdoku.pl:28`.
- [x] `findall/3`, `bagof/3`, `setof/3` ou similares: contagem limitada de soluções para comprovar unicidade em `has_unique_solution/2` em `backend/prolog/meowdoku.pl:115`.
- [x] Corte (`!`) ou negação (`\+`), e por que foram necessários: uso de corte em `filter_cells_by_region/4` (`backend/prolog/meowdoku.pl:50`) e na seleção da dica prioritária em `hint/4` (`backend/prolog/meowdoku.pl:126`), evitando buscas desnecessárias após encontrar o resultado pretendido.
- [x] Programação por restrições (CLP(FD) ou outra): definição do domínio binário `0..1`, somatórios de linha, coluna e região com `#=`, e restrições de vizinhança com `#=<` em `backend/prolog/meowdoku.pl:21-27`.
- [x] Predicados de ordem superior (`maplist`, `foldl`, `include` e correlatos): aplicação uniforme de restrições em matrizes usando `maplist/2` e `maplist/3` em `backend/prolog/meowdoku.pl:19-24`.

### 5.3 Trecho em destaque

```prolog
constrain_neighbors(Grid, R, C, N) :-
    get_cell(Grid, R, C, CellA),
    C1 is C + 1,
    ( C1 < N -> get_cell(Grid, R, C1, CellR), CellA + CellR #=< 1 ; true ),
    R1 is R + 1,
    ( R1 < N -> get_cell(Grid, R1, C, CellD), CellA + CellD #=< 1 ; true ),
    ( (R1 < N, C1 < N) -> get_cell(Grid, R1, C1, CellDR), CellA + CellDR #=< 1 ; true ),
    C0 is C - 1,
    ( (R1 < N, C0 >= 0) -> get_cell(Grid, R1, C0, CellDL), CellA + CellDL #=< 1 ; true ).
```

Escolhemos esse trecho do arquivo `backend/prolog/meowdoku.pl` (linhas 70 a 79) porque ele resolve a regra de não adjacência de forma declarativa e direta. Em vez de escrever laços imperativos checando se as células vizinhas contêm gatos, representamos cada posição como uma variável binária (0 ou 1) e impomos a inequação `CellA + CellB #=< 1` para cada par de casas adjacentes. Como os valores só podem ser 0 ou 1, a soma nunca permite que dois gatos fiquem lado a lado ou na mesma diagonal.

Durante o desenvolvimento, tentamos inicialmente aplicar essa restrição usando `forall/2`, mas descobrimos que a semântica de negação por falha do `forall` desfazia as restrições de CLP(FD) ao retroceder. Reescrevemos a varredura com recursão determinística sobre os índices de linhas e colunas. Dessa forma, as restrições permanecem ativas na base de restrições do solver durante toda a rotulação (`labeling`), fazendo com que qualquer gato colocado propague imediatamente o valor 0 para todas as oito casas ao redor.

## 6. Parte em Elm

### 6.1 Modelo e mensagens

```elm
type CellMark
    = Empty
    | MarkedX
    | HasCat

type alias Cell =
    { row : Int
    , col : Int
    , regionId : Int
    , mark : CellMark
    , hasConflict : Bool
    }

type alias Board =
    { size : Int
    , cells : List Cell
    , catsPerUnit : Int
    }

type Msg
    = NewGame Difficulty
    | GotPuzzle (Result String Board)
    | CellClicked Position
    | HintRequested
    | GotHint (Result String Api.Hint)
    | SolveRequested
    | GotSolution (Result String Board)
    | ResetRequested
```

No módulo `frontend/src/Meowdoku.elm`, criamos o tipo `CellMark` com os construtores `Empty`, `MarkedX` e `HasCat`. Essa escolha garante que uma casa do tabuleiro só possa estar em um desses três estados por vez. Se tivéssemos usado valores booleanos separados para marcar o X e o gato, precisaríamos checar manualmente em vários pontos do código se uma mesma casa não ficou marcada com X e com gato ao mesmo tempo.

Para as mensagens que envolvem chamadas de rede, como `GotPuzzle` e `GotHint`, utilizamos o tipo `Result String a`. Isso obriga a função `update` a tratar tanto o caso em que a resposta chega com sucesso quanto os cenários de erro, como falha de conexão ou tabuleiro inválido, sem deixar exceções estourarem na tela.

### 6.2 Conceitos do paradigma funcional utilizados

- [x] Arquitetura Elm (Model, update, view): organização da aplicação no ciclo reativo padrão em `frontend/src/Main.elm:38-46`.
- [x] Custom types e `case` exaustivo: modelagem das marcações com `CellMark` e correspondência exaustiva de padrões em `frontend/src/Meowdoku.elm:18-35`.
- [x] `Maybe` e `Result` no lugar de null e exceções: busca de casas com `getCell` retornando `Maybe Cell` em `frontend/src/Meowdoku.elm:63` e retorno de requisições com `Result String a` em `frontend/src/Api.elm:160-180`.
- [x] Funções de ordem superior e aplicação parcial: contagem de gatos por linha, coluna e região usando `List.filter` e `List.length` em `frontend/src/Meowdoku.elm:108-128`.
- [x] Composição (`|>`, `>>`): encadeamento de transformações na montagem inicial do tabuleiro e na validação em `frontend/src/Meowdoku.elm:45-56`.
- [x] Decoders e encoders JSON: decodificação das respostas da API usando `Decode.map3` em `frontend/src/Api.elm:143-149`.
- [x] Comandos e subscriptions (efeitos controlados): envio de requisições HTTP assíncronas encapsuladas em comandos `Cmd Msg` em `frontend/src/Api.elm:215-220`.
- [x] Imutabilidade e atualização de records: atualização do estado do tabuleiro gerando novas instâncias com `{ board | cells = updatedCells }` em `frontend/src/Meowdoku.elm:94`.

### 6.3 Trecho em destaque

```elm
checkConflicts : Board -> Board
checkConflicts board =
    let
        catCells =
            List.filter (\cell -> cell.mark == HasCat) board.cells

        touchesAnotherCat cell =
            if cell.mark /= HasCat then
                False
            else
                catCells
                    |> List.any
                        (\other ->
                            (cell.row /= other.row || cell.col /= other.col)
                                && (abs (cell.row - other.row) <= 1)
                                && (abs (cell.col - other.col) <= 1)
                        )

        exceedsUnit cell =
            if cell.mark /= HasCat then
                False
            else
                (countCatsInRow cell.row board > board.catsPerUnit)
                    || (countCatsInCol cell.col board > board.catsPerUnit)
                    || (countCatsInRegion cell.regionId board > board.catsPerUnit)

        updatedCells =
            List.map
                (\cell ->
                    { cell | hasConflict = touchesAnotherCat cell || exceedsUnit cell }
                )
                board.cells
    in
    { board | cells = updatedCells }
```

O trecho em destaque faz parte do arquivo `frontend/src/Meowdoku.elm` (linhas 132 a 167) e implementa a verificação de conflitos diretamente no frontend. A função `checkConflicts` recebe o tabuleiro atual e devolve uma nova versão com a propriedade `hasConflict` atualizada em cada casa, sem alterar o estado original na memória.

Para cada casa que contém um gato, a função verifica se existe outro gato na vizinhança de Chebyshev, calculando se a distância entre linhas e colunas é menor ou igual a 1. Também confere se a linha, a coluna ou a região ultrapassaram a quantidade máxima permitida de gatos. Usando `List.map` e funções anônimas, o código gera a lista atualizada de células e a interface reflete esses conflitos imediatamente na cor vermelha, dando retorno visual ao jogador a cada clique.

## 7. Integração

A comunicação entre a interface em Elm e o motor em Prolog é intermediada por rotas REST em FastAPI. A camada em Python não possui regras do jogo; ela apenas recebe o JSON da requisição, valida os campos com Pydantic e chama os predicados correspondentes no Prolog usando a biblioteca Janus, devolvendo a resposta em JSON.

| Rota / chamada | Entrada | Saída | Predicado Prolog |
|---|---|---|---|
| `GET /api/meowdoku/example` | Parâmetro opcional `name` com o identificador do puzzle | JSON com `name`, `size`, `cats_per_unit` e a matriz `regions` | `example_puzzle/4` |
| `POST /api/meowdoku/solve` | JSON com a matriz `regions` e a quantidade `cats_per_unit` | JSON com a matriz `solution` ou status HTTP 422 se não houver resposta | `solve/3` |
| `POST /api/meowdoku/hint` | JSON com `regions`, a matriz do `board` atual e `cats_per_unit` | JSON com as coordenadas `row`, `col`, o valor e o texto de explicação `reason` | `hint/4` |

## 8. Testes e validação

A validação do sistema foi estruturada em duas etapas principais, cobrindo tanto a lógica de restrições em Prolog quanto a integração dos endpoints em Python.

No SWI-Prolog, criamos uma suíte com dez testes automatizados no arquivo `backend/prolog/test_meowdoku.pl` utilizando o módulo `plunit`. Os testes cobrem a resolução de tabuleiros 6x6 e 8x8 no modo clássico com um gato, a resolução no modo avançado com dois gatos por região (K=2), a detecção de colisões ortogonais e diagonais, o bloqueio de tabuleiros com excesso de gatos por linha ou território, a falha determinística em puzzles impossíveis e a geração correta de dicas dedutivas. Todos os testes são executados com o comando `swipl -g run_tests -t halt backend/prolog/test_meowdoku.pl` e passam em aproximadamente 0,1 segundo sem deixar pontos de escolha em aberto.

Para a API em Python, implementamos testes de integração com `pytest` no arquivo `backend/tests/test_api.py`. Esses testes utilizam o TestClient do FastAPI para verificar as rotas `/api/meowdoku/example`, `/api/meowdoku/solve` e `/api/meowdoku/hint`, garantindo que os dados retornem no formato esperado e que requisições inconsistentes recebam o código HTTP 422.

Durante os testes manuais e automatizados, demos atenção especial aos casos de borda do jogo. As células situadas nos cantos e nas extremidades do tabuleiro têm menos vizinhos do que as células centrais, o que exigiu checagens de limites de índice nas coordenadas para evitar falhas de execução. Também verificamos tabuleiros sem nenhuma solução possível para confirmar que o predicado `solve/3` falha silenciosamente em vez de entrar em laço infinito, além de testar o modo K=2 com dezesseis gatos em grade 8x8 para assegurar que gatos na mesma região não gerem falso positivo de colisão desde que mantenham a distância mínima exigida.

## 9. Limitações e problemas conhecidos

Em tabuleiros com dimensões superiores a 10x10 que possuam regiões muito recortadas, a etapa de rotulação do CLP(FD) pode levar alguns segundos adicionais para encontrar a solução, já que o número de variáveis e combinações cresce de forma quadrática.

Outro ponto que deixamos identificado é que a geração dinâmica de novos mapas aleatórios com garantia matemática de solução única (prevista na Issue #9) ainda está em fase inicial de desenvolvimento. Por essa razão, a versão atual utiliza tabuleiros pré-configurados e validados para garantir que o jogador sempre receba desafios consistentes.

Caso o grupo tivesse mais semanas para trabalhar no projeto, a prioridade seria implementar um gerador procedural de regiões baseado em diagramas de Voronoi com teste de unicidade em segundo plano, além de adicionar no frontend um criador interativo de tabuleiros onde o próprio usuário pudesse desenhar seus mapas.

## 10. Contribuição de cada integrante

| Integrante | Principais contribuições |
|---|---|
| Gabriel Santos Monteiro | Modelou as restrições em CLP(FD) no arquivo `meowdoku.pl`, implementou o suporte ao modo K=2, escreveu os dez testes automatizados em plunit e fechou as Issues #1 e #8. |
| Ana Luíza Fernandes | Implementou a lógica dedutiva do predicado de dicas `hint/4` com justificativas textuais e pesquisou o algoritmo de partição conexa de regiões nas Issues #2 e #9. |
| Cayo Alencar | Estruturou a integração entre FastAPI e SWI-Prolog usando Janus, configurou os modelos Pydantic, desenvolveu as rotas REST e escreveu os testes com pytest nas Issues #3 e #10. |
| Tales R. G. | Desenvolveu o módulo de domínio em Elm (`Meowdoku.elm`), definindo os tipos de dados imutáveis, a máquina de estados das células e o algoritmo funcional de conflitos nas Issues #4 e #11. |
| Gabriel Marques de Souza | Escreveu os decodificadores e codificadores JSON no Elm, organizou o ciclo update na arquitetura TEA e cuidou da comunicação HTTP nas Issues #5 e #12. |
| Renata Quadros Kurzawa | Projetou a interface visual em CSS Grid com paleta diferenciada para os territórios, criou o retorno visual de conflitos em vermelho e montou o modal de vitória nas Issues #6 e #13. |
| Paola Nascimento | Atuou na garantia de qualidade, configurando e rodando o script `validar_entrega.py`, redigindo e revisando as seções do `RELATORIO.md` e organizando as atas nas Issues #7 e #14. |

## 11. Fontes, código de terceiros e uso de IA

**Código reaproveitado.** Partimos do template base de Sudoku fornecido pelo professor Fábio Macêdo Mendes. Aproveitamos a estrutura de diretórios, a configuração de empacotamento com Vite e o esqueleto de conexão com o Janus. Toda a lógica de regras e resolução do Meowdoku em `meowdoku.pl`, a suíte de testes em `test_meowdoku.pl`, as rotas específicas da API em `main.py` e os módulos em Elm foram escritos pelo grupo.

**Referências.** Consultamos a documentação oficial do SWI-Prolog sobre a biblioteca `library(clpfd)`, o guia de arquitetura da documentação do Elm, a documentação de integração da biblioteca Janus entre Python e Prolog, além das regras tradicionais do jogo Queens do LinkedIn.

**Uso de ferramentas de IA.**

- **Faixa de uso no código:** auxiliar

| Ferramenta | Para que foi usada | Como o grupo verificou o resultado |
|---|---|---|
| Claude | Validação da ideia proposta e pequenos ajustes de escrita do código | Validação estrita de compilação pelo compilador Elm e testes automatizados de requisição no pytest |
| Gemini | Organização interna do grupo, como divisão de atividades, criação de issues e organização da equipe | Projects, issues e organização da equipe |

## 12. Apresentação oral

- **Slides:** não há
- **Roteiro:**

| Parte | Duração | Quem apresenta |
|---|:---:|---|
| Introdução e Contextualização do Meowdoku | 2 min | Paola Nascimento |
| Demonstração Prática e Interface Web | 4 min | Renata Quadros Kurzawa e Tales R. G. |
| Paradigma Lógico: CLP(FD), K=2 e Dicas | 4 min | Gabriel Santos Monteiro e Ana Luíza Fernandes |
| Paradigma Funcional e Integração HTTP | 3 min | Gabriel Marques de Souza e Cayo Alencar |
| Limitações, Conclusão e Arguição | 2 min | Gabriel Santos Monteiro |

## 13. Reflexão sobre os paradigmas

Trabalhar simultaneamente com SWI-Prolog e Elm evidenciou duas maneiras muito diferentes de estruturar um software. No Prolog, a modelagem com CLP(FD) permitiu tratar as regras do jogo quase como uma especificação matemática. Não precisamos implementar buscas manuais com laços ou gerenciar estruturas mutáveis de pilha para testar hipóteses; bastou definir o domínio das células e as restrições de linha, coluna, região e distância. A maior dificuldade esteve em entender como o motor de propagação opera internamente. O caso do `forall/2`, que desfazia restrições por causa da dupla negação, mostrou que mesmo em código puramente relacional é preciso compreender a semântica operacional do interpretador para não introduzir comportamentos inesperados.

No Elm, o foco foi completamente diferente. A ausência de variáveis mutáveis e o sistema de tipos estáticos mudaram a forma como pensamos a interface. Como o compilador não permite valores nulos e exige tratamento exaustivo em todos os blocos `case`, grande parte dos erros comuns de frontend simplesmente não acontece em tempo de execução. A modelagem do estado das células com o tipo `CellMark` em vez de múltiplos booleanos tornou impossível criar estados inválidos, e o fluxo unidirecional da arquitetura TEA facilitou muito rastrear como cada clique altera a tela.

A mudança de mentalidade entre as duas linguagens foi perceptível durante todo o projeto. No Elm, pensamos em termos de transformações determinísticas de dados em um fluxo contínuo de entrada e saída. No Prolog, pensamos em termos de relações e restrições sobre um espaço de busca, deixando a dedução por conta do motor lógico. A combinação das duas abordagens, mediada pela ponte em FastAPI, permitiu que cada linguagem ficasse responsável exatamente pelo que faz de melhor.
