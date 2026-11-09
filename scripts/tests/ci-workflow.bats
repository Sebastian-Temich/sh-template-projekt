#!/usr/bin/env bats
# Workflow GitHub Actions oszczędzają minuty (sh-system/docs/serwer.md, „CI i minuty GitHub Actions”).
# Pilnuje też zmian zadania szkieletu w ci.yml: timeout w każdym jobie, ciężkie joby za check-dod.

setup() {
  command -v yq >/dev/null || skip "brak yq"
  W="$BATS_TEST_DIRNAME/../../.github/workflows"
}

@test "kazdy job ma timeout-minutes" {
  for f in "$W"/*.yml; do
    run yq -r '.jobs | to_entries[] | select(.value["timeout-minutes"] == null) | .key' "$f"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "$(basename "$f"): bez timeout-minutes: $output"; false; }
  done
}

@test "ci.yml: concurrency anuluje tylko biegi PR" {
  [ "$(yq -r '.concurrency["cancel-in-progress"]' "$W/ci.yml")" = "\${{ github.event_name == 'pull_request' }}" ]
  yq -r '.concurrency.group' "$W/ci.yml" | grep -q 'github.event.pull_request.number'
}

@test "ci.yml: bez filtra paths na poziomie workflow (shctl potrzebuje checkow na kazdym PR)" {
  [ "$(yq -r '.on.pull_request.paths // "brak"' "$W/ci.yml")" = brak ]
  [ "$(yq -r '.on.push.paths // "brak"' "$W/ci.yml")" = brak ]
}

@test "ci.yml: check-dod i gitleaks bez zaleznosci, reszta za check-dod z warunkiem" {
  [ "$(yq -r '.jobs["check-dod"].needs // "brak"' "$W/ci.yml")" = brak ]
  [ "$(yq -r '.jobs.gitleaks.needs // "brak"' "$W/ci.yml")" = brak ]
  for j in $(yq -r '.jobs | keys | .[]' "$W/ci.yml"); do
    case "$j" in check-dod | gitleaks) continue ;; esac
    [ "$(yq -r ".jobs[\"$j\"].needs" "$W/ci.yml")" = check-dod ] || { echo "$j bez needs: check-dod"; false; }
    yq -r ".jobs[\"$j\"].if" "$W/ci.yml" | grep -q 'needs.check-dod.outputs.' || { echo "$j bez if"; false; }
  done
}

@test "ci.yml: nocny przebieg i reczne uruchomienie" {
  [ "$(yq -r '.on.schedule[0].cron' "$W/ci.yml")" != null ]
  [ "$(yq -r '.on | has("workflow_dispatch")' "$W/ci.yml")" = true ]
}

@test "staging.yml: tylko przy zmianie migracji" {
  yq -r '.on.push.paths[]' "$W/staging.yml" | grep -qx 'supabase/migrations/\*\*'
}

@test "ci.yml: gitleaks na kazdym PR i pushu (na pushu w jobie check-dod), ta sama wersja i suma" {
  yq -r '.jobs.gitleaks.if' "$W/ci.yml" | grep -q "pull_request"
  yq -r '.jobs["check-dod"].steps[] | select(.name == "Skan historii gitleaks (push)") | .if' "$W/ci.yml" | grep -q "push"
  [ "$(yq -r '.jobs.gitleaks.env.GITLEAKS_SHA256' "$W/ci.yml")" = \
    "$(yq -r '.jobs["check-dod"].steps[] | select(.name == "Instalacja gitleaks (push)") | .env.GITLEAKS_SHA256' "$W/ci.yml")" ]
}

@test "ci.yml: bez testow skryptow szablonu (falszywe alarmy na zywych docs/ projektu)" {
  [ "$(yq -r '.jobs | has("testy-skryptow")' "$W/ci.yml")" = false ]
  ! grep -q 'bats scripts/tests' "$W/ci.yml"
}

@test "szablon.yml: testy skryptow tylko w repo szablonu" {
  [ "$(yq -r '.jobs["testy-skryptow"].if' "$W/szablon.yml")" = 'github.event.repository.is_template' ]
  yq -r '.jobs["testy-skryptow"].steps[].run // ""' "$W/szablon.yml" | grep -q 'bats scripts/tests'
}

@test "ci.yml: e2e za zakresem e2e, z cache przegladarek i limitami krokow" {
  [ "$(yq -r '.jobs.e2e.if' "$W/ci.yml")" = "needs.check-dod.outputs.e2e == 'true'" ]
  yq -r '.jobs.e2e.steps[].uses // ""' "$W/ci.yml" | grep -q '^actions/cache@'
  yq -r '.jobs.e2e.steps[] | select(.uses // "" | test("^actions/cache@")) | .with.path' "$W/ci.yml" | grep -qx '~/.cache/ms-playwright'
  [ "$(yq -r '.jobs.e2e.steps[].run // ""' "$W/ci.yml" | grep -c 'timeout [0-9]*m')" -eq 2 ]
  yq -r '.jobs.e2e.steps[].run // ""' "$W/ci.yml" | grep -q '::error title='
}
