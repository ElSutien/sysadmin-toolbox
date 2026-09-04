#!/bin/bash
(return 0 2>/dev/null) || { echo "This file can only be sourced"; exit 1; }

# =========================
# Terminal label top-right
# =========================

# Colores (256-color):
# BG verde oscuro = 22, FG claro = 231
export TERM_LABEL_BG="${TERM_LABEL_BG:-22}"
export TERM_LABEL_FG="${TERM_LABEL_FG:-231}"

#Header
export TERM_HEADER_LINES="${TERM_LABEL_LINES:-1}"   # líneas reservadas arriba

# Guarda tu PS1 "real" una vez (sin cambiarlo visualmente)
if [ -z "${__PS1_BASE+x}" ]; then
  __PS1_BASE="$PS1"
fi

# Estado interno para poder borrar el label previo
__TERM_LABEL_LASTLEN=0
__TERM_LABEL_LASTCOLS=0

__set_window_title_ps1() {
  # No cambia el prompt visible, solo añade el escape de título
  local title
  [ -n "$1" ] && title="$1" || title='\\u@\\h: \\w'
  #PS1="\[\e]0;${title}\a\]${__PS1_BASE}"
  PS1=$(echo "$PS1" | sed -E 's#\\\[\\e]0;(.)*\\a\\]#\\\[\\e]0;'"${title}"'\\a\\\]#')
}

__draw_term_label_topright() {
  [ -z "$TERM_LABEL" ] && return

  local cols label padded len start old_start
  cols=$(tput cols 2>/dev/null || echo 80)

  # Label en mayúsculas
  label=$(printf '%s' "$TERM_LABEL" | tr '[:lower:]' '[:upper:]')

  # Píntalo con padding para que se vea mejor
  padded=" ${label} "
  len=${#padded}

  # --- Borra el label anterior (en su posición anterior) ---
  if [ "${__TERM_LABEL_LASTLEN:-0}" -gt 0 ] && [ "${__TERM_LABEL_LASTCOLS:-0}" -gt 0 ]; then
    old_start=$((__TERM_LABEL_LASTCOLS - __TERM_LABEL_LASTLEN + 1))
    [ "$old_start" -lt 1 ] && old_start=1

    printf '\e7'                      # save cursor
    printf '\e[1;%dH' "$old_start"    # row 1, old column
    printf '\e[0m'                    # reset attrs
    printf '%*s' "$__TERM_LABEL_LASTLEN" ""  # spaces
    printf '\e8'                      # restore cursor
  fi

  # --- Calcula nueva posición (top-right) ---
  start=$((cols - len + 1))
  [ "$start" -lt 1 ] && start=1

  # Dibuja sin mover el cursor del usuario
  printf '\e7'                    # save cursor
  printf '\e[1;%dH' "$start"      # row 1, new column

  # Fondo verde oscuro + texto claro
  printf '\e[48;5;%sm\e[38;5;%sm' "$TERM_LABEL_BG" "$TERM_LABEL_FG"

  # Si no cabe entero, recorta por la izquierda
  if [ "$len" -gt "$cols" ]; then
    padded="${padded: -$cols}"
    len=${#padded}
    start=1
    printf '\e[1;1H'
  fi

  printf '%s' "$padded"
  printf '\e[0m'                  # reset
  printf '\e8'                    # restore cursor

  # Guarda estado para borrar luego
  __TERM_LABEL_LASTLEN=$len
  __TERM_LABEL_LASTCOLS=$cols
}

__term_label_header() {
  local padded len
  local label="$TERM_HEAD"
  local H="$TERM_HEADER_LINES"

  # Si no hay label: reset de región de scroll y salir
  if [ -z "$label" ]; then
    printf '\e[r'      # reset scroll region a pantalla completa
    return
  fi
  
  padded=" ${label} "
  len=${#padded}

  #command -v figlet >/dev/null 2>&1 || return

  local lines cols top bottom
  lines=$(tput lines 2>/dev/null || echo 24)
  cols=$(tput cols 2>/dev/null || echo 80)

  # Si la terminal es muy pequeña, no hacemos nada raro
  if [ "$lines" -le "$((H+2))" ]; then
    return
  fi

  top=$((H+1))
  bottom=$lines
  
  # --- Calcula nueva posición (top-right) ---
  start=$((cols - len + 1))
  [ "$start" -lt 1 ] && start=1

  # Guarda cursor
  printf '\e7'
  
  # Ajusta región de scroll: SOLO de (H+1) hasta el final
  printf '\e[%d;%dr' "$top" "$bottom"
  
  # Limpia la cabecera (líneas 1..H)
  printf '\e[1;1H'
  for _ in $(seq 1 "$H"); do
    printf '\e[2K\e[1B'
  done
  
  # Dibuja sin mover el cursor del usuario
  printf '\e[1;%dH' "$start"      # row 1, new column

  # Fondo verde oscuro + texto claro
  printf '\e[48;5;%sm\e[38;5;%sm' "$TERM_LABEL_BG" "$TERM_LABEL_FG"
  
  # Si no cabe entero, recorta por la izquierda
  if [ "$len" -gt "$cols" ]; then
    padded="${padded: -$cols}"
    len=${#padded}
    start=1
    printf '\e[1;1H'
  fi

  #Print label
  printf '%s' "$padded"
  
  # Reset de modificadores
  printf '\e[0m'

  # Restore cursor to user position
  printf '\e8'
}

# Hook antes de cada prompt (sin romper PROMPT_COMMAND existente)
__PROMPT_COMMAND_OLD="$PROMPT_COMMAND"
PROMPT_COMMAND='__draw_term_label_topright;'"${__PROMPT_COMMAND_OLD:+ $' '"$__PROMPT_COMMAND_OLD"}"

# Comando: set label + cambia título de ventana
tlabel() {
  TERM_LABEL="$*"
  local upper
  upper=$(printf '%s' "$TERM_LABEL" | tr '[:lower:]' '[:upper:]')

  __set_window_title_ps1 "$upper"
  __draw_term_label_topright
}

# Quitar label + limpiar + restaurar título vacío
tlabeloff() {
  TERM_LABEL=""
  __set_window_title_ps1 ""
  __draw_term_label_topright  # borra el anterior (por el mecanismo interno)
  __TERM_LABEL_LASTLEN=0
  __TERM_LABEL_LASTCOLS=0
}


thead() {
  local head=$(printf '%s' "$*" | tr '[:lower:]' '[:upper:]')
  export TERM_HEAD="$head"
  __term_label_header
}

theadoff() {
  unset TERM_HEAD
  printf '\e[r'
}


ttitle() {
  local TERM_TITLE="$*"
  
  __set_window_title_ps1 "$TERM_TITLE"
}

ttitleoff() {
  __set_window_title_ps1 ""
}



# =========================
# SSH: painter en background mientras ssh está activo
# =========================

# Actívalo/desactívalo fácil:
: "${TERM_LABEL_SSH_PAINTER:=1}"     # 1 = ON, 0 = OFF
: "${TERM_LABEL_SSH_INTERVAL:=1}"    # segundos entre repintados

__TERM_LABEL_PAINTER_PID=""

__term_label_painter_start() {
  # Solo en terminal interactiva real
  [[ $- != *i* ]] && return
  [[ ! -t 1 ]] && return

  # Si ya está corriendo, no lo duplices
  [[ -n "$__TERM_LABEL_PAINTER_PID" ]] && return

  # Pintor en background escribiendo al TTY
  (
    while :; do
      __draw_term_label_topright
      sleep "$TERM_LABEL_SSH_INTERVAL"
    done
  ) >/dev/tty 2>/dev/null &

  __TERM_LABEL_PAINTER_PID=$!
}

__term_label_painter_stop() {
  [[ -z "$__TERM_LABEL_PAINTER_PID" ]] && return
  kill "$__TERM_LABEL_PAINTER_PID" 2>/dev/null
  wait "$__TERM_LABEL_PAINTER_PID" 2>/dev/null
  __TERM_LABEL_PAINTER_PID=""
}

__ssh_pick_dest() {
  # Intenta sacar el "destino" (host) del comando ssh
  # (heurística suficientemente buena para el 95% de usos)
  local skip=0 arg dest=""
  for arg in "$@"; do
    if ((skip)); then skip=0; continue; fi
    case "$arg" in
      -p|-i|-F|-J|-o|-l|-b|-c|-D|-E|-I|-L|-m|-O|-Q|-R|-S|-W|-w)
        skip=1 ;;
      -*) ;;
      *)
        dest="$arg"
        break ;;
    esac
  done
  printf '%s' "$dest"
}

# Wrapper de ssh (para que sea automático)
ssh() {
  # Si el usuario lo desactiva, usa ssh normal
  if [[ "${TERM_LABEL_SSH_PAINTER}" != "1" ]] || [[ -z "${TERM_LABEL}" ]]; then
    command ssh "$@"
    return $?
  fi

  # Solo en modo interactivo
  if [[ $- != *i* || ! -t 1 ]]; then
    command ssh "$@"
    return $?
  fi

  local prev_label="${TERM_LABEL-}"
  local prev_lastlen="${__TERM_LABEL_LASTLEN-0}"
  local prev_lastcols="${__TERM_LABEL_LASTCOLS-0}"

  local dest host label
  dest="$(__ssh_pick_dest "$@")"
  host="${dest##*@}"
  host="${host%%:*}"              # por si viene raro (normalmente no)

  if [[ -n "$TERM_LABEL" ]]; then
    label="$TERM_LABEL"
  elif [[ -n "$host" ]]; then
    label="SSH:${host%%.*}"
  else
    label="SSH"
  fi

  # Set label + título antes de entrar
  TERM_LABEL="$label"
  __TERM_LABEL_LASTLEN=0
  __TERM_LABEL_LASTCOLS=0
  __set_window_title_ps1 "$TERM_LABEL"
  __draw_term_label_topright

  # Arranca pintor y ejecuta ssh real
  __term_label_painter_start
  command ssh "$@"
  local rc=$?

  # Para pintor y restaura label anterior
  __term_label_painter_stop
  TERM_LABEL="$prev_label"
  __TERM_LABEL_LASTLEN="$prev_lastlen"
  __TERM_LABEL_LASTCOLS="$prev_lastcols"

  # Restaura título y repinta (ya vuelve PROMPT_COMMAND luego)
  __set_window_title_ps1 "$(printf '%s' "$TERM_LABEL" | tr '[:lower:]' '[:upper:]')"
  __draw_term_label_topright

  return $rc
}


