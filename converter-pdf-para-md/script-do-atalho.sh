export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export LANG="pt_BR.UTF-8" LC_ALL="pt_BR.UTF-8"

LOG="$HOME/Library/Logs/converter-pdf-md.log"
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
  display notification (item 1 of argv) with title "Converter PDF para MD"
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
  ObjC.registerSubclass({ name: 'BarraPDF', methods: {
    'tick:': { types: ['void', ['id']], implementation: function () { ler(); } },
    'cancelar:': { types: ['void', ['id']], implementation: function () {
      cancelando = true;
      item.button.title = '⏹ Cancelando...';
      fm.createFileAtPathContentsAttributes(arq + '.cancelar', $(), $());
    } }
  } });
  const alvo = $.BarraPDF.alloc.init;
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

# Funções nativas do macOS (PDFKit + Vision), sem instalar nem compilar nada:
#   apple diagnostico <pdf>                -> "ok" (texto interno confiável) ou "ocr" + estatísticas
#   apple ocr <pdf> <saida.md> [status]    -> OCR da Apple, grava o Markdown em <saida.md>
apple() {
  osascript -l JavaScript - "$@" <<'EOF'
ObjC.import('AppKit');
ObjC.import('PDFKit');
ObjC.import('Vision');

function run(argv) {
  const [modo, pdfPath, saida, status] = argv;
  const doc = $.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(pdfPath));
  if (doc.isNil()) throw new Error('Não foi possível abrir o PDF');
  const n = doc.pageCount;
  if (modo === 'diagnostico') return diagnostico(doc, n);
  if (modo === 'ocr') return ocr(doc, n, saida, status);
  throw new Error('Modo inválido: ' + modo);
}

// Texto interno confiável? Vazio (escaneado) ou com a maioria das palavras
// fora do dicionário (fonte com codificação quebrada) = precisa de OCR.
function diagnostico(doc, n) {
  let texto = '';
  for (let i = 0; i < n; i++) {
    const s = doc.pageAtIndex(i).string;
    if (!s.isNil()) texto += s.js + '\n';
  }
  const letras = (texto.match(/\p{L}/gu) || []).length;
  const todas = texto.match(/\p{L}{3,}/gu) || [];
  // Cobertura: fração das letras que formam palavras de 3+ letras. Texto com
  // codificação quebrada vira letras soltas ("O P O O") e fica com cobertura baixa.
  const cobertura = letras ? todas.join('').length / letras : 0;
  const palavras = todas.slice(0, 400);
  const sc = $.NSSpellChecker.sharedSpellChecker;
  const valida = (p) => ['pt_BR', 'en'].some((lang) =>
    Number(sc.checkSpellingOfStringStartingAtLanguageWrapInSpellDocumentWithTagWordCount(p, 0, lang, false, 0, null).length) === 0);
  const taxa = palavras.length ? palavras.filter(valida).length / palavras.length : 0;
  const ok = letras >= 50 && cobertura >= 0.6 && taxa >= 0.6;
  return `${ok ? 'ok' : 'ocr'} paginas=${n} letras=${letras} cobertura=${Math.round(cobertura * 100)}% validas=${Math.round(taxa * 100)}%`;
}

function ocr(doc, n, saida, status) {
  const blocos = [];
  for (let i = 0; i < n; i++) {
    if (status) $(`📄 ${statusPrefixo()}OCR página ${i + 1}/${n}`).writeToFileAtomicallyEncodingError(status, true, $.NSUTF8StringEncoding, null);
    blocos.push(...linhasDaPagina(doc.pageAtIndex(i)));
    blocos.push(null); // fim de página: força quebra de parágrafo
  }
  const md = montarMarkdown(blocos);
  $(md).writeToFileAtomicallyEncodingError(saida, true, $.NSUTF8StringEncoding, null);
  return `ok paginas=${n}`;
}

function statusPrefixo() {
  const env = $.NSProcessInfo.processInfo.environment.objectForKey('STATUS_PREFIXO');
  return env.isNil() ? '' : env.js;
}

// Renderiza a página a 2x e devolve as linhas reconhecidas, de cima para baixo.
function linhasDaPagina(page) {
  const box = page.boundsForBox($.kPDFDisplayBoxMediaBox);
  const escala = 2;
  const img = page.thumbnailOfSizeForBox($.NSMakeSize(box.size.width * escala, box.size.height * escala), $.kPDFDisplayBoxMediaBox);
  const cg = img.CGImageForProposedRectContextHints(null, $(), $());
  const req = $.VNRecognizeTextRequest.alloc.init;
  req.recognitionLevel = $.VNRequestTextRecognitionLevelAccurate;
  req.usesLanguageCorrection = true;
  req.recognitionLanguages = $(['pt-BR', 'en-US']);
  const handler = $.VNImageRequestHandler.alloc.initWithCGImageOptions(cg, $({}));
  if (!handler.performRequestsError($([req]), null)) throw new Error('Falha no OCR');
  const res = req.results;
  const linhas = [];
  for (let j = 0; j < res.count; j++) {
    const o = res.objectAtIndex(j);
    const c = o.topCandidates(1);
    if (c.count === 0) continue;
    const b = o.boundingBox;
    linhas.push({ texto: c.objectAtIndex(0).string.js, x: b.origin.x, topo: 1 - (b.origin.y + b.size.height), altura: b.size.height });
  }
  linhas.sort((a, b) => (Math.abs(a.topo - b.topo) < a.altura * 0.5 ? a.x - b.x : a.topo - b.topo));
  return linhas;
}

// Junta linhas em parágrafos pelo espaçamento vertical; marcadores viram lista,
// linhas bem mais altas que a média viram título.
function montarMarkdown(linhas) {
  const alturas = linhas.filter(Boolean).map((l) => l.altura).sort((a, b) => a - b);
  const mediana = alturas.length ? alturas[Math.floor(alturas.length / 2)] : 0;
  const marcador = /^\s*([•●▪◦·\-–*]|\d{1,2}[.)])\s+/;
  const out = [];
  let atual = null, anterior = null;
  const fechar = () => { if (atual) out.push(atual); atual = null; };
  for (const l of linhas) {
    if (!l) { fechar(); anterior = null; continue; }
    const titulo = l.altura > mediana * 1.35;
    const item = marcador.test(l.texto);
    const salto = anterior && (l.topo - (anterior.topo + anterior.altura)) > anterior.altura * 0.8;
    if (titulo) { fechar(); out.push('## ' + l.texto.trim()); anterior = l; continue; }
    if (item) { fechar(); atual = '- ' + l.texto.replace(marcador, '').trim(); anterior = l; continue; }
    if (!atual || salto || (anterior && anterior.altura > mediana * 1.35)) { fechar(); atual = l.texto.trim(); }
    else atual = atual.endsWith('-') ? atual.slice(0, -1) + l.texto.trim() : atual + ' ' + l.texto.trim();
    anterior = l;
  }
  fechar();
  return out.join('\n\n') + '\n';
}
EOF
}

# Traduz a última barra de progresso do Marker (ex.: "Recognizing Text:  44%") para o texto do ícone.
# LC_ALL=C: o tail corta no meio dos caracteres da barra de progresso, o que quebra o tr em UTF-8.
etapa() {
  local linha rotulo pct
  linha=$(tail -c 2000 "$1" 2>/dev/null | LC_ALL=C tr '\r' '\n' 2>/dev/null | LC_ALL=C grep -aoE '^[A-Za-z ]+: +[0-9]+%' | tail -1)
  [ -z "$linha" ] && return
  rotulo="${linha%%:*}"; pct="${linha##* }"
  case "$rotulo" in
    "Recognizing Layout") rotulo="Analisando layout" ;;
    "Running OCR Error Detection") rotulo="Verificando OCR" ;;
    "Detecting bboxes") rotulo="Detectando texto" ;;
    "Recognizing Text") rotulo="Reconhecendo texto" ;;
    "Recognizing tables") rotulo="Lendo tabelas" ;;
    *) rotulo="Processando" ;;
  esac
  echo "$rotulo $pct"
}

if ! command -v marker_single >/dev/null 2>&1; then
  osascript -e 'display alert "marker_single não encontrado" message "Instale no Terminal com: pipx install marker-pdf" as critical'
  echo "Falhou: marker_single não encontrado"
  exit 0
fi

total=$#
i=0; ok=0; com_imagens=0; cancelado=0
falhas=(); pulados=(); ignorados=(); via_ocr=()

for f in "$@"; do
  i=$((i+1))
  [ -e "$STATUS.cancelar" ] && { cancelado=1; break; }
  nome=$(basename "$f")
  dir=$(dirname "$f")
  base="${nome%.*}"
  destino="$dir/$base.md"

  case "${f:e:l}" in
    pdf) ;;
    *) ignorados+=("$nome"); continue ;;
  esac

  if [ -e "$destino" ] || [ -e "$dir/$base" ]; then
    pulados+=("$nome")
    continue
  fi

  notificar "($i/$total) $nome"
  echo "===== $nome =====" >> "$LOG"

  # Texto interno ilegível (fonte com codificação quebrada) ou ausente (escaneado):
  # o PDF inteiro vai para o OCR da Apple, que é rápido e não usa o llama-server do Marker.
  barra "📄 $i/$total · Analisando PDF"
  diag=$(apple diagnostico "$f" 2>> "$LOG")
  echo "Diagnóstico: $diag" >> "$LOG"
  if [[ "$diag" == ocr* ]]; then
    saida_ocr="$tmpdir/$i.md"
    if STATUS_PREFIXO="$i/$total · " apple ocr "$f" "$saida_ocr" "$STATUS" >> "$LOG" 2>&1 && [ -s "$saida_ocr" ] \
       && cp "$saida_ocr" "$destino" >> "$LOG" 2>&1; then
      ok=$((ok+1)); via_ocr+=("$nome")
    else
      falhas+=("$nome")
    fi
    continue
  elif [[ "$diag" != ok* ]]; then
    falhas+=("$nome")
    continue
  fi

  # O Marker sempre cria a subpasta <saida>/<base>/ com o .md, um _meta.json e as imagens.
  # Gera tudo no temporário e copia para o lado do PDF só o que interessa.
  saida="$tmpdir/$i"
  md="$saida/$base/$base.md"
  plog="$tmpdir/$i.log"
  progresso="Carregando modelos"
  barra "📄 $i/$total · $progresso"
  # nice: prioridade menor, para o Mac engasgar menos enquanto o Marker roda.
  # --disable_ocr: o texto já foi validado, então o Marker nunca precisa subir o llama-server.
  nice -n 10 marker_single "$f" --output_dir "$saida" --disable_ocr > "$plog" 2>&1 &
  marker_pid=$!
  while kill -0 $marker_pid 2>/dev/null; do
    if [ -e "$STATUS.cancelar" ]; then
      pkill -P $marker_pid 2>/dev/null; kill $marker_pid 2>/dev/null
      cancelado=1
      break
    fi
    e=$(etapa "$plog"); [ -n "$e" ] && progresso="$e"
    barra "📄 $i/$total · $progresso"
    sleep 1
  done
  wait $marker_pid; rc=$?; marker_pid=""
  cat "$plog" >> "$LOG"
  if [ $cancelado -eq 1 ]; then
    echo "Cancelado pelo usuário" >> "$LOG"
    break
  fi

  if [ $rc -eq 0 ] && [ -s "$md" ]; then
    # Imagens = tudo na pasta que não é o .md nem o _meta.json (este é sempre descartado).
    imagens=("$saida/$base"/*(N.))
    imagens=(${imagens:#$md})
    imagens=(${imagens:#$saida/$base/${base}_meta.json})
    echo "Imagens: ${#imagens[@]}" >> "$LOG"
    if [ ${#imagens[@]} -eq 0 ]; then
      # Sem imagens: só o .md, direto ao lado do PDF.
      cp "$md" "$destino" >> "$LOG" 2>&1 && ok=$((ok+1)) || falhas+=("$nome")
    else
      # Com imagens: pasta <base>/ com o .md e as imagens (o .md referencia as imagens pelo nome).
      if mkdir "$dir/$base" >> "$LOG" 2>&1 && cp "$md" "${imagens[@]}" "$dir/$base/" >> "$LOG" 2>&1; then
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

resumo="Convertidos: $ok de $total"
[ $cancelado -eq 1 ] && resumo+=$'\n'"Cancelado pelo usuário"
[ $com_imagens -gt 0 ] && resumo+=$'\n'"Com imagens (salvos em pasta): $com_imagens"
if [ ${#via_ocr[@]} -gt 0 ]; then
  resumo+=$'\n'"Texto do PDF ilegível, convertido por OCR (sem imagens e com menos formatação): ${#via_ocr[@]}"
  resumo+=$'\n'"$(printf '• %s\n' "${via_ocr[@]:0:3}")"
  [ ${#via_ocr[@]} -gt 3 ] && resumo+=$'\n'"• e mais $(( ${#via_ocr[@]} - 3 ))"
fi
[ ${#pulados[@]} -gt 0 ] && resumo+=$'\n'"Pulados (MD já existia): ${#pulados[@]}"
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
