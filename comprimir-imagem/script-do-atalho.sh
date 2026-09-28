export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export LANG="pt_BR.UTF-8" LC_ALL="pt_BR.UTF-8"

LOG="$HOME/Library/Logs/comprimir-imagem.log"
: > "$LOG"

# Qualidade máxima do JPG (só recomprime se a original estiver acima disso).
QUALIDADE_JPG=85
# Faixa de qualidade aceita pelo pngquant para reduzir o PNG a uma paleta; abaixo disso, fica sem perda.
QUALIDADE_PNG="90-100"
# Qualidade ao recomprimir HEIC e WebP (formatos que já vêm comprimidos).
QUALIDADE_REENCODE=80
# Ganho mínimo (%) para manter o resultado. Em HEIC e WebP com perda é maior, para não perder qualidade à toa.
GANHO_MIN=2
GANHO_MIN_REENCODE=10

notificar() {
  osascript - "$1" <<'EOF'
on run argv
  display notification (item 1 of argv) with title "Comprimir imagem"
end run
EOF
}

# Diz se a imagem tem algo que a recompressão descartaria: "hdr" (mapa de ganho),
# "profundidade" (modo Retrato), "varias" (mais de uma imagem no arquivo) ou "ok".
inspecionar() {
  osascript -l JavaScript - "$1" <<'EOF'
ObjC.import("Foundation"); ObjC.import("ImageIO");
function run(argv) {
  var src = $.CGImageSourceCreateWithURL($.NSURL.fileURLWithPath(argv[0]), $());
  if (!src) return "erro";
  if (Number($.CGImageSourceGetCount(src)) > 1) return "varias";
  function tem(t) { return !ObjC.castRefToObject($.CGImageSourceCopyAuxiliaryDataInfoAtIndex(src, 0, $(t))).isNil(); }
  if (tem("kCGImageAuxiliaryDataTypeHDRGainMap") || tem("kCGImageAuxiliaryDataTypeISOGainMap")) return "hdr";
  if (tem("kCGImageAuxiliaryDataTypeDepth") || tem("kCGImageAuxiliaryDataTypeDisparity") ||
      tem("kCGImageAuxiliaryDataTypePortraitEffectsMatte")) return "profundidade";
  return "ok";
}
EOF
}

tamanho() { stat -f%z "$1" 2>/dev/null || echo 0; }

formatar() {
  if [ "$1" -ge 1048576 ]; then
    printf "%.1f MB" $(( $1 / 1048576.0 ))
  else
    printf "%.0f KB" $(( $1 / 1024.0 ))
  fi
}

faltando=()
for c in jpegoptim pngquant oxipng gifsicle cwebp webpinfo; do
  command -v $c >/dev/null 2>&1 || faltando+=($c)
done
if [ ${#faltando[@]} -gt 0 ]; then
  osascript - "${faltando[*]}" <<'EOF'
on run argv
  display alert "Ferramentas não encontradas: " & (item 1 of argv) message "Instale no Terminal com: brew install jpegoptim pngquant oxipng gifsicle webp" as critical
end run
EOF
  echo "Falhou: faltam ${faltando[*]}"
  exit 0
fi

# Todo o trabalho acontece numa pasta temporária; só o resultado final vai para a pasta do original.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

total=$#
i=0; ok=0
antes=0; depois=0
falhas=(); pulados=(); ignorados=(); otimizadas=(); preservadas=()

for f in "$@"; do
  i=$((i+1))
  nome=$(basename "$f")
  ext="${f:e}"
  destino="${f%.*} (comprimida).$ext"

  case "${ext:l}" in
    jpg|jpeg|png|gif|tif|tiff|heic|heif|webp) ;;
    *) ignorados+=("$nome"); continue ;;
  esac

  if [[ "$nome" == *"(comprimida)"* ]] || [ -e "$destino" ]; then
    pulados+=("$nome")
    continue
  fi

  notificar "($i/$total) $nome"
  echo "===== $nome =====" >> "$LOG"

  case "${ext:l}" in
    jpg|jpeg|heic|heif|tif|tiff)
      estado=$(inspecionar "$f" 2>> "$LOG")
      case "$estado" in
        ok) ;;
        hdr|profundidade|varias)
          echo "Não comprimida: $estado" >> "$LOG"
          preservadas+=("$nome"); continue ;;
        *)
          echo "Não foi possível inspecionar a imagem" >> "$LOG"
          falhas+=("$nome"); continue ;;
      esac ;;
  esac

  saida="$TMP/$i.$ext"
  minimo=$GANHO_MIN
  rc=0

  case "${ext:l}" in
    jpg|jpeg)
      # Mantém EXIF (orientação, data) e perfil de cor; tira comentários, XMP e IPTC.
      jpegoptim --max=$QUALIDADE_JPG --all-progressive --strip-com --strip-xmp --strip-iptc \
        --stdout "$f" > "$saida" 2>> "$LOG" || rc=$? ;;
    png)
      pngquant --quality=$QUALIDADE_PNG --speed 1 --skip-if-larger --output "$saida" -- "$f" >> "$LOG" 2>&1
      q=$?
      if [ $q -ne 0 ]; then
        echo "pngquant não reduziu (código $q); só otimização sem perda" >> "$LOG"
        cp "$f" "$saida" || rc=1
      fi
      [ $rc -eq 0 ] && { oxipng -q -o 4 --strip safe "$saida" >> "$LOG" 2>&1 || rc=$?; } ;;
    gif)
      gifsicle -O3 --lossy=20 "$f" -o "$saida" >> "$LOG" 2>&1 || rc=$? ;;
    tif|tiff)
      sips -s formatOptions lzw "$f" --out "$saida" >> "$LOG" 2>&1 || rc=$? ;;
    heic|heif)
      minimo=$GANHO_MIN_REENCODE
      sips -s formatOptions $QUALIDADE_REENCODE "$f" --out "$saida" >> "$LOG" 2>&1 || rc=$? ;;
    webp)
      info=$(webpinfo "$f" 2>&1)
      if [[ "$info" == *"Animation: 1"* ]]; then
        echo "WebP animado, não suportado" >> "$LOG"
        ignorados+=("$nome"); continue
      elif [[ "$info" == *"Format: Lossless"* ]]; then
        cwebp -quiet -lossless -z 9 -mt -metadata icc "$f" -o "$saida" >> "$LOG" 2>&1 || rc=$?
      else
        minimo=$GANHO_MIN_REENCODE
        cwebp -quiet -q $QUALIDADE_REENCODE -m 6 -sharp_yuv -mt -metadata icc "$f" -o "$saida" >> "$LOG" 2>&1 || rc=$?
      fi ;;
  esac

  a=$(tamanho "$f"); d=$(tamanho "$saida")
  if [ $rc -ne 0 ] || [ "$d" -eq 0 ]; then
    falhas+=("$nome")
    continue
  fi

  ganho=$(( (a - d) * 100 / a ))
  echo "$(formatar $a) → $(formatar $d) ($ganho% menor)" >> "$LOG"
  if [ $ganho -lt $minimo ]; then
    echo "Ganho abaixo de $minimo%, resultado descartado" >> "$LOG"
    otimizadas+=("$nome")
    continue
  fi

  if mv "$saida" "$destino" 2>> "$LOG"; then
    ok=$((ok+1))
    antes=$((antes+a)); depois=$((depois+d))
  else
    falhas+=("$nome")
  fi
done

resumo="Comprimidas: $ok de $total"
if [ $ok -gt 0 ]; then
  resumo+=$'\n'"$(formatar $antes) → $(formatar $depois) ($(( (antes - depois) * 100 / antes ))% menor)"
fi
[ ${#otimizadas[@]} -gt 0 ] && resumo+=$'\n'"Já estavam otimizadas: ${#otimizadas[@]}"
[ ${#preservadas[@]} -gt 0 ] && resumo+=$'\n'"Não comprimidas (HDR, Retrato ou várias imagens): ${#preservadas[@]}"
[ ${#pulados[@]} -gt 0 ] && resumo+=$'\n'"Pulados (já comprimida): ${#pulados[@]}"
[ ${#ignorados[@]} -gt 0 ] && resumo+=$'\n'"Ignorados (formato não aceito): ${#ignorados[@]}"

if [ ${#falhas[@]} -gt 0 ]; then
  resumo+=$'\n'"Falharam: ${#falhas[@]}"
  lista=$(printf '• %s\n' "${falhas[@]}")
  osascript - "$resumo" "$lista" "$LOG" <<'EOF'
on run argv
  set msg to (item 1 of argv) & return & return & "Falharam:" & return & (item 2 of argv)
  set r to display alert "Algumas imagens falharam" message msg as critical buttons {"Ver log", "OK"} default button "OK"
  if button returned of r is "Ver log" then do shell script "open -e " & quoted form of (item 3 of argv)
end run
EOF
fi

echo "$resumo"
