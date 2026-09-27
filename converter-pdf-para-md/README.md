# Converter PDF para MD

Ação Rápida do Finder que converte PDFs para Markdown (`.md`), **localmente no seu Mac**. Nada é enviado para a internet.

## Como funciona

Antes de converter, o atalho analisa o texto que vem dentro do PDF (menos de 1 segundo, com o PDFKit do macOS) e escolhe o caminho:

| Texto interno do PDF | Conversão | Resultado |
|---|---|---|
| **Legível** (a maioria dos PDFs) | [Marker](https://github.com/datalab-to/marker) 2.0, com o OCR desligado | Títulos, listas, tabelas e imagens. Alguns segundos por PDF. |
| **Ilegível ou ausente** (PDF escaneado, ou exportado com fonte de codificação quebrada, em que o texto sai como `OWLYLGDGH P OFDGHPLD`) | OCR nativo da Apple (Vision), lendo a imagem de cada página | Parágrafos e listas, **sem títulos, tabelas nem imagens**. Menos de 1 segundo por página. |

Para saber se o texto é legível, o atalho confere se ele forma palavras e se essas palavras existem no corretor ortográfico do macOS (português ou inglês). O PDF vai **inteiro** para um caminho ou para o outro, nunca misturado. Quando um PDF vai pelo OCR, a notificação final avisa.

O Marker nunca usa o OCR dele, que depende de um modelo de IA rodando no `llama-server` e leva cerca de 1 minuto por PDF. O OCR da Apple faz esse papel em uma fração do tempo.

## Saída

- **PDF sem imagens:** gera um `.md` com o mesmo nome e na mesma pasta do PDF.
- **PDF com imagens** (só no caminho do Marker): gera uma pasta com o nome do PDF, contendo o `.md` e as imagens em `.jpeg`. O `.md` referencia as imagens pelo nome, então os arquivos precisam ficar juntos.
- **PDF convertido por OCR:** sempre só o `.md`, ao lado do PDF.

```
Relatório.pdf       →  Relatório.md
Apresentação.pdf    →  Apresentação/
                         ├── Apresentação.md
                         └── _page_0_Figure_2.jpeg
```

## Requisitos

- Mac com Apple Silicon (M1 ou mais novo). Funciona em Intel, mas fica bem mais lento.
- macOS 26 ou mais novo, com o app **Atalhos** (Shortcuts).
- Alguns GB livres para o Marker, suas dependências e modelos.
- [Homebrew](https://brew.sh), `pipx` e `marker-pdf` (passo a passo abaixo).

## Setup rápido

Todos os comandos abaixo são rodados no app **Terminal** (Aplicativos > Utilitários > Terminal).

### 1. Instalar o Homebrew

Pule este passo se o comando `brew --version` já responder com um número de versão.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Ele vai pedir a senha do Mac. No fim da instalação, o próprio instalador mostra dois comandos em "Next steps" para colocar o `brew` no PATH. No Apple Silicon, são estes:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
```

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 2. Instalar o pipx

O Marker é um programa em Python. O `pipx` instala programas Python cada um no seu ambiente isolado, sem mexer no Python do sistema.

```bash
brew install pipx
```

```bash
pipx ensurepath
```

Feche e abra o Terminal depois do `ensurepath`.

### 3. Instalar o Marker

```bash
pipx install marker-pdf
```

A instalação baixa bastante coisa (PyTorch e outras dependências) e pode levar alguns minutos. Para conferir:

```bash
marker_single --help
```

O atalho procura o `marker_single` em `~/.local/bin`, que é onde o `pipx` coloca os comandos por padrão.

### 4. Baixar os modelos (primeira conversão)

Os modelos do Marker são baixados automaticamente na **primeira** conversão. Para fazer isso pelo Terminal, onde dá para acompanhar o progresso, converta qualquer PDF uma vez:

```bash
marker_single ~/Downloads/algum-arquivo.pdf --output_dir /tmp/teste-marker --disable_ocr
```

Se pular este passo, a primeira conversão pelo atalho vai demorar bem mais que o normal.

O OCR da Apple já vem no macOS e não precisa de instalação. Na primeira vez que ele roda, o macOS pode levar uns 30 segundos para carregar o modelo; depois disso é rápido.

### 5. Liberar scripts no app Atalhos

1. Abra o app **Atalhos**.
2. Menu **Atalhos > Ajustes > Avançado**.
3. Marque **Permitir Execução de Scripts**.

Recomendado: em **Ajustes do Sistema > Privacidade e Segurança > Acesso Total ao Disco**, ative o **Atalhos**. Sem isso, o macOS pode bloquear o acesso a arquivos em pastas como Downloads e Documentos.

### 6. Importar o atalho

1. Baixe o arquivo [`Converter PDF para MD.shortcut`](Converter%20PDF%20para%20MD.shortcut) (botão **Download** na página do arquivo) e dê dois cliques nele.
2. Clique em **Adicionar Atalho**.

## Como usar

1. No Finder, selecione um ou mais PDFs.
2. Clique com o botão direito > **Ações Rápidas** > **Converter PDF para MD**.
3. Acompanhe o progresso pelo **ícone na barra de menu**, que mostra o arquivo atual e a etapa (ex.: `📄 1/3 · Convertendo com o Marker` ou `📄 2/3 · OCR página 4/10`). Também aparece uma notificação no início de cada arquivo.
4. Para parar no meio, clique no ícone da barra de menu > **Cancelar conversão**. Uma conversão em andamento no Marker é descartada, e os arquivos que já terminaram são mantidos.
5. No fim, aparece uma notificação com o resumo:

```
Convertidos: 3 de 3
Com imagens (salvos em pasta): 1
Texto do PDF ilegível, convertido por OCR (sem imagens e com menos formatação): 1
• Estudo de caso.pdf
```

Na primeira execução, o macOS pode pedir permissões (rodar script, enviar notificações, acessar a pasta). Clique em **Permitir**.

Se a opção não aparecer no menu, clique com o botão direito > **Ações Rápidas** > **Personalizar...** e ative **Converter PDF para MD**. A opção só aparece quando a seleção tem PDFs.

### Comportamento

- **Não sobrescreve:** se já existir um `.md` ou uma pasta com o nome do PDF, o arquivo é pulado. Para converter de novo, apague o resultado anterior.
- **Arquivos que não são PDF** são ignorados e contados no resumo. A extensão pode estar em maiúsculas (`.PDF`).
- **Metadados:** o Marker também gera um `_meta.json`, que o atalho descarta.
- **Falhas:** se algum arquivo falhar, aparece um alerta com a lista e um botão **Ver log**.
- **Desempenho:** o Marker roda com prioridade reduzida (`nice`) para o Mac engasgar menos.
- **Tempo:** pelo Marker, cerca de 5 segundos por PDF para carregar os modelos, mais a conversão (cerca de 1 segundo para um PDF de 3 páginas). Pelo OCR, menos de 1 segundo por página.
- **Diagnóstico:** o log registra por qual caminho cada PDF foi e por quê (ex.: `Diagnóstico: ocr paginas=3 letras=154 cobertura=13% validas=100%`).

## Log

Cada execução grava os detalhes em:

```
~/Library/Logs/converter-pdf-md.log
```

O log é zerado a cada execução, então ele sempre mostra só a última.

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Alerta "marker_single não encontrado" | Marker não instalado ou fora de `~/.local/bin` | Refaça os passos 2 e 3 |
| Erro dizendo que scripts não são permitidos | Opção desativada no Atalhos | Refaça o passo 5 |
| Primeira conversão muito demorada | Download dos modelos do Marker ou primeira carga do OCR da Apple | Faça o passo 4 pelo Terminal |
| PDF foi pelo OCR sem precisar (ou o contrário) | Diagnóstico errou no limite | Veja a linha "Diagnóstico" no log |
| Arquivo aparece como "Falharam" | PDF protegido por senha, corrompido ou falta de memória | Clique em **Ver log** |
| Arquivo aparece como "Pulados" | Já existe `.md` ou pasta com o mesmo nome | Apague o resultado anterior |

## Como o atalho é montado

Caso queira recriar ou editar no app Atalhos:

1. **Receber** **PDFs** de **Ações Rápidas** (com **Finder** marcado nos detalhes). Aqui o tipo é "PDFs", e não "Arquivos" como nos outros atalhos, porque o macOS reconhece PDF, e assim a Ação Rápida só aparece para PDFs.
2. **Executar Script de Shell:** Shell `zsh`, Entrada = Entrada do Atalho, Passar entrada = **como argumentos**. O conteúdo é o do arquivo [`script-do-atalho.sh`](script-do-atalho.sh).
3. **Mostrar Notificação** com o **Resultado do Script de Shell**.
