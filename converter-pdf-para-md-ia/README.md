# Converter PDF para MD (IA)

Ação Rápida do Finder que converte PDFs para Markdown (`.md`) usando o [Marker](https://github.com/datalab-to/marker) com revisão por IA, via [OpenRouter](https://openrouter.ai). É a versão de **máxima qualidade** do [Converter PDF para MD](../converter-pdf-para-md/): use quando o resultado do atalho normal não ficou bom.

> **Antes do primeiro uso:** você precisa de uma **conta na OpenRouter com créditos** e de uma chave da API salva nas Senhas do macOS (passos 4 a 6 do [setup](#setup-rápido)). Sem a chave, o atalho mostra um alerta e não converte nada.

Com a IA, o Marker melhora tabelas, títulos, fórmulas, formulários, texto manuscrito e a descrição de imagens. Em PDFs escaneados ou com texto ilegível, ele faz OCR localmente e a IA revisa o resultado.

**Atenção:** diferente do atalho normal, este **envia imagens e trechos do PDF para a OpenRouter**, que repassa ao provedor do modelo. Não use com documentos que não podem sair do seu Mac.

## Saída

O arquivo recebe o sufixo **(IA)**, para conviver com o `.md` do atalho normal e dar para comparar os dois:

```
Relatório.pdf       →  Relatório (IA).md
Apresentação.pdf    →  Apresentação (IA)/
                         ├── Apresentação (IA).md
                         └── _page_0_Figure_2.jpeg
```

- **PDF sem imagens:** gera `Nome (IA).md` ao lado do PDF.
- **PDF com imagens:** gera a pasta `Nome (IA)/` com o `.md` e as imagens em `.jpeg`. O `.md` referencia as imagens pelo nome, então os arquivos precisam ficar juntos.

## Requisitos

- Mac com Apple Silicon (M1 ou mais novo).
- macOS com o app **Atalhos** (Shortcuts).
- Alguns GB livres para o Marker, suas dependências e modelos.
- [Homebrew](https://brew.sh), `pipx` e `marker-pdf` 2.0 ou mais novo.
- Conta na [OpenRouter](https://openrouter.ai) com créditos (serviço pago, cobrado por uso).

## Custo

O atalho usa o modelo `openai/gpt-5.6-luna`, um dos mais baratos com suporte a imagens: US$ 0,20 por milhão de tokens de entrada e US$ 1,20 por milhão de saída (preço da OpenRouter em setembro de 2026). Cada PDF gera vários pedidos à IA (um por tabela, imagem, página a revisar etc.), então o custo cresce com o tamanho e a complexidade do documento. O gasto por pedido aparece em [openrouter.ai/activity](https://openrouter.ai/activity).

## Setup rápido

Todos os comandos abaixo são rodados no app **Terminal** (Aplicativos > Utilitários > Terminal). Se você já usa o **Converter PDF para MD**, pule para o passo 4.

### 1. Instalar o Homebrew

Pule este passo se o comando `brew --version` já responder com um número de versão.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

No fim da instalação, o instalador mostra dois comandos em "Next steps" para colocar o `brew` no PATH. No Apple Silicon, são estes:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
```

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 2. Instalar o pipx

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

Se já tiver uma versão antiga (1.x), atualize:

```bash
pipx upgrade marker-pdf
```

Os modelos do Marker são baixados automaticamente na primeira conversão.

### 4. Criar a conta na OpenRouter e adicionar créditos

1. Crie uma conta em [openrouter.ai](https://openrouter.ai).
2. Adicione créditos em [Settings > Credits](https://openrouter.ai/settings/credits). Alguns dólares bastam para muitos PDFs.

**Mantenha pelo menos US$ 1 de saldo.** O Marker não limita o tamanho das respostas, então a OpenRouter só aceita um pedido se o saldo cobrir a maior resposta possível do modelo (65.536 tokens, cerca de US$ 0,08), mesmo que depois cobre bem menos. Com saldo abaixo disso, os pedidos são recusados com erro 402 e o resumo avisa "Sem créditos na OpenRouter". O mesmo vale para o limite de crédito da chave (passo 5): não deixe abaixo de US$ 1.

### 5. Criar a chave da API

1. Acesse [Settings > Keys](https://openrouter.ai/settings/keys) e clique em **Create Key**.
2. Opcional, mas recomendado: defina um **limite de crédito** para a chave, para ela nunca gastar mais do que você quer.
3. Copie a chave (começa com `sk-or-`). Ela só aparece uma vez.

### 6. Guardar a chave nas Senhas do macOS

A chave fica no Keychain do macOS, e não dentro do atalho. Assim ela não aparece no script, no arquivo `.shortcut` nem se você compartilhar o atalho.

```bash
security add-generic-password -a "$USER" -s openrouter-api-key -w
```

O Terminal vai pedir a chave duas vezes. Cole e aperte Enter; ela não aparece na tela. Cole a chave exatamente como a OpenRouter mostra, sem espaços.

Para trocar a chave depois, apague a antiga e rode o comando acima de novo:

```bash
security delete-generic-password -s openrouter-api-key
```

### 7. Liberar scripts no app Atalhos

1. Abra o app **Atalhos**.
2. Menu **Atalhos > Ajustes > Avançado**.
3. Marque **Permitir Execução de Scripts**.

Recomendado: em **Ajustes do Sistema > Privacidade e Segurança > Acesso Total ao Disco**, ative o **Atalhos**.

### 8. Importar o atalho

1. Baixe o arquivo [`Converter PDF para MD (IA).shortcut`](Converter%20PDF%20para%20MD%20(IA).shortcut) (botão **Download** na página do arquivo) e dê dois cliques nele.
2. Clique em **Adicionar Atalho**.

## Como usar

1. No Finder, selecione um ou mais PDFs.
2. Clique com o botão direito > **Ações Rápidas** > **Converter PDF para MD (IA)**.
3. Acompanhe pelo **ícone na barra de menu**, que mostra o arquivo atual e o tempo decorrido (ex.: `📄 1/2 · Convertendo com IA · 42 s`).
4. Para parar no meio, clique no ícone > **Cancelar conversão**.
5. No fim, aparece uma notificação com o resumo:

```
Convertidos com IA: 2 de 2
Com imagens (salvos em pasta): 1
```

### Comportamento

- **Modelo:** `openai/gpt-5.6-luna`. Para trocar, edite a variável `MODELO` no início do script, dentro do atalho. O modelo precisa aceitar imagens e respostas estruturadas; veja a [lista de modelos](https://openrouter.ai/models).
- **Falhas da IA:** quando a API limita os pedidos ou demora demais, o atalho tenta de novo até 5 vezes, esperando cada vez mais. Se mesmo assim algum pedido falhar, o Marker continua sem a IA naquele trecho, e o resumo avisa: `A IA falhou em parte da conversão (saldo, rede ou chave; veja o log)`. Se a causa for a chave ou a falta de créditos, o resumo diz qual.
- **Não sobrescreve:** se já existir `Nome (IA).md` ou a pasta `Nome (IA)/`, o PDF é pulado.
- **Arquivos que não são PDF** são ignorados. A extensão pode estar em maiúsculas (`.PDF`).
- **Metadados:** o `_meta.json` do Marker é descartado.
- **Tempo:** bem mais lento que o atalho normal, porque espera as respostas da IA. PDFs com texto ilegível ou escaneados demoram mais ainda (cerca de 1 minuto a mais), porque o Marker faz OCR localmente antes da revisão.

## Log

```
~/Library/Logs/converter-pdf-md-ia.log
```

O log é zerado a cada execução. Ele nunca contém a chave da API.

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Alerta "Chave da OpenRouter não encontrada" | Chave não salva no Keychain | Refaça o passo 6 |
| Alerta "Chave da OpenRouter inválida" | Chave salva com espaço, aspas ou quebra de linha | Apague e salve de novo (passo 6), sem espaços |
| Resumo diz que a OpenRouter recusou a chave | Chave errada, revogada ou colada com erro (erro 401) | Crie outra chave (passo 5) e salve de novo (passo 6) |
| Resumo diz que não há créditos | Saldo ou limite da chave abaixo de ~US$ 0,08, o necessário para reservar a resposta máxima (erro 402) | Adicione créditos (passo 4) ou aumente o limite da chave |
| Resumo avisa que a IA falhou por outro motivo | Sem internet, modelo fora do ar ou limite de pedidos | Veja as linhas `OpenRouter inference failed` no log e tente de novo |
| Alerta "marker_single não encontrado" | Marker não instalado ou fora de `~/.local/bin` | Refaça os passos 2 e 3 |
| Erro dizendo que scripts não são permitidos | Opção desativada no Atalhos | Refaça o passo 7 |
| Arquivo aparece como "Pulados" | Já existe `Nome (IA).md` ou a pasta | Apague o resultado anterior |

## Como o atalho é montado

1. **Receber** **PDFs** de **Ações Rápidas** (com **Finder** marcado nos detalhes).
2. **Executar Script de Shell:** Shell `zsh`, Entrada = Entrada do Atalho, Passar entrada = **como argumentos**. O conteúdo é o do arquivo [`script-do-atalho.sh`](script-do-atalho.sh).
3. **Mostrar Notificação** com o **Resultado do Script de Shell**.
