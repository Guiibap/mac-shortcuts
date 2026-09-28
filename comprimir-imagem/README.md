# Comprimir imagem

Ação Rápida do Finder que reduz o peso de imagens **sem mudar as dimensões nem o formato**, com perda invisível a olho nu, localmente no seu Mac.

Para cada imagem selecionada, gera uma cópia comprimida com o mesmo formato, na mesma pasta do original. O arquivo original não é alterado.

```
IMG_4821.jpg        →  IMG_4821 (comprimida).jpg
Captura de Tela.png →  Captura de Tela (comprimida).png
```

## Requisitos

- Mac com macOS e o app **Atalhos** (Shortcuts).
- [Homebrew](https://brew.sh) e as ferramentas `jpegoptim`, `pngquant`, `oxipng`, `gifsicle` e `webp` (passo a passo abaixo). Nenhuma depende de Python.

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

### 2. Instalar as ferramentas de compressão

```bash
brew install jpegoptim pngquant oxipng gifsicle webp
```

### 3. Liberar scripts no app Atalhos

1. Abra o app **Atalhos**.
2. Menu **Atalhos > Ajustes > Avançado**.
3. Marque **Permitir Execução de Scripts**.

Recomendado: em **Ajustes do Sistema > Privacidade e Segurança > Acesso Total ao Disco**, ative o **Atalhos**. Sem isso, o macOS pode bloquear o acesso a arquivos em pastas como Downloads e Documentos.

### 4. Importar o atalho

1. Baixe o arquivo [`Comprimir imagem.shortcut`](Comprimir%20imagem.shortcut) (botão **Download** na página do arquivo) e dê dois cliques nele.
2. Clique em **Adicionar Atalho**.

## Como usar

1. No Finder, selecione uma ou mais imagens.
2. Clique com o botão direito > **Ações Rápidas** > **Comprimir imagem**.
3. Acompanhe o progresso pelas notificações (`(1/3) nome-da-imagem.jpg`).
4. No fim, aparece uma notificação com o resumo:

```
Comprimidas: 10 de 12
39,7 MB → 14,9 MB (62% menor)
Já estavam otimizadas: 1
Não comprimidas (HDR, Retrato ou várias imagens): 1
```

Na primeira execução, o macOS pode pedir permissões (rodar script, enviar notificações, acessar a pasta). Clique em **Permitir**.

Se a opção não aparecer no menu, clique com o botão direito > **Ações Rápidas** > **Personalizar...** e ative **Comprimir imagem**.

## O que é feito em cada formato

| Formato | Ferramenta | O que faz | Economia típica |
|---|---|---|---|
| JPG | `jpegoptim` | Se a qualidade da imagem estiver acima de 85, recomprime em 85; senão, só otimiza sem perda. Salva como progressivo | 20 a 60% |
| PNG | `pngquant` + `oxipng` | Reduz para uma paleta de até 256 cores **só se** a qualidade ficar entre 90 e 100 (ícones, prints, logos). Em fotos, onde isso apareceria, fica só a otimização sem perda | 15 a 90% |
| GIF | `gifsicle` | Otimiza os quadros e aplica compressão com perda leve (`--lossy=20`). GIFs animados continuam animados | 10 a 40% |
| TIFF | `sips` (nativo) | Compressão LZW, sem perda | 30 a 60% |
| HEIC | `sips` (nativo) | Recomprime com qualidade 80 | varia |
| WebP | `cwebp` | Com perda: recomprime com qualidade 80. Sem perda: otimiza sem perda | varia |

Formatos não aceitos são ignorados e contados no resumo, assim como WebP animado.

### Proteções

- **Metadados:** mantém a orientação, a data e o perfil de cor. No JPG, descarta comentários, XMP e IPTC.
- **HDR e Retrato:** fotos do iPhone com HDR (mapa de ganho) ou com profundidade (modo Retrato) **não são comprimidas**, porque a recompressão apagaria esses dados. Elas aparecem no resumo como "Não comprimidas".
- **Várias imagens no arquivo** (ex.: TIFF de várias páginas): não comprimidas, pelo mesmo motivo.
- **Ganho mínimo:** se a economia ficar abaixo de 2% (ou de 10% em HEIC e WebP com perda, para não perder qualidade à toa), o resultado é descartado e a imagem aparece como "Já estavam otimizadas".
- **Não sobrescreve:** se a cópia `(comprimida)` já existir, a imagem é pulada. Arquivos que já têm `(comprimida)` no nome também são pulados.

### Ajustes

No início do script do atalho ficam as variáveis de qualidade: `QUALIDADE_JPG` (85), `QUALIDADE_PNG` (`90-100`), `QUALIDADE_REENCODE` (80, para HEIC e WebP) e os ganhos mínimos.

## Log

Cada execução grava os detalhes em:

```
~/Library/Logs/comprimir-imagem.log
```

O log é zerado a cada execução, então ele sempre mostra só a última. Para cada imagem, mostra o tamanho antes e depois.

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Alerta "Ferramentas não encontradas" | Alguma ferramenta não instalada | Refaça o passo 2 |
| Erro dizendo que scripts não são permitidos | Opção desativada no Atalhos | Refaça o passo 3 |
| Imagem aparece como "Falharam" | Arquivo corrompido ou formato inesperado | Clique em **Ver log** |
| "Já estavam otimizadas" | A imagem já estava bem comprimida | Nada a fazer; o original já é o menor |
| PNG de foto quase não diminuiu | A paleta de 256 cores estragaria a foto, então só entrou a otimização sem perda | Para fotos, o formato WebP (atalho [Converter para WebP](../converter-para-webp/)) ou JPG é bem menor |

## Como o atalho é montado

Caso queira recriar ou editar no app Atalhos:

1. **Receber** Imagens de **Ações Rápidas** (com **Finder** marcado nos detalhes).
2. **Executar Script de Shell:** Shell `zsh`, Entrada = Entrada do Atalho, Passar entrada = **como argumentos**. O conteúdo é o do arquivo [`script-do-atalho.sh`](script-do-atalho.sh).
3. **Mostrar Notificação** com o **Resultado do Script de Shell**.
