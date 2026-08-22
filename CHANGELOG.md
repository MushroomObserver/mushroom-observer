# Changelog

## 2026-08-22 (deploy-2026-08-22-01-42)

- Prefix only bare-number field slip codes in `AddDispatchController` (PR 5147, @mo-nathan)
- Truncate oversized import digests (PR 5130, @JoeCohen)
- Clean up the abandoned `Occurrence` when an observation moves to another (PR 5151, @mo-nathan)
- Fix four recurring #alerts noise sources (`UserStats` orphans, `external_id` 500, scanner MIME 500, `define_a_location` deadlock) (PR 5152, @mo-nathan)
- Convert `comments.comment` and `users.notes` to utf8mb4 (emoji 500s) (PR 5153, @mo-nathan)
- Nightly retry sweep for failed GPS strips (`Image.retry_failed_gps_strips`) (PR 5154, @mo-nathan)
- oauth2 2.0.25 (PR 5157, @JoeCohen)
- Fix false constraint-violation warning from reused field-slip prefix (PR 5156, @JoeCohen)

## 2026-08-21 (deploy-2026-08-21-12-04)

- Add `MO/NoHandRolledMethodField` rubocop cop (PR 5128, @nimmolo)
- Wire `Publication` into `InlineCRUDLinks` (PR 5132, @nimmolo)
- Dedupe `Query` param URL-merge logic between `add_q_param` and `Tab::Base#with_q_param` (PR 5135, @nimmolo)
- Add `block_banned_words.sh` hook to enforce style-ban words automatically (PR 5133, @nimmolo)
- Add `MO/NoRenderPhlexMethodName` cop, rename all `render_phlex_*` methods (PR 5134, @nimmolo)
- Add general `.btn-group`/`.input-group` flex-height fixes (PR 5136, @nimmolo)
- Add rotate/mirror icons to `ImagePanel`'s transform controls (PR 5127, @nimmolo)
- Flip Turbo `forms.mode` to opt-out (#5100), eliminate remaining hand-rolled forms (PR 5141, @nimmolo)
- "Flat Query Params" foundation work (#5137) - no changes, just plumbing (PR 5142, @nimmolo)
- prev/next nav: Cached-window lookup with seek-backed fill (PR 5118, @nimmolo)
- Add UI to add/remove an observation to/from a `Project` (PR 5123, @nimmolo)
- Add "Attach to Field Slip" UI to the observation show page (PR 5124, @nimmolo)
- Carry project context to species-list checklists; add `Missing taxa` panel (PR 5145, @mo-nathan)
- Show importable cap (PR 5126, @JoeCohen)

## 2026-08-18 (deploy-2026-08-18-15-03)

- Fix title-bar edit/delete icon alignment via `Components::InlineLinkBlock` (PR 5099, @nimmolo)
- Fix pattern-search icon rendering outside the input (PR 5097, @nimmolo)
- Fix flaky `observation_show_system_test` race on "Your Observations" (PR 5113, @nimmolo)
- Project-less field slips: skip the null-project bucket in `users_last_location` (PR 5111, @mo-nathan)
- Filtered search: accept comma date ranges in `DateRangeParser`; never silently drop an unparseable date (PR 5112, @mo-nathan)
- Add index on `observations(log_updated_at, id)` (PR 5117, @nimmolo)
- Create obs slowness: Add missing `observations.user_id` index; fix project-checkbox N+1 (PR 5106, @nimmolo)
- Parse provisional `sp` without a trailing period (PR 5105, @JoeCohen)
- Fix mcp backfill test warnings (PR 5109, @JoeCohen)
- Reduce observations "Sort by" options for unfiltered index (PR 5119, @nimmolo)
- Fix `size:` being silently ignored on `Button(type: :modal, ...)` (PR 5125, @nimmolo)
- Show the "reopen announcements" banner icon on mobile too (PR 5121, @nimmolo)
- Fix `.inline-icon-link` baseline and `.input-group-btn` icon-button height (PR 5120, @nimmolo)

## 2026-08-17 (deploy-2026-08-17-11-02)

- Observation upload row: `Take Photo` capture button, `Select Photos` naming, drop/paste hint, paste support (PR 5084, @mo-nathan)
- Add `FieldSlip::Template::Nama` for the NAMA 2026 foray slips (PR 5087, @mo-nathan)
- Firm-up `turbo:`/`context:` convention on `Components::ApplicationForm`, fix bugs found along the way (PR 5095, @nimmolo)
- Fix user autocompleter dropping login-only matches (issue #3537) (PR 5096, @nimmolo)
- Script to backfill MCP ExternalLinks (PR 4877, @JoeCohen)

## 2026-08-16 (deploy-2026-08-16-14-11)

- Update rubocop extensions (PR 5089, @JoeCohen)

## 2026-08-16 (deploy-2026-08-16-00-02)

- Fix field-slip review loop: duplicate `_method` made Turbo submit the save as a bare POST (PR 5088, @mo-nathan)

## 2026-08-15 (deploy-2026-08-15-20-06)

- Turbo-submit `InatImportsController` (issue #5052) (PR 5066, @nimmolo)
- Turbo-submit sweep batch 2: `Admin::*`, `Descriptions::*`, `FieldSlips*`, `Images::*`, `Names*`, `Occurrences*`, `Projects*` (issue #5052) (PR 5061, @nimmolo)
- Turbo-submit sweep batch 3: `Names::Synonyms::*`, `Observations::*`, `Publications*`, `Sequences*`, `SpeciesLists*`, `Support*`, `Users::*`, `VisualGroups*`, `VisualModels*` (issue #5052) (PR 5069, @nimmolo)
- Use `NormalizedHash` -> `NotesHash` PORO everywhere for notes-Hash shape and Phlex prop validation (PR 5082, @nimmolo)
- Say "delete" instead of "destroy" throughout user-facing text (PR 5049, @nimmolo)

## 2026-08-15 (deploy-2026-08-15-16-08)

- Allow iNat imported data Place to be Private (PR 5086, @JoeCohen)

## 2026-08-15 (deploy-2026-08-15-04-58)

- Fix the dubious-locality approval loop and the sticky free-text Locality default (`approved_where` / `field_slip_for_code`) (PR 5083, @mo-nathan)

## 2026-08-14 (deploy-2026-08-14-22-28)

- Turbo submit observation form (issue #5052) and disable in-flight form on submit (#5077) (PR 5055, @nimmolo)
- Turbo-submit sweep batch 1: `Account::*`, `Admin::*`, `Articles`, `CollectionNumbers`, `Comments`, `Descriptions::*`, `Herbaria*`, `Images::*`, `Info`, `Locations*`, `Names::*`, `Observations::ImagesController` (issue #5052) (PR 5058, @nimmolo)
- Fix `Location.contains_point` for boxes straddling the antimeridian (PR 5081, @nimmolo)

## 2026-08-14 (deploy-2026-08-14-22-09)

- Bump json from 2.21.1 to 2.21.2 (PR 5019, @app/dependabot)
- Fix language locale leakage: stop persisting `?user_locale=` to `@user.locale`, make the switcher POST (PR 5075, @nimmolo)
- Manual geocoding entry - Fix `#5017` viewport jump / paste-split and `#5014` zero-coordinate falsy bug (PR 5076, @nimmolo)
- Fix observation, species_list, project forms looping on a confirmed dubious location name (DRY) (PR 5079, @nimmolo)
- Don't raise on links in field labels (fixes production crash on `/support/donate`) (PR 5078, @nimmolo)

## 2026-08-14 (deploy-2026-08-14-08-12)

- Make a separate `/projects/:project_id/violations` update route (PR 5071, @nimmolo)

## 2026-08-14 (deploy-2026-08-14-07-55)

- Turbo-submit `Observations::NamingsController` + fix two lightbox/clone bugs found along the way (PR 5065, @nimmolo)

## 2026-08-14 (deploy-2026-08-14-01-07)

- Fix `Components::Form::NameFeedback` losing its help text for unrecognized names (PR 5073, @nimmolo)

## 2026-08-14 (deploy-2026-08-14-00-35)

- Restore the spinners the SVG-sprite conversion emptied (`.spinner-right`) (PR 5067, @mo-nathan)
- Extract `Account::PasswordResetsController` from `Account::LoginController` (PR 5070, @nimmolo)
- Address Copilot findings on `Account::PasswordResetsController` from #5070 (PR 5072, @nimmolo)
- Fix `section-update` Stimulus controller: never dispatching `section-update:updated` (PR 5064, @nimmolo)

## 2026-08-13 (deploy-2026-08-13-16-41)

- Broaden image transform permission (PR 5009, @JoeCohen)

## 2026-08-13 (deploy-2026-08-13-12-38)

- Give submit buttons in-flight feedback (`form-feedback` Stimulus controller) (PR 5035, @mo-nathan)
- A spare slip still resolves its event's aliases via the printed prefix (`FieldSlip#event_project`) (PR 5057, @mo-nathan)
- Don't warn "in use" about a slip the QR job just attached to this observation (`explain_in_use_slip` race) (PR 5059, @mo-nathan)
- Update gets Create's slip-review handoff for newly added photos (PR 5060, @mo-nathan)

## 2026-08-13 (deploy-2026-08-13-00-54)

- Prototype Turbo submission on `LicensesController`; hoist `render_*_view_invalid`; fix `form-images_controller.js` resubmission (PR 5054, @nimmolo)
- Skip permission-denied flash when turning off admin mode from an admin-only page (PR 5056, @nimmolo)

## 2026-08-12 (deploy-2026-08-12-22-26)

- Fix observation destroy-redirect test assumption; hook up dead `areAllItemsExifPopulated()` gate (PR 5053, @nimmolo)

## 2026-08-12 (deploy-2026-08-12-22-03)

- One-pass project alert incl. the slip's target project; slip+observation leave a violating project together (PR 5046, @mo-nathan)
- Post-event cleanup report + field-slip event docs split by audience (admin article draft, dev notes) (PR 5047, @mo-nathan)
- Scan-page photo/action spacing + `.claude/rules/ui_spacing.md` UI-spacing conventions (PR 5044, @mo-nathan)
- Remove the last #5038 locality-trap leftovers from the event docs (PR 5050, @mo-nathan)
- Make `Components::ApplicationForm` Literal-props-native, use props in forms (PR 5051, @nimmolo)

## 2026-08-12 (deploy-2026-08-12-09-07)

- Convert Phlex `initialize`s to Literal props; add 4 custom cops (PR 5025, @nimmolo)
- Switch `Components::Icon` rendering from Bootstrap 3 glyphicon font to an SVG sprite (PR 5020, @nimmolo)

## 2026-08-11 (deploy-2026-08-11-02-32)

- Attach the field slip from the extraction's read code (`ExtractFieldSlipJob`, review form, repair script) (PR 5040, @mo-nathan)
- Normalize separator-grouped iNaturalist ids in every template's iNat slot (`Template::Base`) (PR 5043, @mo-nathan)
- Review-save joins an in-use slip's occurrence (`Attacher` `join_in_use:`); explain the create-time pause (PR 5045, @mo-nathan)

## 2026-08-09 (deploy-2026-08-09-19-14)

- Fix QR slip detection in production: probe the direct disk path (`FieldSlip::QRDecoder`) (PR 5034, @mo-nathan)

## 2026-08-09 (deploy-2026-08-09-18-30)

- Keep line breaks in multi-line field slip values through review (`textarea` for multi-line rows) (PR 5031, @mo-nathan)
- Add `zbar` to setup docs, dev-setup scripts, and `Dockerfile` (PR 5030, @mo-nathan)
- Index `names.text_name` and `names.search_name` (PR 5033, @mo-nathan)
- Run slip extraction in the background (`ExtractFieldSlipJob`); land Create on the review page (PR 5032, @mo-nathan)

## 2026-08-09 (deploy-2026-08-09-15-00)

- Narrow icon-library checkouts to just `mo-icons.svg` (PR 5021, @nimmolo)
- Add `FieldSlip::Template` layouts; read Andy Wilson's DBG voucher slips (PR 5026, @mo-nathan)
- Auto-attach observations to field slips via QR codes in uploaded photos (`FieldSlip::QRDecoder`) (PR 5029, @mo-nathan)

## 2026-08-07 (deploy-2026-08-07-23-03)

- Read a handwritten MycoMap voucher number (PR 5018, @mo-nathan)

## 2026-08-07 (deploy-2026-08-07-22-17)

- Ignore a question mark when looking up a name (PR 5015, @mo-nathan)
- Fetch icon-library's sprite in CI via a scoped PAT (PR 5011, @nimmolo)
- Make the Geolocation checkbox on the observation form mean something (PR 5016, @mo-nathan)
- Fix stale `rvm` reference in `README_PRODUCTION_INSTALL`, add missing `RUBY_MANAGER` to `solidqueue.service` (PR 4997, @nimmolo)

## 2026-08-07 (deploy-2026-08-07-16-12)

- Make the observation form's Geolocation section usable as loaded (PR 5013, @mo-nathan)
- Grant `editing` trust on project creation and `Project#join`, and backfill untouched `hidden_gps` (PR 5008, @mo-nathan)

## 2026-08-07 (deploy-2026-08-07-14-03)

- Extract dev-setup finish sequence, fold Ubuntu root/mo scripts, drop dead unicorn config (PR 5004, @nimmolo)
- Scripts to clone private icon-library repo to dev or production (PR 5001, @nimmolo)
- Resolve names written in a single case (`russula compacta`, `RUSSULA COMPACTA`) (PR 4999, @mo-nathan)

## 2026-08-06 (deploy-2026-08-06-08-04)

- DRY component/view test render calls; add `MO/DryTestRenderHelper` cop to catch it going forward (PR 4995, @nimmolo)
- DRY up `API2::*Test` param hashes (issue #4707) (PR 4996, @nimmolo)
- Add `dev_setup_macos` and `dev_setup_ubuntu`, share setup modules (PR 4998, @nimmolo)

## 2026-08-05 (deploy-2026-08-05-16-21)

- Reset the WebMock request registry between tests (PR 4958, @mo-nathan)
- Note the two-config maintenance of the GCS archive cutoff in `config/etc/nginx.conf` (PR 4987, @mo-nathan)
- Fix glyphicon misalignment on carousel controls and the lightbox theater button (PR 4994, @nimmolo)

## 2026-08-05 (deploy-2026-08-05-12-24)

- Let a field slip read report that the image holds no slip (`slip_present`) (PR 4993, @mo-nathan)
- Default the navbar search type to Observations on the Activity Log (PR 4970, @mo-nathan)

## 2026-08-04 (deploy-2026-08-04-23-29)

- Move observation source-credit line into `ObjectFooter` (PR 4990, @nimmolo)
- nginx: Proxy image requests in instead of redirecting (minor fix for slow image loading) (PR 4982, @nimmolo)

## 2026-08-04 (deploy-2026-08-04-23-15)

- Fix carousel vote-button tooltip clipping; scope `.glyphicon` `top` offset to `.btn` (PR 4991, @nimmolo)

## 2026-08-04 (deploy-2026-08-04-11-42)

- Fix lingering gray thumbnails: batch vote-interface streams, raise Puma concurrency, HTTP/2, stable `updated_at` on votes (#4984) (PR 4985, @mo-nathan)

## 2026-08-03 (deploy-2026-08-03-23-34)

- Silence and assert on expected-failure log noise in 2 tests (PR 4981, @nimmolo)
- Redesign image vote UI: theme-independent meter, `ButtonGroup` links (PR 4972, @mo-nathan)
- Move the thumbnail map into `Show::Details` under the location info (PR 4968, @mo-nathan)

## 2026-08-03 (deploy-2026-08-03-22-15)

- Enforce `assert_equal(nil, ...)` as a failure; fix remaining offenders (PR 4980, @nimmolo)

## 2026-08-03 (deploy-2026-08-03-20-02)

- Add the `su mo mo` directive logrotate needs to rotate `mo`-owned app logs (PR 4978, @mo-nathan)
- Fix `MatrixBox` heading/badge display (PR 4979, @nimmolo)

## 2026-08-02 (deploy-2026-08-02-10-37)

- Alert on image-processing failures, classify stale files, and retry failed transfers (#4974) (PR 4977, @mo-nathan)

## 2026-08-01 (deploy-2026-08-01-10-26)

- Store field slip "Id by" as a user link, and stop the prompt expanding initials (PR 4963, @mo-nathan)

## 2026-08-01 (deploy-2026-08-01-00-36)

- Tick every field slip row by default, and mark the disagreements (PR 4960, @mo-nathan)

## 2026-07-31 (deploy-2026-07-31-21-14)

- Read field slips from their photos with an LLM, for admin review (PR 4951, @mo-nathan)

## 2026-07-31 (deploy-2026-07-31-15-14)

- Fix the field-slip note fields on the observation edit form (`Other Codes` duplicated, iNat flag not persisting) (PR 4950, @mo-nathan)

## 2026-07-30 (deploy-2026-07-30-22-12)

- Bump oauth2 from 2.0.20 to 2.0.22 (PR 4947, @app/dependabot)

## 2026-07-30 (deploy-2026-07-30-19-54)

- Change Rank dropdown order on Names form (PR 4946, @JoeCohen)

## 2026-07-30 (deploy-2026-07-30-00-22)

- Derive API2 `external_link` url from `external_id` (PR 4944, @AlanRockefeller)

## 2026-07-29 (deploy-2026-07-29-21-19)

- Add coverage lost in #4915 (PR 4943, @JoeCohen)
- Convert `assert_flash` call sites to tag-only signature (#4931) (PR 4936, @nimmolo)

## 2026-07-29 (deploy-2026-07-29-19-18)

- Fix doubled colons on `Form::Specimen`'s Fungarium Name and Accession Number labels (PR 4937, @mo-nathan)
- Route `/qr/<code>` to the Create Observation page (#4932) (PR 4938, @mo-nathan)
- Enforce the occurrence/project membership invariants (#4932) (PR 4940, @mo-nathan)
- Add dry-run/apply convention rule: `--apply` for runner scripts, `APPLY=1` for rake tasks (PR 4933, @mo-nathan)

## 2026-07-28 (deploy-2026-07-28-14-25)

- Fix ambiguous imported rank (PR 4915, @JoeCohen)

## 2026-07-28 (deploy-2026-07-28-06-50)

- Make native Rails validation errors translatable (phase 2 of #4901) (PR 4920, @nimmolo)
- Make name authors non-breaking wherever they render (`String#small_author`) (PR 4934, @nimmolo)
- Make observation `SpecimenPanel` collapsible (PR 4935, @nimmolo)

## 2026-07-27 (deploy-2026-07-27-19-56)

- Resync read-only reflections from their iNaturalist source + `Sync now` button (#4215) (PR 4853, @mo-nathan)

## 2026-07-27 (deploy-2026-07-27-19-33)

- Render field help outside `.form-group`, fixing autocompleter dropdown positioning (alt. to #4911) (PR 4922, @nimmolo)

## 2026-07-27 (deploy-2026-07-27-18-50)

- Consolidate validation-error display into `Components::Form::Errors` (#4901, phase 1) (PR 4914, @nimmolo)

## 2026-07-26 (deploy-2026-07-26-14-35)

- Fix `FieldSlip#users_last_location` picking the oldest slip; smarter location fallbacks (PR 4908, @mo-nathan)
- Fix `ensure_thumb_image` discarding a newly uploaded image chosen as thumbnail (PR 4906, @mo-nathan)

## 2026-07-26 (deploy-2026-07-26-04-21)

- Move `page_title`/`document_title` from 16 models to a `Title::` PORO family (#4901) (PR 4913, @nimmolo)

## 2026-07-26 (deploy-2026-07-26-03-04)

- Return unresolved `[tag, args]` pairs from `Location`'s dubious-name checks (#4901) (PR 4910, @nimmolo)
- Key `NamingConsensus` vote table by canonical value, not resolved text (#4901) (PR 4912, @nimmolo)

## 2026-07-26 (deploy-2026-07-26-01-51)

- Move `Location`/`Herbarium`/`Name::Format#merge_info` to a dedicated mailer (#4901) (PR 4905, @nimmolo)

## 2026-07-26 (deploy-2026-07-26-00-37)

- Extract `RssLog::Title` PORO; move `Project::Date#date_range` to views (#4901) (PR 4903, @nimmolo)

## 2026-07-25 (deploy-2026-07-25-00-39)

- Move 5 more model-level tag resolvers to the view layer (#4901) (PR 4902, @nimmolo)

## 2026-07-24 (deploy-2026-07-24-20-39)

- Move `RssLog#detail` and `Observation#source_credit` to the view layer (PR 4900, @nimmolo)

## 2026-07-24 (deploy-2026-07-24-11-33)

- Memoize `User#in_group?` per-instance (#4896) (PR 4898, @nimmolo)

## 2026-07-24 (deploy-2026-07-24-11-29)

(no merged PRs -- asset-only or config deploy)

## 2026-07-24 (deploy-2026-07-24-05-49)

- Fix N+1 on observations index when `perform_caching` is off (PR 4897, @nimmolo)
- Establish `Components::<Model>Fragment` dispatcher pattern; restore lightbox vote UI (PR 4892, @nimmolo)

## 2026-07-23 (deploy-2026-07-23-23-28)

- Add `MO/NoRawLinkOrButtonTo` cop; convert remaining `link_to`/`button_to`/`button` call sites (PR 4883, @nimmolo)

## 2026-07-23 (deploy-2026-07-23-21-25)

- Move external-link badge tooltip to top (PR 4893, @nimmolo)

## 2026-07-23 (deploy-2026-07-23-14-47)

- Bump websocket-driver from 0.8.1 to 0.8.2 (PR 4889, @app/dependabot)

## 2026-07-23 (deploy-2026-07-23-14-44)

- Bump rails-html-sanitizer from 1.7.0 to 1.7.1 (PR 4888, @app/dependabot)

## 2026-07-23 (deploy-2026-07-23-14-37)

- Bump loofah from 2.25.1 to 2.25.2 (PR 4880, @app/dependabot)

## 2026-07-23 (deploy-2026-07-23-12-41)

- Address Copilot review comments on #4881 (PR 4882, @nimmolo)
- Fix dead lightbox caption links behind invisible `.vote-section` overlay; extract `Components::ObservationWho` (PR 4885, @mo-nathan)

## 2026-07-23 (deploy-2026-07-23-09-18)

- Reorganize observation `ExternalLinks`, `Notes` and `Specimen` sub-views (PR 4821, @nimmolo)
- Add empty-state caption + inline add-link to the observation external-links row (PR 4881, @nimmolo)

## 2026-07-23 (deploy-2026-07-23-07-49)

- Move and rubocop `Language::Exporter`/`Language::Tracking` (PR 4878, @nimmolo)
- Parallelize `lang.rake` multi-language tasks; skip entirely if no change (PR 4772, @nimmolo)
- Delete confirmed-complete parity tests (PR 4876, @nimmolo)
- Make tooltip activation properly reactive by using a Stimulus target (PR 4879, @nimmolo)

## 2026-07-23 (deploy-2026-07-23-04-04)

- Warn on dev server/console boot when Solid Cache caching is off (PR 4875, @nimmolo)
- Remove 327 unused `en.txt` tags and add regression test (part of #4867) (PR 4871, @nimmolo)
- Fix 3 flaky/stale system test assertions (PR 4874, @nimmolo)

## 2026-07-23 (deploy-2026-07-23-00-28)

- Log rsync exit code + stderr on image transfer failure (PR 4870, @mo-nathan)
- Enforce image upload size limit client-side; block over-limit submits (#4872) (PR 4873, @mo-nathan)

## 2026-07-22 (deploy-2026-07-22-18-54)

- Batch `MatrixBox`'s per-object cache reads/writes (PR 4865, @nimmolo)

## 2026-07-22 (deploy-2026-07-22-15-17)

- Add weekly `GpsLeakDetectorJob` tripwire + re-archiving `rclone_originals.sh` (PR 4860, @mo-nathan)

## 2026-07-22 (deploy-2026-07-22-08-20)

- Silence `SolidCache::Entry` query logging (PR 4863, @nimmolo)
- Bulk-delete obsolete translation strings in `Language#strip` (PR 4864, @nimmolo)

## 2026-07-21 (deploy-2026-07-21-22-50)

- `i18n`: consolidate `:ALL_CAPS`/`:all_caps` translation tags, add `Symbol#ti` (PR 4861, @nimmolo)

## 2026-07-21 (deploy-2026-07-21-17-58)

- Fix image rotation live-update broadcast (#4854) (PR 4857, @nimmolo)

## 2026-07-20 (deploy-2026-07-20-20-31)

- Skip re-sending images already in MCP (PR 4822, @JoeCohen)

## 2026-07-20 (deploy-2026-07-20-20-27)

- Force iNat confirm-form links to the UI host (PR 4810, @JoeCohen)

## 2026-07-20 (deploy-2026-07-20-14-11)

- Fix GPS-leak race between image file rewrites (`strip_gps!`, rotate) and `TransferImagesJob` (PR 4858, @mo-nathan)

## 2026-07-20 (deploy-2026-07-20-07-17)

- Extract `Components::ApplicationForm::FieldWrapperRendering` (PR 4856, @nimmolo)

## 2026-07-19 (deploy-2026-07-19-22-52)

- Notes merge: show shared values + `Concatenate All` (#4849) (PR 4851, @mo-nathan)

## 2026-07-19 (deploy-2026-07-19-17-01)

- Exempt `db/schema.rb` from the rubocop-on-save hook (PR 4845, @nimmolo)
- Coerce scalar request params so hash-shaped probes don't 500 (PR 4846, @mo-nathan)
- Fix dangling-reference leaks at their sources; report every broken-references cleanup (PR 4848, @mo-nathan)
- Scrub invalid UTF-8 from incoming requests via `Rack::UTF8Sanitizer` (PR 4847, @mo-nathan)
- Add a code-comments rule: explain *why* (only when unclear), one source of truth (PR 4850, @mo-nathan)

## 2026-07-19 (deploy-2026-07-19-07-33)

- Block cc from uselessly `cd`'ing into the current directory (PR 4838, @nimmolo)
- Sweep remaining `render(Components::X.new(...))` callers to Kit syntax (PR 4839, @nimmolo)
- Fix `script/exiftool_remote` argument handling and `Shellwords` corruption of GPS-stripping tests (PR 4836, @nimmolo)
- Rename `Components::Image::Interactive` to top-level `Components::InteractiveImage`; sweep callers to Kit syntax (PR 4841, @nimmolo)

## 2026-07-18 (deploy-2026-07-18-12-03)

- Update page upon modifying Comment (PR 4835, @JoeCohen)

## 2026-07-18 (deploy-2026-07-18-08-00)

- Extract `CoordinateFormat` module; dedupe coordinate/collection/query logic out of `Observation` and `Mappable` (PR 4837, @nimmolo)

## 2026-07-17 (deploy-2026-07-17-21-54)

- `backfill_image_dhashes.rb`: per-image output for small runs + timed progress with ETA (PR 4834, @mo-nathan)

## 2026-07-17 (deploy-2026-07-17-15-04)

- API2 `set_dhash` (site-admin, fill-null-only) + local-compute/API-push mode for `backfill_image_dhashes.rb` (PR 4831, @mo-nathan)

## 2026-07-17 (deploy-2026-07-17-13-16)

- Silence the deliberate `boom` backtrace `test_process_image_command_failure` dumps into every suite run (PR 4827, @mo-nathan)
- Scope `[image, :processed]` broadcasts/subscriptions to the image-show page only (PR 4830, @mo-nathan)

## 2026-07-17 (deploy-2026-07-17-11-02)

- Broadcast `Image` processing completion via Turbo Streams + `Matrix::Table` cache-key fixes (PR 4825, @mo-nathan)

## 2026-07-17 (deploy-2026-07-17-09-43)

- Supress brakeman in CI (PR 4823, @JoeCohen)
- Cache-bust image rendition URLs with an `updated_at` token in `Image::URL#source_url` (PR 4824, @mo-nathan)

## 2026-07-16 (deploy-2026-07-16-20-38)

- Fix `Components::Help`'s `element: :span` markers wrapping onto their own line (PR 4816, @nimmolo)

## 2026-07-16 (deploy-2026-07-16-13-56)

- Include unverifiable observations in confirm form counts and links (PR 4781, @JoeCohen)

## 2026-07-16 (deploy-2026-07-16-13-50)

- Bump websocket-driver from 0.8.0 to 0.8.1 (PR 4815, @app/dependabot)

## 2026-07-16 (deploy-2026-07-16-10-23)

- Close modal and flash the page on successful email send (PR 4802, @nimmolo)
- Eliminate the 3 remaining `Style/ClassVars` exceptions (PR 4801, @nimmolo)

## 2026-07-15 (deploy-2026-07-15-23-54)

- Confirm image transfers in the same run so fresh uploads don't stay `transferred=false` (PR 4814, @mo-nathan)

## 2026-07-15 (deploy-2026-07-15-19-12)

- Njw job fix (PR 4812, @mo-nathan)

## 2026-07-15 (deploy-2026-07-15-18-08)

- (#4735 PR 1/3) - port image processing to Ruby + job-ify `retransfer`/`verify`/`rotate`; fix #4791 image transfer race + implement target-design pipeline (PR 4751, @nimmolo)

## 2026-07-14 (deploy-2026-07-14-22-32)

- Fix `ImageDhashJob` racing `script/process_image`'s async resize/transfer (PR 4806, @nimmolo)

## 2026-07-14 (deploy-2026-07-14-20-05)

- Centralize field label resolution and colon-appending (`FieldLabelRow`, #4687) (PR 4805, @nimmolo)

## 2026-07-14 (deploy-2026-07-14-18-17)

- Scrub personal herbarium when anonymizing an account (Fixes #4793) (PR 4794, @mo-nathan)
- Use `Components::Localization` more widely, fix `image_vote_short` drift (PR 4803, @nimmolo)

## 2026-07-14 (deploy-2026-07-14-16-51)

- Hash the small rendition, never the full-size original (Fixes #4796) (PR 4799, @mo-nathan)

## 2026-07-14 (deploy-2026-07-14-16-31)

- Add title-backtick rule to gh PR/issue formatting doc (PR 4800, @nimmolo)
- Add `Components::Container`, centralize width-class handling (1/3: Container, Row, Column) (PR 4795, @nimmolo)
- Add `Components::Row`, sweep all direct `.row` call sites (PR 4798, @nimmolo)
- Add `Components::Column`, sweep `Grid::` and raw `col-*` literals onto it (PR 4797, @nimmolo)

## 2026-07-14 (deploy-2026-07-14-01-17)

- Block PII (emails) in GitHub publish commands via PreToolUse hook + rule (PR 4768, @mo-nathan)
- Retire dead v1 /api routes so /api* 404s instead of 500ing (Fixes #4782) (PR 4789, @mo-nathan)
- Retain a self-deleted user's content instead of destroying it (Fixes #4767) (PR 4790, @mo-nathan)
- Route remaining raw col-xs-* strings through Grid constants (#3797 prep) (PR 4776, @nimmolo)
- Delete dead BasePresenter and salvaged rules doc (PR 4786, @JoeCohen)

## 2026-07-12 (deploy-2026-07-12-21-16)

- Alert on nil box_area in UpdateBoxAreaAndCenterColumnsJob (#4780) (PR 4787, @mo-nathan)
- Port `check_rss_logs` script into 2 Solid Queue jobs, split by measured cost (PR 4733, @nimmolo)
- Retire check_for_orphaned_thumbnails (redundant with #4732; no legit error in 4+ years) (PR 4734, @nimmolo)

## 2026-07-12 (deploy-2026-07-12-18-51)

- Fix job-alert de-dup: anchor JobAlert backtrace per message (#4780) (PR 4785, @mo-nathan)

## 2026-07-12 (deploy-2026-07-12-18-16)

- Route review-worthy job output to #alerts via ApplicationJob#alert (#4780) (PR 4783, @mo-nathan)

## 2026-07-12 (deploy-2026-07-12-14-52)

- Port `check_for_broken_references` script into a Solid Queue job (PR 4732, @nimmolo)

## 2026-07-12 (deploy-2026-07-12-12-58)

- Retire repair_observation_vote_cache; refresh crontab; drop dead QueuedEmail config (PR 4728, @nimmolo)
- Port `refresh_name_lister_cache` script into a Solid Queue job (PR 4729, @nimmolo)
- Port `refresh_caches` script into 4 Solid Queue jobs, staggered by measured cost (PR 4730, @nimmolo)

## 2026-07-12 (deploy-2026-07-12-11-59)

- Fix Errno::ENOENT race reading blocked_ips.txt during rewrite (PR 4777, @mo-nathan)

## 2026-07-12 (deploy-2026-07-12-05-04)

- Fix Textile cache leak across sequential matrix-box renders and background jobs (PR 4774, @nimmolo)

## 2026-07-12 (deploy-2026-07-12-04-05)

- Add `PreToolUse` hook: auto `lang:update` before `rails test` if `en.txt` drifted (PR 4771, @nimmolo)
- Replace `report_email` test hack with Rails' own job-enqueue assertions (PR 4770, @nimmolo)

## 2026-07-12 (deploy-2026-07-12-02-39)

- Convert Textile's name-lookup cache to thread-local storage (PR 4741, @nimmolo)
- Convert Location's `names_for_unknown` cache to `i18n` lookup (PR 4744, @nimmolo)
- Convert UserGroup's meta-group caching to Rails.cache/Concurrent::Map (PR 4743, @nimmolo)
- Fix NoMethodError updating a naming with a blank name (PR 4769, @mo-nathan)
- Fix thread safety of Symbol's missing-tags and Language's tracking (PR 4745, @nimmolo)

## 2026-07-11 (deploy-2026-07-11-23-15)

- Add `Components::Modal::CloseButton`; route 5 Cancel-button sites through it (PR 4762, @nimmolo)
- Migrate 8 remaining `collapse`/`collapse in` sites onto `Collapsible`, update `Icon` API (PR 4761, @nimmolo)

## 2026-07-11 (deploy-2026-07-11-22-26)

- Recognize webp/heic uploads instead of mislabeling them "raw" (PR 4756, @nimmolo)
- Route raw navbar-*/btn classes through `Components::Navbar` constants and `Link` `button:`/`size:` kwargs (PR 4760, @nimmolo)

## 2026-07-11 (deploy-2026-07-11-18-30)

- Refuse to write to an orphaned RssLog (defuse ghost landmines) (PR 4764, @mo-nathan)

## 2026-07-11 (deploy-2026-07-11-00-15)

- Bump css_parser from 2.2.0 to 3.0.0 (PR 4758, @app/dependabot)

## 2026-07-10 (deploy-2026-07-10-19-46)

- Add variant: to Components::Navbar for the outer nav wrapper shape (PR 4736, @nimmolo)

## 2026-07-10 (deploy-2026-07-10-18-53)

- Prevent bulk-import notification floods (#4757) (PR 4759, @mo-nathan)

## 2026-07-09 (deploy-2026-07-09-22-56)

- Delete dead constant and smelly comment (PR 4671, @JoeCohen)

## 2026-07-09 (deploy-2026-07-09-22-26)

- Tweak Naming reason for misspelt name (PR 4630, @JoeCohen)

## 2026-07-09 (deploy-2026-07-09-22-22)

- Fix unimportable iconic_taxa (PR 4712, @JoeCohen)

## 2026-07-09 (deploy-2026-07-09-21-26)

- Fix handling of licensed param in URL (PR 4719, @JoeCohen)

## 2026-07-09 (deploy-2026-07-09-21-07)

- Stagger the two midnight :maintenance jobs off collision marks (PR 4746, @nimmolo)
- Rewrite Vote's `observation_views` joins in Arel (PR 4731, @nimmolo)

## 2026-07-09 (deploy-2026-07-09-20-10)

- Guard against Solid Queue thread-pool-vs-DB-pool crash (prod incident) (PR 4750, @nimmolo)

## 2026-07-09 (deploy-2026-07-09-15-06)

- .claude hooks: Run git commit before blocking a behind-branch push (PR 4742, @nimmolo)
- Remove dead `@@last_update` class variable from Language (PR 4739, @nimmolo)
- Delete `RunLevel` entirely (PR 4740, @nimmolo)
- Halt daily "reviewed observation  (insert)" (PR 4702, @JoeCohen)

## 2026-07-09 (deploy-2026-07-09-04-15)

- Fix strip_checkpoint SQL syntax error; document db/ checkpoint scripts (PR 4725, @nimmolo)
- Add Components::Navbar, InputGroup, and ButtonGroup (PR 4721, @nimmolo)
- Split Solid Queue into default + maintenance worker pools (PR 4727, @nimmolo)

## 2026-07-08 (deploy-2026-07-08-18-08)

- Rubocop 1.88.2 (PR 4724, @JoeCohen)
- Fix tracker never done (PR 4669, @JoeCohen)

## 2026-07-08 (deploy-2026-07-08-10-33)

- Make lang-tag test failures self-explanatory (PR 4723, @nimmolo)

## 2026-07-08 (deploy-2026-07-08-09-03)

- Split all Name::* module tests out of name_test.rb (#4708) (PR 4711, @nimmolo)

## 2026-07-07 (deploy-2026-07-07-21-55)

- Add (corrected) API2 error-constructor contract test lost from #4694 (PR 4718, @mo-nathan)
- DRY up observation field-slip handling; fix invalid-code path on create (PR 4715, @mo-nathan)
- Bump brakeman to 8.0.5 (PR 4698, @JoeCohen)
- Bump RuboCop to 1.88.1 (PR 4699, @JoeCohen)
- Defer field-slip creation in the add-images flow (prevent orphans) (PR 4717, @mo-nathan)

## 2026-07-06 (deploy-2026-07-06-23-12)

- Remove user_* viewer-format methods; thread user through bare methods (PR 4703, @nimmolo)

## 2026-07-06 (deploy-2026-07-06-22-14)

- Delete User.current entirely - APIKey/RssLog/SpeciesList/RtfLabels/PatternSearch + the whole mechanism (PR 4705, @nimmolo)

## 2026-07-06 (deploy-2026-07-06-17-45)

- Remove dead ActionView::LogSubscriber override (PR 4701, @mo-nathan)
- Convert Comment/Herbarium/GlossaryTerm/NameTracker/TranslationString/UserStats/LanguageExporter off User.current (PR 4700, @nimmolo)

## 2026-07-06 (deploy-2026-07-06-12-07)

- Coverage cleanup: remove dead API2::ParameterDeclaration duplicate (PR 4694, @mo-nathan)
- Remove remaining User.current reads (viewer-format) from Observation, Occurrence, Naming, Vote, Image (PR 4697, @nimmolo)

## 2026-07-06 (deploy-2026-07-06-06-25)

- Remove User.current attribution from Observation, Occurrence, Naming, Vote, Image (PR 4696, @nimmolo)

## 2026-07-06 (deploy-2026-07-06-05-15)

- Make Location display-name/place-name and sort order viewer-aware, not global (PR 4695, @nimmolo)

## 2026-07-06 (deploy-2026-07-06-02-00)

- Remove User.current from Name, NameDescription, Location, LocationDescription, and Interest (PR 4693, @nimmolo)

## 2026-07-05 (deploy-2026-07-05-23-22)

- Wrap Name::Merge#merge in a transaction; close correct_spelling race (PR 4689, @nimmolo)

## 2026-07-05 (deploy-2026-07-05-22-45)

- Cover uncovered app/models/image.rb lines; remove dead unique_format_name branch (PR 4692, @mo-nathan)
- Close remaining User.current reads in controllers/views; drop cop exemptions (PR 4688, @nimmolo)

## 2026-07-05 (deploy-2026-07-05-20-41)

- Reflection-resolution infrastructure: image dHash, iNat obs cache, reflected_at (#4585 phase 1) (PR 4677, @mo-nathan)

## 2026-07-05 (deploy-2026-07-05-20-26)

- Route bare Bootstrap col-* classes through Grid constants (#4663) (PR 4684, @nimmolo)

## 2026-07-05 (deploy-2026-07-05-19-38)

- Stop eager-loading .namings/.observations on Name show/edit/update (PR 4685, @nimmolo)

## 2026-07-05 (deploy-2026-07-05-18-41)

- Convert all Action Mailer templates from ERB to Phlex (#4676) (PR 4683, @nimmolo)

## 2026-07-05 (deploy-2026-07-05-07-09)

- Fix block_python.sh false positives; document the per-line coveralls endpoint (PR 4682, @nimmolo)
- Sidebar navbar/list-group split; ListGroup::LinkItem; language picker as inline collapse (PR 4675, @nimmolo)
- Merge Help::Block/Note into Components::Help; fix Kit-sugar gap in application_form/ (PR 4680, @nimmolo)

## 2026-07-04 (deploy-2026-07-04-22-39)

- Merge Phlex docs into phlex_reference.md; remove Views Kit-syntax extension (PR 4678, @nimmolo)

## 2026-07-04 (deploy-2026-07-04-15-26)

- Gate iNat imports on ExternalLinks; add recheck-all checkbox (PR 4665, @mo-nathan)

## 2026-07-04 (deploy-2026-07-04-07-18)

- Kit-syntax Icon sweep + Link/Tab conversions; fix stripped-icon regressions (PR 4670, @nimmolo)
- Flatten Components::ListGroup::Base to top-level ListGroup Kit component; sweep callers (PR 4672, @nimmolo)

## 2026-07-03 (deploy-2026-07-03-22-27)

- Replace hand-set Tab ids with the existing auto-derived class (PR 4661, @nimmolo)
- Sweep PaginatedResults callers to Kit syntax (PR 4668, @nimmolo)
- Fix 2 failing system tests: missing help id, stale .d-none selector (PR 4662, @nimmolo)
- location form: surface Google Maps geocode failures (#4535) (PR 4546, @nimmolo)

## 2026-07-03 (deploy-2026-07-03-22-10)

- Sweep 8 small top-level components to Kit syntax (PR 4667, @nimmolo)

## 2026-07-03 (deploy-2026-07-03-18-06)

- Persist inat_username before building imported observations (PR 4660, @mo-nathan)

## 2026-07-03 (deploy-2026-07-03-17-26)

- Fix UserStats per-field counter sign on delete (PR 4658, @mo-nathan)
- Gate SolidQueue Puma plugin to non-production (PR 4657, @mo-nathan)

## 2026-07-03 (deploy-2026-07-03-15-09)

- iNaturalist imports: one persistent record per import (PR 4644, @mo-nathan)
- Batch iNat imports and broadcast `InatImport` status via Turbo, removing `InatImportJobTracker` (PR 4632, @nimmolo)

## 2026-07-03 (deploy-2026-07-03-14-16)

- Restore Turbo on CRUD buttons; scope session-toggle opt-out narrowly (PR 4655, @nimmolo)
- Turbo Stream in-place update for reviewer export-status toggle (PR 4654, @nimmolo)

## 2026-07-03 (deploy-2026-07-03-05-46)

- Add Components::Modal dispatcher; sweep callers to Kit/dispatcher API (PR 4650, @nimmolo)
- Add variant:/identifier: props to Components::Table; sweep callers to Kit syntax (PR 4651, @nimmolo)
- Prune phlex_conversions.md: remove ERB-specific sections (PR 4649, @nimmolo)
- Sweep render(Components::Alert.new) → Alert() Kit syntax (PR 4652, @nimmolo)
- Sweep render(Components::Button.new) → Button() Kit syntax (PR 4653, @nimmolo)

## 2026-07-03 (deploy-2026-07-03-01-45)

- BS4 pre-migration cleanup: panel-title, Accordion component, table column widths (PR 4645, @nimmolo)
- Link dispatcher + Kit sweep; fix Turbo/dropdown/logout regressions (PR 4648, @nimmolo)

## 2026-07-02 (deploy-2026-07-02-15-50)

- Sweep plain(" ") → whitespace in components and views (PR 4641, @nimmolo)

## 2026-07-02 (deploy-2026-07-02-14-31)

- Fix long copyright_holder error (PR 4643, @JoeCohen)

## 2026-07-02 (deploy-2026-07-02-14-27)

- Close 3 coverage gaps (1 dead branch removed, 2 tested) (PR 4619, @mo-nathan)

## 2026-06-30 (deploy-2026-06-30-18-24)

- Glyphicon + raw button cleanup in Phlex views (PR 4623, @nimmolo)

## 2026-06-30 (deploy-2026-06-30-14-46)

- Fix nil observation_id in add_missing_views_corresponding_to_votes (PR 4600, @JoeCohen)
- Return message without throwing Error for bad /api2 root requests (PR 4612, @JoeCohen)
- Allow iNat import to match misspelled MO names by text_name (PR 4614, @JoeCohen)

## 2026-06-29 (deploy-2026-06-29-22-04)

- Fix 500 on unauthenticated request to  engine controller  (PR 4622, @JoeCohen)

## 2026-06-29 (deploy-2026-06-29-16-16)

- Drop dead skip_inat_update column; canonicalize schema.rb to production (PR 4626, @mo-nathan)

## 2026-06-29 (deploy-2026-06-29-13-14)

- Materialize MO↔iNat correspondences as typed ExternalLinks (#4565) (PR 4601, @mo-nathan)

## 2026-06-28 (deploy-2026-06-28-20-13)

- Extract Matrix::Box footer rendering into Footer module (PR 4618, @nimmolo)
- Add Grid constants for Bootstrap 3→4 column class migration (PR 4620, @nimmolo)

## 2026-06-28 (deploy-2026-06-28-13-04)

- Ignore invalid q[model] params instead of 500ing (PR 4615, @mo-nathan)
- Sweep raw target="_blank" anchors → Link::External / Link::Get (PR 4607, @nimmolo)
- Add Components::CollapseDiv; convert 6 inline collapse divs (PR 4616, @nimmolo)

## 2026-06-27 (deploy-2026-06-27-01-54)

- URL mode imports (PR 4478, @JoeCohen)

## 2026-06-26 (deploy-2026-06-26-18-26)

- Fix description show-page OOM: stop preloading all_users on public descriptions (PR 4608, @mo-nathan)
- Improvements to display of sequencing data (PR 4580, @jonkiparsky)

## 2026-06-26 (deploy-2026-06-26-17-47)

- Sweep raw glyphicon class strings → Icon components (PR 4606, @nimmolo)

## 2026-06-26 (deploy-2026-06-26-17-12)

- Refactor Map::Popup: use link components, move bbox query creation to caller (PR 4604, @nimmolo)

## 2026-06-26 (deploy-2026-06-26-11-11)

- Fix stale data-target assertions after collapse-trigger change (PR 4605, @nimmolo)

## 2026-06-26 (deploy-2026-06-26-10-55)

- Fix `InterestIcons`: one `<li>` per link (PR 4603, @nimmolo)

## 2026-06-26 (deploy-2026-06-26-10-53)

- Add pagination-strip weaving tests to PaginatedResultsTest (PR 4602, @nimmolo)

## 2026-06-26 (deploy-2026-06-26-09-29)

- Document Postfix→Gmail authenticated relay in production install (PR 4596, @mo-nathan)
- Add Link::CollapseToggle; sweep hand-rolled collapse triggers (PR 4594, @nimmolo)

## 2026-06-24 (deploy-2026-06-24-23-21)

- Extract paginated_results into Components::PaginatedResults (PR 4593, @nimmolo)

## 2026-06-24 (deploy-2026-06-24-22-18)

- Real-time Slack error alerts via exception_notification (#4595) (PR 4598, @mo-nathan)

## 2026-06-24 (deploy-2026-06-24-17-27)

- Sweep glyphicon / help-note / help-block / list-group raw class strings → Phlex components (PR 4588, @nimmolo)

## 2026-06-24 (deploy-2026-06-24-15-16)

- Bump actions/checkout from 6 to 7 (PR 4587, @app/dependabot)
- Bump nokogiri from 1.19.3 to 1.19.4 (PR 4581, @app/dependabot)
- Bump faraday from 2.14.2 to 2.14.3 (PR 4582, @app/dependabot)
- Bump concurrent-ruby from 1.3.6 to 1.3.7 (PR 4586, @app/dependabot)

## 2026-06-24 (deploy-2026-06-24-14-35)

- Fix obs-show crash on iNat import links (nil url) (PR 4590, @mo-nathan)

## 2026-06-24 (deploy-2026-06-24-04-33)

- Button component - new API and sweeping refactor (PR 4570, @nimmolo)

## 2026-06-22 (deploy-2026-06-22-21-58)

- Fix header icon/sorter regressions + flaky herbarium system test (PR 4577, @nimmolo)

## 2026-06-22 (deploy-2026-06-22-00-40)

- Add production-log route analysis scripts (PR 4573, @mo-nathan)
- Fix N+1 on observations/species_lists edit page (PR 4574, @mo-nathan)

## 2026-06-21 (deploy-2026-06-21-14-02)

- Drop Source table + source columns (#4299 phase 2) (PR 4572, @mo-nathan)

## 2026-06-21 (deploy-2026-06-21-13-54)

(no merged PRs -- asset-only or config deploy)

## 2026-06-19 (deploy-2026-06-19-21-01)

- CRUD refactor: split InfoController#textile_sandbox into GET new + POST create (PR 4569, @nimmolo)

## 2026-06-19 (deploy-2026-06-19-17-16)

- Strip provenance-only history comments from Phlex views (PR 4566, @nimmolo)

## 2026-06-19 (deploy-2026-06-19-11-39)

- Sweep content_for helpers into Views::FullPageBase per-concern modules (PR 4564, @nimmolo)

## 2026-06-18 (deploy-2026-06-18-17-15)

- Promote Descriptions::Versions::Show to Views::FullPageBase (PR 4563, @nimmolo)

## 2026-06-18 (deploy-2026-06-18-16-42)

- Rip /search/advanced (the new Advanced is the per-controller search forms) (PR 4562, @nimmolo)
- Convert application + printable layouts to Phlex (PR 4561, @nimmolo)

## 2026-06-18 (deploy-2026-06-18-00-48)

- Update the nginx.conf and README_GOOGLE_CLOUD_STORAGE (PR 4558, @mo-nathan)
- Phlex hygiene: helper sweep + layouts/header + modal title + sorter/dropdown (PR 4557, @nimmolo)
- Components folder reorg (1/2): image/ + carousel/ + form_carousel/ + link/ + button/ + form/ + Icon (PR 4559, @nimmolo)
- test infra: parallel system tests + per-worker Capybara port (PR 4523, @nimmolo)
- Components folder reorg (2/2) + Components::Carousel primitive extraction (PR 4560, @nimmolo)

## 2026-06-17 (deploy-2026-06-17-05-48)

- rubocop: wire in rubocop-capybara + rubocop-minitest (PR 4539, @nimmolo)

## 2026-06-17 (deploy-2026-06-17-00-00)

- Record iNat image provenance structurally, not in original_name (#4529) (PR 4555, @mo-nathan)

## 2026-06-16 (deploy-2026-06-16-23-38)

- Add classification provenance audit script (roadmap Phase 2) (PR 4550, @mo-nathan)
- controllers: ERB→Phlex sweep for licenses, publications, interests, support, theme, policy, info, locations (PR 4547, @nimmolo)
- controllers: ERB→Phlex for rss_logs, sequences, translations, users + observation_views turbo_stream (PR 4548, @nimmolo)

## 2026-06-16 (deploy-2026-06-16-19-39)

- iNat write-back: admin per-import checkbox (replaces env toggle) (PR 4545, @mo-nathan)
- Guard nil verified date in user profile heading (#4551) (PR 4552, @mo-nathan)
- Fix blank-line handling in observation notes (import cleanup + show display) (#4536) (PR 4537, @mo-nathan)

## 2026-06-15 (deploy-2026-06-15-22-58)

- Containerize app for local development (PR 4512, @jonkiparsky)
- Read-only iNat import audit + migration inventory (#4213) (PR 4528, @mo-nathan)
- Document: never `cd` back to the session working directory in Bash (PR 4542, @mo-nathan)
- Serve maintenance-page logo past the maintenance gate (#4312) (PR 4541, @mo-nathan)
- ERB -> Phlex: images (index / show / EXIF / emails / licenses / votes) (PR 4538, @nimmolo)

## 2026-06-15 (deploy-2026-06-15-15-12)

(no merged PRs -- asset-only or config deploy)

## 2026-06-15 (deploy-2026-06-15-15-09)

- hooks: orphan-render guard + view_context ban + Phlex view fixes (PR 4540, @nimmolo)

## 2026-06-15 (deploy-2026-06-15-13-22)

- ERB -> Phlex: herbaria (index / show / curator_table) + Table heading row (PR 4532, @nimmolo)

## 2026-06-15 (deploy-2026-06-15-11-19)

- Honor "Species Name Override" from iNat (#4533) (PR 4534, @mo-nathan)

## 2026-06-14 (deploy-2026-06-14-23-08)

- phlex guardrails: helpers ban + on-save _Any/raw/html_safe hook + TrustedHtml move (PR 4531, @nimmolo)

## 2026-06-14 (deploy-2026-06-14-21-53)

- ERB -> Phlex: contributors index + legend (PR 4526, @nimmolo)
- ERB -> Phlex: glossary_terms (index / show / form / versions / images-remove) (PR 4527, @nimmolo)

## 2026-06-14 (deploy-2026-06-14-13-18)

- claude: add Rubocop pre-commit + Coveralls post-push hooks (PR 4525, @nimmolo)
- Weight imported naming votes by source confidence (#4212) (PR 4509, @mo-nathan)

## 2026-06-14 (deploy-2026-06-14-08-44)

- admin: convert remaining ERBs in app/views/controllers/admin to Phlex (PR 4521, @nimmolo)
- articles: convert app/views/controllers/articles ERBs to Phlex (PR 4522, @nimmolo)
- test: sweep assert_template → stable element / body-class assertions (PR 4524, @nimmolo)

## 2026-06-13 (deploy-2026-06-13-21-34)

- Import observations with by-nc-sa license (PR 4520, @JoeCohen)

## 2026-06-13 (deploy-2026-06-13-15-49)

- bump mo_acts_as_versioned 0.8.0 + drop :extend blocks (PR 4515, @nimmolo)
- Fix description form double-escaping source-name HTML entities (PR 4495, @mo-nathan)
- strict_loading: extract subtrees, refetch for destroy, fix stale Location merge (PR 4518, @nimmolo)

## 2026-06-13 (deploy-2026-06-13-09-29)

- enforce strict_loading_by_default on 9 low-risk models (#4510) (PR 4513, @nimmolo)

## 2026-06-13 (deploy-2026-06-13-06-44)

- herbarium_records + collection_numbers: convert all ERBs to Phlex (PR 4507, @nimmolo)
- Phlex views: queries → controllers; ContentPadded + MatrixTable sweep; rename ObjectFooter → VersionsFooter (PR 4508, @nimmolo)

## 2026-06-11 (deploy-2026-06-11-20-26)

- Collector identity, contract release: strip notes + enforce single source (#4211) (PR 4499, @mo-nathan)

## 2026-06-11 (deploy-2026-06-11-20-07)

- Collector identity, expand release: column + backfill (invisible) (#4211) (PR 4452, @mo-nathan)

## 2026-06-11 (deploy-2026-06-11-18-01)

- projects: convert remaining ERBs under views/controllers/projects to Phlex (PR 4505, @nimmolo)

## 2026-06-11 (deploy-2026-06-11-17-37)

- account: convert every ERB under controllers/account to Phlex (PR 4503, @nimmolo)

## 2026-06-11 (deploy-2026-06-11-15-53)

- top_nav: convert search_bar ERB to Phlex + split out PatternSearchForm (PR 4502, @nimmolo)

## 2026-06-11 (deploy-2026-06-11-14-57)

- projects/list_item: drop .list-group-item wrapper, let caller supply it (PR 4504, @nimmolo)

## 2026-06-11 (deploy-2026-06-11-13-31)

- field_slips: convert all controllers/field_slips ERBs to Phlex (PR 4501, @nimmolo)

## 2026-06-11 (deploy-2026-06-11-11-51)

- Purge register_output_helper from Phlex files (most are dead/superseded) (PR 4500, @nimmolo)

## 2026-06-11 (deploy-2026-06-11-03-20)

- Accept whitespace-delimited iNat ID lists and ignore header rows (PR 4468, @JoeCohen)

## 2026-06-10 (deploy-2026-06-10-22-05)

- Index users.inat_username and users.name for collector lookups (PR 4498, @mo-nathan)

## 2026-06-10 (deploy-2026-06-10-18-32)

- observations: drop unused user: prop from 4 Phlex views (PR 4496, @nimmolo)

## 2026-06-10 (deploy-2026-06-10-17-53)

- Drop check_index_sorting test helper + its callers + docstring refs (PR 4497, @nimmolo)

## 2026-06-10 (deploy-2026-06-10-11-15)

- Components::Map: consolidate make_map + helpers into one component (PR 4489, @nimmolo)

## 2026-06-10 (deploy-2026-06-10-00-33)

- Fix Name show panels rendering HTML entity codes instead of characters (#4491) (PR 4494, @mo-nathan)

## 2026-06-10 (deploy-2026-06-10-00-03)

- Bump net-imap from 0.6.4 to 0.6.4.1 (PR 4490, @app/dependabot)
- Bump puma from 8.0.1 to 8.0.2 (PR 4487, @app/dependabot)
- Fix advanced search: JSON-encode Stimulus Array values in top_nav (#4492) (PR 4493, @mo-nathan)

## 2026-06-09 (deploy-2026-06-09-18-50)

- Add request-scoped current_user + current_query helpers for Phlex views (PR 4488, @nimmolo)

## 2026-06-09 (deploy-2026-06-09-18-47)

- Phlexify observations/index + fix the MatrixBox cache pre-check (PR 4483, @nimmolo)

## 2026-06-08 (deploy-2026-06-08-22-17)

- Allow Name citation to be clickable link (PR 4486, @JoeCohen)

## 2026-06-08 (deploy-2026-06-08-15-20)

- Phlexify all remaining form-rendering ERBs under /observations (PR 4482, @nimmolo)

## 2026-06-08 (deploy-2026-06-08-15-00)

- Move context_nav into layout homes; phlexify top_nav; add Components::Dropdown (PR 4481, @nimmolo)

## 2026-06-08 (deploy-2026-06-08-12-05)

- Merge nimmo-phlexify-namings-domain into main (brings #4460's Phlex header + 12 other commits) (PR 4480, @nimmolo)

## 2026-06-08 (deploy-2026-06-08-11-11)

- Project.admin_power? requires the obs owner to be a trusting member (#4439) (PR 4446, @mo-nathan)

## 2026-06-08 (deploy-2026-06-08-05-34)

- species_lists/index + listing: use Components::ListGroup (PR 4476, @nimmolo)
- phlex.rb: drop dead Tabs::*Helper auto-include block (PR 4479, @nimmolo)

## 2026-06-08 (deploy-2026-06-08-04-33)

- Index sort options: hoist to controllers; delete 13 helpers (PR 4477, @nimmolo)

## 2026-06-08 (deploy-2026-06-08-02-13)

- Add script/coveralls_pr_check.py: per-file PR coverage checker (PR 4475, @nimmolo)
- Phlexify all remaining /names ERB views (incl. index) (PR 4474, @nimmolo)

## 2026-06-08 (deploy-2026-06-08-01-58)

- Body class: map create→new, update→edit (template-rendered, not action) (PR 4472, @nimmolo)
- NoAnyPhlexPropsTest: scan multi-line props with a paren stack (PR 4473, @nimmolo)

## 2026-06-08 (deploy-2026-06-08-00-15)

- Phlexify Names::Show + NamesHelper chain into Tab POROs + 3 Collections (PR 4469, @nimmolo)
- Sweep _Any prop violations + add regression guard test (PR 4471, @nimmolo)

## 2026-06-07 (deploy-2026-06-07-23-10)

(no merged PRs -- asset-only or config deploy)

## 2026-06-07 (deploy-2026-06-07-22-53)

- Improve coverage post deploy-2026-06-05-18-07 (PR 4453, @JoeCohen)
- Workflow requesting Copilot review on nimmolo's PRs (PR 4461, @JoeCohen)
- Bump rubocop-rails to 2.35.4 (PR 4463, @JoeCohen)

## 2026-06-06 (deploy-2026-06-06-11-41)

(no merged PRs -- asset-only or config deploy)

## 2026-06-06 (deploy-2026-06-06-08-20)

- Phlexify comments-for-object panel + comment row; broadcasts render Phlex (PR 4456, @nimmolo)
- Move AccountPreferencesForm into Account::Preferences::Form namespace (PR 4457, @nimmolo)

## 2026-06-06 (deploy-2026-06-06-06-14)

- Phlexify the obs-show namings sub-panel + Votes::Form + Components::ListGroup (PR 4455, @nimmolo)

## 2026-06-06 (deploy-2026-06-06-05-48)

- Fix Use assert_nil if expecting nil (PR 4451, @JoeCohen)
- Sweep Components::Base helper registrations + absorb InternalLink into Tab (PR 4454, @nimmolo)

## 2026-06-05 (deploy-2026-06-05-18-07)

- Phlexify descriptions/ views folder; delete description + version helpers (PR 4449, @nimmolo)

## 2026-06-05 (deploy-2026-06-05-01-01)

- Phlex views: replace _Any / vague Array+Hash prop types with concrete types (PR 4448, @nimmolo)

## 2026-06-05 (deploy-2026-06-05-00-01)

- obs/show: convert all sub-partials to Phlex + extract Components::InlineModLinks (PR 4444, @nimmolo)

## 2026-06-04 (deploy-2026-06-04-15-03)

- Fix field slip editing when project prefix added after creation (#4436) (PR 4441, @mo-nathan)
- Add Field Slips sub-tab to project Admin tab (#4442) (PR 4445, @mo-nathan)

## 2026-06-04 (deploy-2026-06-04-13-05)

(no merged PRs -- asset-only or config deploy)

## 2026-06-04 (deploy-2026-06-04-12-09)

(no merged PRs -- asset-only or config deploy)

## 2026-06-04 (deploy-2026-06-04-10-41)

(no merged PRs -- asset-only or config deploy)

## 2026-06-04 (deploy-2026-06-04-00-43)

(no merged PRs -- asset-only or config deploy)

## 2026-06-04 (deploy-2026-06-04-00-24)

(no merged PRs -- asset-only or config deploy)

## 2026-06-03 (deploy-2026-06-03-23-38)

(no merged PRs -- asset-only or config deploy)

## 2026-06-03 (deploy-2026-06-03-22-04)

(no merged PRs -- asset-only or config deploy)

## 2026-06-03 (deploy-2026-06-03-21-11)

(no merged PRs -- asset-only or config deploy)

## 2026-06-03 (deploy-2026-06-03-15-29)

(no merged PRs -- asset-only or config deploy)

## 2026-06-02 (deploy-2026-06-02-18-19)

(no merged PRs -- asset-only or config deploy)

## 2026-06-02 (deploy-2026-06-02-17-53)

(no merged PRs -- asset-only or config deploy)

## 2026-06-02 (deploy-2026-06-02-17-27)

- Drop cross-form vestigial logic in description merge/move forms; close namings form coverage gap (PR 4420, @mo-nathan)

## 2026-06-02 (deploy-2026-06-02-00-48)

(no merged PRs -- asset-only or config deploy)

## 2026-06-01 (deploy-2026-06-01-13-15)

- Tab POROs leaves: convert general_helper + related_objects_helper (PR 4409, @nimmolo)
- Tab POROs: convert locations + locations/descriptions (PR 4412, @nimmolo)
- Tab POROs: convert names + names/descriptions (action tabs + 3 cross-domain externals) (PR 4411, @nimmolo)
- Tab POROs: convert observations (15 single Tabs + 12 Collections) (PR 4413, @nimmolo)

## 2026-05-31 (deploy-2026-05-31-23-34)

- Fix prod 500: SearchController#pattern fallthrough when session return-to set (PR 4407, @nimmolo)
- Tab POROs: convert herbaria domain (5 Tabs + 5 Collections + 4 ERB shims) (PR 4408, @nimmolo)

## 2026-05-31 (deploy-2026-05-31-14-29)

- Tab POROs: convert species_lists domain (PR 4405, @nimmolo)
- Fix 2 system test failures (external_link helper + autocompleter wait) (PR 4406, @nimmolo)

## 2026-05-31 (deploy-2026-05-31-13-25)

- Foundational Tab POROs; convert Project domain (PR 4404, @nimmolo)

## 2026-05-31 (deploy-2026-05-31-11-43)

- Rubocop 1.87.0 (PR 4399, @JoeCohen)
- visual_groups: convert edit.html.erb to Phlex (PR 4398, @nimmolo)
- link_helper: extract icon_link_to + link_icon into Phlex components (PR 4400, @nimmolo)
- Components::Table: add row + body modes, explicit attributes hash; convert 5 Phlex tables (PR 4402, @nimmolo)
- link_helper: extract modal_link_to + external_link + active_link_to into Phlex components (PR 4401, @nimmolo)
- Add Components::NavTabs; convert project tab bars to use it (PR 4403, @nimmolo)

## 2026-05-30 (deploy-2026-05-30-11-34)

(no merged PRs -- asset-only or config deploy)

## 2026-05-30 (deploy-2026-05-30-11-23)

(no merged PRs -- asset-only or config deploy)

## 2026-05-29 (deploy-2026-05-29-11-34)

(no merged PRs -- asset-only or config deploy)

## 2026-05-29 (deploy-2026-05-29-11-29)

(no merged PRs -- asset-only or config deploy)

## 2026-05-29 (deploy-2026-05-29-10-44)

(no merged PRs -- asset-only or config deploy)

## 2026-05-29 (deploy-2026-05-29-00-19)

(no merged PRs -- asset-only or config deploy)

## 2026-05-28 (deploy-2026-05-28-02-12)

(no merged PRs -- asset-only or config deploy)

## 2026-05-28 (deploy-2026-05-28-01-37)

- Bump rubocop-rails to 2.35.3 (PR 4383, @JoeCohen)

## 2026-05-27 (deploy-2026-05-27-16-29)

(no merged PRs -- asset-only or config deploy)

## 2026-05-27 (deploy-2026-05-27-00-56)

(no merged PRs -- asset-only or config deploy)

## 2026-05-26 (deploy-2026-05-26-16-15)

(no merged PRs -- asset-only or config deploy)

## 2026-05-26 (deploy-2026-05-26-16-10)

(no merged PRs -- asset-only or config deploy)

## 2026-05-26 (deploy-2026-05-26-16-03)

(no merged PRs -- asset-only or config deploy)

## 2026-05-26 (deploy-2026-05-26-14-40)

(no merged PRs -- asset-only or config deploy)

## 2026-05-26 (deploy-2026-05-26-11-10)

(no merged PRs -- asset-only or config deploy)

## 2026-05-26 (deploy-2026-05-26-10-16)

(no merged PRs -- asset-only or config deploy)

## 2026-05-25 (deploy-2026-05-25-13-57)

- glossary_terms: move 2 forms to Views/ (PR 4342, @nimmolo)
- herbaria: move 2 forms to Views/ (PR 4343, @nimmolo)

## 2026-05-24 (deploy-2026-05-24-12-07)

- ModalTurboForm: look up form class via caller's controller_path (PR 4330, @nimmolo)
- sequences: move SequenceForm to Views/ (PR 4329, @nimmolo)
- collection_numbers: move CollectionNumberForm to Views/ (PR 4332, @nimmolo)
- field_slips: move FieldSlipForm to Views/ (PR 4333, @nimmolo)
- herbarium_records: move HerbariumRecordForm to Views/ (PR 4334, @nimmolo)
- publications: move PublicationForm to Views/ (PR 4335, @nimmolo)
- users/emails: move UserQuestionForm to Views/ (PR 4336, @nimmolo)
- translations: move TranslationForm to Views/ (PR 4337, @nimmolo)
- visual_groups: move VisualGroupForm to Views/ (PR 4338, @nimmolo)
- visual_models: move VisualModelForm to Views/ (PR 4339, @nimmolo)
- info: move TextileSandboxForm to Views/ (PR 4340, @nimmolo)
- licenses: move LicenseForm to Views/ (PR 4341, @nimmolo)

## 2026-05-24 (deploy-2026-05-24-10-15)

- Fix map cluster Show All returning nothing for shared-location observations (PR 4319, @mo-nathan)
- Inline filter form component + visual_groups filter refactor (PR 4320, @nimmolo)
- Phlex conversion rule: views/ vs components/ (PR 4324, @nimmolo)
- account/api_keys: Phlex edit/new views + Table component on index + activate-URL fix (PR 4321, @nimmolo)
- comments: move CommentForm to Views/; fix ModalTurboForm lookup + form-id derivation (PR 4328, @nimmolo)
- articles: move ArticleForm to Views/ (PR 4327, @nimmolo)
- images/licenses/edit: ERB → Phlex with FormObject (PR 4323, @nimmolo)

## 2026-05-22 (deploy-2026-05-22-19-35)

- Fix Name footer showing creator instead of last editor (PR 4257, @JoeCohen)

## 2026-05-21 (deploy-2026-05-21-19-04)

- Project + species_list membership, `ImagesEditForm` Phlex (PR 4315, @nimmolo)

## 2026-05-21 (deploy-2026-05-21-19-01)

- Fix and DRY `page_title` / `document_title` methods (PR 4317, @nimmolo)

## 2026-05-21 (deploy-2026-05-21-16-19)

- Replace top-nav [+] with green [+ Add] button (Fixes #3930) (PR 4302, @mo-nathan)
- Fix target-location Create-link flow in violations modal (Fixes #4304) (PR 4307, @mo-nathan)
- Maintenance page during deploy + restyle 404/422/500 with Amanita theme (PR 4313, @mo-nathan)

## 2026-05-21 (deploy-2026-05-21-08-45)

- SpeciesListForm: Phlex Superform replacing species_lists/_form.html.erb (PR 4310, @nimmolo)

## 2026-05-20 (deploy-2026-05-20-22-50)

- hidden_field: route both paths through HiddenField (PR 4314, @nimmolo)

## 2026-05-20 (deploy-2026-05-20-17-04)

- Fix map_controller race: openMap can fire before google.maps loads (PR 4311, @nimmolo)

## 2026-05-20 (deploy-2026-05-20-13-49)

- Stabilize Checklist::Contents coverage (seed-dependent line 72) (PR 4301, @mo-nathan)
- Delete Components::AddObsModal — controller renders Modal via Phlex view (PR 4300, @nimmolo)
- Modal: knobs for header/controller/body_class; refactor Confirm + Spinner (PR 4303, @nimmolo)
- Bump rubocop-rails to 2.35.2 (PR 4309, @JoeCohen)
- OccurrenceResolveForm: render via Modal :form_content slot (restore .modal-footer) (PR 4294, @nimmolo)

## 2026-05-19 (deploy-2026-05-19-10-07)

- TrustSettingsForm: Superform + render via ModalTurboForm (PR 4292, @nimmolo)
- TargetLocationForm: extract from ProjectViolationsForm + namespace under project[...] (PR 4296, @nimmolo)

## 2026-05-18 (deploy-2026-05-18-22-23)

- bundle update for May 18, 2026 (PR 4298, @mo-nathan)

## 2026-05-18 (deploy-2026-05-18-18-36)

- Bump faraday from 2.14.1 to 2.14.2 (PR 4295, @app/dependabot)

## 2026-05-18 (deploy-2026-05-18-13-33)

- Speed up Project show: memoize visible obs + widen show_includes (PR 4289, @mo-nathan)

## 2026-05-18 (deploy-2026-05-18-10-22)

- Test sweep: assert_match-on-HTML → selector assertions + catch-up coverage (PR 4291, @nimmolo)
- Components::Modal: add :form_content slot for form-wrapped body+footer (PR 4293, @nimmolo)

## 2026-05-18 (deploy-2026-05-18-00-48)

- Fix CheckboxField block-mode label association (#4286) (PR 4287, @mo-nathan)
- Coverage catch-up: ButtonStyleRadio + ImagesToRemoveForm + RadioField append-Proc (PR 4282, @nimmolo)
- Fix BS3 modal unclickable at narrow viewports (drop translate3d hack) (PR 4290, @nimmolo)
- project_violations: route radios through RadioField (PR 4277, @nimmolo)
- Convert field-slip form to Phlex (using FormNotes) (PR 4270, @nimmolo)
- OccurrenceResolveForm: Superform + drop OccurrenceResolveModal wrapper (PR 4279, @nimmolo)
- Activity-log filters: ButtonStyleCheckbox + caption fix + UX cleanup (PR 4276, @nimmolo)

## 2026-05-17 (deploy-2026-05-17-16-11)

- Fix OccurrenceResolveForm Add All submission (#4284) (PR 4285, @mo-nathan)

## 2026-05-17 (deploy-2026-05-17-14-54)

- RadioField: per-choice opts (disabled / append / label_block) (PR 4281, @nimmolo)
- Jdc rubocop 1 86 2 (PR 4283, @JoeCohen)

## 2026-05-17 (deploy-2026-05-17-12-18)

- Get all system tests green, fix "create herbarium on the fly" modal in create obs form (PR 4280, @nimmolo)

## 2026-05-17 (deploy-2026-05-17-11-30)

- Extract Components::Modal, rename ModalForm -> ModalTurboForm (PR 4278, @nimmolo)

## 2026-05-17 (deploy-2026-05-17-09-55)

- Convert images-to-remove form to Phlex (PR 4271, @nimmolo)

## 2026-05-17 (deploy-2026-05-17-00-29)

- Drop dead naming_form_reasons_* helpers (PR 4273, @nimmolo)
- Convert api-keys verified indicator to Phlex CheckboxField (PR 4272, @nimmolo)
- FormCarousel: real `thumb_image_id` radio + CSS-only active state (PR 4274, @nimmolo)
- Carousel thumb button: theme-aware active state (PR 4275, @nimmolo)

## 2026-05-16 (deploy-2026-05-16-10-49)

- Extract Components::FormNotes (shared Panel + notes textareas) (PR 4269, @nimmolo)

## 2026-05-15 (deploy-2026-05-15-19-28)

- Switch report rows from positional to named columns (#3637) (PR 4237, @mo-nathan)
- Imported-source banner + new-tab credit links (PR 4235, @mo-nathan)

## 2026-05-15 (deploy-2026-05-15-15-39)

- Fix more ERB↔Phlex form helper divergences (10 fixes) (PR 4268, @nimmolo)

## 2026-05-15 (deploy-2026-05-15-09-51)

- `number_field` & `password_field`: ERB/Phlex parity (PR 4267, @nimmolo)

## 2026-05-14 (deploy-2026-05-14-23-19)

- ERB/Phlex form-helper parity nits (issue #4258 items 0 + 5) (PR 4259, @nimmolo)
- Form labels: emit matching for= attrs across Phlex + ERB (PR 4261, @nimmolo)
- Rename ERB `hidden_field_with_label` → `read_only_field_with_label` (PR 4262, @nimmolo)
- TextareaField: honor monospace at component level (PR 4265, @nimmolo)
- Phlex form helpers honor `prefs: true` (PR 4266, @nimmolo)
- Occurrence forms: Rails-native Superform via AR-model nesting (group C of #4225) (PR 4250, @nimmolo)

## 2026-05-14 (deploy-2026-05-14-15-40)

- Fix Superform 0.7.0 attributes: keyword deprecation (PR 4260, @JoeCohen)

## 2026-05-14 (deploy-2026-05-14-10-36)

- Native text-year date helper; remove year-input Stimulus controller (PR 4255, @nimmolo)

## 2026-05-13 (deploy-2026-05-13-23-24)

- Align ERB and Phlex autocompleter HTML emission (PR 4253, @nimmolo)
- Add updated encoded credentials (PR 4251, @mo-nathan)
- Fix Phlex `SelectField` `option` with nil key (PR 4254, @nimmolo)

## 2026-05-12 (deploy-2026-05-12-21-48)

- Add assert_html_element_equivalent helper to ComponentTestCase (PR 4246, @nimmolo)
- Switch `superform` from @nimmolo's fork to upstream ~> 0.7.0 (PR 4247, @nimmolo)

## 2026-05-12 (deploy-2026-05-12-21-33)

- Enable bare select for superform `SelectField` (group B of #4225) (PR 4245, @nimmolo)

## 2026-05-11 (deploy-2026-05-11-12-00)

- Replace hand-rolled form inputs with helpers / FieldProxy (group A of #4225) (PR 4236, @nimmolo)

## 2026-05-11 (deploy-2026-05-11-10-46)

- Tolerate nil iNat credentials at module load (PR 4240, @mo-nathan)
- Skip ConfigTest#test_secrets when credentials cannot decrypt (PR 4242, @mo-nathan)
- Fix typo (PR 4239, @jonkiparsky)
- Make test setup resets unbypassable (#4238) (PR 4243, @mo-nathan)
- Fix undefined method error in sibling_sequences archive link (PR 4244, @mo-nathan)

## 2026-05-09 (deploy-2026-05-09-17-09)

- Keep synonym-only-observed targets in Unobserved (Fixes #4152) (PR 4204, @mo-nathan)
- Per-worker email-debug.log to fix parallel test pollution (PR 4233, @mo-nathan)
- Sources table + external_id migration for imported observations (PR 4230, @mo-nathan)

## 2026-05-08 (deploy-2026-05-08-18-08)

- Bump nokogiri from 1.19.2 to 1.19.3 (PR 4229, @app/dependabot)
- Bump css_parser from 1.21.1 to 2.1.0 (PR 4228, @app/dependabot)
- Harden iNat import against duplicates and back-link leak (PR 4223, @mo-nathan)

## 2026-05-07 (deploy-2026-05-07-22-58)

- Phlex `ProjectForm` - use `radio_field` helper for `dates_any` toggle (PR 4224, @nimmolo)
- Remove misleading field.hidden alias on ApplicationForm::Field (PR 4227, @nimmolo)
- Un-pin gem `mini-racer` (PR 4222, @nimmolo)

## 2026-05-05 (deploy-2026-05-05-19-31)

- Bump net-imap from 0.5.12 to 0.5.14 (PR 4207, @app/dependabot)

## 2026-05-04 (deploy-2026-05-04-21-01)

- Map iNat monomial complexes to MO Group names with parent genus (PR 4196, @JoeCohen)
- Prevent creation of non-fungi/slime-mold MO Names from iNat identification taxa (PR 4200, @JoeCohen)

## 2026-05-04 (deploy-2026-05-04-18-16)

- Cleanup project Summary tab (Fixes #4148) (PR 4199, @mo-nathan)

## 2026-05-02 (deploy-2026-05-02-16-47)

- Cleanup project locations tab (Fixes #4147) (PR 4193, @mo-nathan)

## 2026-05-02 (deploy-2026-05-02-12-46)

- Close coverage gaps from PRs #4191 and #4153 (PR 4192, @mo-nathan)
- Distinguish Site Admin from Project Admin (Fixes #4145) (PR 4188, @mo-nathan)

## 2026-05-01 (deploy-2026-05-01-20-30)

- Njw 4136 expand violations (PR 4191, @mo-nathan)

## 2026-05-01 (deploy-2026-05-01-20-20)

- Drop step 4 of name lookup; rely on classification data (#4154) (PR 4156, @mo-nathan)
- Obscure GPS in MyCoPortal export for gps_hidden observations (PR 4186, @JoeCohen)
- Include sub-taxa in project target-name matching (Fixes #4130) (PR 4153, @mo-nathan)
- Convert project target_names / target_locations widgets to Phlex (PR 4185, @mo-nathan)

## 2026-04-28 (deploy-2026-04-28-18-03)

- Smart Name version browser + audit Phase 2 versioning (#4166) (PR 4168, @mo-nathan)

## 2026-04-28 (deploy-2026-04-28-13-11)

- Repair + alert for stale observation vote_cache (#4171) (PR 4172, @mo-nathan)

## 2026-04-27 (deploy-2026-04-27-21-37)

- Suppress expected logger noise in safe_done test (PR 4164, @JoeCohen)
- Limit Add My Observations to 100 per click with count preview (PR 4135, @mo-nathan)

## 2026-04-27 (deploy-2026-04-27-18-37)

- Add missing indexes for slow queries surfaced by 2026-04-27 outage (PR 4177, @mo-nathan)

## 2026-04-27 (deploy-2026-04-27-10-54)

- Remove user_stats.checklist cache (PR 4146, @mo-nathan)

## 2026-04-26 (deploy-2026-04-26-14-41)

- Fix stuck InatImport when worker crashes (PR 4122, @JoeCohen)

## 2026-04-26 (deploy-2026-04-26-13-44)

- Phlexicize print labels (PR 4030, @JoeCohen)

## 2026-04-26 (deploy-2026-04-26-11-29)

- Map clustering + GPS trust fixes (#4159) (PR 4162, @mo-nathan)

## 2026-04-24 (deploy-2026-04-24-23-51)

- Fix MCP data report for GBIF (PR 4104, @JoeCohen)
- Fix MCP image report for GBIF (PR 4116, @JoeCohen)

## 2026-04-22 (deploy-2026-04-22-21-27)

- Cleanup name reporting on project checklist tab (PR 4138, @mo-nathan)
- Map popups: thumbnail + taxon + date + confidence; colored markers (PR 4140, @mo-nathan)

## 2026-04-22 (deploy-2026-04-22-21-07)

- Prevent duplicate comments and close modal reliably (PR 4132, @mo-nathan)

## 2026-04-21 (deploy-2026-04-21-12-23)

- Fix flaky herbarium-record create test (PR 4150, @mo-nathan)
- Bump erb gem to 6.0.4 (PR 4151, @JoeCohen)

## 2026-04-20 (deploy-2026-04-20-22-16)

- Show Location edit icon to any logged-in user (PR 4149, @mo-nathan)

## 2026-04-20 (deploy-2026-04-20-18-14)

- Project excluded_observations list and Exclude buttons (PR 4137, @mo-nathan)

## 2026-04-20 (deploy-2026-04-20-15-52)

- Fix fill in missing ranks (PR 4143, @JoeCohen)

## 2026-04-17 (deploy-2026-04-17-21-11)

- Remove duplicate text/html from nginx gzip_types (PR 4133, @mo-nathan)
- Fix add space between Name ranks (PR 4090, @JoeCohen)

## 2026-04-16 (deploy-2026-04-16-18-48)

- Group sub-locations under target locations (PR 4127, @mo-nathan)

## 2026-04-16 (deploy-2026-04-16-13-58)

- Opt into CodeQL file coverage on PRs via advanced setup workflow (PR 4096, @app/copilot-swe-agent)
- Fix blank images in matrix box after upload (PR 4124, @mo-nathan)

## 2026-04-14 (deploy-2026-04-14-11-59)

- Add running job check to deploy script (PR 4120, @mo-nathan)

## 2026-04-14 (deploy-2026-04-14-11-45)

- Rubocop 1 86 1 (PR 4121, @JoeCohen)

## 2026-04-11 (deploy-2026-04-11-19-52)

- Show project banner on observation index from query params (PR 4110, @mo-nathan)

## 2026-04-11 (deploy-2026-04-11-19-10)

- Fix N+1 queries on project updates index page (PR 4109, @mo-nathan)

## 2026-04-11 (deploy-2026-04-11-18-36)

- Optimize exclude_non_primary scope for large projects (PR 4108, @mo-nathan)

## 2026-04-11 (deploy-2026-04-11-17-28)

- Add target names/locations data model for Rare Fungi Challenges (PR 4101, @mo-nathan)

## 2026-04-10 (deploy-2026-04-10-13-02)

- Convert Project ERB views to Phlex components (PR 4084, @mo-nathan)

## 2026-04-10 (deploy-2026-04-10-12-53)

- Simplify iNat import source credit label (PR 4105, @mo-nathan)

## 2026-04-08 (deploy-2026-04-08-13-15)

- Bump addressable from 2.8.9 to 2.9.0 (PR 4103, @app/dependabot)

## 2026-04-08 (deploy-2026-04-08-03-15)

- Bump rack-session from 2.1.1 to 2.1.2 (PR 4102, @app/dependabot)

## 2026-04-07 (deploy-2026-04-07-16-27)

- Revive Exports to MyCoPortal (PR 4034, @JoeCohen)

## 2026-04-06 (deploy-2026-04-06-21-29)

- Bump github actions/checkout from v4 to v6 (PR 4089, @JoeCohen)
- Bump trilogy from 2.11.1 to 2.12.3 (PR 4093, @app/dependabot)

## 2026-04-06 (deploy-2026-04-06-19-04)

- Fix vote_cache display to apply sub-max boost consistently (PR 4071, @mo-nathan)
- Bump minitest-reporters from 1.7.1 to 1.8.0 (PR 4094, @app/dependabot)
- Add Occurrence model and migration (#3808) (PR 3988, @mo-nathan)

## 2026-04-02 (deploy-2026-04-02-23-09)

- Bump rack from 3.1.20 to 3.1.21 (PR 4083, @app/dependabot)

## 2026-04-02 (deploy-2026-04-02-18-30)

- Enable hot-reloading for Phlex view components (PR 4079, @mo-nathan)
- Fix false name warning in field slip Add Images workflow (PR 4081, @mo-nathan)
- Convert projects forms to Phlex component (PR 4076, @mo-nathan)

## 2026-04-02 (deploy-2026-04-02-17-29)

- Upgrade Ruby from 3.3.6 to 3.4.9 (PR 4074, @mo-nathan)

## 2026-04-01 (deploy-2026-04-01-14-57)

- Fix awkward grammar in iNat import confirmation explanation (PR 3993, @app/copilot-swe-agent)
- Bump rubocop from 1.85.1 to 1.86.0 (PR 4069, @app/dependabot)
- Fix prawn-svg deprecation warning (PR 4070, @mo-nathan)
- Import only licensed stuff (PR 3992, @JoeCohen)

## 2026-03-30 (deploy-2026-03-30-02-05)

- Bump google-cloud-storage from 1.58.0 to 1.59.0 (PR 4068, @app/dependabot)

## 2026-03-30 (deploy-2026-03-30-02-03)

- Bump terser from 1.2.6 to 1.2.7 (PR 4067, @app/dependabot)

## 2026-03-28 (deploy-2026-03-28-18-03)

- Validate iNat ExternalLink entire URL (PR 4066, @JoeCohen)

## 2026-03-28 (deploy-2026-03-28-03-43)

- Bump mcp from 0.8.0 to 0.9.2 (PR 4063, @app/dependabot)

## 2026-03-27 (deploy-2026-03-27-23-53)

- Resume adding external links to imports. (PR 4064, @JoeCohen)

## 2026-03-26 (deploy-2026-03-26-22-26)

- Bump Trilogy to 2.11.1 (PR 4059, @JoeCohen)

## 2026-03-25 (deploy-2026-03-25-14-22)

- Clear connection after fork (PR 4057, @JoeCohen)

## 2026-03-23 (deploy-2026-03-23-03-12)

- Bump webmock from 3.26.1 to 3.26.2 (PR 4052, @app/dependabot)
- Bump solid_queue from 1.3.2 to 1.4.0 (PR 4053, @app/dependabot)
- Bump trilogy from 2.10.0 to 2.11.0 (PR 4054, @app/dependabot)

## 2026-03-19 (deploy-2026-03-19-19-01)

- Bump bcrypt from 3.1.21 to 3.1.22 (PR 4047, @app/dependabot)

## 2026-03-19 (deploy-2026-03-19-13-04)

- Bump json from 2.18.1 to 2.19.2 (PR 4044, @app/dependabot)

## 2026-03-19 (deploy-2026-03-19-00-19)

- Bump loofah from 2.25.0 to 2.25.1 (PR 4043, @app/dependabot)

## 2026-03-17 (deploy-2026-03-17-18-48)

- Add missing database indexes and optimize checklist query (PR 4039, @mo-nathan)

## 2026-03-16 (deploy-2026-03-16-14-31)

- Fix just-created record test bug (PR 4029, @JoeCohen)
- Bump prawn-svg from 0.38.1 to 0.40.0 (PR 4037, @app/dependabot)
- Bump fastimage from 2.4.0 to 2.4.1 (PR 4038, @app/dependabot)

## 2026-03-13 (deploy-2026-03-13-02-19)

- Guard against nil user in Inat::Taxon#create_mo_name (PR 3977, @app/copilot-swe-agent)
- Fix grammar in inat/taxon.rb comment (PR 4003, @app/copilot-swe-agent)
- Fix flaky license create test (PR 4027, @JoeCohen)
- Document Phlex view patterns, form gotchas, and testing strategies (PR 4001, @mo-nathan)
- Add missing Name at supported rank (PR 3975, @JoeCohen)

## 2026-03-11 (deploy-2026-03-11-13-20)

- Phlexicize account profile form (PR 3994, @JoeCohen)

## 2026-03-11 (deploy-2026-03-11-12-13)

- Add `log` param to Name API, fix silent save failures in `save_parents` (PR 4008, @app/copilot-swe-agent)
- Revert "Add `log` param to Name API, fix silent save failures in `save_parents`" (PR 4011, @JoeCohen)
- Log creation of a Name via the API (PR 4007, @JoeCohen)

## 2026-03-09 (deploy-2026-03-09-11-15)

- Convert identify filter form to Phlex, remove orphaned naming ERB (PR 3989, @mo-nathan)

## 2026-03-09 (deploy-2026-03-09-01-59)

- Bump sorted_set from 1.0.3 to 1.1.0 (PR 4000, @app/dependabot)

## 2026-03-08 (deploy-2026-03-08-20-48)

- Fix thumbnail not reassigned when removed via edit form (PR 3996, @mo-nathan)

## 2026-03-07 (deploy-2026-03-07-13-43)

- Fix location.rb metrics offenses (PR 3990, @JoeCohen)

## 2026-03-07 (deploy-2026-03-07-10-38)

- Reverse FieldSlip-Observation relationship (PR 3986, @mo-nathan)

## 2026-03-06 (deploy-2026-03-06-22-08)

- Fix flaky MailDeliveryErrorLoggingTest in parallel runs (PR 3963, @mo-nathan)
- Bump rubocop to 1.85.1 (PR 3976, @JoeCohen)
- Standardize CLAUDE.md with init-style structure (PR 3973, @mo-nathan)
- Exclude projects/ directory from RuboCop (PR 3987, @mo-nathan)
- Ignore iNat non-myxo protozoa (PR 3944, @JoeCohen)

## 2026-03-02 (deploy-2026-03-02-22-21)

- Fix parameter shadowing in `OneOrTheOther#initialize` (PR 3957, @app/copilot-swe-agent)
- Fix file descriptor leak in UploadFromFile (PR 3958, @app/copilot-swe-agent)
- Fix NoMethodError: use `NodeSet#to_s` instead of `NodeSet#join` in session form extensions (PR 3959, @app/copilot-swe-agent)
- Fix NoMethodError from Style/MapJoin autocorrect on Nokogiri NodeSet (PR 3960, @app/copilot-swe-agent)
- Bump rubocop to 1.85.0 (PR 3956, @JoeCohen)
- Fix count for all superimporter's iNat observations (PR 3972, @JoeCohen)

## 2026-03-02 (deploy-2026-03-02-20-36)

- Fix missing review widgets on Help Identify page (PR 3962, @mo-nathan)

## 2026-03-02 (deploy-2026-03-02-15-02)

- Bump literal from 1.8.1 to 1.9.0 (PR 3967, @app/dependabot)

## 2026-03-02 (deploy-2026-03-02-14-59)

- Bump prawn-manual_builder from 0.3.1 to 0.5.0 (PR 3964, @app/dependabot)

## 2026-02-28 (deploy-2026-02-28-14-19)

- Bump brakeman to 8.0.4 (PR 3955, @JoeCohen)
- Fix superimporter preview estimate (PR 3946, @JoeCohen)

## 2026-02-24 (deploy-2026-02-24-23-38)

- Fix TOCTOU race condition in MailDeliveryErrorLoggingTest (PR 3952, @app/copilot-swe-agent)
- Fix order-dependent mail delivery test failure (PR 3951, @JoeCohen)
- Fix order-dependent translation test failure (PR 3950, @JoeCohen)
- Phlex ProjectViolations form (PR 3929, @JoeCohen)

## 2026-02-23 (deploy-2026-02-23-19-30)

- Convert Translation Edit form to Phlex (PR 3938, @JoeCohen)

## 2026-02-23 (deploy-2026-02-23-19-25)

- Bump solid_queue from 1.3.1 to 1.3.2 (PR 3947, @app/dependabot)

## 2026-02-22 (deploy-2026-02-22-09-58)

- 3852 remove queuedemail references (PR 3853, @JoeCohen)

## 2026-02-21 (deploy-2026-02-21-11-54)

- Enable raise_delivery_errors and log email failures (PR 3943, @mo-nathan)

## 2026-02-20 (deploy-2026-02-20-10-10)

- Bump nokogiri from 1.19.0 to 1.19.1 (PR 3941, @app/dependabot)

## 2026-02-17 (deploy-2026-02-17-16-48)

- Bump rack from 3.1.19 to 3.1.20 (PR 3936, @app/dependabot)

## 2026-02-17 (deploy-2026-02-17-14-41)

- Revert "Email outage recovery plan and scripts" (PR 3933, @mo-nathan)

## 2026-02-17 (deploy-2026-02-17-12-17)

- Email outage recovery plan and scripts (PR 3931, @mo-nathan)

## 2026-02-17 (deploy-2026-02-17-04-03)

- Delete Phlex form conversion tracker file (PR 3928, @JoeCohen)
- Make the "admin donations review form" more Superform-idiomatic (PR 3851, @nimmolo)

## 2026-02-16 (deploy-2026-02-16-01-17)

- Convert admin/donations/edit to Phlex component (PR 3845, @mo-nathan)

## 2026-02-16 (deploy-2026-02-16-00-15)

- Escape regex metacharacters in localized string assertions (PR 3842, @app/copilot-swe-agent)
- Rename misleading parameter in merge_form_param helper (PR 3843, @app/copilot-swe-agent)
- Bump rubocop to 1.84.2 (PR 3847, @JoeCohen)
- Jdc phlex import preview (PR 3849, @JoeCohen)

## 2026-02-13 (deploy-2026-02-13-23-13)

- Fix RuboCop style offenses in observations downloads controller (PR 3836, @app/copilot-swe-agent)
- Convert observations downloads form from ERB to Phlex (PR 3828, @JoeCohen)

## 2026-02-13 (deploy-2026-02-13-10-52)

- Fix modal close button visibility in dark themes (PR 3841, @mo-nathan)

## 2026-02-13 (deploy-2026-02-13-00-57)

- Update consensus algorithm to boost sub-max agreeing votes (PR 3816, @mo-nathan)

## 2026-02-12 (deploy-2026-02-12-16-34)

(no merged PRs -- asset-only or config deploy)

## 2026-02-09 (deploy-2026-02-09-22-35)

- Update form_conversion_tracker.md (PR 3835, @nimmolo)
- Bump faraday from 2.14.0 to 2.14.1 (PR 3839, @app/dependabot)

## 2026-02-09 (deploy-2026-02-09-06-48)

- Fix rubocop offenses after 1.84.0 → 1.84.1 upgrade (PR 3834, @app/copilot-swe-agent)
- Bump rubocop from 1.84.0 to 1.84.1 (PR 3832, @app/dependabot)
- Bump brakeman from 8.0.1 to 8.0.2 (PR 3833, @app/dependabot)
- Phlex `DescriptionForm`, plus `MergeForm`, `MoveForm`, `PermissionsForm` (PR 3787, @nimmolo)

## 2026-02-09 (deploy-2026-02-09-02-52)

- Fix radio_field attribute merge order to preserve value stringification (PR 3830, @app/copilot-swe-agent)
- Add regression test for Symbol radio field values (PR 3831, @app/copilot-swe-agent)
- Fix radio_field value attribute (PR 3829, @JoeCohen)

## 2026-02-08 (deploy-2026-02-08-03-12)

- Bump phlex from 2.4.0 to 2.4.1 (PR 3820, @app/dependabot)
- Phlex Superform: Use convenience field methods consistently (PR 3824, @nimmolo)
- Sync checkbox_field block handling and herbarium form (PR 3826, @nimmolo)

## 2026-02-07 (deploy-2026-02-07-02-15)

- Allow import_all as a user's first import (PR 3817, @JoeCohen)

## 2026-02-05 (deploy-2026-02-05-22-51)

- Phlex - Name classification/synonymy forms (PR 3782, @nimmolo)
- Convert modal email forms to build the form object internally (PR 3796, @nimmolo)

## 2026-02-04 (deploy-2026-02-04-18-29)

- End reliance on "Voucher Specimen Taken" (PR 3804, @JoeCohen)

## 2026-02-02 (deploy-2026-02-02-15-51)

- Bump rubocop from 1.82.1 to 1.84.0 (PR 3794, @app/dependabot)
- Bump brakeman from 7.1.2 to 8.0.1 (PR 3793, @app/dependabot)
- Bump turbo-rails from 2.0.21 to 2.0.23 (PR 3795, @app/dependabot)

## 2026-01-30 (deploy-2026-01-30-02-33)

- Fix potential account signup bug re: theme select, pt. 2 (PR 3789, @nimmolo)

## 2026-01-29 (deploy-2026-01-29-22-02)

- Fix signup silently failing when theme is invalid/empty (PR 3788, @nimmolo)

## 2026-01-29 (deploy-2026-01-29-01-27)

- Delete unused observation form ERB files (PR 3784, @nimmolo)
- Consolidate email form objects into reusable `FormObject::EmailRequest` (PR 3785, @nimmolo)
- Fix CI error when blocked_ips files don't exist (PR 3786, @nimmolo)

## 2026-01-28 (deploy-2026-01-28-19-56)

- Use `superform` fork with `radio_field` support (PR 3783, @nimmolo)

## 2026-01-28 (deploy-2026-01-28-09-30)

- Fix checklist column layout alignment issue (PR 3776, @mo-nathan)

## 2026-01-28 (deploy-2026-01-28-09-29)

- Phlex: use new `mark_safe` for `register_output_helper` (PR 3781, @nimmolo)
- Phlex `NameForm` — show `locked` field (admin only) (PR 3779, @nimmolo)

## 2026-01-27 (deploy-2026-01-27-07-18)

- Clean up bad code examples in Phlex components (PR 3780, @nimmolo)

## 2026-01-26 (deploy-2026-01-26-18-46)

- Bump phlex-rails from 2.3.1 to 2.4.0 (PR 3777, @app/dependabot)
- Bump puma from 7.1.0 to 7.2.0 (PR 3778, @app/dependabot)

## 2026-01-25 (deploy-2026-01-25-23-35)

- Fix field slip ID losing underscores when editing other fields (PR 3774, @mo-nathan)
- Cache location center coordinates on observations (PR 3771, @mo-nathan)
- Use bounding box matching for project location checklists (PR 3772, @mo-nathan)

## 2026-01-24 (deploy-2026-01-24-01-25)

- Extract iNat sequence detection logic (PR 3766, @JoeCohen)

## 2026-01-23 (deploy-2026-01-23-14-48)

- Clear naming reasons notes field when reason unchecked (PR 3764, @nimmolo)

## 2026-01-23 (deploy-2026-01-23-14-44)

- Vertical space between term definition and external searches (PR 3763, @JoeCohen)

## 2026-01-22 (deploy-2026-01-22-02-40)

- Restore naming reasons to obs form (PR 3760, @nimmolo)

## 2026-01-21 (deploy-2026-01-21-18-05)

- Bump rqrcode from 3.1.1 to 3.2.0 (PR 3748, @app/dependabot)
- Bump solid_queue from 1.3.0 to 1.3.1 (PR 3749, @app/dependabot)
- Bump turbo-rails from 2.0.20 to 2.0.21 (PR 3750, @app/dependabot)

## 2026-01-21 (deploy-2026-01-21-13-44)

- Add test coverage for FieldSlip API edge cases and XML rendering (PR 3754, @app/copilot-swe-agent)
- Fix uninitialized constant FileMissing in API2::Uploads (PR 3756, @mo-nathan)
- Refactor API page lengths to use level-based abstraction (PR 3755, @mo-nathan)
- Add FieldSlip API calls (PR 3752, @mo-nathan)

## 2026-01-16 (deploy-2026-01-16-18-07)

- 3427 relax import list limit (PR 3739, @JoeCohen)

## 2026-01-12 (deploy-2026-01-12-20-26)

- Bump trilogy from 2.9.0 to 2.10.0 (PR 3732, @app/dependabot)

## 2026-01-12 (deploy-2026-01-12-20-25)

(no merged PRs -- asset-only or config deploy)

## 2026-01-12 (deploy-2026-01-12-16-19)

- Bump solid_queue from 1.2.4 to 1.3.0 (PR 3734, @app/dependabot)
- Bump importmap-rails from 2.2.2 to 2.2.3 (PR 3730, @app/dependabot)
- Bump google-cloud-storage from 1.57.1 to 1.58.0 (PR 3733, @app/dependabot)

## 2026-01-09 (deploy-2026-01-09-22-38)

- Phlex `Table` component, `IpsManager` form (PR 3722, @nimmolo)

## 2026-01-09 (deploy-2026-01-09-20-26)

- Phlex `ObservationForm` (PR 3698, @nimmolo)

## 2026-01-09 (deploy-2026-01-09-20-24)

- Enable SimpleCov coverage reports by default with parallel test support (PR 3726, @mo-nathan)

## 2026-01-09 (deploy-2026-01-09-20-19)

- nimmo alterations to project banner (PR 3728, @nimmolo)
- Fix image upload file type validation (PR 3721, @nimmolo)
- Convert _project_banner.erb to Phlex (PR 3712, @mo-nathan)

## 2026-01-09 (deploy-2026-01-09-04-37)

- Convert _translators_credit partial to Phlex component (PR 3717, @mo-nathan)
- Fix intermittent TranslatorsCreditTest failure from test isolation issue (PR 3723, @mo-nathan)
- Update report test error diagnostic message (PR 3724, @nimmolo)
- Enable `simplecov` to run parallel tests with merged coverage results (PR 3725, @nimmolo)

## 2026-01-07 (deploy-2026-01-07-16-15)

- Fix Publications index Action menu (PR 3707, @JoeCohen)

## 2026-01-07 (deploy-2026-01-07-16-11)

- Convert account signup form to Phlex component (PR 3720, @JoeCohen)

## 2026-01-07 (deploy-2026-01-07-14-53)

- Address PR feedback: sidebar cache key ordering and test coverage (PR 3711, @mo-nathan)
- Convert admin banner change form to Phlex component (PR 3718, @JoeCohen)

## 2026-01-06 (deploy-2026-01-06-22-31)

- Obs form - fix EXIF transfer of date and location data (PR 3708, @nimmolo)

## 2026-01-06 (deploy-2026-01-06-08-59)

- Phlex `AdminSessionForm` (PR 3714, @nimmolo)

## 2026-01-06 (deploy-2026-01-06-01-04)

- Remove references to `current_user` helper in components (PR 3716, @nimmolo)

## 2026-01-06 (deploy-2026-01-06-00-20)

- Create `FormObject::Base` to remove boilerplate (PR 3715, @nimmolo)

## 2026-01-05 (deploy-2026-01-05-14-18)

- Fix sidebar cache to update when changing languages (PR 3710, @mo-nathan)

## 2026-01-05 (deploy-2026-01-05-14-07)

- Fix language switching in sidebar (PR 3709, @mo-nathan)

## 2026-01-05 (deploy-2026-01-05-13-51)

- Convert application sidebar to Phlex components (PR 3696, @mo-nathan)

## 2026-01-05 (deploy-2026-01-05-00-17)

- Bump rubocop-rails from 2.34.2 to 2.34.3 (PR 3705, @app/dependabot)
- Bump bcrypt from 3.1.20 to 3.1.21 (PR 3704, @app/dependabot)

## 2026-01-04 (deploy-2026-01-04-21-55)

- Convert login_layout partial to Phlex component (PR 3697, @mo-nathan)
- Fix map autozoom for locations (PR 3702, @nimmolo)

## 2026-01-04 (deploy-2026-01-04-03-24)

- Fix edit/destroy icon logic for Location show page (PR 3701, @nimmolo)

## 2026-01-03 (deploy-2026-01-03-22-57)

- Phlex `LocationForm`, `Map`, `FormCompassFields`, `FormElevationFields` (PR 3681, @nimmolo)
- Phlex `ModalForm` component (PR 3680, @nimmolo)
- Convert `namings`, `image_matrix` panels to use `Panel` component (PR 3695, @nimmolo)
- Create form_conversion_tracker.md (PR 3700, @nimmolo)
- Delete location form partials (PR 3699, @nimmolo)

## 2026-01-02 (deploy-2026-01-02-21-30)

- Delete form partials already replaced by components (PR 3692, @nimmolo)

## 2026-01-02 (deploy-2026-01-02-21-26)

- Remove `QueuedEmail` everywhere (PR 3683, @nimmolo)

## 2026-01-02 (deploy-2026-01-02-21-24)

- Phlex `ProjectAliasForm` `ProjectMemberForm` conversions (PR 3689, @nimmolo)

## 2026-01-02 (deploy-2026-01-02-04-37)

- Consolidate component test methods (PR 3686, @nimmolo)
- Update testing.md for component tests (PR 3687, @nimmolo)

## 2026-01-02 (deploy-2026-01-02-03-32)

- `CrudActionButton` and `ModalConfirm` Phlex components (PR 3678, @nimmolo)

## 2026-01-02 (deploy-2026-01-02-03-16)

- Convert form_location_feedback partial to Phlex component (PR 3668, @mo-nathan)
- Phlex `ModalProgressSpinner` (PR 3679, @nimmolo)

## 2026-01-02 (deploy-2026-01-02-01-35)

- Coverage and logic in CN, HR, Sequences controllers (PR 3684, @nimmolo)

## 2026-01-01 (deploy-2026-01-01-21-18)

- Fix TypeError when params[:q] is a String in set_project_ivar (PR 3672, @JoeCohen)

## 2026-01-01 (deploy-2026-01-01-14-35)

- Convert form_list_feedback partial to Phlex component (PR 3666, @mo-nathan)

## 2026-01-01 (deploy-2026-01-01-08-18)

- New `ComponentTestCase` (PR 3682, @nimmolo)

## 2026-01-01 (deploy-2026-01-01-04-59)

- Simplify modals_helper.rb by passing locals directly (PR 3677, @nimmolo)

## 2026-01-01 (deploy-2026-01-01-01-20)

- Delete `herbaria/_form.erb` (PR 3676, @nimmolo)

## 2026-01-01 (deploy-2026-01-01-00-27)

- Fix destroy buttons on show pages for observation associated records (PR 3675, @nimmolo)

## 2026-01-01 (deploy-2026-01-01-00-21)

- Fix autocompleter JS - should clear matching id when string changes (PR 3674, @nimmolo)
- Phlex HerbariumForm component (PR 3640, @nimmolo)
