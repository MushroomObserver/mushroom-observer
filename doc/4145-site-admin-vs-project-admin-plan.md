# Issue #4145 — Site Admin vs Project Admin cleanup

Status: design resolved, ready to implement.

PR #4135 (issue #4129) surfaced two papercuts caused by
`Project#member?` and `Project#is_admin?` returning `true` for any
Site Admin (`user.admin == true`). The fix tightens both predicates
to mean *actual* group membership, audits every call site that
relied on the implicit Site-Admin fallthrough, and adds an explicit
"Administer Project" affordance so Site Admins can still moderate a
project — but as a deliberate action, not a blanket UI state.

This document is the implementation plan; the resolved design
decisions are inline below so reviewers don't have to re-derive them
from the issue thread.

---

## Background invariant (verified)

The current schema lets `admin_group` and `user_group` be populated
independently, but in practice every admin is also a member. Verified
on prod data with:

```ruby
Project.find_each do |p|
  admin_only = p.admin_group.users.where.not(
    id: p.user_group.users.select(:id)
  ).pluck(:login)
  puts "#{p.id} #{p.title}: #{admin_only.inspect}" if admin_only.any?
end
```

Result: empty. We treat `admin_group ⊆ user_group` as a real-world
invariant for this work — every code path that promotes a user to
admin must also ensure they're a member, and every place that lists
"members" can keep reading from `user_group.users` without unioning.

If a future feature wants to break that invariant, this plan needs
to be revisited.

---

## Resolved design decisions

### 1. Tighten `Project#member?` and `Project#is_admin?`

Drop the `|| user.admin` fallthrough on both. Each predicate now
reflects only actual group membership.

```ruby
def member?(user)
  user && user_group.users.member?(user)
end

def is_admin?(user)
  user && admin_group.users.member?(user)
end
```

Every call site that previously relied on the implicit Site-Admin
fallthrough is migrated to explicit semantics — see "Call-site
audit" below. The decision in every case was: **Site Admins must
self-promote** (via the new "Administer Project" button) before
they get Project-Admin or member powers on a project they aren't
part of.

### 2. New "Administer Project" button

- **Where:** Project show summary tab (`render_actions` in
  `app/views/controllers/projects/show.rb`).
- **Visibility:** rendered only when `@user&.admin && !@project.is_admin?(@user)`.
- **Action:** adds the user to both `admin_group` and `user_group`,
  and creates a `ProjectMember` row with `trust_level: "editing"`
  (matching the default produced by the existing `add_member` path
  through `update_project_membership`). Implemented as
  `Project#add_administrator(user)` so the data manipulation lives
  in the model.
- **Authorization:** the controller action is restricted to
  `user.admin == true` — non-Site-Admins calling the endpoint
  directly get the standard "must be project admin" denial.
- **Coexistence with Join:** for open-membership projects, the
  existing Join button still appears for Site Admins who aren't
  members; the "Administer Project" button appears alongside it.
  Joining gives them member status; Administer gives them admin
  status (and member status as a side effect).

### 3. Audit trail

When a Site Admin self-promotes via "Administer Project," the
project owner receives an email. No new audit log table; a `Mailer`
delivery + a `flash_notice` to the promoting user is sufficient
surface for now.

### 4. Demotion

Self-demotion uses the existing project members edit page —
`change_member_status_make_member` flips the user out of
`admin_group` while keeping them in `user_group`. No new UI needed.
A Site Admin who wants to fully step down can use the existing
"Leave" affordance afterward.

### 5. `member_status(user)` for non-members

After tightening, `member_status` falls through to `:MEMBER.t` for
users in neither group, which would be misleading. Update it to
return `nil` (and harden any callers that don't already guard
against nil).

### 6. Cosmetic cleanup on the Summary tab

The buttons rendered by `render_actions` in `show.rb` currently use
inconsistent classes — most are `btn btn-default btn-lg` with no
margin, while `violations_button` is `btn btn-lg btn-warning` (also
no margin). On narrow viewports the trust/leave/add-obs buttons
crowd horizontally, and the Constraint Violations button collides
vertically with the row above it.

Fix: route every button in `render_actions` (and
`violations_button` in `app/helpers/tabs/projects_helper.rb`)
through a single shared class string with consistent horizontal +
vertical margins, e.g. `btn btn-default btn-lg my-2 mr-2` (matching
the spirit of the existing `project_button_args` helper that's used
elsewhere in this file). Apply to: Join, the trust buttons, Leave,
Add My Observations, Members, Aliases, Constraint Violations,
Admin Request, and the new Administer Project button.

### 7. Trust-button redesign — out of scope here

The existing trust UI ("Share Hidden GPS" / "Allow Editing" /
"Revoke Trust") describes transitions rather than states, and the
three trust levels (`no_trust`, `hidden_gps`, `editing`) are
mutually exclusive — better fit for radio buttons in a modal than
for three side-by-side transition buttons. A modal with radio
buttons + Save + an explanatory paragraph is a worthwhile UX win.

Recommendation: do it in a separate PR after this one merges.
Reasons: (a) #4145 is already touching every project permission
call site and a redesign would balloon the diff; (b) the modal
infrastructure built for #4129 (`Components::AddObsModal`) is the
natural template, so the follow-up has a clear pattern to reuse;
(c) the cosmetic margin fix in (6) already gets the buttons looking
acceptable in the meantime.

---

## Call-site audit

| Call site | Old behavior | New behavior |
|---|---|---|
| `Project#member?` (project.rb:196) | `user.admin` ⇒ true everywhere | actual `user_group` membership only |
| `Project#is_admin?` (project.rb:201) | `user.admin` ⇒ true everywhere | actual `admin_group` membership only |
| `Project.admin_power?` (project.rb:276) | Site Admin moderated obs in any project | must self-promote first |
| `Project.can_edit?` (project.rb:261) | Site Admin edited any project's content | must self-promote first |
| `Project#can_edit?(user)` instance (project.rb:211) | same | same |
| `Project#member_status` (project.rb:239) | returned `:MEMBER` for non-members | returns `nil` |
| `Api2::ObservationApi` member check (observation_api.rb:179) | Site Admin added obs to any project via API | must self-promote first |
| `Article#news_articles_project.member?` (article.rb:79) | Site Admin authored news articles | must self-promote into the news-articles project (consistency over special-case; existing Site Admins are already members) |
| `MembersController#new / create / edit / update` (members_controller.rb:35, 53, 74, 84) | Site Admin managed members of any project | must self-promote first |
| `MatrixBox` Exclude button (matrix_box.rb:303) | Visible to Site Admins on any obs | only visible to actual project admins |
| `ProjectGroups` admin-list edit affordance (project_groups.rb:18) | shown to Site Admins on any project | only shown to actual project members |
| `Projects::Tabs#update_tab` (tabs.rb:78) | Site Admin saw Updates tab on any project with targets | only actual project admins |
| `Projects::LocationsTable @admin` (locations_table.rb:31) | Site Admin saw admin column | only actual project admins |
| `ProjectsController#set_ivars_for_show` (projects_controller.rb:223-224) | `@is_member` / `@is_admin` true for Site Admin | reflects actual roles |
| `Projects::FieldSlipsController#field_slip_max` (field_slips_controller.rb:81-83) | Site Admin got admin tier | gets non-member default; can self-promote for more |
| `Project#can_join?` (project.rb:220) | false for Site Admins (treated as members) | true on open-membership projects they aren't part of — Join button reappears, alongside Administer Project |

---

## Implementation steps

Order matters: tightening the predicates without first adding the
self-promote path locks Site Admins out of moderating any project.
Steps 1–2 land first as a single change; the call-site migrations
follow once the safety valve exists.

1. **Add `ProjectAdministrationsController` (or equivalent route on
   `MembersController`) and the "Administer Project" button.**
   - New controller action authorized by `user.admin == true`.
   - Inserts the user into `admin_group` and `user_group` and
     ensures a `ProjectMember` row exists, defaulting to
     `trust_level: "editing"` on create (matching the existing
     add-member flow through `update_project_membership`).
   - Sends an email to the project owner via the existing mailer
     infrastructure (new template under `app/views/observer_mailer/`
     or `app/mailers/`, plus locale strings in `en.txt`).
   - Renders the button in `render_actions` in
     `app/views/controllers/projects/show.rb` when
     `@user&.admin && !@project.is_admin?(@user)`.
   - Tests: controller test (auth, group membership effects, email
     enqueue), view-renders-button test in the Show component test.

2. **Tighten `Project#member?` and `Project#is_admin?`** by removing
   the `|| user.admin` fallthroughs.
   - Update `Project#member_status` to return `nil` for users in
     neither group.
   - This is the moment the call-site behavior changes; expect test
     churn here.

3. **Migrate explicit call sites** that need Site Admin to keep
   working without self-promotion.
   - Per the audit table above, the answer is "none" — every call
     site shifts to require self-promotion. So step 3 is mostly:
     read each call site, confirm tightening is the intended
     behavior, and update tests.
   - Notable test files: `test/controllers/projects/`,
     `test/components/`, `test/models/project_test.rb`,
     `test/controllers/api2_controller_test.rb` (for the
     observation API path).

4. **Cosmetic Summary-tab button cleanup.**
   - Introduce a single shared class string (or extend
     `project_button_args`) and apply to every button rendered by
     `render_actions` in `show.rb` plus `violations_button` in
     `app/helpers/tabs/projects_helper.rb`.
   - Visual check: load the project show page at narrow and wide
     viewports as both an unrelated user, a member, an admin, and a
     Site Admin; confirm spacing.

5. **Documentation.**
   - Update `doc/site_admin_setup.md` (if it exists) or add a brief
     section to project-admin docs describing the
     "Administer Project" affordance and that Site Admins are no
     longer implicit admins everywhere.

---

## Test impact

Substantial test churn is expected — fixtures named like
`users(:admin)` and several controller/component tests have been
written assuming the implicit-admin behavior. Plan to:

- Audit all `users(:admin)` references in
  `test/controllers/projects/`, `test/components/`,
  `test/models/project_test.rb`.
- For tests that *intend* to exercise Site-Admin moderation, switch
  them to either (a) explicitly add the user to the relevant
  `admin_group` in setup, or (b) hit the new self-promote endpoint
  as part of the test setup.
- For tests that *accidentally* rely on the implicit-admin
  behavior, fix the test to set up an actual project admin.

This is bookkeeping work, not design work, but it's the bulk of the
diff; budget time accordingly.

---

## Out of scope (deferred)

- **Trust-button modal redesign.** Worth doing; separate PR (see
  decision 7).
- **Whether Site Admins can see the member roster on projects they
  aren't members of.** Not needed for this work — the
  "Administer Project" button is the only Site-Admin-only affordance
  and it lives on the Summary tab, not behind the members page.
- **Default trust level on self-join.** Unchanged.
- **Generalizing the news-articles permission model away from
  "membership in a magic project."** Acknowledged as worth a
  rethink, deferred to a separate effort.
