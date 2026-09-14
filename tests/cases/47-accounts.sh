# shellcheck shell=bash
# Chat accounts (Open WebUI): users / passwd / reset against a hand-built sqlite db. Chat is stopped
# by the time this file runs (stopped in 20-services.sh), so no stop/start dance is exercised here.
DB="$TMP/home/webui-data/webui.db"
mkdir -p "$(dirname "$DB")"
python3 - "$DB" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("CREATE TABLE auth (id TEXT, email TEXT, password TEXT, active INTEGER)")
con.execute("CREATE TABLE user (id TEXT, name TEXT, email TEXT, role TEXT, profile_image_url TEXT, "
            "last_active_at INTEGER, updated_at INTEGER, created_at INTEGER, api_key TEXT, settings TEXT, "
            "info TEXT, oauth_sub TEXT)")
rows = [("1", "Admin", "admin@example.com", "admin"), ("2", "User", "user@example.com", "user")]
for uid, name, email, role in rows:
    con.execute("INSERT INTO auth (id, email, password, active) VALUES (?, ?, ?, 1)",
                (uid, email, "$2b$12$placeholderplaceholderplaceholderplace"))
    con.execute("INSERT INTO user (id, name, email, role, created_at, updated_at, last_active_at) "
                "VALUES (?, ?, ?, ?, 1700000000, 1700000000, 1700000000)", (uid, name, email, role))
con.commit()
PY

check "users: lists the admin account" "admin@example.com" < <(timeout 20 "$N" chat users)
check "users: lists the second account" "user@example.com" < <(timeout 20 "$N" chat users)

check "passwd: unknown email lists the known ones" "admin@example.com.*user@example.com" \
  < <(timeout 20 "$N" chat passwd doesnotexist@example.com)

# A DB read failure (locked db, corrupt file, …) must be reported honestly, not misread as
# "zero admins" / "unknown email" from the (empty) output of a python traceback.
cp "$DB" "$DB.bak"
printf 'not a sqlite database' >"$DB"
check "users: db error is reported honestly, not silently empty" "Datenbankfehler" \
  < <(timeout 20 "$N" chat users)
check "passwd: db error surfaces as a db error, not 'unknown email'" "Datenbankfehler" \
  < <(NIMCTL_CHAT_PASSWORD=Sup3rSecret timeout 20 "$N" chat passwd admin@example.com)
mv "$DB.bak" "$DB"

# bcrypt has a 72-byte input limit; a too-long password must get an honest message, not the
# "no bcrypt available" message (which is wrong and misdirecting when bcrypt is present).
LONGPW=$(printf 'a%.0s' {1..100})
check "passwd: overlong password is rejected with an honest message" "72 Byte" \
  < <(NIMCTL_CHAT_PASSWORD="$LONGPW" timeout 20 "$N" chat passwd admin@example.com)
nocheck "passwd: overlong password is not misreported as missing bcrypt" "kein bcrypt verfügbar" \
  < <(NIMCTL_CHAT_PASSWORD="$LONGPW" timeout 20 "$N" chat passwd admin@example.com)

HAVE_HASHER=0
python3 -c 'import bcrypt' 2>/dev/null && HAVE_HASHER=1
command -v htpasswd >/dev/null 2>&1 && HAVE_HASHER=1
if (( HAVE_HASHER )); then
  check "passwd: hash updated" "Passwort aktualisiert" \
    < <(NIMCTL_CHAT_PASSWORD=Sup3rSecret timeout 20 "$N" chat passwd admin@example.com)
  python3 - "$DB" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
h = con.execute("SELECT password FROM auth WHERE email='admin@example.com'").fetchone()[0]
sys.exit(0 if h.startswith("$2") and "placeholder" not in h else 1)
PY
  assert "passwd: bcrypt hash actually written to the db" [ $? -eq 0 ]
else
  check "passwd: clear error when no hasher is available" "bcrypt|htpasswd|apache2-utils" \
    < <(NIMCTL_CHAT_PASSWORD=Sup3rSecret timeout 20 "$N" chat passwd admin@example.com)
  echo "  (skipped: neither python3-bcrypt nor htpasswd present in this test environment)"
fi

check "reset: refuses non-interactively without --yes" "abgebrochen" \
  < <(NIMCTL_INTERACTIVE='' timeout 20 "$N" chat reset </dev/null)
python3 - "$DB" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
sys.exit(0 if con.execute("SELECT count(*) FROM user").fetchone()[0] == 2 else 1)
PY
assert "reset: rows remain after the refusal" [ $? -eq 0 ]

check "reset --yes: confirms and empties the tables" "Konten gelöscht" \
  < <(NIMCTL_INTERACTIVE='' timeout 20 "$N" chat reset --yes </dev/null)
python3 - "$DB" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
a = con.execute("SELECT count(*) FROM auth").fetchone()[0]
u = con.execute("SELECT count(*) FROM user").fetchone()[0]
sys.exit(0 if a == 0 and u == 0 else 1)
PY
assert "reset --yes: auth and user tables empty" [ $? -eq 0 ]

check "dashboard: accounts menu (key n)" "1\) Konten +2\) Passwort +3\) Zurücksetzen" \
  < <(printf 'n\n\nq\n' | timeout 30 "$N")
