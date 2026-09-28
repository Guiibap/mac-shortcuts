export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export LANG="pt_BR.UTF-8" LC_ALL="pt_BR.UTF-8"

# Modelo da OpenRouter usado pelo Marker para revisar a conversão (precisa aceitar imagens
# e respostas estruturadas). Lista de modelos: https://openrouter.ai/models
MODELO="openai/gpt-6-luna"
# Nome do item nas Senhas do macOS (Keychain) que guarda a chave da API da OpenRouter.
CHAVE_KEYCHAIN="openrouter-api-key"
# Subpasta criada dentro de cada pasta selecionada, com um .md por PDF.
SUBPASTA="Markdown (IA)"
# PDFs convertidos ao mesmo tempo. Cada um é um processo do Marker com o próprio modelo na memória;
# mais que isso pesa no Mac e esbarra no limite de pedidos da OpenRouter.
PROCESSOS=2

LOG="$HOME/Library/Logs/converter-pasta-pdf-md-ia.log"
: > "$LOG"

tmpdir=$(mktemp -d)
STATUS="$tmpdir/status"
# O Marker em lote abre processos filhos (um por PDF em paralelo, mais o llama-server); mata a árvore toda.
matar() {
  local c
  for c in $(pgrep -P $1); do matar $c; done
  kill $1 2>/dev/null
}
limpar() {
  [ -n "$marker_pid" ] && matar $marker_pid
  [ -n "$barra_pid" ] && kill $barra_pid 2>/dev/null
  rm -rf "$tmpdir"
}
trap limpar EXIT
trap 'exit 1' INT TERM HUP

notificar() {
  osascript - "$1" <<'EOF'
on run argv
  display notification (item 1 of argv) with title "Converter pasta de PDFs para MD (IA)"
end run
EOF
}

alerta() {
  osascript - "$1" "$2" <<'EOF'
on run argv
  display alert (item 1 of argv) message (item 2 of argv) as critical
end run
EOF
}

# Ícone na barra de menu com o progresso, lido do arquivo $STATUS a cada meio segundo.
# Some sozinho quando o arquivo deixa de existir ou fica 60 s sem atualizar (script interrompido). O menu "Cancelar conversão" cria $STATUS.cancelar.
barra() {
  printf '%s' "$1" > "$STATUS"
  [ -n "$barra_pid" ] && return
  osascript -l JavaScript - "$STATUS" >> "$LOG" 2>&1 <<'EOF' &
ObjC.import('Cocoa');
function run(argv) {
  const arq = argv[0];
  const app = $.NSApplication.sharedApplication;
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
  const fm = $.NSFileManager.defaultManager;
  const item = $.NSStatusBar.systemStatusBar.statusItemWithLength($.NSVariableStatusItemLength);
  let cancelando = false;
  function ler() {
    const attrs = fm.attributesOfItemAtPathError(arq, $());
    if (attrs.isNil() || $.NSDate.date.timeIntervalSinceDate(attrs.fileModificationDate) > 60) { app.terminate(null); return; }
    if (cancelando) return;
    const t = $.NSString.stringWithContentsOfFileEncodingError(arq, $.NSUTF8StringEncoding, null);
    if (!t.isNil()) item.button.title = t.js;
  }
  ObjC.registerSubclass({ name: 'BarraPastaPDFIA', methods: {
    'tick:': { types: ['void', ['id']], implementation: function () { ler(); } },
    'cancelar:': { types: ['void', ['id']], implementation: function () {
      cancelando = true;
      item.button.title = '⏹ Cancelando...';
      fm.createFileAtPathContentsAttributes(arq + '.cancelar', $(), $());
    } }
  } });
  const alvo = $.BarraPastaPDFIA.alloc.init;
  const menu = $.NSMenu.alloc.init;
  const mi = $.NSMenuItem.alloc.initWithTitleActionKeyEquivalent('Cancelar conversão', 'cancelar:', '');
  mi.target = alvo;
  menu.addItem(mi);
  item.menu = menu;
  ler();
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(0.5, alvo, 'tick:', $(), true);
  app.run;
}
EOF
  barra_pid=$!
}

if ! command -v marker >/dev/null 2>&1; then
  alerta "marker não encontrado" "Instale no Terminal com: pipx install marker-pdf"
  echo "Falhou: marker não encontrado"
  exit 0
fi

# A chave vem do Keychain e vai para o Marker por um arquivo de configuração no temporário
# (só o seu usuário lê, apagado no fim), para não aparecer no script, no .shortcut
# nem na lista de processos. O Marker 2.0 não lê a chave de variável de ambiente.
chave=$(security find-generic-password -s "$CHAVE_KEYCHAIN" -w 2>/dev/null)
if [ -z "$chave" ]; then
  alerta "Chave da OpenRouter não encontrada" "Salve a chave nas Senhas do macOS rodando no Terminal: security add-generic-password -a \"$USER\" -s $CHAVE_KEYCHAIN -w"
  echo "Falhou: chave da OpenRouter não encontrada no Keychain"
  exit 0
fi
# Só recusa o que quebraria o JSON abaixo (aspas, barra invertida, espaços, controle);
# não depende do formato exato da chave.
if [[ "$chave" == *[\"\\[:space:][:cntrl:]]* ]]; then
  alerta "Chave da OpenRouter inválida" "A chave salva no Keychain tem aspas, barra invertida ou espaços. Apague com: security delete-generic-password -s $CHAVE_KEYCHAIN e salve de novo, sem espaços."
  echo "Falhou: chave da OpenRouter inválida"
  exit 0
fi
CONFIG="$tmpdir/config.json"
# max_retries/retry_wait_time: insiste mais antes de desistir quando a API limita os pedidos.
( umask 077; printf '{"openrouter_api_key": "%s", "max_retries": 5, "retry_wait_time": 5}\n' "$chave" > "$CONFIG" )
unset chave

# Monta uma pasta de entrada no temporário com um link para cada PDF a converter, de todas
# as pastas selecionadas. Os links se chamam 1.pdf, 2.pdf...: assim uma única execução do
# Marker cobre tudo, só entram PDFs (o Marker em lote pega qualquer arquivo da pasta) e
# PDFs com o mesmo nome em pastas diferentes não colidem.
entrada="$tmpdir/entrada"
saida="$tmpdir/saida"
mkdir "$entrada" "$saida"
n=0; pastas=0
origens=(); destinos=(); pulados=(); nao_pastas=(); sem_pdf=(); pastas_saida=()
for pasta in "$@"; do
  if [ ! -d "$pasta" ]; then
    nao_pastas+=("$(basename "$pasta")")
    continue
  fi
  pastas=$((pastas+1))
  achou=0
  # Só os PDFs direto na pasta, sem entrar em subpastas.
  for f in "$pasta"/*(N.); do
    [[ "${f:e:l}" == pdf ]] || continue
    achou=1
    nome=$(basename "$f")
    destino="$pasta/$SUBPASTA/${nome%.*}.md"
    if [ -e "$destino" ]; then
      pulados+=("$nome")
      continue
    fi
    n=$((n+1))
    ln -s "$f" "$entrada/$n.pdf"
    origens[$n]="$f"
    destinos[$n]="$destino"
  done
  [ $achou -eq 0 ] && sem_pdf+=("$(basename "$pasta")")
done
total=$n

ok=0; cancelado=0; chave_recusada=0; sem_saldo=0; erros_ia=0
falhas=()

if [ $total -gt 0 ]; then
  notificar "$total PDFs para converter"
  echo "===== $total PDFs =====" >> "$LOG"
  for k in {1..$total}; do echo "$k.pdf = ${origens[$k]}" >> "$LOG"; done

  plog="$tmpdir/marker.log"
  inicio=$SECONDS
  barra "📁 0/$total · Convertendo com IA · 0 s"
  # Aqui o OCR fica ligado: em PDFs com texto ilegível o Marker faz OCR local (llama-server)
  # e a IA revisa. Em lote, o llama-server e os modelos sobem uma vez só para todos os PDFs.
  # --disable_image_extraction: um único .md por PDF; a IA descreve as imagens em texto.
  # nice: prioridade menor, para o Mac engasgar menos enquanto o Marker roda.
  nice -n 10 marker "$entrada" --output_dir "$saida" --workers $PROCESSOS --use_llm \
    --llm_service marker.services.openrouter.OpenRouterService --openrouter_model "$MODELO" \
    --config_json "$CONFIG" --disable_image_extraction > "$plog" 2>&1 &
  marker_pid=$!
  while kill -0 $marker_pid 2>/dev/null; do
    if [ -e "$STATUS.cancelar" ]; then
      matar $marker_pid
      cancelado=1
      break
    fi
    # Progresso: cada PDF pronto vira <saida>/<n>/<n>.md.
    prontos=("$saida"/*/*.md(N))
    barra "📁 ${#prontos[@]}/$total · Convertendo com IA · $((SECONDS - inicio)) s"
    sleep 1
  done
  wait $marker_pid; marker_pid=""
  cat "$plog" >> "$LOG"
  [ $cancelado -eq 1 ] && echo "Cancelado pelo usuário" >> "$LOG"

  # Se alguma chamada à IA falhou (saldo, rede, chave), o Marker segue sem a IA naquele trecho.
  # Conta só pedidos abandonados; tentativas que depois deram certo ("Retrying") não contam.
  # No lote os PDFs rodam juntos e o log mistura todos, então não dá para saber de qual PDF é o erro.
  erros_ia=$(grep 'Giving up\|inference failed\|Exception:' "$plog" | grep -vc 'Retrying')
  echo "Erros da IA: $erros_ia" >> "$LOG"
  grep -q "Error code: 401" "$plog" && chave_recusada=1
  grep -q "Error code: 402" "$plog" && sem_saldo=1

  for k in {1..$total}; do
    md="$saida/$k/$k.md"
    nome=$(basename "${origens[$k]}")
    if [ -s "$md" ]; then
      dir_md=$(dirname "${destinos[$k]}")
      if mkdir -p "$dir_md" >> "$LOG" 2>&1 && cp "$md" "${destinos[$k]}" >> "$LOG" 2>&1; then
        ok=$((ok+1))
        (( ${pastas_saida[(Ie)$dir_md]} )) || pastas_saida+=("$dir_md")
      else
        falhas+=("$nome")
      fi
    elif [ $cancelado -eq 0 ]; then
      falhas+=("$nome")
    fi
  done
fi

rm -f "$STATUS"

resumo="Convertidos com IA: $ok de $total"
[ $cancelado -eq 1 ] && resumo+=$'\n'"Cancelado pelo usuário (os PDFs já prontos foram salvos; rode de novo para continuar)"
[ $erros_ia -gt 0 ] && resumo+=$'\n'"A IA falhou em parte da conversão (saldo, rede ou chave; veja o log)"
[ $chave_recusada -eq 1 ] && resumo+=$'\n'"A OpenRouter recusou a chave: confira a chave salva no Keychain"
[ $sem_saldo -eq 1 ] && resumo+=$'\n'"Sem créditos na OpenRouter: adicione saldo em openrouter.ai/settings/credits"
[ ${#pulados[@]} -gt 0 ] && resumo+=$'\n'"Pulados (MD já existia): ${#pulados[@]}"
[ ${#sem_pdf[@]} -gt 0 ] && resumo+=$'\n'"Pastas sem PDF: ${#sem_pdf[@]}"
[ ${#nao_pastas[@]} -gt 0 ] && resumo+=$'\n'"Ignorados (não é pasta): ${#nao_pastas[@]}"

if [ ${#falhas[@]} -gt 0 ]; then
  resumo+=$'\n'"Falharam: ${#falhas[@]}"
  lista=$(printf '• %s\n' "${falhas[@]}")
  osascript - "$resumo" "$lista" "$LOG" <<'EOF'
on run argv
  set msg to (item 1 of argv) & return & return & "Falharam:" & return & (item 2 of argv)
  set r to display alert "Algumas conversões falharam" message msg as critical buttons {"Ver log", "OK"} default button "OK"
  if button returned of r is "Ver log" then do shell script "open -e " & quoted form of (item 3 of argv)
end run
EOF
fi

# Abre no Finder as pastas com os .md gerados.
for p in "${pastas_saida[@]}"; do open "$p"; done

echo "$resumo"
