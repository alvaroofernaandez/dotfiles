# Tasks: invalidation propagation with per-field provenance (issue #7)

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | 600–800 (server ~200, client ~150, tests ~250, e2e ~50, docstrings not counted) |
| Delivery strategy | ask-on-risk |
| 400-line budget risk | Low |
| Chained PRs recommended | No |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception pending — single PR is the right shape; the four WUs are tightly coupled by a single data shape (`{value, _via, _at}`) and a single consumer (the `InvalidationBanner`). An intermediate "walker without a slice" or "slice without a consumer" PR has no review value.
400-line budget risk: Low

The blast radius is small (no new SSE event kinds, no new stores, no edits to `data/graph.yaml` or `data/requirements.yaml`, no renames of `via` to `_via`) and the change is one cohesive feature: a per-field wrap on disk + a pure forward walker + one slice + one minimum banner. The four WUs are stacked so a partial WU is still reviewable, but they ship in one PR because the consumer of the slice is the banner in the same change.

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| WU1 | Pure invalidation walker with the `MONEY_COMMITTED_FACTS` constant; eight unit tests; static guard against importing `trip.store.save_state` | PR 1 (part 1) | Base: `main`. Standalone: yes. No consumer yet — the API call is added in WU2. |
| WU2 | Wrap/unwrap in `store.py`, kw-only `assumptions` on `update_requirement`, `state.invalidation.affected[]` in `_state_payload` and `_update`, `assumptions` kw on MCP `update_requirement`; server tests for AC-1/2/5/6/8 | PR 1 (part 2) | Base: WU1. Standalone: yes. The wrap is invisible to the existing 313 pytests (it is unwrapped before any reader). |
| WU3 | `PanelState.invalidation`, `useLiveState.applyLocal` signature, `InvalidationBanner` in `OverviewView`; vitest unit tests | PR 1 (part 3) | Base: WU2. Standalone: yes. The banner reads the slice the server now sends. |
| WU4 | Production Playwright e2e for the banner; final verification gates (contrast, banned-Spanish, Host + `X-Trip-Panel`, static guard) | PR 1 (part 4) | Base: WU3. Standalone: yes. The e2e exercises the SSE channel end to end. |

## WU1 — Walker puro (capa fundación, sin API ni disco)

El motor es la única pieza que el resto necesita: una función pura `(graph, catalogue, states, requirement_id, before_values, after_values, active_hypotheses, now) -> list[InvalidationItem]`, simétrica a `propagate_for_assumption`, con la constante `MONEY_COMMITTED_FACTS` y la garantía estática de que este módulo no importa `store.save_state`. Ningún consumidor todavía: el API llega en WU2.

### 1.1 Esqueleto de `src/trip/invalidation.py` con la constante, el dataclass y las dos funciones devolviendo `[]`

- **RED:** crear `tests/test_invalidation.py` con un único test `test_module_exposes_money_committed_facts_with_the_four_ids` que importe `MONEY_COMMITTED_FACTS` desde `trip.invalidation` y aserte que contiene exactamente `{"flight.confirmed", "accommodation.booked", "insurance.policy", "trip.dates"}`. Ejecutar `uv run pytest tests/test_invalidation.py::test_module_exposes_money_committed_facts_with_the_four_ids`; el import falla con `ModuleNotFoundError`.
- **GREEN:** en `src/trip/invalidation.py` declarar `MONEY_COMMITTED_FACTS: frozenset[str] = frozenset({"flight.confirmed", "accommodation.booked", "insurance.policy", "trip.dates"})`, el dataclass `@dataclass(frozen=True) class InvalidationItem: requirement_id: str; field: str; classification: str; reason: str; since: str | None`, y las dos firmas `def propagate_for_requirement(graph, catalogue, states, requirement_id, before_values, after_values, active_hypotheses, now) -> list[InvalidationItem]: ...` y `def propagate_for_assumption(graph, catalogue, states, hypothesis_id, before, after, now) -> list[InvalidationItem]: ...` con cuerpo `return []`. Reejecutar; el test pasa.
- **Checkpoint:** `uv run pytest tests/test_invalidation.py -v`.

### 1.2 Walker básico: lista vacía cuando nada cuelga, lista un campo cuando `_via` intersecta con el conjunto cambiado

- **RED:** añadir a `tests/test_invalidation.py` dos tests: `test_propagate_returns_empty_for_a_field_under_no_assumption` (un requisito con un campo `airline: "ANA"` escalar, sin wrap; `propagate_for_requirement` con `active_hypotheses={"window"}` debe devolver `[]`) y `test_propagate_lists_a_field_when_its_via_changes` (un requisito `dates-decision` con `values.target_month = {"value": "2027-10", "_via": ["window"], "_at": "2026-07-30T12:00:00"}`; `propagate_for_requirement(..., requirement_id="dates-decision", before_values={}, after_values={"target_month": "2027-10"}, active_hypotheses={"window"}, now=...)` debe devolver un `InvalidationItem` con `requirement_id="dates-decision"`, `field="target_month"`, `classification in {"review", "conflict"}`, y NO debe incluir `airline`). Ejecutar `uv run pytest tests/test_invalidation.py -k "empty or lists_a_field"`; los dos casos fallan porque el walker devuelve `[]` siempre.
- **GREEN:** en `src/trip/invalidation.py` implementar `propagate_for_requirement` que itera `graph.nodes`, encuentra los nodos cuyo `requirement == requirement_id`, y para cada `field_name` de `after_values` que exista en el catálogo: lee `before_values` y `after_values`, busca el wrap en `states[requirement_id].values[field_name]` (con `_unwrap`), y si el wrap tiene `_via` que intersecta con `active_hypotheses`, emite un `InvalidationItem` con `reason` construido desde `graph.hypotheses[hid].label` (plantilla: `f"dependía de {label}, que ha cambiado"`). Reejecutar; los dos casos pasan.
- **Checkpoint:** `uv run pytest tests/test_invalidation.py -k "empty or lists_a_field"`.

### 1.3 Clasificador `review` / `conflict` y paseo de dos saltos

- **RED:** añadir a `tests/test_invalidation.py` tres tests: `test_propagate_classifies_paid_value_as_conflict` (campo `booked: true` con `_via: ["window"]` cuyo nodo padre es evidencia de `flight.confirmed`; el item debe llevar `classification: "conflict"`), `test_propagate_classifies_non_paid_value_as_review` (campo `target_month: "2027-10"` con `_via: ["window"]` cuyo nodo es evidencia de un hecho fuera de `MONEY_COMMITTED_FACTS`; el item debe llevar `classification: "review"`), y `test_propagate_walks_through_a_two_hop_chain` (una hipótesis A cubre un hecho del nodo X, X produce un hecho que requiere el nodo Y, el campo de Y tiene `_via: ["A"]`; al cambiar A, Y se lista). Ejecutar `uv run pytest tests/test_invalidation.py -k "paid or non_paid or two_hop"`; los tres casos fallan.
- **GREEN:** en `propagate_for_requirement`, después de decidir que un campo se lista, consultar el grafo: para cada `fact` en `node.evidence` (a través de `graph.facts[fact].evidence`) ver si el campo es `fields` o `flags` de ese hecho; si `fact ∈ MONEY_COMMITTED_FACTS`, `classification = "conflict"`, en otro caso `"review"`. Para el paseo de dos saltos, expandir `after_values` con un `propagate_for_assumption` recursivo: si un nodo produce un hecho requerido por otro nodo que tiene un campo con `_via` que coincide, ese campo también se lista. Reejecutar; los tres casos pasan.
- **Checkpoint:** `uv run pytest tests/test_invalidation.py -k "paid or non_paid or two_hop"`.

### 1.4 Pureza: no escribe en disco, ignora hipótesis no declaradas, `propagate_for_assumption` simétrico

- **RED:** añadir a `tests/test_invalidation.py` dos tests: `test_propagate_does_not_touch_state_yaml` (crear un `state.yaml` temporal con valores; llamar a `propagate_for_requirement` con cualquier `change`; medir `hashlib.sha256(path.read_bytes()).hexdigest()` antes y después; los hashes son idénticos; el conjunto de claves bajo `requirements.*.values.*` no cambia) y `test_propagate_ignores_undeclared_assumptions_in_state` (campo con `_via: ["window"]` pero `active_hypotheses` no incluye `"window"`; el campo NO se lista aunque `_via` exista en disco). Ejecutar `uv run pytest tests/test_invalidation.py -k "touches_state or undeclared"`; ambos fallan.
- **GREEN:** asegurar que `propagate_for_requirement` solo lee `states` (no muta), no llama a `save_state`, no llama a `os.replace`, y filtra por `field._via ∩ active_hypotheses` (no por el `_via` del disco, que puede ser histórico). Implementar `propagate_for_assumption` como un wrapper que llama a `propagate_for_requirement` con `active_hypotheses = {hypothesis_id}` y `before_values={}/after_values={}` filtrando después los items cuyo `field._via` no contiene la hipótesis. Reejecutar; los dos casos pasan.
- **Checkpoint:** `uv run pytest tests/test_invalidation.py`.

### 1.5 WU1 checkpoint integral + guard estático

- **Comando:** `uv run pytest tests/test_invalidation.py -v` seguido de `! rg -n 'from trip\.store import .*save_state' src/trip/invalidation.py`. El primer comando demuestra 8 tests verdes; el segundo demuestra que el módulo no importa `save_state` (cero matches; el `!` invierte el exit code para que un match devuelva error).
- **Lo que demuestra:** la constante `MONEY_COMMITTED_FACTS` está exportada y contiene los cuatro ids; el walker clasifica `review`/`conflict` correctamente; la pureza del módulo se verifica tanto por un test funcional (hash SHA-256 del fichero) como por la regla estática del grep; los 313 pytests vigentes NO se han tocado todavía — siguen verdes al correr `uv run pytest --collect-only -q` (313 tests collected).

## WU2 — Persistencia, API y MCP (server integration)

La proveniencia por campo entra en disco, se calcula en cada POST, viaja en la respuesta y se ofrece a través del MCP. La regla "el wrap vive solo en disco, `_unwrap` es la única puerta" se aplica aquí sin excepciones.

### 2.1 Wrap/unwrap + kw-only `assumptions` en `src/trip/store.py`

- **RED:** añadir a `tests/test_store.py` tres tests: `test_writing_under_an_assumption_records_via_in_state` (AC-1: `update_requirement({}, "dates-decision", values={"target_month": "2027-10"}, assumptions={"window"}, now=NOW)` deja `states["dates-decision"].values["target_month"]` con el wrap `{"value": "2027-10", "_via": ["window"], "_at": "2026-07-28T12:30:00"}` — pero la firma actual de `update_requirement` no acepta `assumptions`, así que el test falla con `TypeError`), `test_writing_without_an_assumption_does_not_record_via` (mismo POST sin `assumptions` deja el campo escalar `"2027-10"`), y `test_at_is_serialized_as_iso` (el `_at` es exactamente `now.replace(microsecond=0).isoformat()`). Ejecutar `uv run pytest tests/test_store.py -k "via or at_iso"`; los tres fallan.
- **GREEN:** en `src/trip/store.py` añadir dos helpers privados `_wrap_value(raw, via, at) -> dict | raw` (devuelve `raw` si `not via`, si no `{"value": raw, "_via": list(via), "_at": at}`) y `_unwrap(value) -> Any` (si `isinstance(value, dict) and set(value.keys()) >= {"value", "_via", "_at"}`, devuelve `value["value"]`; en otro caso devuelve `value` tal cual). Extender `update_requirement` con `*, assumptions: set[str] | None = None`; dentro del bucle `for name, value in values.items():` calcular `intersecting = (assumptions or set()) & hypotheses_for_field(requirement_id, name, graph)` (helper privado que mira `graph.nodes` para ese `requirement` y filtra las hipótesis activas cuyos hechos son `requires` de algún nodo del requisito) y reemplazar `merged[name] = value` por `merged[name] = _wrap_value(value, sorted(intersecting), now.isoformat() if value is not None else None)` cuando `value is not None and intersecting`, si no `merged[name] = value`. Cuando `assumptions` es `None` o `intersecting` es vacío, comportamiento bit a bit como hoy. Reejecutar; los tres casos pasan.
- **Checkpoint:** `uv run pytest tests/test_store.py -k "via or at_iso"`.

### 2.2 Carga retrocompatible, idempotencia, sin herencia de `_via`

- **RED:** añadir a `tests/test_store.py` cinco tests: `test_state_without_via_loads_as_confirmed` (AC-2: un `state.yaml` con `requirements.passport-validity.values.alvaro_expires: "2029-01-01"` escalar carga como `RequirementState(values={"alvaro_expires": "2029-01-01"})` y `catalogue.progress(passport) == 0.25`), `test_hand_edited_state_yaml_treated_as_confirmed` (REQ-9: el mismo state.yaml, leído N veces, sigue mostrando el escalar), `test_fields_not_written_do_not_inherit_via_from_previous_save` (escribir `target_month` con `assumptions={"window"}` y luego escribir `airline` sin `assumptions`; el `state.yaml` final tiene `target_month` con wrap y `airline` escalar), `test_wrap_round_trips_idempotently` (REQ-10: un `save_state` + `load_state` de un campo con wrap produce el mismo shape, no un wrap doble), y `test_empty_via_collapses_to_scalar_on_rewrite` (REQ-10: un campo con `{value: "x", _via: [], _at: "..."}` colapsa a `"x"` escalar al reescribirse). Ejecutar `uv run pytest tests/test_store.py -k "without_via or hand_edited or inherits or round_trip or empty_via"`; los cinco fallan.
- **GREEN:** en `src/trip/store.py` introducir un helper privado `_load_value(raw) -> Any` que valide el wrap en `load_state`: si `raw` es un dict con exactamente las tres claves `value`, `_via`, `_at` y `_via` es una lista de strings, pasa tal cual; en otro caso loggea y devuelve `raw` (defensa contra YAML corrupto). Modificar `load_state` para que `values = dict(entry.get("values") or {})` se mantenga como dict (los lectores harán `_unwrap` por su cuenta). Añadir al bucle de `update_requirement` la rama `_unwrap` antes de `merged[name] = value` cuando el valor previo en `merged` es un wrap con `_via: []` (lo aplana al escalar antes de reescribir). Reejecutar; los cinco casos pasan.
- **Checkpoint:** `uv run pytest tests/test_store.py -k "without_via or hand_edited or inherits or round_trip or empty_via"`.

### 2.3 Slice `state.invalidation.affected[]` en `_state_payload` y `_update` de `src/trip/api.py`

- **RED:** añadir a `tests/test_api.py` dos tests: `test_state_payload_always_includes_invalidation_slice` (un `GET /api/state` siempre lleva `body["invalidation"]["affected"]` como lista, posiblemente vacía, junto a las claves existentes) y `test_update_response_carries_invalidation_slice_with_affected_for_changed_fields` (un `POST /api/requirement/dates-decision` con `assumptions=["window"]` devuelve 200 con `body["invalidation"]["affected"]` conteniendo al menos un `InvalidationItem` para `target_month`). Ejecutar `uv run pytest tests/test_api.py -k "invalidation"`; ambos fallan con `KeyError: "invalidation"`.
- **GREEN:** en `src/trip/api.py` importar `propagate_for_requirement` desde `trip.invalidation`. Añadir un helper privado `_invalidation_for_state(graph, catalogue, states, now) -> list[dict[str, Any]]` que itera los requisitos de `catalogue` y para cada uno llama a `propagate_for_requirement` con `before_values=states[rid].values`, `after_values=states[rid].values` y `active_hypotheses={hid for hid in graph.hypotheses if any(a.id == hid and a.active for a in load_assumptions(...))}`; aplana cada `InvalidationItem` a `{"requirement_id", "field", "classification", "reason", "since"}` con `since` ISO o `None`. En `_state_payload`, añadir `"invalidation": {"affected": _invalidation_for_state(graph, catalogue, states, today)}` al dict de retorno. En `_update`, capturar `before_values = states[requirement_id].values` antes de la escritura y `after_values = states[requirement_id].values` después; pasar ambos a `propagate_for_requirement(..., requirement_id=requirement_id, before_values=before_values, after_values=after_values, active_hypotheses=..., now=today)`; añadir el slice `"invalidation": {"affected": [item.__dict__ for item in items]}` al body de la respuesta 200. Reejecutar; los dos casos pasan.
- **Checkpoint:** `uv run pytest tests/test_api.py -k "invalidation or legacy"`.

### 2.4 Kw `assumptions` en `mcp_server.update_requirement` y propagación al POST interno

- **RED:** crear `tests/test_mcp_server.py` con dos tests: `test_update_requirement_with_assumptions_records_provenance` (crear un `data_dir` con la fixture, llamar directamente al handler subyacente — o, si la capa MCP solo expone strings, parsear el `_call` indirectamente — con `assumptions=["window"]`; el `state.yaml` resultante contiene `target_month: {value: ..., _via: [window], _at: ...}`) y `test_update_requirement_without_assumptions_does_not_record_provenance` (mismo POST sin `assumptions`; el `state.yaml` no contiene `_via` para el campo escrito). Ejecutar `uv run pytest tests/test_mcp_server.py`; ambos fallan porque la herramienta MCP no acepta `assumptions`.
- **GREEN:** en `src/trip/mcp_server.py` extender la firma de `@mcp.tool() def update_requirement(...)` con `assumptions: list[str] = []` y añadir al `payload` la línea `if assumptions: payload["assumptions"] = assumptions`. Actualizar el docstring (neutral Spanish) indicando que pasar `assumptions` registra provenancia y que omitirlo deja el campo confirmado. Reejecutar; los dos casos pasan.
- **Checkpoint:** `uv run pytest tests/test_mcp_server.py`.

### 2.5 WU2 checkpoint integral (servidor)

- **Comando:** `uv run pytest`.
- **Lo que demuestra:** los 313 tests previos + los nuevos (3 de 2.1 + 5 de 2.2 + 2 de 2.3 + 2 de 2.4 + 8 de WU1) están verdes. Los regresiones críticas se mantienen: `test_saving_never_leaves_a_partial_file` (atomicidad de `os.replace`); `test_state_adds_graph_aware_planning_without_removing_legacy_keys` (superset de claves en `body`); `test_empty_trip_has_24_actionable_requirements_in_graph_order` (`planning.actionable.count == 24` con la fixture vacía); `test_state_adds_planning_slice` (suite `test_planning` con la nueva clave `blocked`); `test_requirement_write_returns_fresh_planning` (POST refresca `planning.root.status`). El `Catalogue.progress` no cambia para los mismos valores, porque `_unwrap` es la única puerta y el wrap no entra nunca en `is_filled`.

## WU3 — Tipos, SSE patch y banner (cliente)

El cliente acepta el nuevo slice, lo parchea desde el SSE y monta el banner mínimo en Resumen. Ningún test e2e todavía: eso es WU4.

### 3.1 Extender `PanelState` con `invalidation: PanelInvalidation` y los tipos asociados

- **RED:** ejecutar `pnpm --dir apps/web check` para confirmar que el proyecto compila hoy con `PanelState` sin `invalidation`. El RED no es un test fallido sino una baseline: si la compilación falla por otro motivo, paramos. La transición a RED se demuestra al final de 3.2, cuando el banner y `applyLocal` se referencian.
- **GREEN:** en `apps/web/src/lib/types.ts` añadir `export const INVALIDATION_CLASSIFICATIONS = { REVIEW: 'review', CONFLICT: 'conflict' } as const;`, `export type InvalidationClassification = (typeof INVALIDATION_CLASSIFICATIONS)[keyof typeof INVALIDATION_CLASSIFICATIONS];`, `export interface InvalidationItem { requirement_id: string; field: string; reason: string; classification: InvalidationClassification; since: string | null; }`, `export interface PanelInvalidation { affected: InvalidationItem[]; }`, y añadir `invalidation: PanelInvalidation` como clave obligatoria de `PanelState`. Reejecutar `pnpm --dir apps/web check`; cero errores (la nueva clave es aditiva: nada en el código actual la lee aún).
- **Checkpoint:** `pnpm --dir apps/web check`.

### 3.2 Extender `useLiveState.applyLocal` con `invalidation` y propagar desde el SSE

- **RED:** crear `apps/web/src/lib/useLiveState.test.ts` con un solo test `test_apply_local_patches_invalidation_slice_from_sse_payload` que use `renderHook` de `@testing-library/react`, monte `useLiveState` con `EventSource` mockeado (vi.stubGlobal), simule un `EventSource` cuyo primer mensaje `requirement.updated` lleve `payload.invalidation = { affected: [{ requirement_id: 'dates-decision', field: 'target_month', reason: '...', classification: 'review', since: null }] }`, espere al siguiente tick, y verifique que `result.current.state.invalidation.affected` contiene el item. Ejecutar `pnpm --dir apps/web test src/lib/useLiveState.test.ts`; el test falla porque `applyLocal` actual solo acepta tres parámetros.
- **GREEN:** en `apps/web/src/lib/useLiveState.ts` extender la firma de `applyLocal` con un cuarto parámetro `invalidation: PanelInvalidation` y patchear `state.invalidation = invalidation` dentro del `setState`. En el handler `events.addEventListener('requirement.updated', ...)`, pasar `payload.invalidation` como cuarto argumento a `applyLocal`. Reejecutar; el caso pasa.
- **Checkpoint:** `pnpm --dir apps/web test src/lib/useLiveState.test.ts`.

### 3.3 Crear `InvalidationBanner` y montarlo en `OverviewView` entre `Supuestos activos` y `DeadlineList`

- **RED:** añadir a `apps/web/src/components/views/OverviewView.test.ts` tres tests: `test_invalidation_banner_is_absent_when_affected_is_empty` (con `state.invalidation.affected = []`, el `[data-testid="invalidation-banner"]` NO está en el DOM), `test_invalidation_banner_shows_count_and_link_when_affected_is_non_empty` (con un `affected` de un solo item, el banner está en el DOM, su texto contiene `"1 elemento caducado por tu último cambio de hipótesis"`, y el botón con texto `"Ver en Requisitos"` invoca `onNavigate('requisitos')`), y `test_invalidation_banner_uses_plural_for_more_than_one` (con tres items, el texto es `"3 elementos caducados por tu último cambio de hipótesis"` — la `s` final no se pierde). Ejecutar `pnpm --dir apps/web test src/components/views/OverviewView.test.tsx`; los tres fallan.
- **GREEN:** en `apps/web/src/components/views/OverviewView.tsx` añadir un subcomponente `InvalidationBanner` que recibe `{affected: InvalidationItem[]; onNavigate: (view: ViewId) => void}`; si `affected.length === 0` devuelve `null`; en otro caso renderiza un `<div role="status" data-testid="invalidation-banner" className="mb-3">` con un `<Card icon={AlertTriangle} tone="warn" title="Hipótesis cambiadas" description="Estos elementos colgaban de un supuesto que ya no encaja" bodyClassName="p-0">` que contiene un `<ul>` con un `<li>` mostrando `{affected.length} {affected.length === 1 ? 'elemento caducado' : 'elementos caducados'} por tu último cambio de hipótesis` seguido de un `Button variant="ghost" size="sm"` con texto `"Ver en Requisitos"` y un `<ArrowRight />` que invoca `onNavigate('requisitos')`. Montar el banner en `OverviewView` **entre** el bloque `{state.planning.assumptions.length > 0 && (...)}` y `<DeadlineList ... />` con la condición `state.invalidation.affected.length > 0`. Reejecutar; los tres casos pasan.
- **Checkpoint:** `pnpm --dir apps/web test src/components/views/OverviewView.test.tsx`.

### 3.4 WU3 checkpoint integral (cliente)

- **Comando:** `pnpm --dir apps/web test && pnpm --dir apps/web check && pnpm --dir apps/web build`.
- **Lo que demuestra:** los 30+ vitest previos (incluido `OverviewView.test.tsx` con los 3 casos nuevos) verdes; `astro check` cero errores; build de producción sin warnings. El `PanelState` ampliado es compatible hacia atrás: cualquier consumidor que todavía lea `state.planning` o `state.requirements` lo hace igual; el nuevo `invalidation.affected` es aditivo. El banner se monta exactamente una vez, solo cuando `affected.length > 0`, en la posición documentada (entre `Supuestos activos` y `DeadlineList`). Las 7 pruebas previas de `OverviewView.test.tsx` (frente de trabajo, encargo raíz, supuestos con plazos provisionales, etc.) siguen verdes sin tocarse: el banner es aditivo y no desplaza otras regiones.

## WU4 — E2E y verificación final

El e2e es la prueba de que el banner aparece cuando toca, se oculta cuando no, y la suite completa sigue verde. La verificación final cierra el change.

### 4.1 Caso e2e: el banner aparece tras un POST bajo hipótesis + cambio de hipótesis, en ambos temas

- **RED:** añadir a `apps/web/e2e/overview.spec.ts` un nuevo test `la propagación de invalidación muestra el banner y enlaza a Requisitos` parametrizado sobre `THEMES` (igual que el primer test). El test: (a) `page.goto('/#resumen')` con el tema aplicado, (b) `page.evaluate` para hacer un POST `'/api/requirement/dates-decision'` con `{ values: { alvaro_leave: true, miguel_leave: true } }` y `assumptions: ['window']` (necesita que el fixture tenga el supuesto `window` activo; `serve-fixture.mjs` ya lo deja así para el fixture `empty` en `state.yaml` y para `malformed` con un `state.yaml` activo), (c) esperar al SSE `requirement.updated` con `page.waitForResponse('/api/events')` o un `waitForFunction` que mire `window.__lastEvent`, (d) `expect(page.getByTestId('invalidation-banner')).toBeVisible()` con texto conteniendo `'elemento'`, (e) `await page.getByRole('button', { name: 'Ver en Requisitos' }).click()` y `expect(page).toHaveURL(/#requisitos$/)`, (f) `expectNoAxeViolations(page)`. Ejecutar `pnpm --dir apps/web test:e2e`; el test falla porque el banner no existe todavía en el cliente.
- **GREEN:** el test ya está escrito. La implementación llegó en 3.3; el resto es verificar que la integración funciona con el fixture `empty` real (que ya tiene `assumptions: window` cargado). Si el fixture no tiene `window` activo, ajustar `serve-fixture.mjs` para inyectarlo en el setup de `empty` (un `state.yaml` con `assumptions: [{ id: window, active: true, value: { departure_date: '2027-10-15', label: 'segunda quincena de octubre' } }]` antes de levantar el servidor). Reejecutar; el caso pasa en ambos temas.
- **Checkpoint:** `pnpm --dir apps/web test:e2e`.

### 4.2 WU4 checkpoint integral (e2e + build)

- **Comando:** `pnpm --dir apps/web test:e2e` (corre contra el build de producción lanzado por `serve-fixture.mjs`). Re-ejecutar también `pnpm --dir apps/web test && pnpm --dir apps/web check && pnpm --dir apps/web build` para confirmar que la cadena sigue verde después de la última pasada.
- **Lo que demuestra:** los 30 e2e previos (12 a11y × 2 temas + 4 mapa + 2 responsive + 5 shell + 7 overview) más el nuevo caso de 4.1 están verdes. El banner se muestra en `Resumen` cuando el POST bajo hipótesis registra provenancia, y el deep-link a `/requisitos` funciona. `axe-core` reporta cero violaciones en el nuevo `Card` (mismo `tone="warn"` que ya estaba en la tabla de pares del script `check-contrast.py`).

### 4.3 Verificación final del change

- **Comandos (en este orden):**
  1. `uv run pytest` — los 313 previos + 18 nuevos (8 invalidación + 3 wrap+at_iso + 5 retrocompat+idempotente + 2 API slice) verdes. Críticos: `test_saving_never_leaves_a_partial_file`, `test_state_adds_graph_aware_planning_without_removing_legacy_keys`, `test_empty_trip_has_24_actionable_requirements_in_graph_order`, `test_requirement_write_returns_fresh_planning`, `test_state_planning_blocked_slice_present_and_consistent`.
  2. `pnpm --dir apps/web test` — los 30+ vitest previos + los 4 nuevos (1 `useLiveState` + 3 `OverviewView` banner) verdes.
  3. `pnpm --dir apps/web check` — `astro check` cero errores.
  4. `pnpm --dir apps/web build` — build de producción sin warnings.
  5. `pnpm --dir apps/web test:e2e` — los 30 e2e previos + el nuevo de 4.1 verdes; axe en ambos temas con cero violaciones.
  6. `uv run python scripts/check-contrast.py` — la tabla de pares no cambia (no se introduce token nuevo; el banner reusa `Card` `tone="warn"`).
  7. **Guard estático nuevo:** `! rg -n 'from trip\.store import .*save_state' src/trip/invalidation.py` debe devolver cero matches (exit code 1 invertido a 0 con `!`). Este guard es CI: cualquier futuro commit que importe `save_state` en el walker lo rompe.
  8. **Banned-Spanish scan** en `apps/web/src` (no test):
     `rg -n -i '\b(tenés|querés|podés|sabés|sos|hacé|mirá|fijate|acordate|dale|andá|vení|decí|pensá|configurá|seleccioná|guardá|escribí|probá|invitá|enviá|verificá|elegí|presioná|tocá|tomá|borrá|cerrá|abrí|salí|cargá|recargá)\b' apps/web/src` debe devolver cero matches. La copia del banner (`"elemento caducado"`, `"por tu último cambio de hipótesis"`, `"Ver en Requisitos"`) es español neutro.
  9. **Smoke Host + `X-Trip-Panel`:** `curl -H 'X-Trip-Panel: 1' -H 'Content-Type: application/json' -d '{"values":{"target_month":"2027-10"},"assumptions":["window"]}' http://127.0.0.1:8027/api/requirement/dates-decision` debe devolver 200; sin `X-Trip-Panel` debe ser 403. Las protecciones no se tocan.
  10. **Hash check de `data/`:** el `git status` después de la implementación no muestra cambios en `data/graph.yaml`, `data/requirements.yaml`, `data/state.yaml`, ni en ningún otro fichero bajo `data/`. El `git diff -- data/` debe estar vacío.

## Coverage map (especificación → WU + tarea)

| Escenario spec | WU | Tarea |
|---|---|---|
| AC-1 Escritura bajo hipótesis registra `_via` y `_at` (REQ-1) | WU2 | 2.1 (`test_writing_under_an_assumption_records_via_in_state`) |
| AC-1bis Escritura sin hipótesis NO registra `_via` (REQ-1) | WU2 | 2.1 (`test_writing_without_an_assumption_does_not_record_via`) |
| AC-1bis `_at` se serializa como ISO (REQ-1) | WU2 | 2.1 (`test_at_is_serialized_as_iso`) |
| AC-2 `state.yaml` sin `_via` carga como confirmado (REQ-2) | WU2 | 2.2 (`test_state_without_via_loads_as_confirmed`) |
| AC-2 Hand-edited values treated as confirmed (REQ-2) | WU2 | 2.2 (`test_hand_edited_state_yaml_treated_as_confirmed`) |
| AC-2 Completitud derivada igual con/sin wrap (regresión) | WU2 | 2.2 (covered por el mismo test: `catalogue.progress` se mide tras `load_state` con wrap ausente) |
| AC-3 Walker devuelve afectados con clasificación (REQ-3) | WU1 | 1.2 (`test_propagate_lists_a_field_when_its_via_changes`) |
| AC-3 Walker vacío cuando nada cuelga (REQ-3) | WU1 | 1.2 (`test_propagate_returns_empty_for_a_field_under_no_assumption`) |
| AC-3 Paseo de dos saltos (REQ-3) | WU1 | 1.3 (`test_propagate_walks_through_a_two_hop_chain`) |
| AC-4 Bytes de `state.yaml` idénticos (REQ-5) | WU1 | 1.4 (`test_propagate_does_not_touch_state_yaml` con hash SHA-256) |
| AC-4 `invalidation.py` no importa `trip.store.save_state` (estático) | WU1 | 1.5 (guard `rg -n 'from trip\.store import .*save_state' src/trip/invalidation.py`) |
| AC-5 Valor pagado → `conflict` (REQ-4) | WU1 | 1.3 (`test_propagate_classifies_paid_value_as_conflict`) |
| AC-5 Valor no pagado → `review` (REQ-4) | WU1 | 1.3 (`test_propagate_classifies_non_paid_value_as_review`) |
| AC-5 Constante contiene los cuatro ids (REQ-4) | WU1 | 1.1 (`test_module_exposes_money_committed_facts_with_the_four_ids`) |
| REQ-6 GET siempre lleva `invalidation.affected` (REQ-6) | WU2 | 2.3 (`test_state_payload_always_includes_invalidation_slice`) |
| REQ-6 POST recalcula el slice (REQ-6) | WU2 | 2.3 (`test_update_response_carries_invalidation_slice_with_affected_for_changed_fields`) |
| REQ-6 SSE `requirement.updated` lleva el slice (REQ-6) | WU3 + WU4 | 3.2 (unit) + 4.1 (e2e end-to-end con SSE) |
| REQ-7 Banner aparece cuando `affected > 0` (REQ-7) | WU3 | 3.3 (`test_invalidation_banner_shows_count_and_link_when_affected_is_non_empty`) |
| REQ-7 Banner ausente cuando `affected === 0` (REQ-7) | WU3 | 3.3 (`test_invalidation_banner_is_absent_when_affected_is_empty`) |
| REQ-7 Singular/plural del conteo (REQ-7) | WU3 | 3.3 (`test_invalidation_banner_uses_plural_for_more_than_one`) |
| REQ-8 MCP `assumptions` registra provenancia (REQ-8) | WU2 | 2.4 (`test_update_requirement_with_assumptions_records_provenance`) |
| REQ-8 MCP sin `assumptions` no registra (REQ-8) | WU2 | 2.4 (`test_update_requirement_without_assumptions_does_not_record_provenance`) |
| REQ-9 Hand-edit se queda escalar (REQ-9) | WU2 | 2.2 (`test_hand_edited_state_yaml_treated_as_confirmed`) |
| REQ-9 Propagación no lista hand-edits aunque cambie la hipótesis (REQ-9) | WU1 | 1.4 (`test_propagate_ignores_undeclared_assumptions_in_state`) |
| REQ-10 Round-trip idempotente (REQ-10) | WU2 | 2.2 (`test_wrap_round_trips_idempotently`) |
| REQ-10 Empty `_via` colapsa a escalar (REQ-10) | WU2 | 2.2 (`test_empty_via_collapses_to_scalar_on_rewrite`) |
| Regresión: 313 pytests vigentes verdes | WU2 | 2.5 |
| Regresión: 30+ vitest vigentes verdes | WU3 | 3.4 |
| Regresión: 30 e2e vigentes verdes | WU4 | 4.2 |
| Regresión: `scripts/check-contrast.py` pasa | WU4 | 4.3 (no hay token nuevo) |
| Regresión: `save_state` mantiene `os.replace` | WU2 | 2.5 (`test_saving_never_leaves_a_partial_file`) |
| Regresión: `Catalogue.progress` no cambia | WU2 | 2.5 (mismo `passport-validity` con y sin wrap) |
| Regresión: `planning.actionable.count == 24` con fixture vacía | WU2 | 2.5 (`test_empty_trip_has_24_actionable_requirements_in_graph_order`) |
| Regresión: `planning.blocked.count == 19` con fixture vacía | WU2 | 2.5 (`test_state_planning_blocked_slice_present_and_consistent`) |
| Regresión: `OverviewView.test.tsx` (6 casos previos) verdes | WU3 | 3.3 (banner es aditivo) |
| Regresión: `command-menu.tsx` no se toca | WU3 | 3.4 (no se modifica) |
| Regresión: `MapView` y `PricesView` no cambian | WU3 | 3.4 (sin `BlockedBanner` adicional — el issue #7 no introduce banner de bloqueo) |

## Regression map (qué debe seguir verde en cada frontera)

### Después de WU1 (módulo puro)
- `uv run pytest` — los 313 tests previos verdes; los 8 nuevos de `test_invalidation.py` verdes. El cliente no se ha tocado. El comando `uv run pytest --collect-only -q` debe reportar 321 tests.
- El guard estático `! rg -n 'from trip\.store import .*save_state' src/trip/invalidation.py` debe devolver cero matches.
- `pnpm --dir apps/web check` y `pnpm --dir apps/web test` siguen verdes (cliente intacto).

### Después de WU2 (servidor integrado)
- `uv run pytest` — 313 + 18 nuevos = 331 tests verdes. Críticos: `test_saving_never_leaves_a_partial_file`, `test_state_adds_graph_aware_planning_without_removing_legacy_keys`, `test_empty_trip_has_24_actionable_requirements_in_graph_order`, `test_requirement_write_returns_fresh_planning`, `test_state_planning_blocked_slice_present_and_consistent`, `test_post_write_refreshes_planning_blocked_count`, `test_split_advance_tickets_is_unlocked_in_state_payload`. El `Catalogue.progress` no cambia porque `_unwrap` se aplica en la única puerta de `is_filled` (que `update_requirement` no usa — `update_requirement` opera sobre el dict `merged`; `is_filled` lo lee más tarde, en `Catalogue.progress`, y ya recibe el escalar).
- `pnpm --dir apps/web check` sigue verde (el cliente todavía no consume el slice). `pnpm --dir apps/web test` también: el `OverviewView.test.tsx` no se ha tocado.
- E2E no se ejecuta todavía (no hay cliente cambiado), pero los 30 e2e reales deben seguir verdes en cuanto se relance el panel: el slice nuevo es aditivo en `body`, los consumidores existentes lo ignoran.

### Después de WU3 (cliente integrado)
- `pnpm --dir apps/web test && pnpm --dir apps/web check && pnpm --dir apps/web build` — todo verde. Los 6 tests previos de `OverviewView.test.tsx` (frente de trabajo, encargo raíz, supuestos con plazos, etc.) siguen verdes porque el `InvalidationBanner` se monta en una posición nueva (entre `Supuestos activos` y `DeadlineList`) y no desplaza las otras regiones.
- `uv run pytest` — sigue en 331 verdes; el cliente no toca el servidor.
- E2E: los 30 e2e reales deben seguir verdes. El nuevo `PanelState.invalidation` es obligatorio, así que `serve-fixture.mjs` debe asegurarse de que el fixture `empty` devuelve `invalidation: { affected: [] }`; esto ya pasa implícitamente porque `_state_payload` siempre añade el slice.

### Después de WU4 (e2e + final)
- `pnpm --dir apps/web test:e2e` — los 30 e2e previos + el nuevo (1 caso × 2 temas = 2 ejecuciones) verdes. `axe-core` cero violaciones en el banner.
- `uv run pytest` — 331 verdes.
- `pnpm --dir apps/web test && pnpm --dir apps/web check && pnpm --dir apps/web build` — todo verde.
- `uv run python scripts/check-contrast.py` — pasa (sin tokens nuevos).
- `! rg -n 'from trip\.store import .*save_state' src/trip/invalidation.py` — cero matches.
- Banned-Spanish scan sobre `apps/web/src` (no test) — cero matches.
- `git diff -- data/` — vacío.

## Final verification checklist (apply debe ejecutar todo, en este orden)

1. `uv run pytest` — los 331 tests verdes.
2. `pnpm --dir apps/web test` — los 30+ vitest verdes (incluidos los 4 nuevos).
3. `pnpm --dir apps/web check` — `astro check` cero errores.
4. `pnpm --dir apps/web build` — build de producción sin warnings.
5. `pnpm --dir apps/web test:e2e` — los 30 e2e previos + el nuevo verde; axe en ambos temas con cero violaciones.
6. `uv run python scripts/check-contrast.py` — pasa con la paleta actual; no se introduce token nuevo (el banner reusa `Card` `tone="warn"`).
7. **Guard estático nuevo:** `! rg -n 'from trip\.store import .*save_state' src/trip/invalidation.py` — cero matches. El `!` invierte el exit code: cualquier match futuro rompe el guard.
8. **Banned-Spanish scan** en `apps/web/src` (no test):
   `rg -n -i '\b(tenés|querés|podés|sabés|sos|hacé|mirá|fijate|acordate|dale|andá|vení|decí|pensá|configurá|seleccioná|guardá|escribí|probá|invitá|enviá|verificá|elegí|presioná|tocá|tomá|borrá|cerrá|abrí|salí|cargá|recargá)\b' apps/web/src` — cero matches.
9. **Smoke Host + `X-Trip-Panel`:** un `curl -H 'X-Trip-Panel: 1' -H 'Content-Type: application/json' -d '{"values":{"target_month":"2027-10"},"assumptions":["window"]}' http://127.0.0.1:8027/api/requirement/dates-decision` con `Host: 127.0.0.1` debe ser 200; sin `X-Trip-Panel` debe ser 403. Las dos protecciones no se tocan.
10. **Hash check de `data/`:** `git diff -- data/` debe estar vacío. No se modifica `data/graph.yaml`, `data/requirements.yaml`, `data/state.yaml`, ni ningún otro fichero bajo `data/`.

## Constraints (lo que NO se hace)

- **Sin voseo / Rioplatense** en strings del UI, `docs/`, ni YAML. El script del paso 8 del checklist es el guard. La copia del banner (`"elemento caducado"`, `"por tu último cambio de hipótesis"`, `"Ver en Requisitos"`) y la docstring de la herramienta MCP (en `mcp_server.py`) son español neutro.
- **Sin atribución de IA ni trailers `Co-Authored-By`** en commits. Conventional commits. La memoria del trabajo se guarda en Engram, no en el log de git.
- **Sin nuevos tipos de evento SSE.** WU3 no añade nada a `BUS.publish`; el slice `invalidation` viaja en el payload existente `requirement.updated`. `useLiveState.ts` no recibe un nuevo `addEventListener` — solo extiende la firma de `applyLocal` con un cuarto parámetro.
- **Sin nuevos stores.** No se introduce ningún módulo nuevo de almacenamiento; `invalidation.py` es puro y no importa `store.save_state` (verificado por el guard del paso 7).
- **Sin edición de `data/graph.yaml` ni `data/requirements.yaml`.** Solo se modifican `src/trip/*.py`, `apps/web/src/**/*.{ts,tsx}`, `tests/*.py`, `apps/web/e2e/*.ts`.
- **Sin borrado automático de ninguna clave de `state.yaml`.** El motor no escribe; la marca vive en el slice de respuesta. Cuando el usuario reescribe un campo bajo otra hipótesis, su `_via` cambia; cuando lo borra (`null`), la clave desaparece por la rama existente de `update_requirement` (no por el nuevo código).
- **Sin segundo banner del mismo tipo.** Solo se monta **un** `InvalidationBanner` en `OverviewView`, solo cuando `affected.length > 0`, y se posiciona entre la lista de supuestos activos y `DeadlineList`. No se duplica en Requisitos, Mapa, ni Precios. El chip por fila y la lista detallada en línea son SCOPE-OUT explícito.
- **`MONEY_COMMITTED_FACTS` hardcoded en `invalidation.py`** con exactamente `{"flight.confirmed", "accommodation.booked", "insurance.policy", "trip.dates"}`. No se añade `commits_money: bool` a `Fact` ni a `data/graph.yaml`. Si en el futuro se añade un hecho de dinero, hay que actualizar la constante y un test (`test_module_exposes_money_committed_facts_with_the_four_ids`) rompe hasta entonces.
- **Sin renombrar `via` (`NodeStatus`) a `_via` (per-field).** Conviven con semánticas distintas: `via` cubre huecos del nodo en el momento de resolución; `_via` registra bajo qué hipótesis se escribió el campo. El banner nunca referencia `via`; la API mantiene los dos nombres; los docstrings de `unlock.resolve` y `_wrap_value` documentan la distinción.
- **Sin `display: none` ni atributo `hidden` en filas afectadas.** El motor solo expone datos; el panel no oculta nada. Las filas siguen visibles (el banner es la única superficie nueva).
- **Sin nuevos paquetes.** Las dependencias son las mismas.
- **Sin reescritura de `unlock.resolve()` ni de `Catalogue.progress`.** El comparador sigue siendo el mismo; la regla de completitud por campos rellenados se mantiene byte a byte.

## Implementation order y dependencias

Strict TDD: cada tarea `n.x` corre PRIMERO el test que falla (RED), DESPUÉS el cambio mínimo que lo hace pasar (GREEN). El apply agent debe demostrar el RED antes del GREEN en cada par.

El orden recomendado, alineado con la dependencia de capas:

1. **WU1 entero** (1.1 → 1.2 → 1.3 → 1.4 → 1.5) — sin esto, WU2 no puede invocar el walker y WU3 no tiene contenido que mostrar.
2. **WU2 entero** (2.1 → 2.2 → 2.3 → 2.4 → 2.5) — sin esto, el cliente no recibe el slice y WU3 lee un payload sin `invalidation`.
3. **WU3 entero** (3.1 → 3.2 → 3.3 → 3.4) — el cliente no puede renderizar lo que el servidor no envía.
4. **WU4 entero** (4.1 → 4.2 → 4.3) — el e2e no tiene banner que probar hasta que WU3 está listo.

## Notes para el apply agent

- **No tocar `data/` en ningún momento.** El hash check del paso 10 del checklist es el guard. Si un test parece necesitar editar `data/graph.yaml` o `data/requirements.yaml`, hay un bug en el test, no una necesidad real.
- **El módulo `invalidation.py` es puro.** No importa `trip.store`, no importa `os`, no llama a `save_state` ni a `os.replace`. El guard `rg -n 'from trip\.store import .*save_state' src/trip/invalidation.py` es la primera línea de defensa; la segunda es que el test `test_propagate_does_not_touch_state_yaml` compara hashes SHA-256 del fichero.
- **`_unwrap` es la única puerta** entre el wrap en disco y el escalar en memoria. No leer `recorded.values[name]` directamente en el nuevo código sin pasar por `_unwrap`. El dataclass `RequirementState.values` permanece como `dict[str, Any]` plano en memoria; el wrap solo existe en `state.yaml`.
- **El `via` de `NodeStatus` y el `_via` por campo son dos nombres distintos para dos cosas distintas.** `via` es "qué hipótesis cubren los huecos de este nodo" (a nivel de nodo, vivo en `unlock.resolve`); `_via` es "bajo qué hipótesis se escribió este valor" (a nivel de campo, vivo en `store._wrap_value`). El banner nunca los mezcla; la docstring de cada uno documenta la distinción.
- **`MONEY_COMMITTED_FACTS` se exporta con `__all__`** o como nombre público explícito, y el test `test_module_exposes_money_committed_facts_with_the_four_ids` la importa por nombre. Si se renombra, ese test rompe.
- **El kw `assumptions` en `update_requirement` y en MCP `update_requirement` es keyword-only.** Default `None` / `[]` mantiene el comportamiento actual bit a bit. Los 313 tests previos no tocan este kw y siguen verdes.
- **El banner se monta en una sola posición** en `OverviewView.tsx`: entre el bloque `{state.planning.assumptions.length > 0 && (...)}` y `<DeadlineList ... />`. No se duplica. La condición es `state.invalidation.affected.length > 0`. La copia es `"X elemento(s) caducado(s) por tu último cambio de hipótesis"`, con singular/plural correcto.
- **El test e2e (4.1) necesita que el fixture `empty` tenga `assumptions: window` activo.** Si el setup de `serve-fixture.mjs` no lo hace, hay que añadirlo. Es un cambio en `e2e/serve-fixture.mjs` (no en `data/`) y se justifica porque el e2e prueba el flujo bajo hipótesis.
- **El SSE en el e2e se valida con un `page.waitForFunction`** que mire `window.__lastEvent` o, alternativamente, un `page.waitForResponse` sobre `/api/events`. El primer POST no muestra banner (es la propia escritura); el segundo POST (o el cambio de hipótesis posterior) sí lo muestra. Si el test es flaky, el aserto se puede mover a un `expect.poll` con timeout.
- **El `applyLocal` se llama desde dos sitios** en el código actual: `Panel.tsx:246` (`onSaved={applyLocal}`) y `useLiveState.ts:97` (handler SSE). Ambos sitios deben pasar el cuarto argumento (`payload.invalidation` o `invalidation` del state actual). El test 3.2 cubre el path SSE; el path del Panel se cubre implícitamente por el e2e 4.1 (el POST devuelve el slice en la respuesta 200, y el panel lo aplica localmente).
- **El `command-menu.tsx`, `MapView.tsx`, `PricesView.tsx`, `RequirementsView.tsx`, y `RequirementRow.tsx` no se tocan.** El banner es exclusivo de `OverviewView`. Si durante apply se observa que cualquiera de estos archivos cambia, es un bug.
