# PR body formatting

When using `gh pr create` or `gh pr edit`, **always** write the body to a file first and pass it via `--body-file`. Never use a HEREDOC (`$(cat <<'EOF' ... EOF)`) for a PR body that contains backticks for code formatting.

## No hard-wrapped paragraphs

**Never hard-wrap a paragraph at ~70-72 columns.** Write each paragraph as a single logical line in the source. The only line breaks in a Markdown body should be: between paragraphs (one blank line), in code blocks, in lists, in tables. Inside a paragraph: no breaks.

GitHub renders soft-wrapped paragraphs perfectly. Hard-wrapping does nothing for the reader and makes the body harder to edit, harder to diff, and harder to copy a sentence out of. The user has flagged this enough times that it's a hard rule.

Wrong:

```
Adds `Location.dubious_reasons_for(user:, place_name:, approved:)` that
encapsulates the `user_format` + `dubious_name?(…, true)` pattern that
lived as 2-3 lines in 4 controllers across 6 call sites.
```

Right:

```
Adds `Location.dubious_reasons_for(user:, place_name:, approved:)` that encapsulates the `user_format` + `dubious_name?(…, true)` pattern that lived as 2-3 lines in 4 controllers across 6 call sites.
```

Lists and tables and code blocks still use their natural line structure — this rule is about prose paragraphs only.

## Why

Inside `$(...)`, backticks must be escaped as `` \` ``. The escape
character passes through `gh` to the GitHub API and GitHub Markdown
then renders the backslash as a literal character before the tick.
A line that should display as `Foo::Bar` ships as `\Foo::Bar\` — the
classes/methods/files in the PR description lose their monospace
treatment, and the diff between intent and rendering goes unnoticed
unless someone (the human author) catches it after the fact. This has
been caught on multiple PRs.

The user has flagged this enough times that it's now a permanent rule,
not a "remember next time" thing.

## Do

```bash
cat > /tmp/pr_body.md <<'EOF'
## Summary
- `Foo::Bar` renamed to `Baz::Qux`
- `app/components/foo.rb` → `app/views/controllers/foo/form.rb`

## Test plan
- [x] `bin/rails test ...`
EOF

gh pr create --title "..." --body-file /tmp/pr_body.md
# or, for edits:
gh pr edit 1234 --body-file /tmp/pr_body.md
```

The Markdown body file is plain — no shell escaping. Backticks render
correctly. Multi-line code blocks, links, lists, all work.

## Don't

```bash
# ❌ HEREDOC mangles backticks via $(...) escaping:
gh pr create --title "..." --body "$(cat <<'EOF'
- \`Foo::Bar\` renamed   # ← backslashes render literally on GitHub
EOF
)"
```

If you absolutely cannot write to a file (extremely rare), use
single-quoted string concatenation rather than `$(...)`. But the file
path is always available and is always the right choice.

## Verify

After creating or editing, spot-check the rendered body:

```bash
gh pr view <num> --json body --jq .body | head -20
```

If you see `\\\`` anywhere, the body got mangled — re-edit with
`--body-file`.
