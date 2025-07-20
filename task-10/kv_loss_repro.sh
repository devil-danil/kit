#!/usr/bin/env bash
# kv_loss_repro.sh ─ 100 % воспроизводимый тест + полный сбор артефактов
set -Eeuo pipefail

### ────────── конфиг кластера ──────────
DATA_DIR_BASE=/opt/data          # → /opt/data1,2,3.  поменяйте при необходимости
API_PORT=8080                    # front-порт (curl ходит только сюда)
UNITS=(database1 database2 database3)

### ────────── prereq & sudo ──────────
for t in jq curl ss journalctl tar; do command -v "$t" &>/dev/null || { echo "need $t"; exit 1; }; done
[[ $EUID -ne 0 ]] && exec sudo -E "$0" "$@"

die(){ echo -e "\e[1;31m$*\e[0m"; exit 1; }
say(){ echo -e "\e[1;36m$*\e[0m"; }

### ────────── helpers ──────────
front_unit() {                    # кто реально слушает :8080
  local pid unit
  pid=$(ss -lntp | awk -v p=":${API_PORT}$" '$4~p{print gensub(/.*pid=([0-9]+).*/, "\\1", 1, $NF)}')
  [[ -z $pid ]] && die "порт $API_PORT не слушается"
  unit=$(systemctl status "$pid" --no-legend | awk '{print $1}')
  echo "${unit%.service}"
}

dump_dir() {                      # $1=вход-дир; $2=выход-файл
  mkdir -p "$(dirname "$2")"
  if [[ -d $1 ]]; then
    (cd "$1" && ls -lR) >"$2"
  else
    echo "DIR_MISSING" >"$2"
  fi
}

store_file() {                    # src  dst
  [[ -f $1 ]] && cp -a "$1" "$2" || echo "NO_FILE" >"$2"
}

save_state() {                    # pre | post
  local phase=$1 dir
  mkdir -p "$ARCH/$phase"
  for i in 1 2 3; do
    dir="${DATA_DIR_BASE}${i}"
    ### файл-листинг каталога
    dump_dir "$dir"               "$ARCH/$phase/db${i}.ls"
    ### последний checkpoint (если есть)
    local cp=$(ls "$dir"/checkpoints/checkpoint-*.json.lz4 2>/dev/null | tail -1 || true)
    if [[ -n $cp ]]; then
      lz4 -d "$cp" -c >"$ARCH/$phase/db${i}.json" 2>/dev/null || echo "DECODE_ERR" >"$ARCH/$phase/db${i}.json"
    else
      echo "NO_CHECKPOINT" >"$ARCH/$phase/db${i}.json"
    fi
    ### WAL
    store_file "$dir/wal.log"   "$ARCH/$phase/db${i}_wal.log"
  done
}

### ────────── сценарий ──────────
FRONT=$(front_unit)
for u in "${UNITS[@]}"; do [[ $u != "$FRONT" ]] && VICTIM=$u && break; done

ts=$(date +%Y%m%d_%H%M%S)
ARCH=evidence_"$ts"
key="lost_$ts"
val="value_$RANDOM"

say "Front=$FRONT   Victim=$VICTIM"

say "Step A  stop $VICTIM"; systemctl stop "$VICTIM".service; sleep 3
say "Step B  POST $key"
code=$(curl -s -o /dev/null -w "%{http_code}" -L --post302 \
        -X POST "http://localhost:$API_PORT/keys/$key" -d "$val" || true)
[[ $code =~ ^2 ]] || die "curl вернул HTTP $code"

save_state pre

say "Step C  start $VICTIM"; systemctl start "$VICTIM".service; sleep 5
say "Step D  stop $FRONT";  systemctl stop "$FRONT".service;  sleep 5
say "Step E  GET $key"
got=$(curl -s http://localhost:$API_PORT/keys/$key || true)

rc=0; msg="✓ без потери"
[[ $got != "$val" ]] && { rc=42; msg="✗ ключ потерян! ожидали '$val', получили '${got:-<пусто>}'"; }
echo -e "\e[1;35m$msg\e[0m"

save_state post
journalctl -u database1.service -u database2.service -u database3.service --since "-8min" >"$ARCH/cluster.log"
tar czf "$ARCH.tar.gz" "$ARCH"
say "Архив сформирован: $ARCH.tar.gz"

for ph in pre post; do
  echo "── $ph ──"
  for n in 1 2 3; do
    jq -r --arg k "$key" '.db[$k] // "ABSENT"' "$ARCH/$ph/db${n}.json" 2>/dev/null | sed "s/^/db${n}: /"
  done
done

exit $rc