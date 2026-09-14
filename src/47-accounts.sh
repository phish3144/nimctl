# ── Chat accounts (Open WebUI) ────────────────────────────────────────────────
T_de+=(
  [acc_nodb]="Chat wurde noch nie gestartet – keine Datenbank" [acc_nopython]="kein Python-Interpreter gefunden – python3 installieren"
  [acc_dberr]="Datenbankfehler" [acc_none]="keine Konten" [acc_col_name]="Name" [acc_col_email]="E-Mail" [acc_col_role]="Rolle" [acc_col_created]="Erstellt"
  [acc_menu]="1) Konten  2) Passwort  3) Zurücksetzen  (Enter = zurück)"
  [acc_email_prompt]="E-Mail-Adresse" [acc_email_missing]="E-Mail-Adresse erforderlich" [acc_email_unknown]="%s: unbekannte E-Mail-Adresse – bekannt: %s"
  [acc_pw_new]="Neues Passwort" [acc_pw_confirm]="Passwort wiederholen" [acc_pw_mismatch]="Passwörter stimmen nicht überein"
  [acc_pw_short]="Passwort muss mindestens 8 Zeichen haben" [acc_pw_long]="Passwort darf höchstens 72 Byte lang sein (bcrypt-Grenze)"
  [acc_pw_noninteractive]="kein Terminal und NIMCTL_CHAT_PASSWORD nicht gesetzt – NIMCTL_CHAT_PASSWORD=… setzen"
  [acc_hash_missing]="kein bcrypt verfügbar – installieren: python3-bcrypt oder apache2-utils (htpasswd)"
  [acc_hash_failed]="Passwort-Hashing fehlgeschlagen"
  [acc_stop_q]="Chat stoppen, damit die Änderung wirkt?" [acc_write_fail]="Schreiben fehlgeschlagen" [acc_passwd_ok]="%s: Passwort aktualisiert"
  [acc_reset_warn]="Bestehende Chats bleiben in der Datenbank, gehören aber niemandem mehr – das nächste registrierte Konto wird automatisch Admin."
  [acc_reset_q]="Wirklich alle Konten löschen?" [acc_reset_type]="Zur Bestätigung RESET eingeben" [acc_reset_mismatch]="RESET nicht eingegeben – abgebrochen"
  [acc_reset_done]="Konten gelöscht" [h_accounts]="Chat-Konten verwalten: nimctl chat users | passwd [E-Mail] [--admin] | reset"
)
T_en+=(
  [acc_nodb]="chat has never been started – no database" [acc_nopython]="no Python interpreter found – install python3"
  [acc_dberr]="database error" [acc_none]="no accounts" [acc_col_name]="Name" [acc_col_email]="Email" [acc_col_role]="Role" [acc_col_created]="Created"
  [acc_menu]="1) users  2) passwd  3) reset  (Enter = back)"
  [acc_email_prompt]="Email address" [acc_email_missing]="email address required" [acc_email_unknown]="%s: unknown email address – known: %s"
  [acc_pw_new]="New password" [acc_pw_confirm]="Repeat password" [acc_pw_mismatch]="passwords do not match"
  [acc_pw_short]="password must be at least 8 characters" [acc_pw_long]="password must be at most 72 bytes (bcrypt limit)"
  [acc_pw_noninteractive]="no terminal and NIMCTL_CHAT_PASSWORD not set – set NIMCTL_CHAT_PASSWORD=…"
  [acc_hash_missing]="no bcrypt available – install: python3-bcrypt or apache2-utils (htpasswd)"
  [acc_hash_failed]="password hashing failed"
  [acc_stop_q]="Stop chat so the change takes effect?" [acc_write_fail]="write failed" [acc_passwd_ok]="%s: password updated"
  [acc_reset_warn]="Existing chats stay in the database but will belong to nobody – the next account that signs up automatically becomes admin."
  [acc_reset_q]="Really delete all accounts?" [acc_reset_type]="Type RESET to confirm" [acc_reset_mismatch]="RESET not entered – aborted"
  [acc_reset_done]="accounts deleted" [h_accounts]="manage chat accounts: nimctl chat users | passwd [email] [--admin] | reset"
)

acc_db() { printf '%s/webui-data/webui.db' "$NIM_DIR"; }
acc_python() { # first working interpreter: $NIMCTL_WEBUI_PYTHON, the open-webui uv tool's own python (has bcrypt), else python3
  [[ -n "${NIMCTL_WEBUI_PYTHON:-}" ]] && { printf '%s' "$NIMCTL_WEBUI_PYTHON"; return 0; }
  local u; u="$(uv tool dir 2>/dev/null)/open-webui/bin/python"
  [[ -x "$u" ]] && { printf '%s' "$u"; return 0; }
  has python3 && { printf 'python3'; return 0; }
  return 1
}
acc_py() { # acc_py <<'PY' … PY – runs the chosen interpreter, script on stdin, $NIMCTL_ACCOUNTS_DB exported
  local py; py=$(acc_python) || return 1
  NIMCTL_ACCOUNTS_DB="$(acc_db)" "$py" -
}
acc_hash() { # acc_hash <password> → bcrypt hash on stdout; 1 = neither bcrypt nor htpasswd available; 2 = bcrypt present but hashing failed (see stderr)
  local pw="$1" py hash rc
  if py=$(acc_python); then
    hash=$(NIMCTL_ACCOUNTS_PW="$pw" "$py" - <<'PY'
import os, sys
try:
    import bcrypt
except ImportError:
    sys.exit(1)
pw = os.environ.get("NIMCTL_ACCOUNTS_PW", "").encode()
try:
    print(bcrypt.hashpw(pw, bcrypt.gensalt(12)).decode())
except Exception as e:
    print(f"nimctl: bcrypt: {e}", file=sys.stderr)
    sys.exit(2)
PY
    ); rc=$?
    [[ $rc -eq 0 && -n "$hash" ]] && { printf '%s' "$hash"; return 0; }
    (( rc == 2 )) && return 2
  fi
  if has htpasswd; then
    hash=$(htpasswd -bnBC 12 '' "$pw" 2>/dev/null | tr -d ':\n')
    [[ -n "$hash" ]] && { printf '%s' "$hash"; return 0; }
  fi
  return 1
}
acc_list() { # \x1f-separated: name email role created_at
  acc_py <<'PY'
import os, sqlite3, sys
con = sqlite3.connect(os.environ["NIMCTL_ACCOUNTS_DB"], timeout=5)
try:
    for name, email, role, created in con.execute("SELECT name, email, role, created_at FROM user ORDER BY created_at"):
        print(f"{name}\x1f{email}\x1f{role}\x1f{created or 0}")
except sqlite3.Error as e:
    print(f"nimctl: {e}", file=sys.stderr); sys.exit(1)
PY
}
acc_admin_emails() {
  acc_py <<'PY'
import os, sqlite3, sys
con = sqlite3.connect(os.environ["NIMCTL_ACCOUNTS_DB"], timeout=5)
try:
    for (email,) in con.execute("SELECT email FROM user WHERE role='admin' ORDER BY email"):
        print(email)
except sqlite3.Error as e:
    print(f"nimctl: {e}", file=sys.stderr); sys.exit(1)
PY
}
acc_known_emails() {
  acc_py <<'PY'
import os, sqlite3, sys
con = sqlite3.connect(os.environ["NIMCTL_ACCOUNTS_DB"], timeout=5)
try:
    for (email,) in con.execute("SELECT email FROM user ORDER BY email"):
        print(email)
except sqlite3.Error as e:
    print(f"nimctl: {e}", file=sys.stderr); sys.exit(1)
PY
}
acc_email_exists() { # $1=email; 0=exists 1=not found 2=db error (no message shown – caller decides)
  local known; known=$(acc_known_emails) || return 2
  grep -qxF "$1" <<<"$known"
}
acc_resolve_email() { # acc_resolve_email <given> → REPLY=target email; 1 = failed (message already shown)
  local given="$1" admins n=0
  if [[ -n "$given" ]]; then REPLY="$given"; return 0; fi
  admins=$(acc_admin_emails) || { bad "$(t acc_dberr)"; return 1; }
  [[ -n "$admins" ]] && n=$(wc -l <<<"$admins")
  if [[ "$n" -eq 1 ]]; then REPLY="$admins"; return 0; fi
  prompt "$(t acc_email_prompt)" || return 1
  [[ -n "$REPLY" ]] || { bad "$(t acc_email_missing)"; return 1; }
}
acc_read_password() { # → REPLY=new password; 1 = failed (message already shown)
  local p1
  if [[ -n "${NIMCTL_CHAT_PASSWORD:-}" ]]; then
    p1="$NIMCTL_CHAT_PASSWORD"
  else
    (( INTERACTIVE )) || { bad "$(t acc_pw_noninteractive)"; return 1; }
    local p2
    prompt "$(t acc_pw_new)" hidden || return 1; p1="$REPLY"
    prompt "$(t acc_pw_confirm)" hidden || return 1; p2="$REPLY"
    [[ "$p1" == "$p2" ]] || { bad "$(t acc_pw_mismatch)"; return 1; }
    [[ ${#p1} -ge 8 ]] || { bad "$(t acc_pw_short)"; return 1; }
  fi
  local pwbytes; pwbytes=$(printf '%s' "$p1" | wc -c)
  (( pwbytes <= 72 )) || { bad "$(t acc_pw_long)"; return 1; }
  REPLY="$p1"
}
acc_pause_chat() { # ensures chat isn't running before a DB write; ACC_RESUME=1 → caller should start_chat again
  ACC_RESUME=0
  svc_state chat || return 0
  [[ "$SVC_BY" == nimctl || "$SVC_BY" == systemd ]] || return 0
  ask "$(t acc_stop_q)" n || { info "$(t aborted)"; return 1; }
  stop_svc chat; ACC_RESUME=1
}
acc_resume_chat() { (( ACC_RESUME )) && start_chat; return 0; }

acc_users() {
  [[ -f "$(acc_db)" ]] || { bad "$(t acc_nodb)"; return 1; }
  acc_python >/dev/null || { bad "$(t acc_nopython)"; return 1; }
  local rows; rows=$(acc_list) || { bad "$(t acc_dberr)"; return 1; }
  [[ -n "$rows" ]] || { info "$(t acc_none)"; return 0; }
  printf "  %-22s %-28s %-7s %s\n" "$(t acc_col_name)" "$(t acc_col_email)" "$(t acc_col_role)" "$(t acc_col_created)"
  local name email role created
  while IFS=$'\x1f' read -r name email role created; do
    printf "  %-22s %-28s %-7s %s\n" "$(trunc "$name" 22)" "$(trunc "$email" 28)" "$role" "$(fmt_time "$created" '+%Y-%m-%d %H:%M')"
  done <<<"$rows"
}
acc_passwd() { # acc_passwd [email] [--admin]
  [[ -f "$(acc_db)" ]] || { bad "$(t acc_nodb)"; return 1; }
  acc_python >/dev/null || { bad "$(t acc_nopython)"; return 1; }
  local email="" admin=0 a
  for a in "$@"; do case "$a" in --admin) admin=1;; *) [[ -z "$email" ]] && email="$a";; esac; done
  acc_resolve_email "$email" || return 1
  email="$REPLY"
  acc_email_exists "$email"; local exists_rc=$?
  if (( exists_rc == 2 )); then bad "$(t acc_dberr)"; return 1; fi
  if (( exists_rc == 1 )); then
    local known; known=$(acc_known_emails) || { bad "$(t acc_dberr)"; return 1; }
    known=$(tr '\n' ' ' <<<"$known"); known="${known% }"
    bad "$(tf acc_email_unknown "$email" "$known")"; return 1
  fi
  acc_read_password || return 1
  local pw="$REPLY" hash hash_rc
  hash=$(acc_hash "$pw"); hash_rc=$?
  if (( hash_rc == 2 )); then bad "$(t acc_hash_failed)"; return 1; fi
  (( hash_rc == 0 )) || { bad "$(t acc_hash_missing)"; return 1; }
  acc_pause_chat || return 1
  local rc
  NIMCTL_ACCOUNTS_EMAIL="$email" NIMCTL_ACCOUNTS_HASH="$hash" NIMCTL_ACCOUNTS_ADMIN="$admin" acc_py >/dev/null <<'PY'
import os, sqlite3, sys
con = sqlite3.connect(os.environ["NIMCTL_ACCOUNTS_DB"], timeout=5)
email = os.environ["NIMCTL_ACCOUNTS_EMAIL"]; h = os.environ["NIMCTL_ACCOUNTS_HASH"]
try:
    cur = con.execute("UPDATE auth SET password=?, active=1 WHERE email=?", (h, email))
    if cur.rowcount < 1:
        sys.exit(1)
    if os.environ.get("NIMCTL_ACCOUNTS_ADMIN") == "1":
        con.execute("UPDATE user SET role='admin' WHERE email=?", (email,))
    con.commit()
except sqlite3.Error as e:
    print(f"nimctl: {e}", file=sys.stderr); sys.exit(1)
PY
  rc=$?
  if (( rc == 0 )); then ok "$(tf acc_passwd_ok "$email")"; else bad "$(t acc_write_fail)"; fi
  acc_resume_chat; return $rc
}
acc_reset() {
  [[ -f "$(acc_db)" ]] || { bad "$(t acc_nodb)"; return 1; }
  acc_python >/dev/null || { bad "$(t acc_nopython)"; return 1; }
  warn "$(t acc_reset_warn)"
  ask "$(t acc_reset_q)" n || { info "$(t aborted)"; return 1; }
  if (( INTERACTIVE )); then
    prompt "$(t acc_reset_type)" || return 1
    [[ "$REPLY" == RESET ]] || { bad "$(t acc_reset_mismatch)"; return 1; }
  fi
  acc_pause_chat || return 1
  local rc
  acc_py >/dev/null <<'PY'
import os, sqlite3, sys
con = sqlite3.connect(os.environ["NIMCTL_ACCOUNTS_DB"], timeout=5)
try:
    con.execute("DELETE FROM auth"); con.execute("DELETE FROM user")
    con.commit()
except sqlite3.Error as e:
    print(f"nimctl: {e}", file=sys.stderr); sys.exit(1)
PY
  rc=$?
  if (( rc == 0 )); then ok "$(t acc_reset_done)"; else bad "$(t acc_write_fail)"; fi
  acc_resume_chat; return $rc
}
chat_admin() { # chat_admin <users|passwd|reset> [args…] – dispatched from `nimctl chat <sub>` (src/90-main.sh)
  local sub="${1:-}"; (( $# )) && shift
  case "$sub" in
    users)  acc_users;;
    passwd) acc_passwd "$@";;
    reset)  acc_reset "$@";;
    *)      bad "$(t unknown): $sub"; return 2;;
  esac
}
cmd_accounts() {
  sect "$(t k_n)"
  prompt "$(t acc_menu)" || return 1
  case "$REPLY" in
    1) acc_users;; 2) acc_passwd;; 3) acc_reset;;
    "") return 0;;
    *) bad "$(t invalid)";;
  esac
}
dash_register n cmd_accounts k_n use
