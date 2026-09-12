# Guard raw params before they reach a Literal-typed prop

When a Literal `prop` on a `Components::Base` / `Views::Base` /
`Components::ApplicationForm` subclass has a scalar type (`String`,
`Integer`, `Symbol`, `_Boolean`, or a `_Nilable(...)` wrapper of any
of those — anything short of `_Any`) and its value traces back to a
raw `params[...]` / `params.dig(...)` read, guard that read before it
reaches the prop.

## Why

Rails parses a scalar param sent as a nested hash (`?back[x]=1`) into
an `ActionController::Parameters` object, not a String. A Literal
`String`/`Integer` prop raises `Literal::TypeError` immediately at
construction — a 500 — instead of degrading gracefully. This is the
same failure mode `ScalarParams` (`app/classes/scalar_params.rb`) was
built to prevent for direct string sinks; a Literal prop is just a
stricter version of the same kind of sink.

Not hypothetical: an audit of the Literal-props-native conversion
(issue #5022) found ~10 real, unguarded call sites. Two crash on
totally ordinary usage, no attacker required —
`observations/form/specimen.rb`'s `herbarium_id` round-trips through
a hidden field as a String on every request with zero coercion, so
any failed observation-create submission with a preferred/entered
herbarium 500s on reload.

## What to do

- Prefer `params.permit(:key)[:key]` at the read site. Rails' own
  strong-params mechanism already filters non-scalar values for a
  permitted key — no custom code needed.
- For an existing raw sub-hash extraction helper
  (`params.dig(:observation, :herbarium_record)`-style) that has no
  `.permit` at all yet, add `.permit(:key1, :key2, ...)` to the
  extraction method rather than guarding every read site downstream
  of it.
- For a value that needs a further type cast beyond shape (String →
  Integer), use `ScalarParams#safe_integer` — degrades a non-numeric
  String to `nil` rather than raising, since it sits at a request
  boundary handling untrusted input. This is deliberately different
  from `LiteralIDCoercion::TO_ID`/`TO_ID_ARRAY` (see
  `app/classes/literal_id_coercion.rb`), which raise loudly — those
  are for Literal prop coercion blocks constructing from an
  already-permitted, already-scalar source, where a bad value
  indicates a programmer bug worth surfacing, not untrusted input to
  sanitize.

## What NOT to do

Don't blanket-convert every `params[...]` read in the app "just in
case." A direct count found 859 raw `params[:key]` reads across 156
controller files — the overwhelming majority never reach a
Literal-typed prop (they flow into `.to_s`, `.to_i`, `==`
comparisons, `Model.find`/`where`, or older untyped code). Scope this
rule to props actually declared on Literal-props-native classes, the
same way `.claude/rules/sweeps.md` scopes any other sweep — don't
self-extend it to call sites the risk doesn't reach.

## When this doesn't apply

- The value only ever reaches `.to_s`, `.to_i`, `==`, or an
  ActiveRecord `find_by`/`where` — these don't raise the same way, or
  are a separate, pre-existing concern outside this rule's scope.
- The prop type is `_Any` — no typecheck to break in the first place
  (though `_Any` is itself discouraged when the real type is known —
  see "ALWAYS use concrete prop types" in
  `.claude/rules/phlex_reference.md`).

## Checklist for new prop conversions

When converting a view/form to Literal props (or adding a new prop to
one), for each scalar-typed prop ask: does this value's chain back to
the controller pass through a raw `params[...]` read? If yes, guard
it per "What to do" above, in the same commit — don't defer it.
