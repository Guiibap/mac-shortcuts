export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export LANG="pt_BR.UTF-8" LC_ALL="pt_BR.UTF-8"

MODEL="$HOME/whisper-models/ggml-large-v3-turbo.bin"
LOG="$HOME/Library/Logs/transcrever-audio.log"
: > "$LOG"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

notificar() {
  osascript - "$1" <<'EOF'
on run argv
  display notification (item 1 of argv) with title "Transcrever áudio"
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

if ! command -v ffmpeg >/dev/null 2>&1; then
  alerta "ffmpeg não encontrado" "Instale no Terminal com: brew install ffmpeg"
  echo "Falhou: ffmpeg não encontrado"
  exit 0
fi

if ! command -v whisper-cli >/dev/null 2>&1; then
  alerta "whisper-cli não encontrado" "Instale no Terminal com: brew install whisper-cpp"
  echo "Falhou: whisper-cli não encontrado"
  exit 0
fi

if [ ! -f "$MODEL" ]; then
  alerta "Modelo não encontrado" "Arquivo esperado em: $MODEL"
  echo "Falhou: modelo não encontrado"
  exit 0
fi

total=$#
i=0; ok=0
falhas=(); pulados=(); ignorados=()

for f in "$@"; do
  i=$((i+1))
  nome=$(basename "$f")
  destino="${f%.*}.txt"

  case "${f:e:l}" in
    mp3|ogg|oga|opus|wav|flac|m4a|aac|wma|aiff|aif|mp4|m4v|mov|webm|mkv) ;;
    *) ignorados+=("$nome"); continue ;;
  esac

  if [ -e "$destino" ]; then
    pulados+=("$nome")
    continue
  fi

  notificar "($i/$total) $nome"
  echo "===== $nome =====" >> "$LOG"

  wav="$tmpdir/audio.wav"
  saida=""
  if ffmpeg -nostdin -y -i "$f" -vn -ar 16000 -ac 1 -c:a pcm_s16le "$wav" >> "$LOG" 2>&1; then
    saida=$(whisper-cli -m "$MODEL" -l pt -np -otxt -of "${f%.*}" -f "$wav" 2>> "$LOG")
    echo "$saida" >> "$LOG"
  fi
  if [[ "$saida" == *[^[:space:]]* ]]; then
    ok=$((ok+1))
  else
    falhas+=("$nome")
    rm -f "$destino"
  fi
  rm -f "$wav"
done

resumo="Transcritos: $ok de $total"
[ ${#pulados[@]} -gt 0 ] && resumo+=$'\n'"Pulados (TXT já existia): ${#pulados[@]}"
[ ${#ignorados[@]} -gt 0 ] && resumo+=$'\n'"Ignorados (não é áudio/vídeo): ${#ignorados[@]}"

if [ ${#falhas[@]} -gt 0 ]; then
  resumo+=$'\n'"Falharam: ${#falhas[@]}"
  lista=$(printf '• %s\n' "${falhas[@]}")
  osascript - "$resumo" "$lista" "$LOG" <<'EOF'
on run argv
  set msg to (item 1 of argv) & return & return & "Falharam:" & return & (item 2 of argv)
  set r to display alert "Algumas transcrições falharam" message msg as critical buttons {"Ver log", "OK"} default button "OK"
  if button returned of r is "Ver log" then do shell script "open -e " & quoted form of (item 3 of argv)
end run
EOF
fi

echo "$resumo"
