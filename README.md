# mac-shortcuts

Coleção de atalhos para o app **Atalhos** (Shortcuts) do macOS.

Cada atalho fica em uma pasta própria, com:

- `README.md`: o que faz, o que instalar antes e como usar.
- `script-do-atalho.sh`: cópia do script de shell que roda dentro do atalho, só para consulta (não instala nada).
- `.shortcut`: o arquivo assinado, pronto para importar com dois cliques.

## Atalhos

| Atalho | O que faz | Dependências |
|---|---|---|
| [Transcrever áudio](transcrever-audio/) | Transcreve áudios e vídeos para `.txt` em português, localmente, com whisper.cpp | Homebrew, `ffmpeg`, `whisper-cpp`, modelo `large-v3-turbo` |
| [Converter para MP3](converter-para-mp3/) | Converte áudios (inclusive `.ogg`/`.opus` do WhatsApp) para `.mp3` | Homebrew, `ffmpeg` |
| [Converter PDF para MD](converter-pdf-para-md/) | Converte PDFs para Markdown, localmente: Marker nos PDFs normais, OCR nativo da Apple nos escaneados ou com texto ilegível | Homebrew, `pipx`, `marker-pdf` |
| [Converter PDF para MD (IA)](converter-pdf-para-md-ia/) | Versão de máxima qualidade: Marker com revisão por IA via OpenRouter (envia o PDF para a API, serviço pago). Gera `Nome (IA).md` | Homebrew, `pipx`, `marker-pdf`, conta na OpenRouter com créditos |

Todos são **Ações Rápidas do Finder**: selecione os arquivos, clique com o botão direito > **Ações Rápidas** e escolha o atalho.

## Requisitos gerais

- macOS com o app Atalhos.
- No app Atalhos: **Ajustes > Avançado > Permitir Execução de Scripts**.
- Recomendado: **Ajustes do Sistema > Privacidade e Segurança > Acesso Total ao Disco** ativado para o Atalhos.

O passo a passo completo de instalação está no README de cada atalho.
