# Transcrever áudio

Ação Rápida do Finder que transcreve áudios e vídeos para texto, em português, usando o [whisper.cpp](https://github.com/ggml-org/whisper.cpp) **localmente no seu Mac**. Nada é enviado para a internet.

Para cada arquivo selecionado, gera um `.txt` com o mesmo nome e na mesma pasta do original.

```
WhatsApp Ptt 2026-09-21 at 15.49.07.ogg  →  WhatsApp Ptt 2026-09-21 at 15.49.07.txt
```

## Requisitos

- Mac com Apple Silicon (M1 ou mais novo). Funciona em Intel, mas fica bem mais lento.
- macOS com o app **Atalhos** (Shortcuts).
- Cerca de 2 GB livres para o modelo de transcrição.
- [Homebrew](https://brew.sh), `ffmpeg` e `whisper-cpp` (passo a passo abaixo).

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

### 2. Instalar o ffmpeg e o whisper-cpp

```bash
brew install ffmpeg whisper-cpp
```

- **ffmpeg:** converte qualquer áudio ou vídeo para o formato que o whisper entende.
- **whisper-cpp:** faz a transcrição (instala o comando `whisper-cli`).

Para conferir:

```bash
ffmpeg -version && whisper-cli --help
```

### 3. Baixar o modelo de transcrição

O atalho usa o modelo `large-v3-turbo` (cerca de 1,6 GB), que tem boa precisão em português e é rápido no Apple Silicon. Ele precisa ficar exatamente em `~/whisper-models/ggml-large-v3-turbo.bin`.

```bash
mkdir -p ~/whisper-models && curl -L -o ~/whisper-models/ggml-large-v3-turbo.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
```

### 4. Liberar scripts no app Atalhos

1. Abra o app **Atalhos**.
2. Menu **Atalhos > Ajustes > Avançado**.
3. Marque **Permitir Execução de Scripts**.

Recomendado: em **Ajustes do Sistema > Privacidade e Segurança > Acesso Total ao Disco**, ative o **Atalhos**. Sem isso, o macOS pode bloquear o acesso a arquivos em pastas como Downloads e Documentos.

### 5. Importar o atalho

1. Baixe o arquivo [`Transcrever áudio.shortcut`](Transcrever%20%C3%A1udio.shortcut) (botão **Download** na página do arquivo) e dê dois cliques nele.
2. Clique em **Adicionar Atalho**.

## Como usar

1. No Finder, selecione um ou mais arquivos de áudio ou vídeo.
2. Clique com o botão direito > **Ações Rápidas** > **Transcrever áudio**.
3. Acompanhe o progresso pelas notificações (`(1/3) nome-do-arquivo.ogg`).
4. No fim, aparece uma notificação com o resumo:

```
Transcritos: 3 de 4
Pulados (TXT já existia): 1
```

Na primeira execução, o macOS pode pedir permissões (rodar script, enviar notificações, acessar a pasta). Clique em **Permitir**.

Se a opção não aparecer no menu, clique com o botão direito > **Ações Rápidas** > **Personalizar...** e ative **Transcrever áudio**.

### Formatos aceitos

- **Áudio:** `mp3`, `ogg`, `oga`, `opus`, `wav`, `flac`, `m4a`, `aac`, `wma`, `aiff`, `aif`
- **Vídeo** (só o áudio é transcrito): `mp4`, `m4v`, `mov`, `webm`, `mkv`

Áudios do WhatsApp (`.ogg`/`.opus`) funcionam direto, sem converter antes.

### Comportamento

- **Não sobrescreve:** se o `.txt` já existir, o arquivo é pulado. Para transcrever de novo, apague o `.txt` antes.
- **Arquivos de outros tipos** (imagens, PDFs etc.) são ignorados e contados no resumo.
- **Falhas:** se algum arquivo falhar, aparece um alerta com a lista e um botão **Ver log**.
- **Idioma:** fixo em português (`-l pt` no script).
- **Tempo:** depende do tamanho do áudio e do Mac. Áudios curtos de WhatsApp levam segundos. A primeira execução é um pouco mais lenta porque o modelo é carregado do disco.

## Log

Cada execução grava os detalhes em:

```
~/Library/Logs/transcrever-audio.log
```

O log é zerado a cada execução, então ele sempre mostra só a última.

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Alerta "ffmpeg não encontrado" | ffmpeg não instalado | `brew install ffmpeg` |
| Alerta "whisper-cli não encontrado" | whisper-cpp não instalado | `brew install whisper-cpp` |
| Alerta "Modelo não encontrado" | Modelo ausente ou em outra pasta | Refaça o passo 3 |
| Erro dizendo que scripts não são permitidos | Opção desativada no Atalhos | Refaça o passo 4 |
| Arquivo aparece como "Falharam" | Áudio corrompido, mudo ou sem fala | Clique em **Ver log** |
| Texto com nomes próprios ou siglas errados | Limitação da transcrição automática | Revise o `.txt` manualmente |

## Como o atalho é montado

Caso queira recriar ou editar no app Atalhos:

1. **Receber** Mídia de **Ações Rápidas** (com **Finder** marcado nos detalhes). Assim a opção só aparece em arquivos de áudio e vídeo. Se ela não aparecer em `.ogg`/`.opus` (versões antigas do macOS não os reconhecem como mídia), troque o tipo para "Arquivos".
2. **Executar Script de Shell:** Shell `zsh`, Entrada = Entrada do Atalho, Passar entrada = **como argumentos**. O conteúdo é o do arquivo [`script-do-atalho.sh`](script-do-atalho.sh).
3. **Mostrar Notificação** com o **Resultado do Script de Shell**.
