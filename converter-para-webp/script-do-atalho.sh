export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export LANG="pt_BR.UTF-8" LC_ALL="pt_BR.UTF-8"

LOG="$HOME/Library/Logs/converter-webp.log"
: > "$LOG"

QUALIDADE=80

notificar() {
  osascript - "$1" <<'EOF'
on run argv
  display notification (item 1 of argv) with title "Converter para WebP"
end run
EOF
}

# Lê a orientação EXIF (1 argumento) ou grava um PNG já na orientação certa (2 argumentos).
# O cwebp ignora a orientação EXIF e não lê HEIC; o ImageIO do macOS resolve os dois casos.
imageio() {
  osascript -l JavaScript - "$@" <<'EOF'
ObjC.import("Foundation"); ObjC.import("ImageIO"); ObjC.import("CoreGraphics");
function run(argv) {
  var src = $.CGImageSourceCreateWithURL($.NSURL.fileURLWithPath(argv[0]), $());
  if (!src) return "erro";
  var p = ObjC.deepUnwrap(ObjC.castRefToObject($.CGImageSourceCopyPropertiesAtIndex(src, 0, $())));
  if (!p) return "erro";
  if (argv.length < 2) return String(Number(p.Orientation || 1));
  var opts = $.NSMutableDictionary.dictionary;
  opts.setObjectForKey($.NSNumber.numberWithBool(true), $("kCGImageSourceCreateThumbnailFromImageAlways"));
  opts.setObjectForKey($.NSNumber.numberWithBool(true), $("kCGImageSourceCreateThumbnailWithTransform"));
  opts.setObjectForKey($.NSNumber.numberWithInt(Math.max(Number(p.PixelWidth), Number(p.PixelHeight))), $("kCGImageSourceThumbnailMaxPixelSize"));
  var img = $.CGImageSourceCreateThumbnailAtIndex(src, 0, opts);
  if (!img) return "erro";
  var dst = $.CGImageDestinationCreateWithURL($.NSURL.fileURLWithPath(argv[1]), $("public.png"), 1, $());
  $.CGImageDestinationAddImage(dst, img, $());
  return $.CGImageDestinationFinalize(dst) ? "ok" : "erro";
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

if ! command -v cwebp >/dev/null 2>&1; then
  osascript -e 'display alert "cwebp não encontrado" message "Instale no Terminal com: brew install webp" as critical'
  echo "Falhou: cwebp não encontrado"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

total=$#
i=0; ok=0
antes=0; depois=0
falhas=(); pulados=(); ignorados=(); maiores=()

for f in "$@"; do
  i=$((i+1))
  nome=$(basename "$f")
  destino="${f%.*}.webp"
  ext="${f:e:l}"

  case "$ext" in
    jpg|jpeg|heic|heif|tif|tiff) modo=foto ;;
    png) modo=png ;;
    gif) modo=gif ;;
    *) ignorados+=("$nome"); continue ;;
  esac

  if [ -e "$destino" ]; then
    pulados+=("$nome")
    continue
  fi

  notificar "($i/$total) $nome"
  echo "===== $nome =====" >> "$LOG"

  entrada="$f"
  if [ "$modo" != gif ]; then
    if [[ "$ext" == hei[cf] ]] || [ "$(imageio "$f")" != 1 ]; then
      entrada="$TMP/$i.png"
      if [ "$(imageio "$f" "$entrada")" != ok ]; then
        echo "Não foi possível ler a imagem pelo ImageIO" >> "$LOG"
        falhas+=("$nome")
        continue
      fi
      echo "Convertida para PNG temporário (HEIC ou orientação EXIF)" >> "$LOG"
    fi
  fi

  case "$modo" in
    foto) cmd=(cwebp -q $QUALIDADE -m 6 -sharp_yuv -mt -metadata icc "$entrada" -o "$destino") ;;
    png)  cmd=(cwebp -near_lossless 60 -q 100 -m 6 -mt -metadata icc "$entrada" -o "$destino") ;;
    gif)  cmd=(gif2webp -mixed -q $QUALIDADE -m 6 -mt "$entrada" -o "$destino") ;;
  esac

  if "${cmd[@]}" >> "$LOG" 2>&1; then
    ok=$((ok+1))
    a=$(tamanho "$f"); d=$(tamanho "$destino")
    antes=$((antes+a)); depois=$((depois+d))
    [ "$d" -gt "$a" ] && maiores+=("$nome")
    echo "$(formatar $a) → $(formatar $d)" >> "$LOG"
  else
    falhas+=("$nome")
    rm -f "$destino"
  fi
done

resumo="Convertidos: $ok de $total"
if [ $ok -gt 0 ] && [ $antes -gt 0 ]; then
  resumo+=$'\n'"$(formatar $antes) → $(formatar $depois) ($(( (antes - depois) * 100 / antes ))% menor)"
fi
[ ${#maiores[@]} -gt 0 ] && resumo+=$'\n'"Ficaram maiores que o original: ${#maiores[@]} (veja o log)"
[ ${#pulados[@]} -gt 0 ] && resumo+=$'\n'"Pulados (WebP já existia): ${#pulados[@]}"
[ ${#ignorados[@]} -gt 0 ] && resumo+=$'\n'"Ignorados (formato não aceito): ${#ignorados[@]}"

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
