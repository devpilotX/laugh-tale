# reset-seasons.sh - wipe all season history so the next season is number 1.
#
# WHY THIS IS A SCRIPT AND NOT A COMMAND I TYPED BY HAND: it deletes live rows. A script is reviewable
# in git, states its scope up front, refuses in the wrong conditions, and can be read afterwards to
# explain exactly what happened. An ad-hoc DELETE cannot do any of that.
#
# WHAT IT DELETES
#   seasons, combat_ratings, champions, combat_events, house_standing, shop_tier_state,
#   chronicle_chapters (and objectives, by cascade), and any titles awarded BY a season -
#   Champion titles and Chronicle chapter titles.
#
# WHAT IT DELIBERATELY DOES NOT TOUCH
#   players, balances, transactions, stats, homes, home_slots, friends, paths, house_members,
#   access_grants, punishments, staff_audit.
#
#   That split is the same one the season rollover uses: Berries, stats, homes and Path progress are
#   IDENTITY and survive a reset. Ratings, standings and the story are a COMPETITION and do not.
#   Path XP in particular is kept on purpose - it is lifetime progress, not a seasonal score.
#
# WHY CHAMPION TITLES GO HERE BUT NOT IN A NORMAL ROLLOVER: a rollover ends a season that really
# happened, so its Champion keeps the title forever (9.6). This wipes seasons that never happened -
# they were created while testing - so a title from one would be a permanent claim to have won a
# season that no longer exists.
#
# LAYERED REFUSALS, because the only irreversible mistake here is doing it to the wrong server.
set -euo pipefail

DEV_VOLUME=4fd2f0a9-6ad6-4a4d-96c8-e11e763bdd22

q() {
  sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'
}

echo "=== refusal 1: the dev volume must exist, so this cannot run against an unknown host ==="
if ! sudo -n test -d "/var/lib/pelican/volumes/$DEV_VOLUME"; then
  echo "REFUSED: the dev server volume was not found. This is not the machine this script is for."
  exit 2
fi
echo "  ok, dev volume present"

echo "=== refusal 2: no players may be online ==="
# A player online during a rating wipe would keep an in-memory view of a rank that no longer exists,
# and their next write would recreate a row against a deleted season.
ONLINE=$(sudo -n grep -c "joined the game" "/var/lib/pelican/volumes/$DEV_VOLUME/logs/latest.log" 2>/dev/null || true)
LEFT=$(sudo -n grep -c "left the game" "/var/lib/pelican/volumes/$DEV_VOLUME/logs/latest.log" 2>/dev/null || true)
if [ "${ONLINE:-0}" -gt "${LEFT:-0}" ]; then
  echo "REFUSED: someone appears to be online ($ONLINE joins, $LEFT leaves this boot)."
  echo "Stop the server first, or wait until it is empty."
  exit 3
fi
echo "  ok, nobody online ($ONLINE joins, $LEFT leaves this boot)"

echo "=== a backup is taken FIRST, so this is reversible ==="
if sudo -n test -x /usr/local/bin/lt-backup-run.sh; then
  sudo -n /usr/local/bin/lt-backup-run.sh --db-only || echo "  WARNING: backup script returned non-zero"
else
  STAMP=$(date -u +%Y%m%d-%H%M%S)
  OUT="/var/backups/laughtail/pre-season-reset-$STAMP.sql"
  sudo -n mkdir -p /var/backups/laughtail
  sudo -n docker exec -u root laughtail-db sh -c "mariadb-dump -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" --single-transaction laughtail" 2>/dev/null | sudo -n tee "$OUT" >/dev/null
  SIZE=$(sudo -n stat -c %s "$OUT")
  echo "  wrote $OUT ($SIZE bytes)"
  if [ "$SIZE" -lt 10000 ]; then
    echo "REFUSED: the backup is implausibly small, so it is not a backup. Nothing was deleted."
    exit 4
  fi
fi

echo
echo "=== before ==="
q "SELECT CONCAT('seasons=',(SELECT COUNT(*) FROM seasons),' ratings=',(SELECT COUNT(*) FROM combat_ratings),' champions=',(SELECT COUNT(*) FROM champions),' events=',(SELECT COUNT(*) FROM combat_events),' chapters=',(SELECT COUNT(*) FROM chronicle_chapters),' objectives=',(SELECT COUNT(*) FROM chronicle_objectives),' season_titles=',(SELECT COUNT(*) FROM titles_owned WHERE source IN ('champion','chronicle')));"
echo "  preserved: balances=$(q "SELECT COUNT(*) FROM balances;") stats=$(q "SELECT COUNT(*) FROM stats;") homes=$(q "SELECT COUNT(*) FROM homes;") paths=$(q "SELECT COUNT(*) FROM paths;") players=$(q "SELECT COUNT(*) FROM players;")"

echo
echo "=== deleting, children before parents so the foreign keys are never violated ==="
# Order matters: combat_ratings and champions both reference seasons, so seasons goes last.
q "DELETE FROM titles_owned WHERE source IN ('champion','chronicle');" >/dev/null
q "DELETE FROM chronicle_objectives;" >/dev/null
q "DELETE FROM chronicle_chapters;" >/dev/null
q "DELETE FROM house_standing;" >/dev/null
q "DELETE FROM shop_tier_state;" >/dev/null
q "DELETE FROM combat_events;" >/dev/null
q "DELETE FROM combat_ratings;" >/dev/null
q "DELETE FROM champions;" >/dev/null
q "DELETE FROM seasons;" >/dev/null
# An active_title pointing at a title that no longer exists would render as nothing; clear it.
q "UPDATE player_identity SET active_title = NULL WHERE active_title IS NOT NULL AND active_title NOT IN (SELECT title_key FROM titles_owned);" >/dev/null

echo "=== after ==="
q "SELECT CONCAT('seasons=',(SELECT COUNT(*) FROM seasons),' ratings=',(SELECT COUNT(*) FROM combat_ratings),' champions=',(SELECT COUNT(*) FROM champions),' events=',(SELECT COUNT(*) FROM combat_events),' chapters=',(SELECT COUNT(*) FROM chronicle_chapters),' objectives=',(SELECT COUNT(*) FROM chronicle_objectives),' season_titles=',(SELECT COUNT(*) FROM titles_owned WHERE source IN ('champion','chronicle')));"
echo "  preserved: balances=$(q "SELECT COUNT(*) FROM balances;") stats=$(q "SELECT COUNT(*) FROM stats;") homes=$(q "SELECT COUNT(*) FROM homes;") paths=$(q "SELECT COUNT(*) FROM paths;") players=$(q "SELECT COUNT(*) FROM players;")"

REMAIN=$(q "SELECT COUNT(*) FROM seasons;")
if [ "$REMAIN" != "0" ]; then
  echo "FAILED: $REMAIN season row(s) remain. Nothing will renumber from 1."
  exit 5
fi

NEXT=$(q "SELECT IFNULL(MAX(season_number),0)+1 FROM seasons;")
echo
echo "The next season will be number $NEXT."
if [ "$NEXT" != "1" ]; then
  echo "WARNING: expected 1. startSeason uses MAX(season_number)+1, so something still holds a row."
  exit 6
fi
echo "SEASON RESET COMPLETE. The scheduler opens season 1 within a minute of the next check,"
echo "or immediately on the next boot - it recovers from having no active season by design."
