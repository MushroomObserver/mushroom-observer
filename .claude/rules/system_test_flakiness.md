# System tests must be CI-ready — zero flake tolerance

**Hard, standing rule, not a per-PR judgment call.** A system test that
flakes — passes most of the time, fails occasionally under full-suite
or CI timing — is not "mostly reliable." It is broken. A flaky gate
trains everyone to re-run instead of investigate, and a real
regression hides behind the noise the first time it matters.

**If a system test flakes, fix it in the same session you found it.**
Don't report it as "pre-existing" or "likely flaky" and stop there —
that is the failure mode this rule exists to stop. Don't record it in
a memory file or a follow-up issue as the resolution either; a written
note describing a known-flaky test is evidence the rule is being
violated, not a fix.

## The fix is assertion granularity, not longer waits

The instinctive patch is to bump `wait:` on the final assertion and
hope extra seconds cover the race. Don't do that — it just makes the
failure slower to surface, and it gives no information about which
step actually broke. The real fix is to **assert on each incremental
DOM change along the way**, instead of waiting once for the end state:

```ruby
# BAD: waits once for the whole async chain, then checks the final
# value. If any intermediate step is slow, this times out with no
# information about which step failed.
assert_field("herbarium_location_id", with: "-1", type: :hidden, wait: 15)

# GOOD: breaks the same wait into the steps the UI actually goes
# through. A failure now names the step that didn't happen, and each
# step's own wait can be short -- it only covers one state transition,
# not the whole chain.
assert_selector("[data-type='location_google']", wait: 5)   # mode swapped
assert_selector(".geocoding-in-progress", wait: 2)           # request fired
assert_no_selector(".geocoding-in-progress", wait: 10)       # request settled
assert_field("herbarium_location_id", with: "-1", type: :hidden, wait: 2)
```

A comment explaining what each step *would* mean if it failed ("if
this fails, the API is dead; if that fails, it's a JS race") is not a
substitute for writing the steps as real assertions — finish the job.

See `.claude/rules/system_test_state_polling.md` for the companion
technique when the intermediate state lives in a Stimulus controller
rather than the DOM (poll the controller object instead of a selector
wait).

## Diagnose the flake type before picking the fix

Not every flake is a timing problem — pick the fix that matches the
actual cause:

- **Async JS/DOM race** (the UI updates in steps and the test only
  checks the last one) → incremental assertions, per above.
- **Non-deterministic DB lookup** — `Model.last`, or a scope like
  `recent_by_user(user).last` with no unique tiebreaker, racing
  against parallel test workers inserting fixtures concurrently →
  fix the query to be deterministic (find by an attribute the test
  itself controls; see `.claude/rules/testing.md`'s "Finding Records
  After Creation").
- **Live, unstubbed external service** (Google Geocoding, iNat's API)
  → stub it (`stub_request`, the pattern already used in
  `InatImportConfirmSystemTest`). No amount of assertion rewriting
  makes a live network call reliable on CI; stub the dependency
  instead of trying to out-wait it.

## Closing the loop

**Calling a test "flaky" is not an exit ramp — it's homework you just
assigned yourself.** The word describes a bug category, not a
resolution. "I reproduced this manually and it worked" does not close
the investigation on its own. A test that only fails under parallel load
or full-suite timing pressure is a real bug in the test — the manual
repro just ruled out an application bug, which narrows the fix to one
of the three categories above. Keep going until the test itself is
fixed and passes reliably under the same conditions it was flaking in
(full suite, parallel workers), not just in isolation.
