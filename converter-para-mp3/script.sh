export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export LANG="pt_BR.UTF-8" LC_ALL="pt_BR.UTF-8"

LOG="$HOME/Library/Logs/converter-mp3.log"
: > "$LOG"

notificar() {
  osascript - "$1" <<'EOF'
on run argv
  display notification (item 1 of argv) with title "Converter para MP3"
end run
EOF
}

if ! command -v ffmpeg >/dev/null 2>&1; then
  osascript -e 'display alert "ffmpeg não encontrado" message "Instale no Terminal com: brew install ffmpeg" as critical'
  echo "Falhou: ffmpeg não encontrado"
  exit 0
fi

total=$#
i=0; ok=0
falhas=(); pulados=(); ignorados=()

for f in "$@"; do
  i=$((i+1))
  nome=$(basename "$f")
  destino="${f%.*}.mp3"

  case "${f:e:l}" in
    ogg|oga|opus|wav|flac|m4a|aac|wma|aiff|aif) ;;
    *) ignorados+=("$nome"); continue ;;
  esac

  if [ -e "$destino" ]; then
    pulados+=("$nome")
    continue
  fi

  notificar "($i/$total) $nome"
  echo "===== $nome =====" >> "$LOG"

  if ffmpeg -nostdin -n -i "$f" -vn -codec:a libmp3lame -q:a 2 "$destino" >> "$LOG" 2>&1; then
    ok=$((ok+1))
  else
    falhas+=("$nome")
    rm -f "$destino"
  fi
done

resumo="Convertidos: $ok de $total"
[ ${#pulados[@]} -gt 0 ] && resumo+=$'\n'"Pulados (MP3 já existia): ${#pulados[@]}"
[ ${#ignorados[@]} -gt 0 ] && resumo+=$'\n'"Ignorados (não é áudio): ${#ignorados[@]}"

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
