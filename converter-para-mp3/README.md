# Converter para MP3

Ação Rápida do Finder que converte arquivos de áudio para MP3 usando o [ffmpeg](https://ffmpeg.org), localmente no seu Mac.

Para cada arquivo selecionado, gera um `.mp3` com o mesmo nome e na mesma pasta do original. O arquivo original não é alterado.

```
WhatsApp Ptt 2026-09-21 at 15.49.07.ogg  →  WhatsApp Ptt 2026-09-21 at 15.49.07.mp3
```

Útil para abrir áudios do WhatsApp (`.ogg`/`.opus`) em apps e aparelhos que só aceitam MP3.

## Requisitos

- Mac com macOS e o app **Atalhos** (Shortcuts).
- [Homebrew](https://brew.sh) e `ffmpeg` (passo a passo abaixo).

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

### 2. Instalar o ffmpeg

```bash
brew install ffmpeg
```

Para conferir:

```bash
ffmpeg -version
```

### 3. Liberar scripts no app Atalhos

1. Abra o app **Atalhos**.
2. Menu **Atalhos > Ajustes > Avançado**.
3. Marque **Permitir Execução de Scripts**.

Recomendado: em **Ajustes do Sistema > Privacidade e Segurança > Acesso Total ao Disco**, ative o **Atalhos**. Sem isso, o macOS pode bloquear o acesso a arquivos em pastas como Downloads e Documentos.

### 4. Importar o atalho

1. Dê dois cliques no arquivo `Converter para MP3.shortcut`.
2. Clique em **Adicionar Atalho**.

## Como usar

1. No Finder, selecione um ou mais arquivos de áudio.
2. Clique com o botão direito > **Ações Rápidas** > **Converter para MP3**.
3. Acompanhe o progresso pelas notificações (`(1/3) nome-do-arquivo.ogg`).
4. No fim, aparece uma notificação com o resumo:

```
Convertidos: 3 de 4
Pulados (MP3 já existia): 1
```

Na primeira execução, o macOS pode pedir permissões (rodar script, enviar notificações, acessar a pasta). Clique em **Permitir**.

Se a opção não aparecer no menu, clique com o botão direito > **Ações Rápidas** > **Personalizar...** e ative **Converter para MP3**.

### Formatos aceitos

`ogg`, `oga`, `opus`, `wav`, `flac`, `m4a`, `aac`, `wma`, `aiff`, `aif`

Arquivos que já são `.mp3` e arquivos de outros tipos são ignorados.

### Comportamento

- **Qualidade:** MP3 VBR de alta qualidade (`-q:a 2`, em média 170 a 210 kbps).
- **Não sobrescreve:** se o `.mp3` já existir, o arquivo é pulado. Para converter de novo, apague o `.mp3` antes.
- **Arquivos de outros tipos** são ignorados e contados no resumo.
- **Falhas:** se algum arquivo falhar, aparece um alerta com a lista e um botão **Ver log**.

## Log

Cada execução grava os detalhes em:

```
~/Library/Logs/converter-mp3.log
```

O log é zerado a cada execução, então ele sempre mostra só a última.

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Alerta "ffmpeg não encontrado" | ffmpeg não instalado | `brew install ffmpeg` |
| Erro dizendo que scripts não são permitidos | Opção desativada no Atalhos | Refaça o passo 3 |
| Arquivo aparece como "Falharam" | Áudio corrompido ou formato inesperado | Clique em **Ver log** |
| Arquivo aparece como "Ignorados" | Extensão fora da lista aceita | Confira os formatos aceitos |

## Como o atalho é montado

Caso queira recriar ou editar no app Atalhos:

1. **Receber** Arquivos de **Ações Rápidas** (com **Finder** marcado nos detalhes). O tipo é "Arquivos" e não "Mídia" porque o macOS não reconhece `.ogg`/`.opus` como mídia.
2. **Executar Script de Shell:** Shell `zsh`, Entrada = Entrada do Atalho, Passar entrada = **como argumentos**. O conteúdo é o do arquivo [`script.sh`](script.sh).
3. **Mostrar Notificação** com o **Resultado do Script de Shell**.
