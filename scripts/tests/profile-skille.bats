#!/usr/bin/env bats
# Profile ról nie widzą starych skilli spoza pluginu software-house. Skille zostają w ~/.claude/skills
# dla Paperclipa; sesje SH ukrywają je (skillOverrides "off") i blokują (deny Skill(NAZWA)).
# Lista: sh-system/docs/serwer.md, sekcja „Stare skille”.

STARE=(tworca-wymagan iskt-softwarehouse-tworca-wymagan iskt-planista-realizacji)

sprawdz() {
  local p="$BATS_TEST_DIRNAME/../../.claude/roles/$1/settings.json" s
  for s in "${STARE[@]}"; do
    jq -e --arg s "$s" '.skillOverrides[$s] == "off"' "$p" >/dev/null || { echo "$1: brak skillOverrides $s"; return 1; }
    jq -e --arg s "Skill($s)" '.permissions.deny | index($s)' "$p" >/dev/null || { echo "$1: brak deny Skill($s)"; return 1; }
  done
}

@test "profil workera ukrywa i blokuje stare skille" { sprawdz worker; }
@test "profil reviewera ukrywa i blokuje stare skille" { sprawdz reviewer; }
