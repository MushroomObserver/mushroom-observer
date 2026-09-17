# Review types — one `review:` label on every PR

Every PR carries one review-type label saying how soon it may merge and
what review it needs (issue #5381). A type decides when a PR may
**merge**: every deploy ships whatever is on `main`, so holding a change
back means not merging it yet. `script/open_pull_requests.rb` (also
printed by `script/prerelease.rb`) lists which open PRs may merge now;
it reports, it does not gate.

| Label | Review | May merge | Ships in |
| --- | --- | --- | --- |
| `review: blocker` | Optional; the author may request one | As soon as the author is comfortable | An off-schedule deploy, run by the PR author |
| `review: urgent` | Optional | Any time | The next scheduled deploy |
| `review: standard` | Optional; no review within 24 hours counts as approval | 24 hours after the PR was last marked ready, or earlier with an approving review | The first deploy at least 24 hours after ready (earlier if approved) |
| `review: needs review` | Required: an approving review | Once approved | The first deploy after it merges |

- **Blocker** — urgent bugs that need a release as soon as possible.
  Every developer can deploy, so the author owns that deploy.
- **Urgent** — bugs (or occasionally features) for the next deploy.
- **Standard** — the default: features (or bugs) that can wait a day or
  two, giving reviewers at least 24 hours.
- **Needs Review** — changes that must not merge unreviewed. Reviewers
  aim to respond within about a week; that is an expectation, not a
  deadline.

A PR with no review label is treated as Standard and flagged in the
report. A PR with several takes the most cautious and is flagged too.
The `changelog-pending` PR is exempt. Dependabot PRs are labeled
`review: urgent` by `.github/dependabot.yml`.

## The clock

- Starts at the PR's latest "ready for review" event; a PR opened as
  ready starts when it was opened. Draft PRs are not on the clock.
- Pushes after the PR is ready do **not** reset it. For a large change,
  convert the PR back to draft and mark it ready again.

## Approvals

- Only a human developer other than the PR author can approve. A PR
  written with Claude's help is the change of the developer who ran the
  session, so that developer cannot approve it.
- Copilot and other bot reviews do not count.
- Commits pushed after an approval keep it valid.
- A review requesting changes holds a Standard or Needs Review PR until
  it is resolved; for Standard it is not the silence that counts as
  approval.

## In Claude sessions

Create PRs with the Standard label:

```bash
gh pr create --draft --label "review: standard" --title "..." --body-file ...
```

Apply `review: blocker`, `review: urgent`, or `review: needs review` only
when the developer says so. A session may suggest a different type in
chat, with the reason, but the choice is the developer's.
