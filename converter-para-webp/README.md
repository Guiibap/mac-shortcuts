# Converter para WebP

Ação Rápida do Finder que converte imagens para WebP otimizado usando o [cwebp](https://developers.google.com/speed/webp/docs/cwebp) (codificador oficial do Google), localmente no seu Mac.

Para cada imagem selecionada, gera um `.webp` com o mesmo nome e na mesma pasta do original. O arquivo original não é alterado e a imagem não é redimensionada.

```
IMG_4821.HEIC       →  IMG_4821.webp
Captura de Tela.png →  Captura de Tela.webp
```

Útil para publicar imagens em sites: o WebP costuma ficar bem menor que JPG e PNG com a mesma aparência.

## Requisitos

- Mac com macOS e o app **Atalhos** (Shortcuts).
- [Homebrew](https://brew.sh) e o pacote `webp` (passo a passo abaixo).

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

### 2. Instalar o webp

O pacote traz o `cwebp` (imagens) e o `gif2webp` (GIFs).

```bash
brew install webp
```

Para conferir:

```bash
cwebp -version
```

### 3. Liberar scripts no app Atalhos

1. Abra o app **Atalhos**.
2. Menu **Atalhos > Ajustes > Avançado**.
3. Marque **Permitir Execução de Scripts**.

Recomendado: em **Ajustes do Sistema > Privacidade e Segurança > Acesso Total ao Disco**, ative o **Atalhos**. Sem isso, o macOS pode bloquear o acesso a arquivos em pastas como Downloads e Documentos.

### 4. Importar o atalho

1. Baixe o arquivo [`Converter para WebP.shortcut`](Converter%20para%20WebP.shortcut) (botão **Download** na página do arquivo) e dê dois cliques nele.
2. Clique em **Adicionar Atalho**.

## Como usar

1. No Finder, selecione uma ou mais imagens.
2. Clique com o botão direito > **Ações Rápidas** > **Converter para WebP**.
3. Acompanhe o progresso pelas notificações (`(1/3) nome-da-imagem.jpg`).
4. No fim, aparece uma notificação com o resumo:

```
Convertidos: 12 de 12
38,2 MB → 6,1 MB (84% menor)
```

Na primeira execução, o macOS pode pedir permissões (rodar script, enviar notificações, acessar a pasta). Clique em **Permitir**.

Se a opção não aparecer no menu, clique com o botão direito > **Ações Rápidas** > **Personalizar...** e ative **Converter para WebP**.

### Formatos aceitos

`jpg`, `jpeg`, `heic`, `heif`, `tif`, `tiff`, `png`, `gif`

Arquivos que já são `.webp` e arquivos de outros tipos são ignorados.

### Comportamento

- **Fotos (JPG, HEIC, TIFF):** WebP com perda, qualidade 80, compressão máxima (`-m 6`) e `-sharp_yuv` para não borrar bordas coloridas.
- **PNG (prints, logos, transparência):** quase sem perda (`-near_lossless 60`). Mantém texto e bordas nítidos, com arquivo bem menor que o lossless puro.
- **GIF:** `gif2webp` no modo misto, que escolhe com ou sem perda quadro a quadro. GIFs animados continuam animados.
- **Rotação:** fotos do iPhone guardam a rotação num campo EXIF que o `cwebp` ignora. O atalho aplica a rotação antes de converter, então a foto não sai deitada.
- **HEIC:** o `cwebp` não lê HEIC. O atalho converte antes para um PNG temporário com o próprio macOS (ImageIO), sem perder qualidade.
- **Cores:** o perfil de cor (ex.: Display P3 das fotos do iPhone) é mantido. Os demais metadados (EXIF, localização GPS) são descartados.
- **Não sobrescreve:** se o `.webp` já existir, a imagem é pulada. Para converter de novo, apague o `.webp` antes.
- **Ficou maior:** raramente, uma imagem já muito comprimida gera um WebP maior que o original. O resumo avisa, e o log mostra os tamanhos de cada uma.
- **Falhas:** se alguma imagem falhar, aparece um alerta com a lista e um botão **Ver log**.

Para mudar a qualidade das fotos e dos GIFs, altere a linha `QUALIDADE=80` no script do atalho (0 a 100; maior = melhor e mais pesado).

## Log

Cada execução grava os detalhes em:

```
~/Library/Logs/converter-webp.log
```

O log é zerado a cada execução, então ele sempre mostra só a última. Para cada imagem, mostra a saída do `cwebp` e o tamanho antes e depois.

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Alerta "cwebp não encontrado" | Pacote webp não instalado | `brew install webp` |
| Erro dizendo que scripts não são permitidos | Opção desativada no Atalhos | Refaça o passo 3 |
| Imagem aparece como "Falharam" | Arquivo corrompido ou formato inesperado | Clique em **Ver log** |
| Imagem aparece como "Ignorados" | Extensão fora da lista aceita | Confira os formatos aceitos |
| "Ficaram maiores que o original" | Imagem já muito comprimida | Use o original ou reduza a qualidade no script |

## Como o atalho é montado

Caso queira recriar ou editar no app Atalhos:

1. **Receber** Imagens de **Ações Rápidas** (com **Finder** marcado nos detalhes).
2. **Executar Script de Shell:** Shell `zsh`, Entrada = Entrada do Atalho, Passar entrada = **como argumentos**. O conteúdo é o do arquivo [`script-do-atalho.sh`](script-do-atalho.sh).
3. **Mostrar Notificação** com o **Resultado do Script de Shell**.
