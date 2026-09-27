export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export LANG="pt_BR.UTF-8" LC_ALL="pt_BR.UTF-8"

# Modelo da OpenRouter usado pelo Marker para revisar a conversão (precisa aceitar imagens
# e respostas estruturadas). Lista de modelos: https://openrouter.ai/models
MODELO="openai/gpt-5.6-luna"
# Nome do item nas Senhas do macOS (Keychain) que guarda a chave da API da OpenRouter.
CHAVE_KEYCHAIN="openrouter-api-key"

LOG="$HOME/Library/Logs/converter-pdf-md-ia.log"
: > "$LOG"

tmpdir=$(mktemp -d)
STATUS="$tmpdir/status"
limpar() {
  [ -n "$marker_pid" ] && { pkill -P $marker_pid; kill $marker_pid; } 2>/dev/null
  [ -n "$barra_pid" ] && kill $barra_pid 2>/dev/null
  rm -rf "$tmpdir"
}
trap limpar EXIT
trap 'exit 1' INT TERM HUP

notificar() {
  osascript - "$1" <<'EOF'
on run argv
  display notification (item 1 of argv) with title "Converter PDF para MD (IA)"
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
  ObjC.registerSubclass({ name: 'BarraPDFIA', methods: {
    'tick:': { types: ['void', ['id']], implementation: function () { ler(); } },
    'cancelar:': { types: ['void', ['id']], implementation: function () {
      cancelando = true;
      item.button.title = '⏹ Cancelando...';
      fm.createFileAtPathContentsAttributes(arq + '.cancelar', $(), $());
    } }
  } });
  const alvo = $.BarraPDFIA.alloc.init;
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

if ! command -v marker_single >/dev/null 2>&1; then
  alerta "marker_single não encontrado" "Instale no Terminal com: pipx install marker-pdf"
  echo "Falhou: marker_single não encontrado"
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

total=$#
i=0; ok=0; com_imagens=0; cancelado=0; chave_recusada=0; sem_saldo=0
falhas=(); pulados=(); ignorados=(); ia_parcial=()

for f in "$@"; do
  i=$((i+1))
  [ -e "$STATUS.cancelar" ] && { cancelado=1; break; }
  nome=$(basename "$f")
  dir=$(dirname "$f")
  base="${nome%.*}"
  # Sufixo (IA): convive com o .md do atalho normal, para dar para comparar os dois.
  alvo="$base (IA)"
  destino="$dir/$alvo.md"

  case "${f:e:l}" in
    pdf) ;;
    *) ignorados+=("$nome"); continue ;;
  esac

  if [ -e "$destino" ] || [ -e "$dir/$alvo" ]; then
    pulados+=("$nome")
    continue
  fi

  notificar "($i/$total) $nome"
  echo "===== $nome =====" >> "$LOG"

  # O Marker sempre cria a subpasta <saida>/<base>/ com o .md, um _meta.json e as imagens.
  # Gera tudo no temporário e copia para o lado do PDF só o que interessa.
  # Aqui o OCR fica ligado: em PDFs com texto ilegível o Marker faz OCR local (llama-server)
  # e a IA revisa; é o modo de máxima qualidade, mais lento.
  saida="$tmpdir/$i"
  md="$saida/$base/$base.md"
  plog="$tmpdir/$i.log"
  inicio=$SECONDS
  barra "📄 $i/$total · Convertendo com IA · 0 s"
  # nice: prioridade menor, para o Mac engasgar menos enquanto o Marker roda.
  nice -n 10 marker_single "$f" --output_dir "$saida" --use_llm \
    --llm_service marker.services.openrouter.OpenRouterService --openrouter_model "$MODELO" \
    --config_json "$CONFIG" > "$plog" 2>&1 &
  marker_pid=$!
  while kill -0 $marker_pid 2>/dev/null; do
    if [ -e "$STATUS.cancelar" ]; then
      pkill -P $marker_pid 2>/dev/null; kill $marker_pid 2>/dev/null
      cancelado=1
      break
    fi
    barra "📄 $i/$total · Convertendo com IA · $((SECONDS - inicio)) s"
    sleep 1
  done
  wait $marker_pid; rc=$?; marker_pid=""
  cat "$plog" >> "$LOG"
  if [ $cancelado -eq 1 ]; then
    echo "Cancelado pelo usuário" >> "$LOG"
    break
  fi

  if [ $rc -eq 0 ] && [ -s "$md" ]; then
    # Se alguma chamada à IA falhou (saldo, rede, chave), o Marker segue sem a IA naquele trecho.
    # Conta só pedidos abandonados; tentativas que depois deram certo ("Retrying") não contam.
    erros_ia=$(grep 'Giving up\|inference failed\|Exception:' "$plog" | grep -vc 'Retrying')
    echo "Erros da IA: $erros_ia" >> "$LOG"
    [ "$erros_ia" -gt 0 ] && ia_parcial+=("$nome")
    grep -q "Error code: 401" "$plog" && chave_recusada=1
    grep -q "Error code: 402" "$plog" && sem_saldo=1
    # Imagens = tudo na pasta que não é o .md nem o _meta.json (este é sempre descartado).
    imagens=("$saida/$base"/*(N.))
    imagens=(${imagens:#$md})
    imagens=(${imagens:#$saida/$base/${base}_meta.json})
    echo "Imagens: ${#imagens[@]}" >> "$LOG"
    if [ ${#imagens[@]} -eq 0 ]; then
      # Sem imagens: só o .md, direto ao lado do PDF.
      cp "$md" "$destino" >> "$LOG" 2>&1 && ok=$((ok+1)) || falhas+=("$nome")
    else
      # Com imagens: pasta "<base> (IA)/" com o .md e as imagens (o .md referencia as imagens pelo nome).
      if mkdir "$dir/$alvo" >> "$LOG" 2>&1 && cp "$md" "$dir/$alvo/$alvo.md" >> "$LOG" 2>&1 \
         && cp "${imagens[@]}" "$dir/$alvo/" >> "$LOG" 2>&1; then
        ok=$((ok+1)); com_imagens=$((com_imagens+1))
      else
        falhas+=("$nome")
      fi
    fi
  else
    falhas+=("$nome")
  fi
done

rm -f "$STATUS"

resumo="Convertidos com IA: $ok de $total"
[ $cancelado -eq 1 ] && resumo+=$'\n'"Cancelado pelo usuário"
[ $com_imagens -gt 0 ] && resumo+=$'\n'"Com imagens (salvos em pasta): $com_imagens"
if [ ${#ia_parcial[@]} -gt 0 ]; then
  resumo+=$'\n'"A IA falhou em parte da conversão (saldo, rede ou chave; veja o log): ${#ia_parcial[@]}"
  resumo+=$'\n'"$(printf '• %s\n' "${ia_parcial[@]:0:3}")"
  [ ${#ia_parcial[@]} -gt 3 ] && resumo+=$'\n'"• e mais $(( ${#ia_parcial[@]} - 3 ))"
fi
[ $chave_recusada -eq 1 ] && resumo+=$'\n'"A OpenRouter recusou a chave: confira a chave salva no Keychain"
[ $sem_saldo -eq 1 ] && resumo+=$'\n'"Sem créditos na OpenRouter: adicione saldo em openrouter.ai/settings/credits"
[ ${#pulados[@]} -gt 0 ] && resumo+=$'\n'"Pulados (MD com IA já existia): ${#pulados[@]}"
[ ${#ignorados[@]} -gt 0 ] && resumo+=$'\n'"Ignorados (não é PDF): ${#ignorados[@]}"

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

echo "$resumo"
