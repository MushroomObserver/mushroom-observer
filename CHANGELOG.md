# Changelog

## 2026-08-24 (deploy-2026-08-24-12-01)

- Changelog block convention: `.claude/rules/changelog.md` + PR template (#5155 step 1) ([PR5158](https://github.com/MushroomObserver/mushroom-observer/pull/5158), @mo-nathan)
- Standalone `CHANGELOG.md` generator: `script/generate_changelog.rb` (#5155 step 2) ([PR5159](https://github.com/MushroomObserver/mushroom-observer/pull/5159), @mo-nathan)
- Changelog: bare `#NNNN` PR references instead of markdown links (#5155) ([PR5167](https://github.com/MushroomObserver/mushroom-observer/pull/5167), @mo-nathan)
- Link field slip scans from the observation and image pages (#5161) ([PR5169](https://github.com/MushroomObserver/mushroom-observer/pull/5169), @mo-nathan)
- Lead with the thumbnail even when it is a sibling's image (#5160) ([PR5170](https://github.com/MushroomObserver/mushroom-observer/pull/5170), @mo-nathan)
- Changelog: find PRs by merge-commit reachability; regenerate 2026 (#5155) ([PR5171](https://github.com/MushroomObserver/mushroom-observer/pull/5171), @mo-nathan)
- Add `script/article_rows.rb`: MO Article rows from PR changelog blocks (#5155) ([PR5176](https://github.com/MushroomObserver/mushroom-observer/pull/5176), @mo-nathan)
- Edit on a read-only reflection opens a companion observation (#4214) ([PR5178](https://github.com/MushroomObserver/mushroom-observer/pull/5178), @mo-nathan)
- Rule: create every PR as a draft ([PR5179](https://github.com/MushroomObserver/mushroom-observer/pull/5179), @mo-nathan)

## 2026-08-22 (deploy-2026-08-22-01-42)

- Prefix only bare-number field slip codes in `AddDispatchController` ([PR5147](https://github.com/MushroomObserver/mushroom-observer/pull/5147), @mo-nathan)
- Truncate oversized import digests ([PR5130](https://github.com/MushroomObserver/mushroom-observer/pull/5130), @JoeCohen)
- Clean up the abandoned `Occurrence` when an observation moves to another ([PR5151](https://github.com/MushroomObserver/mushroom-observer/pull/5151), @mo-nathan)
- Fix four recurring #alerts noise sources (`UserStats` orphans, `external_id` 500, scanner MIME 500, `define_a_location` deadlock) ([PR5152](https://github.com/MushroomObserver/mushroom-observer/pull/5152), @mo-nathan)
- Convert `comments.comment` and `users.notes` to utf8mb4 (emoji 500s) ([PR5153](https://github.com/MushroomObserver/mushroom-observer/pull/5153), @mo-nathan)
- Nightly retry sweep for failed GPS strips (`Image.retry_failed_gps_strips`) ([PR5154](https://github.com/MushroomObserver/mushroom-observer/pull/5154), @mo-nathan)
- oauth2 2.0.25 ([PR5157](https://github.com/MushroomObserver/mushroom-observer/pull/5157), @JoeCohen)
- Fix false constraint-violation warning from reused field-slip prefix ([PR5156](https://github.com/MushroomObserver/mushroom-observer/pull/5156), @JoeCohen)

## 2026-08-21 (deploy-2026-08-21-12-04)

- Add `MO/NoHandRolledMethodField` rubocop cop ([PR5128](https://github.com/MushroomObserver/mushroom-observer/pull/5128), @nimmolo)
- Wire `Publication` into `InlineCRUDLinks` ([PR5132](https://github.com/MushroomObserver/mushroom-observer/pull/5132), @nimmolo)
- Dedupe `Query` param URL-merge logic between `add_q_param` and `Tab::Base#with_q_param` ([PR5135](https://github.com/MushroomObserver/mushroom-observer/pull/5135), @nimmolo)
- Add `block_banned_words.sh` hook to enforce style-ban words automatically ([PR5133](https://github.com/MushroomObserver/mushroom-observer/pull/5133), @nimmolo)
- Add `MO/NoRenderPhlexMethodName` cop, rename all `render_phlex_*` methods ([PR5134](https://github.com/MushroomObserver/mushroom-observer/pull/5134), @nimmolo)
- Add general `.btn-group`/`.input-group` flex-height fixes ([PR5136](https://github.com/MushroomObserver/mushroom-observer/pull/5136), @nimmolo)
- Add rotate/mirror icons to `ImagePanel`'s transform controls ([PR5127](https://github.com/MushroomObserver/mushroom-observer/pull/5127), @nimmolo)
- Flip Turbo `forms.mode` to opt-out (#5100), eliminate remaining hand-rolled forms ([PR5141](https://github.com/MushroomObserver/mushroom-observer/pull/5141), @nimmolo)
- "Flat Query Params" foundation work (#5137) - no changes, just plumbing ([PR5142](https://github.com/MushroomObserver/mushroom-observer/pull/5142), @nimmolo)
- prev/next nav: Cached-window lookup with seek-backed fill ([PR5118](https://github.com/MushroomObserver/mushroom-observer/pull/5118), @nimmolo)
- Add UI to add/remove an observation to/from a `Project` ([PR5123](https://github.com/MushroomObserver/mushroom-observer/pull/5123), @nimmolo)
- Add "Attach to Field Slip" UI to the observation show page ([PR5124](https://github.com/MushroomObserver/mushroom-observer/pull/5124), @nimmolo)
- Carry project context to species-list checklists; add `Missing taxa` panel ([PR5145](https://github.com/MushroomObserver/mushroom-observer/pull/5145), @mo-nathan)
- Show importable cap ([PR5126](https://github.com/MushroomObserver/mushroom-observer/pull/5126), @JoeCohen)

## 2026-08-18 (deploy-2026-08-18-15-03)

- Fix title-bar edit/delete icon alignment via `Components::InlineLinkBlock` ([PR5099](https://github.com/MushroomObserver/mushroom-observer/pull/5099), @nimmolo)
- Fix pattern-search icon rendering outside the input ([PR5097](https://github.com/MushroomObserver/mushroom-observer/pull/5097), @nimmolo)
- Fix flaky `observation_show_system_test` race on "Your Observations" ([PR5113](https://github.com/MushroomObserver/mushroom-observer/pull/5113), @nimmolo)
- Project-less field slips: skip the null-project bucket in `users_last_location` ([PR5111](https://github.com/MushroomObserver/mushroom-observer/pull/5111), @mo-nathan)
- Filtered search: accept comma date ranges in `DateRangeParser`; never silently drop an unparseable date ([PR5112](https://github.com/MushroomObserver/mushroom-observer/pull/5112), @mo-nathan)
- Add index on `observations(log_updated_at, id)` ([PR5117](https://github.com/MushroomObserver/mushroom-observer/pull/5117), @nimmolo)
- Create obs slowness: Add missing `observations.user_id` index; fix project-checkbox N+1 ([PR5106](https://github.com/MushroomObserver/mushroom-observer/pull/5106), @nimmolo)
- Parse provisional `sp` without a trailing period ([PR5105](https://github.com/MushroomObserver/mushroom-observer/pull/5105), @JoeCohen)
- Fix mcp backfill test warnings ([PR5109](https://github.com/MushroomObserver/mushroom-observer/pull/5109), @JoeCohen)
- Reduce observations "Sort by" options for unfiltered index ([PR5119](https://github.com/MushroomObserver/mushroom-observer/pull/5119), @nimmolo)
- Fix `size:` being silently ignored on `Button(type: :modal, ...)` ([PR5125](https://github.com/MushroomObserver/mushroom-observer/pull/5125), @nimmolo)
- Show the "reopen announcements" banner icon on mobile too ([PR5121](https://github.com/MushroomObserver/mushroom-observer/pull/5121), @nimmolo)
- Fix `.inline-icon-link` baseline and `.input-group-btn` icon-button height ([PR5120](https://github.com/MushroomObserver/mushroom-observer/pull/5120), @nimmolo)

## 2026-08-17 (deploy-2026-08-17-11-02)

- Observation upload row: `Take Photo` capture button, `Select Photos` naming, drop/paste hint, paste support ([PR5084](https://github.com/MushroomObserver/mushroom-observer/pull/5084), @mo-nathan)
- Add `FieldSlip::Template::Nama` for the NAMA 2026 foray slips ([PR5087](https://github.com/MushroomObserver/mushroom-observer/pull/5087), @mo-nathan)
- Firm-up `turbo:`/`context:` convention on `Components::ApplicationForm`, fix bugs found along the way ([PR5095](https://github.com/MushroomObserver/mushroom-observer/pull/5095), @nimmolo)
- Fix user autocompleter dropping login-only matches (issue #3537) ([PR5096](https://github.com/MushroomObserver/mushroom-observer/pull/5096), @nimmolo)
- Script to backfill MCP ExternalLinks ([PR4877](https://github.com/MushroomObserver/mushroom-observer/pull/4877), @JoeCohen)

## 2026-08-16 (deploy-2026-08-16-14-11)

- Update rubocop extensions ([PR5089](https://github.com/MushroomObserver/mushroom-observer/pull/5089), @JoeCohen)

## 2026-08-16 (deploy-2026-08-16-00-02)

- Fix field-slip review loop: duplicate `_method` made Turbo submit the save as a bare POST ([PR5088](https://github.com/MushroomObserver/mushroom-observer/pull/5088), @mo-nathan)

## 2026-08-15 (deploy-2026-08-15-20-06)

- Turbo-submit `InatImportsController` (issue #5052) ([PR5066](https://github.com/MushroomObserver/mushroom-observer/pull/5066), @nimmolo)
- Turbo-submit sweep batch 2: `Admin::*`, `Descriptions::*`, `FieldSlips*`, `Images::*`, `Names*`, `Occurrences*`, `Projects*` (issue #5052) ([PR5061](https://github.com/MushroomObserver/mushroom-observer/pull/5061), @nimmolo)
- Turbo-submit sweep batch 3: `Names::Synonyms::*`, `Observations::*`, `Publications*`, `Sequences*`, `SpeciesLists*`, `Support*`, `Users::*`, `VisualGroups*`, `VisualModels*` (issue #5052) ([PR5069](https://github.com/MushroomObserver/mushroom-observer/pull/5069), @nimmolo)
- Use `NormalizedHash` -> `NotesHash` PORO everywhere for notes-Hash shape and Phlex prop validation ([PR5082](https://github.com/MushroomObserver/mushroom-observer/pull/5082), @nimmolo)
- Say "delete" instead of "destroy" throughout user-facing text ([PR5049](https://github.com/MushroomObserver/mushroom-observer/pull/5049), @nimmolo)

## 2026-08-15 (deploy-2026-08-15-16-08)

- Allow iNat imported data Place to be Private ([PR5086](https://github.com/MushroomObserver/mushroom-observer/pull/5086), @JoeCohen)

## 2026-08-15 (deploy-2026-08-15-04-58)

- Fix the dubious-locality approval loop and the sticky free-text Locality default (`approved_where` / `field_slip_for_code`) ([PR5083](https://github.com/MushroomObserver/mushroom-observer/pull/5083), @mo-nathan)

## 2026-08-14 (deploy-2026-08-14-22-28)

- Turbo submit observation form (issue #5052) and disable in-flight form on submit (#5077) ([PR5055](https://github.com/MushroomObserver/mushroom-observer/pull/5055), @nimmolo)
- Turbo-submit sweep batch 1: `Account::*`, `Admin::*`, `Articles`, `CollectionNumbers`, `Comments`, `Descriptions::*`, `Herbaria*`, `Images::*`, `Info`, `Locations*`, `Names::*`, `Observations::ImagesController` (issue #5052) ([PR5058](https://github.com/MushroomObserver/mushroom-observer/pull/5058), @nimmolo)
- Fix `Location.contains_point` for boxes straddling the antimeridian ([PR5081](https://github.com/MushroomObserver/mushroom-observer/pull/5081), @nimmolo)

## 2026-08-14 (deploy-2026-08-14-22-09)

- Bump json from 2.21.1 to 2.21.2 ([PR5019](https://github.com/MushroomObserver/mushroom-observer/pull/5019), @app/dependabot)
- Fix language locale leakage: stop persisting `?user_locale=` to `@user.locale`, make the switcher POST ([PR5075](https://github.com/MushroomObserver/mushroom-observer/pull/5075), @nimmolo)
- Manual geocoding entry - Fix `#5017` viewport jump / paste-split and `#5014` zero-coordinate falsy bug ([PR5076](https://github.com/MushroomObserver/mushroom-observer/pull/5076), @nimmolo)
- Fix observation, species_list, project forms looping on a confirmed dubious location name (DRY) ([PR5079](https://github.com/MushroomObserver/mushroom-observer/pull/5079), @nimmolo)
- Don't raise on links in field labels (fixes production crash on `/support/donate`) ([PR5078](https://github.com/MushroomObserver/mushroom-observer/pull/5078), @nimmolo)

## 2026-08-14 (deploy-2026-08-14-08-12)

- Make a separate `/projects/:project_id/violations` update route ([PR5071](https://github.com/MushroomObserver/mushroom-observer/pull/5071), @nimmolo)

## 2026-08-14 (deploy-2026-08-14-07-55)

- Turbo-submit `Observations::NamingsController` + fix two lightbox/clone bugs found along the way ([PR5065](https://github.com/MushroomObserver/mushroom-observer/pull/5065), @nimmolo)

## 2026-08-14 (deploy-2026-08-14-01-07)

- Fix `Components::Form::NameFeedback` losing its help text for unrecognized names ([PR5073](https://github.com/MushroomObserver/mushroom-observer/pull/5073), @nimmolo)

## 2026-08-14 (deploy-2026-08-14-00-35)

- Restore the spinners the SVG-sprite conversion emptied (`.spinner-right`) ([PR5067](https://github.com/MushroomObserver/mushroom-observer/pull/5067), @mo-nathan)
- Extract `Account::PasswordResetsController` from `Account::LoginController` ([PR5070](https://github.com/MushroomObserver/mushroom-observer/pull/5070), @nimmolo)
- Address Copilot findings on `Account::PasswordResetsController` from #5070 ([PR5072](https://github.com/MushroomObserver/mushroom-observer/pull/5072), @nimmolo)
- Fix `section-update` Stimulus controller: never dispatching `section-update:updated` ([PR5064](https://github.com/MushroomObserver/mushroom-observer/pull/5064), @nimmolo)

## 2026-08-13 (deploy-2026-08-13-16-41)

- Broaden image transform permission ([PR5009](https://github.com/MushroomObserver/mushroom-observer/pull/5009), @JoeCohen)

## 2026-08-13 (deploy-2026-08-13-12-38)

- Give submit buttons in-flight feedback (`form-feedback` Stimulus controller) ([PR5035](https://github.com/MushroomObserver/mushroom-observer/pull/5035), @mo-nathan)
- A spare slip still resolves its event's aliases via the printed prefix (`FieldSlip#event_project`) ([PR5057](https://github.com/MushroomObserver/mushroom-observer/pull/5057), @mo-nathan)
- Don't warn "in use" about a slip the QR job just attached to this observation (`explain_in_use_slip` race) ([PR5059](https://github.com/MushroomObserver/mushroom-observer/pull/5059), @mo-nathan)
- Update gets Create's slip-review handoff for newly added photos ([PR5060](https://github.com/MushroomObserver/mushroom-observer/pull/5060), @mo-nathan)

## 2026-08-13 (deploy-2026-08-13-00-54)

- Prototype Turbo submission on `LicensesController`; hoist `render_*_view_invalid`; fix `form-images_controller.js` resubmission ([PR5054](https://github.com/MushroomObserver/mushroom-observer/pull/5054), @nimmolo)
- Skip permission-denied flash when turning off admin mode from an admin-only page ([PR5056](https://github.com/MushroomObserver/mushroom-observer/pull/5056), @nimmolo)

## 2026-08-12 (deploy-2026-08-12-22-26)

- Fix observation destroy-redirect test assumption; hook up dead `areAllItemsExifPopulated()` gate ([PR5053](https://github.com/MushroomObserver/mushroom-observer/pull/5053), @nimmolo)

## 2026-08-12 (deploy-2026-08-12-22-03)

- One-pass project alert incl. the slip's target project; slip+observation leave a violating project together ([PR5046](https://github.com/MushroomObserver/mushroom-observer/pull/5046), @mo-nathan)
- Post-event cleanup report + field-slip event docs split by audience (admin article draft, dev notes) ([PR5047](https://github.com/MushroomObserver/mushroom-observer/pull/5047), @mo-nathan)
- Scan-page photo/action spacing + `.claude/rules/ui_spacing.md` UI-spacing conventions ([PR5044](https://github.com/MushroomObserver/mushroom-observer/pull/5044), @mo-nathan)
- Remove the last #5038 locality-trap leftovers from the event docs ([PR5050](https://github.com/MushroomObserver/mushroom-observer/pull/5050), @mo-nathan)
- Make `Components::ApplicationForm` Literal-props-native, use props in forms ([PR5051](https://github.com/MushroomObserver/mushroom-observer/pull/5051), @nimmolo)

## 2026-08-12 (deploy-2026-08-12-09-07)

- Convert Phlex `initialize`s to Literal props; add 4 custom cops ([PR5025](https://github.com/MushroomObserver/mushroom-observer/pull/5025), @nimmolo)
- Switch `Components::Icon` rendering from Bootstrap 3 glyphicon font to an SVG sprite ([PR5020](https://github.com/MushroomObserver/mushroom-observer/pull/5020), @nimmolo)

## 2026-08-11 (deploy-2026-08-11-02-32)

- Attach the field slip from the extraction's read code (`ExtractFieldSlipJob`, review form, repair script) ([PR5040](https://github.com/MushroomObserver/mushroom-observer/pull/5040), @mo-nathan)
- Normalize separator-grouped iNaturalist ids in every template's iNat slot (`Template::Base`) ([PR5043](https://github.com/MushroomObserver/mushroom-observer/pull/5043), @mo-nathan)
- Review-save joins an in-use slip's occurrence (`Attacher` `join_in_use:`); explain the create-time pause ([PR5045](https://github.com/MushroomObserver/mushroom-observer/pull/5045), @mo-nathan)

## 2026-08-09 (deploy-2026-08-09-19-14)

- Fix QR slip detection in production: probe the direct disk path (`FieldSlip::QRDecoder`) ([PR5034](https://github.com/MushroomObserver/mushroom-observer/pull/5034), @mo-nathan)

## 2026-08-09 (deploy-2026-08-09-18-30)

- Keep line breaks in multi-line field slip values through review (`textarea` for multi-line rows) ([PR5031](https://github.com/MushroomObserver/mushroom-observer/pull/5031), @mo-nathan)
- Add `zbar` to setup docs, dev-setup scripts, and `Dockerfile` ([PR5030](https://github.com/MushroomObserver/mushroom-observer/pull/5030), @mo-nathan)
- Index `names.text_name` and `names.search_name` ([PR5033](https://github.com/MushroomObserver/mushroom-observer/pull/5033), @mo-nathan)
- Run slip extraction in the background (`ExtractFieldSlipJob`); land Create on the review page ([PR5032](https://github.com/MushroomObserver/mushroom-observer/pull/5032), @mo-nathan)

## 2026-08-09 (deploy-2026-08-09-15-00)

- Narrow icon-library checkouts to just `mo-icons.svg` ([PR5021](https://github.com/MushroomObserver/mushroom-observer/pull/5021), @nimmolo)
- Add `FieldSlip::Template` layouts; read Andy Wilson's DBG voucher slips ([PR5026](https://github.com/MushroomObserver/mushroom-observer/pull/5026), @mo-nathan)
- Auto-attach observations to field slips via QR codes in uploaded photos (`FieldSlip::QRDecoder`) ([PR5029](https://github.com/MushroomObserver/mushroom-observer/pull/5029), @mo-nathan)

## 2026-08-07 (deploy-2026-08-07-23-03)

- Read a handwritten MycoMap voucher number ([PR5018](https://github.com/MushroomObserver/mushroom-observer/pull/5018), @mo-nathan)

## 2026-08-07 (deploy-2026-08-07-22-17)

- Ignore a question mark when looking up a name ([PR5015](https://github.com/MushroomObserver/mushroom-observer/pull/5015), @mo-nathan)
- Fetch icon-library's sprite in CI via a scoped PAT ([PR5011](https://github.com/MushroomObserver/mushroom-observer/pull/5011), @nimmolo)
- Make the Geolocation checkbox on the observation form mean something ([PR5016](https://github.com/MushroomObserver/mushroom-observer/pull/5016), @mo-nathan)
- Fix stale `rvm` reference in `README_PRODUCTION_INSTALL`, add missing `RUBY_MANAGER` to `solidqueue.service` ([PR4997](https://github.com/MushroomObserver/mushroom-observer/pull/4997), @nimmolo)

## 2026-08-07 (deploy-2026-08-07-16-12)

- Make the observation form's Geolocation section usable as loaded ([PR5013](https://github.com/MushroomObserver/mushroom-observer/pull/5013), @mo-nathan)
- Grant `editing` trust on project creation and `Project#join`, and backfill untouched `hidden_gps` ([PR5008](https://github.com/MushroomObserver/mushroom-observer/pull/5008), @mo-nathan)

## 2026-08-07 (deploy-2026-08-07-14-03)

- Extract dev-setup finish sequence, fold Ubuntu root/mo scripts, drop dead unicorn config ([PR5004](https://github.com/MushroomObserver/mushroom-observer/pull/5004), @nimmolo)
- Scripts to clone private icon-library repo to dev or production ([PR5001](https://github.com/MushroomObserver/mushroom-observer/pull/5001), @nimmolo)
- Resolve names written in a single case (`russula compacta`, `RUSSULA COMPACTA`) ([PR4999](https://github.com/MushroomObserver/mushroom-observer/pull/4999), @mo-nathan)

## 2026-08-06 (deploy-2026-08-06-08-04)

- DRY component/view test render calls; add `MO/DryTestRenderHelper` cop to catch it going forward ([PR4995](https://github.com/MushroomObserver/mushroom-observer/pull/4995), @nimmolo)
- DRY up `API2::*Test` param hashes (issue #4707) ([PR4996](https://github.com/MushroomObserver/mushroom-observer/pull/4996), @nimmolo)
- Add `dev_setup_macos` and `dev_setup_ubuntu`, share setup modules ([PR4998](https://github.com/MushroomObserver/mushroom-observer/pull/4998), @nimmolo)

## 2026-08-05 (deploy-2026-08-05-16-21)

- Reset the WebMock request registry between tests ([PR4958](https://github.com/MushroomObserver/mushroom-observer/pull/4958), @mo-nathan)
- Note the two-config maintenance of the GCS archive cutoff in `config/etc/nginx.conf` ([PR4987](https://github.com/MushroomObserver/mushroom-observer/pull/4987), @mo-nathan)
- Fix glyphicon misalignment on carousel controls and the lightbox theater button ([PR4994](https://github.com/MushroomObserver/mushroom-observer/pull/4994), @nimmolo)

## 2026-08-05 (deploy-2026-08-05-12-24)

- Let a field slip read report that the image holds no slip (`slip_present`) ([PR4993](https://github.com/MushroomObserver/mushroom-observer/pull/4993), @mo-nathan)
- Default the navbar search type to Observations on the Activity Log ([PR4970](https://github.com/MushroomObserver/mushroom-observer/pull/4970), @mo-nathan)

## 2026-08-04 (deploy-2026-08-04-23-29)

- Move observation source-credit line into `ObjectFooter` ([PR4990](https://github.com/MushroomObserver/mushroom-observer/pull/4990), @nimmolo)
- nginx: Proxy image requests in instead of redirecting (minor fix for slow image loading) ([PR4982](https://github.com/MushroomObserver/mushroom-observer/pull/4982), @nimmolo)

## 2026-08-04 (deploy-2026-08-04-23-15)

- Fix carousel vote-button tooltip clipping; scope `.glyphicon` `top` offset to `.btn` ([PR4991](https://github.com/MushroomObserver/mushroom-observer/pull/4991), @nimmolo)

## 2026-08-04 (deploy-2026-08-04-11-42)

- Fix lingering gray thumbnails: batch vote-interface streams, raise Puma concurrency, HTTP/2, stable `updated_at` on votes (#4984) ([PR4985](https://github.com/MushroomObserver/mushroom-observer/pull/4985), @mo-nathan)

## 2026-08-03 (deploy-2026-08-03-23-34)

- Silence and assert on expected-failure log noise in 2 tests ([PR4981](https://github.com/MushroomObserver/mushroom-observer/pull/4981), @nimmolo)
- Redesign image vote UI: theme-independent meter, `ButtonGroup` links ([PR4972](https://github.com/MushroomObserver/mushroom-observer/pull/4972), @mo-nathan)
- Move the thumbnail map into `Show::Details` under the location info ([PR4968](https://github.com/MushroomObserver/mushroom-observer/pull/4968), @mo-nathan)

## 2026-08-03 (deploy-2026-08-03-22-15)

- Enforce `assert_equal(nil, ...)` as a failure; fix remaining offenders ([PR4980](https://github.com/MushroomObserver/mushroom-observer/pull/4980), @nimmolo)

## 2026-08-03 (deploy-2026-08-03-20-02)

- Add the `su mo mo` directive logrotate needs to rotate `mo`-owned app logs ([PR4978](https://github.com/MushroomObserver/mushroom-observer/pull/4978), @mo-nathan)
- Fix `MatrixBox` heading/badge display ([PR4979](https://github.com/MushroomObserver/mushroom-observer/pull/4979), @nimmolo)

## 2026-08-02 (deploy-2026-08-02-10-37)

- Alert on image-processing failures, classify stale files, and retry failed transfers (#4974) ([PR4977](https://github.com/MushroomObserver/mushroom-observer/pull/4977), @mo-nathan)

## 2026-08-01 (deploy-2026-08-01-10-26)

- Store field slip "Id by" as a user link, and stop the prompt expanding initials ([PR4963](https://github.com/MushroomObserver/mushroom-observer/pull/4963), @mo-nathan)

## 2026-08-01 (deploy-2026-08-01-00-36)

- Tick every field slip row by default, and mark the disagreements ([PR4960](https://github.com/MushroomObserver/mushroom-observer/pull/4960), @mo-nathan)

## 2026-07-31 (deploy-2026-07-31-21-14)

- Read field slips from their photos with an LLM, for admin review ([PR4951](https://github.com/MushroomObserver/mushroom-observer/pull/4951), @mo-nathan)

## 2026-07-31 (deploy-2026-07-31-15-14)

- Fix the field-slip note fields on the observation edit form (`Other Codes` duplicated, iNat flag not persisting) ([PR4950](https://github.com/MushroomObserver/mushroom-observer/pull/4950), @mo-nathan)

## 2026-07-30 (deploy-2026-07-30-22-12)

- Bump oauth2 from 2.0.20 to 2.0.22 ([PR4947](https://github.com/MushroomObserver/mushroom-observer/pull/4947), @app/dependabot)

## 2026-07-30 (deploy-2026-07-30-19-54)

- Change Rank dropdown order on Names form ([PR4946](https://github.com/MushroomObserver/mushroom-observer/pull/4946), @JoeCohen)

## 2026-07-30 (deploy-2026-07-30-00-22)

- Derive API2 `external_link` url from `external_id` ([PR4944](https://github.com/MushroomObserver/mushroom-observer/pull/4944), @AlanRockefeller)

## 2026-07-29 (deploy-2026-07-29-21-19)

- Add coverage lost in #4915 ([PR4943](https://github.com/MushroomObserver/mushroom-observer/pull/4943), @JoeCohen)
- Convert `assert_flash` call sites to tag-only signature (#4931) ([PR4936](https://github.com/MushroomObserver/mushroom-observer/pull/4936), @nimmolo)

## 2026-07-29 (deploy-2026-07-29-19-18)

- Fix doubled colons on `Form::Specimen`'s Fungarium Name and Accession Number labels ([PR4937](https://github.com/MushroomObserver/mushroom-observer/pull/4937), @mo-nathan)
- Route `/qr/<code>` to the Create Observation page (#4932) ([PR4938](https://github.com/MushroomObserver/mushroom-observer/pull/4938), @mo-nathan)
- Enforce the occurrence/project membership invariants (#4932) ([PR4940](https://github.com/MushroomObserver/mushroom-observer/pull/4940), @mo-nathan)
- Add dry-run/apply convention rule: `--apply` for runner scripts, `APPLY=1` for rake tasks ([PR4933](https://github.com/MushroomObserver/mushroom-observer/pull/4933), @mo-nathan)

## 2026-07-28 (deploy-2026-07-28-14-25)

- Fix ambiguous imported rank ([PR4915](https://github.com/MushroomObserver/mushroom-observer/pull/4915), @JoeCohen)

## 2026-07-28 (deploy-2026-07-28-06-50)

- Make native Rails validation errors translatable (phase 2 of #4901) ([PR4920](https://github.com/MushroomObserver/mushroom-observer/pull/4920), @nimmolo)
- Make name authors non-breaking wherever they render (`String#small_author`) ([PR4934](https://github.com/MushroomObserver/mushroom-observer/pull/4934), @nimmolo)
- Make observation `SpecimenPanel` collapsible ([PR4935](https://github.com/MushroomObserver/mushroom-observer/pull/4935), @nimmolo)

## 2026-07-27 (deploy-2026-07-27-19-56)

- Fix 500 deleting an external link on an occurrence-member observation (`siblings` relation vs typed prop) ([PR4927](https://github.com/MushroomObserver/mushroom-observer/pull/4927), @mo-nathan)
- Resync read-only reflections from their iNaturalist source + `Sync now` button (#4215) ([PR4853](https://github.com/MushroomObserver/mushroom-observer/pull/4853), @mo-nathan)

## 2026-07-27 (deploy-2026-07-27-19-33)

- Render field help outside `.form-group`, fixing autocompleter dropdown positioning (alt. to #4911) ([PR4922](https://github.com/MushroomObserver/mushroom-observer/pull/4922), @nimmolo)

## 2026-07-27 (deploy-2026-07-27-18-50)

- Consolidate validation-error display into `Components::Form::Errors` (#4901, phase 1) ([PR4914](https://github.com/MushroomObserver/mushroom-observer/pull/4914), @nimmolo)

## 2026-07-26 (deploy-2026-07-26-14-35)

- Fix `FieldSlip#users_last_location` picking the oldest slip; smarter location fallbacks ([PR4908](https://github.com/MushroomObserver/mushroom-observer/pull/4908), @mo-nathan)
- Fix `ensure_thumb_image` discarding a newly uploaded image chosen as thumbnail ([PR4906](https://github.com/MushroomObserver/mushroom-observer/pull/4906), @mo-nathan)

## 2026-07-26 (deploy-2026-07-26-04-21)

- Move `page_title`/`document_title` from 16 models to a `Title::` PORO family (#4901) ([PR4913](https://github.com/MushroomObserver/mushroom-observer/pull/4913), @nimmolo)

## 2026-07-26 (deploy-2026-07-26-03-04)

- Return unresolved `[tag, args]` pairs from `Location`'s dubious-name checks (#4901) ([PR4910](https://github.com/MushroomObserver/mushroom-observer/pull/4910), @nimmolo)
- Key `NamingConsensus` vote table by canonical value, not resolved text (#4901) ([PR4912](https://github.com/MushroomObserver/mushroom-observer/pull/4912), @nimmolo)

## 2026-07-26 (deploy-2026-07-26-01-51)

- Move `Location`/`Herbarium`/`Name::Format#merge_info` to a dedicated mailer (#4901) ([PR4905](https://github.com/MushroomObserver/mushroom-observer/pull/4905), @nimmolo)

## 2026-07-26 (deploy-2026-07-26-00-37)

- Extract `RssLog::Title` PORO; move `Project::Date#date_range` to views (#4901) ([PR4903](https://github.com/MushroomObserver/mushroom-observer/pull/4903), @nimmolo)

## 2026-07-25 (deploy-2026-07-25-00-39)

- Move 5 more model-level tag resolvers to the view layer (#4901) ([PR4902](https://github.com/MushroomObserver/mushroom-observer/pull/4902), @nimmolo)

## 2026-07-24 (deploy-2026-07-24-20-39)

- Move `RssLog#detail` and `Observation#source_credit` to the view layer ([PR4900](https://github.com/MushroomObserver/mushroom-observer/pull/4900), @nimmolo)

## 2026-07-24 (deploy-2026-07-24-11-33)

- Memoize `User#in_group?` per-instance (#4896) ([PR4898](https://github.com/MushroomObserver/mushroom-observer/pull/4898), @nimmolo)

## 2026-07-24 (deploy-2026-07-24-11-29)

(no merged PRs -- asset-only or config deploy)

## 2026-07-24 (deploy-2026-07-24-05-49)

- Fix N+1 on observations index when `perform_caching` is off ([PR4897](https://github.com/MushroomObserver/mushroom-observer/pull/4897), @nimmolo)
- Establish `Components::<Model>Fragment` dispatcher pattern; restore lightbox vote UI ([PR4892](https://github.com/MushroomObserver/mushroom-observer/pull/4892), @nimmolo)

## 2026-07-23 (deploy-2026-07-23-23-28)

- Add `MO/NoRawLinkOrButtonTo` cop; convert remaining `link_to`/`button_to`/`button` call sites ([PR4883](https://github.com/MushroomObserver/mushroom-observer/pull/4883), @nimmolo)

## 2026-07-23 (deploy-2026-07-23-21-25)

- Move external-link badge tooltip to top ([PR4893](https://github.com/MushroomObserver/mushroom-observer/pull/4893), @nimmolo)

## 2026-07-23 (deploy-2026-07-23-14-47)

- Bump websocket-driver from 0.8.1 to 0.8.2 ([PR4889](https://github.com/MushroomObserver/mushroom-observer/pull/4889), @app/dependabot)

## 2026-07-23 (deploy-2026-07-23-14-44)

- Bump rails-html-sanitizer from 1.7.0 to 1.7.1 ([PR4888](https://github.com/MushroomObserver/mushroom-observer/pull/4888), @app/dependabot)

## 2026-07-23 (deploy-2026-07-23-14-37)

- Bump loofah from 2.25.1 to 2.25.2 ([PR4880](https://github.com/MushroomObserver/mushroom-observer/pull/4880), @app/dependabot)

## 2026-07-23 (deploy-2026-07-23-12-41)

- Address Copilot review comments on #4881 ([PR4882](https://github.com/MushroomObserver/mushroom-observer/pull/4882), @nimmolo)
- Fix dead lightbox caption links behind invisible `.vote-section` overlay; extract `Components::ObservationWho` ([PR4885](https://github.com/MushroomObserver/mushroom-observer/pull/4885), @mo-nathan)

## 2026-07-23 (deploy-2026-07-23-09-18)

- Reorganize observation `ExternalLinks`, `Notes` and `Specimen` sub-views ([PR4821](https://github.com/MushroomObserver/mushroom-observer/pull/4821), @nimmolo)
- Add empty-state caption + inline add-link to the observation external-links row ([PR4881](https://github.com/MushroomObserver/mushroom-observer/pull/4881), @nimmolo)

## 2026-07-23 (deploy-2026-07-23-07-49)

- Move and rubocop `Language::Exporter`/`Language::Tracking` ([PR4878](https://github.com/MushroomObserver/mushroom-observer/pull/4878), @nimmolo)
- Parallelize `lang.rake` multi-language tasks; skip entirely if no change ([PR4772](https://github.com/MushroomObserver/mushroom-observer/pull/4772), @nimmolo)
- Delete confirmed-complete parity tests ([PR4876](https://github.com/MushroomObserver/mushroom-observer/pull/4876), @nimmolo)
- Make tooltip activation properly reactive by using a Stimulus target ([PR4879](https://github.com/MushroomObserver/mushroom-observer/pull/4879), @nimmolo)

## 2026-07-23 (deploy-2026-07-23-04-04)

- Warn on dev server/console boot when Solid Cache caching is off ([PR4875](https://github.com/MushroomObserver/mushroom-observer/pull/4875), @nimmolo)
- Remove 327 unused `en.txt` tags and add regression test (part of #4867) ([PR4871](https://github.com/MushroomObserver/mushroom-observer/pull/4871), @nimmolo)
- Fix 3 flaky/stale system test assertions ([PR4874](https://github.com/MushroomObserver/mushroom-observer/pull/4874), @nimmolo)

## 2026-07-23 (deploy-2026-07-23-00-28)

- Log rsync exit code + stderr on image transfer failure ([PR4870](https://github.com/MushroomObserver/mushroom-observer/pull/4870), @mo-nathan)
- Enforce image upload size limit client-side; block over-limit submits (#4872) ([PR4873](https://github.com/MushroomObserver/mushroom-observer/pull/4873), @mo-nathan)

## 2026-07-22 (deploy-2026-07-22-18-54)

- Batch `MatrixBox`'s per-object cache reads/writes ([PR4865](https://github.com/MushroomObserver/mushroom-observer/pull/4865), @nimmolo)

## 2026-07-22 (deploy-2026-07-22-15-17)

- Add weekly `GpsLeakDetectorJob` tripwire + re-archiving `rclone_originals.sh` ([PR4860](https://github.com/MushroomObserver/mushroom-observer/pull/4860), @mo-nathan)

## 2026-07-22 (deploy-2026-07-22-08-20)

- Silence `SolidCache::Entry` query logging ([PR4863](https://github.com/MushroomObserver/mushroom-observer/pull/4863), @nimmolo)
- Bulk-delete obsolete translation strings in `Language#strip` ([PR4864](https://github.com/MushroomObserver/mushroom-observer/pull/4864), @nimmolo)

## 2026-07-21 (deploy-2026-07-21-22-50)

- `i18n`: consolidate `:ALL_CAPS`/`:all_caps` translation tags, add `Symbol#ti` ([PR4861](https://github.com/MushroomObserver/mushroom-observer/pull/4861), @nimmolo)

## 2026-07-21 (deploy-2026-07-21-17-58)

- Fix image rotation live-update broadcast (#4854) ([PR4857](https://github.com/MushroomObserver/mushroom-observer/pull/4857), @nimmolo)

## 2026-07-20 (deploy-2026-07-20-20-31)

- Skip re-sending images already in MCP ([PR4822](https://github.com/MushroomObserver/mushroom-observer/pull/4822), @JoeCohen)

## 2026-07-20 (deploy-2026-07-20-20-27)

- Force iNat confirm-form links to the UI host ([PR4810](https://github.com/MushroomObserver/mushroom-observer/pull/4810), @JoeCohen)

## 2026-07-20 (deploy-2026-07-20-14-11)

- Fix GPS-leak race between image file rewrites (`strip_gps!`, rotate) and `TransferImagesJob` ([PR4858](https://github.com/MushroomObserver/mushroom-observer/pull/4858), @mo-nathan)

## 2026-07-20 (deploy-2026-07-20-07-17)

- Extract `Components::ApplicationForm::FieldWrapperRendering` ([PR4856](https://github.com/MushroomObserver/mushroom-observer/pull/4856), @nimmolo)

## 2026-07-19 (deploy-2026-07-19-22-52)

- Notes merge: show shared values + `Concatenate All` (#4849) ([PR4851](https://github.com/MushroomObserver/mushroom-observer/pull/4851), @mo-nathan)

## 2026-07-19 (deploy-2026-07-19-17-01)

- Exempt `db/schema.rb` from the rubocop-on-save hook ([PR4845](https://github.com/MushroomObserver/mushroom-observer/pull/4845), @nimmolo)
- Coerce scalar request params so hash-shaped probes don't 500 ([PR4846](https://github.com/MushroomObserver/mushroom-observer/pull/4846), @mo-nathan)
- Fix dangling-reference leaks at their sources; report every broken-references cleanup ([PR4848](https://github.com/MushroomObserver/mushroom-observer/pull/4848), @mo-nathan)
- Scrub invalid UTF-8 from incoming requests via `Rack::UTF8Sanitizer` ([PR4847](https://github.com/MushroomObserver/mushroom-observer/pull/4847), @mo-nathan)
- Add a code-comments rule: explain *why* (only when unclear), one source of truth ([PR4850](https://github.com/MushroomObserver/mushroom-observer/pull/4850), @mo-nathan)

## 2026-07-19 (deploy-2026-07-19-07-33)

- Block cc from uselessly `cd`'ing into the current directory ([PR4838](https://github.com/MushroomObserver/mushroom-observer/pull/4838), @nimmolo)
- Sweep remaining `render(Components::X.new(...))` callers to Kit syntax ([PR4839](https://github.com/MushroomObserver/mushroom-observer/pull/4839), @nimmolo)
- Fix `script/exiftool_remote` argument handling and `Shellwords` corruption of GPS-stripping tests ([PR4836](https://github.com/MushroomObserver/mushroom-observer/pull/4836), @nimmolo)
- Rename `Components::Image::Interactive` to top-level `Components::InteractiveImage`; sweep callers to Kit syntax ([PR4841](https://github.com/MushroomObserver/mushroom-observer/pull/4841), @nimmolo)

## 2026-07-18 (deploy-2026-07-18-12-03)

- Update page upon modifying Comment ([PR4835](https://github.com/MushroomObserver/mushroom-observer/pull/4835), @JoeCohen)

## 2026-07-18 (deploy-2026-07-18-08-00)

- Extract `CoordinateFormat` module; dedupe coordinate/collection/query logic out of `Observation` and `Mappable` ([PR4837](https://github.com/MushroomObserver/mushroom-observer/pull/4837), @nimmolo)

## 2026-07-17 (deploy-2026-07-17-21-54)

- `backfill_image_dhashes.rb`: per-image output for small runs + timed progress with ETA ([PR4834](https://github.com/MushroomObserver/mushroom-observer/pull/4834), @mo-nathan)

## 2026-07-17 (deploy-2026-07-17-15-04)

- API2 `set_dhash` (site-admin, fill-null-only) + local-compute/API-push mode for `backfill_image_dhashes.rb` ([PR4831](https://github.com/MushroomObserver/mushroom-observer/pull/4831), @mo-nathan)

## 2026-07-17 (deploy-2026-07-17-13-16)

- Silence the deliberate `boom` backtrace `test_process_image_command_failure` dumps into every suite run ([PR4827](https://github.com/MushroomObserver/mushroom-observer/pull/4827), @mo-nathan)
- Scope `[image, :processed]` broadcasts/subscriptions to the image-show page only ([PR4830](https://github.com/MushroomObserver/mushroom-observer/pull/4830), @mo-nathan)

## 2026-07-17 (deploy-2026-07-17-11-02)

- Broadcast `Image` processing completion via Turbo Streams + `Matrix::Table` cache-key fixes ([PR4825](https://github.com/MushroomObserver/mushroom-observer/pull/4825), @mo-nathan)

## 2026-07-17 (deploy-2026-07-17-09-43)

- Supress brakeman in CI ([PR4823](https://github.com/MushroomObserver/mushroom-observer/pull/4823), @JoeCohen)
- Cache-bust image rendition URLs with an `updated_at` token in `Image::URL#source_url` ([PR4824](https://github.com/MushroomObserver/mushroom-observer/pull/4824), @mo-nathan)

## 2026-07-16 (deploy-2026-07-16-20-38)

- Fix `Components::Help`'s `element: :span` markers wrapping onto their own line ([PR4816](https://github.com/MushroomObserver/mushroom-observer/pull/4816), @nimmolo)

## 2026-07-16 (deploy-2026-07-16-13-56)

- Include unverifiable observations in confirm form counts and links ([PR4781](https://github.com/MushroomObserver/mushroom-observer/pull/4781), @JoeCohen)

## 2026-07-16 (deploy-2026-07-16-13-50)

- Bump websocket-driver from 0.8.0 to 0.8.1 ([PR4815](https://github.com/MushroomObserver/mushroom-observer/pull/4815), @app/dependabot)

## 2026-07-16 (deploy-2026-07-16-10-23)

- Close modal and flash the page on successful email send ([PR4802](https://github.com/MushroomObserver/mushroom-observer/pull/4802), @nimmolo)
- Eliminate the 3 remaining `Style/ClassVars` exceptions ([PR4801](https://github.com/MushroomObserver/mushroom-observer/pull/4801), @nimmolo)

## 2026-07-15 (deploy-2026-07-15-23-54)

- Confirm image transfers in the same run so fresh uploads don't stay `transferred=false` ([PR4814](https://github.com/MushroomObserver/mushroom-observer/pull/4814), @mo-nathan)

## 2026-07-15 (deploy-2026-07-15-19-12)

- Njw job fix ([PR4812](https://github.com/MushroomObserver/mushroom-observer/pull/4812), @mo-nathan)

## 2026-07-15 (deploy-2026-07-15-18-08)

- (#4735 PR 1/3) - port image processing to Ruby + job-ify `retransfer`/`verify`/`rotate`; fix #4791 image transfer race + implement target-design pipeline ([PR4751](https://github.com/MushroomObserver/mushroom-observer/pull/4751), @nimmolo)

## 2026-07-14 (deploy-2026-07-14-22-32)

- Fix `ImageDhashJob` racing `script/process_image`'s async resize/transfer ([PR4806](https://github.com/MushroomObserver/mushroom-observer/pull/4806), @nimmolo)

## 2026-07-14 (deploy-2026-07-14-20-05)

- Centralize field label resolution and colon-appending (`FieldLabelRow`, #4687) ([PR4805](https://github.com/MushroomObserver/mushroom-observer/pull/4805), @nimmolo)

## 2026-07-14 (deploy-2026-07-14-18-17)

- Scrub personal herbarium when anonymizing an account (Fixes #4793) ([PR4794](https://github.com/MushroomObserver/mushroom-observer/pull/4794), @mo-nathan)
- Use `Components::Localization` more widely, fix `image_vote_short` drift ([PR4803](https://github.com/MushroomObserver/mushroom-observer/pull/4803), @nimmolo)

## 2026-07-14 (deploy-2026-07-14-16-51)

- Hash the small rendition, never the full-size original (Fixes #4796) ([PR4799](https://github.com/MushroomObserver/mushroom-observer/pull/4799), @mo-nathan)

## 2026-07-14 (deploy-2026-07-14-16-31)

- Add title-backtick rule to gh PR/issue formatting doc ([PR4800](https://github.com/MushroomObserver/mushroom-observer/pull/4800), @nimmolo)
- Add `Components::Container`, centralize width-class handling (1/3: Container, Row, Column) ([PR4795](https://github.com/MushroomObserver/mushroom-observer/pull/4795), @nimmolo)
- Add `Components::Row`, sweep all direct `.row` call sites ([PR4798](https://github.com/MushroomObserver/mushroom-observer/pull/4798), @nimmolo)
- Add `Components::Column`, sweep `Grid::` and raw `col-*` literals onto it ([PR4797](https://github.com/MushroomObserver/mushroom-observer/pull/4797), @nimmolo)

## 2026-07-14 (deploy-2026-07-14-01-17)

- Block PII (emails) in GitHub publish commands via PreToolUse hook + rule ([PR4768](https://github.com/MushroomObserver/mushroom-observer/pull/4768), @mo-nathan)
- Retire dead v1 /api routes so /api* 404s instead of 500ing (Fixes #4782) ([PR4789](https://github.com/MushroomObserver/mushroom-observer/pull/4789), @mo-nathan)
- Retain a self-deleted user's content instead of destroying it (Fixes #4767) ([PR4790](https://github.com/MushroomObserver/mushroom-observer/pull/4790), @mo-nathan)
- Route remaining raw col-xs-* strings through Grid constants (#3797 prep) ([PR4776](https://github.com/MushroomObserver/mushroom-observer/pull/4776), @nimmolo)
- Delete dead BasePresenter and salvaged rules doc ([PR4786](https://github.com/MushroomObserver/mushroom-observer/pull/4786), @JoeCohen)

## 2026-07-12 (deploy-2026-07-12-21-16)

- Alert on nil box_area in UpdateBoxAreaAndCenterColumnsJob (#4780) ([PR4787](https://github.com/MushroomObserver/mushroom-observer/pull/4787), @mo-nathan)
- Port `check_rss_logs` script into 2 Solid Queue jobs, split by measured cost ([PR4733](https://github.com/MushroomObserver/mushroom-observer/pull/4733), @nimmolo)
- Retire check_for_orphaned_thumbnails (redundant with #4732; no legit error in 4+ years) ([PR4734](https://github.com/MushroomObserver/mushroom-observer/pull/4734), @nimmolo)

## 2026-07-12 (deploy-2026-07-12-18-51)

- Fix job-alert de-dup: anchor JobAlert backtrace per message (#4780) ([PR4785](https://github.com/MushroomObserver/mushroom-observer/pull/4785), @mo-nathan)

## 2026-07-12 (deploy-2026-07-12-18-16)

- Route review-worthy job output to #alerts via ApplicationJob#alert (#4780) ([PR4783](https://github.com/MushroomObserver/mushroom-observer/pull/4783), @mo-nathan)

## 2026-07-12 (deploy-2026-07-12-14-52)

- Port `check_for_broken_references` script into a Solid Queue job ([PR4732](https://github.com/MushroomObserver/mushroom-observer/pull/4732), @nimmolo)

## 2026-07-12 (deploy-2026-07-12-12-58)

- Retire repair_observation_vote_cache; refresh crontab; drop dead QueuedEmail config ([PR4728](https://github.com/MushroomObserver/mushroom-observer/pull/4728), @nimmolo)
- Port `refresh_name_lister_cache` script into a Solid Queue job ([PR4729](https://github.com/MushroomObserver/mushroom-observer/pull/4729), @nimmolo)
- Port `refresh_caches` script into 4 Solid Queue jobs, staggered by measured cost ([PR4730](https://github.com/MushroomObserver/mushroom-observer/pull/4730), @nimmolo)

## 2026-07-12 (deploy-2026-07-12-11-59)

- Fix Errno::ENOENT race reading blocked_ips.txt during rewrite ([PR4777](https://github.com/MushroomObserver/mushroom-observer/pull/4777), @mo-nathan)

## 2026-07-12 (deploy-2026-07-12-05-04)

- Fix Textile cache leak across sequential matrix-box renders and background jobs ([PR4774](https://github.com/MushroomObserver/mushroom-observer/pull/4774), @nimmolo)

## 2026-07-12 (deploy-2026-07-12-04-05)

- Add `PreToolUse` hook: auto `lang:update` before `rails test` if `en.txt` drifted ([PR4771](https://github.com/MushroomObserver/mushroom-observer/pull/4771), @nimmolo)
- Replace `report_email` test hack with Rails' own job-enqueue assertions ([PR4770](https://github.com/MushroomObserver/mushroom-observer/pull/4770), @nimmolo)

## 2026-07-12 (deploy-2026-07-12-02-39)

- Convert Textile's name-lookup cache to thread-local storage ([PR4741](https://github.com/MushroomObserver/mushroom-observer/pull/4741), @nimmolo)
- Convert Location's `names_for_unknown` cache to `i18n` lookup ([PR4744](https://github.com/MushroomObserver/mushroom-observer/pull/4744), @nimmolo)
- Convert UserGroup's meta-group caching to Rails.cache/Concurrent::Map ([PR4743](https://github.com/MushroomObserver/mushroom-observer/pull/4743), @nimmolo)
- Fix NoMethodError updating a naming with a blank name ([PR4769](https://github.com/MushroomObserver/mushroom-observer/pull/4769), @mo-nathan)
- Fix thread safety of Symbol's missing-tags and Language's tracking ([PR4745](https://github.com/MushroomObserver/mushroom-observer/pull/4745), @nimmolo)

## 2026-07-11 (deploy-2026-07-11-23-15)

- Add `Components::Modal::CloseButton`; route 5 Cancel-button sites through it ([PR4762](https://github.com/MushroomObserver/mushroom-observer/pull/4762), @nimmolo)
- Migrate 8 remaining `collapse`/`collapse in` sites onto `Collapsible`, update `Icon` API ([PR4761](https://github.com/MushroomObserver/mushroom-observer/pull/4761), @nimmolo)

## 2026-07-11 (deploy-2026-07-11-22-26)

- Recognize webp/heic uploads instead of mislabeling them "raw" ([PR4756](https://github.com/MushroomObserver/mushroom-observer/pull/4756), @nimmolo)
- Route raw navbar-*/btn classes through `Components::Navbar` constants and `Link` `button:`/`size:` kwargs ([PR4760](https://github.com/MushroomObserver/mushroom-observer/pull/4760), @nimmolo)

## 2026-07-11 (deploy-2026-07-11-18-30)

- Refuse to write to an orphaned RssLog (defuse ghost landmines) ([PR4764](https://github.com/MushroomObserver/mushroom-observer/pull/4764), @mo-nathan)

## 2026-07-11 (deploy-2026-07-11-00-15)

- Bump css_parser from 2.2.0 to 3.0.0 ([PR4758](https://github.com/MushroomObserver/mushroom-observer/pull/4758), @app/dependabot)

## 2026-07-10 (deploy-2026-07-10-19-46)

- Add variant: to Components::Navbar for the outer nav wrapper shape ([PR4736](https://github.com/MushroomObserver/mushroom-observer/pull/4736), @nimmolo)

## 2026-07-10 (deploy-2026-07-10-18-53)

- Prevent bulk-import notification floods (#4757) ([PR4759](https://github.com/MushroomObserver/mushroom-observer/pull/4759), @mo-nathan)

## 2026-07-09 (deploy-2026-07-09-22-56)

- Delete dead constant and smelly comment ([PR4671](https://github.com/MushroomObserver/mushroom-observer/pull/4671), @JoeCohen)

## 2026-07-09 (deploy-2026-07-09-22-26)

- Tweak Naming reason for misspelt name ([PR4630](https://github.com/MushroomObserver/mushroom-observer/pull/4630), @JoeCohen)

## 2026-07-09 (deploy-2026-07-09-22-22)

- Fix unimportable iconic_taxa ([PR4712](https://github.com/MushroomObserver/mushroom-observer/pull/4712), @JoeCohen)

## 2026-07-09 (deploy-2026-07-09-21-26)

- Fix handling of licensed param in URL ([PR4719](https://github.com/MushroomObserver/mushroom-observer/pull/4719), @JoeCohen)

## 2026-07-09 (deploy-2026-07-09-21-07)

- Stagger the two midnight :maintenance jobs off collision marks ([PR4746](https://github.com/MushroomObserver/mushroom-observer/pull/4746), @nimmolo)
- Rewrite Vote's `observation_views` joins in Arel ([PR4731](https://github.com/MushroomObserver/mushroom-observer/pull/4731), @nimmolo)

## 2026-07-09 (deploy-2026-07-09-20-10)

- Guard against Solid Queue thread-pool-vs-DB-pool crash (prod incident) ([PR4750](https://github.com/MushroomObserver/mushroom-observer/pull/4750), @nimmolo)

## 2026-07-09 (deploy-2026-07-09-15-06)

- .claude hooks: Run git commit before blocking a behind-branch push ([PR4742](https://github.com/MushroomObserver/mushroom-observer/pull/4742), @nimmolo)
- Remove dead `@@last_update` class variable from Language ([PR4739](https://github.com/MushroomObserver/mushroom-observer/pull/4739), @nimmolo)
- Delete `RunLevel` entirely ([PR4740](https://github.com/MushroomObserver/mushroom-observer/pull/4740), @nimmolo)
- Halt daily "reviewed observation  (insert)" ([PR4702](https://github.com/MushroomObserver/mushroom-observer/pull/4702), @JoeCohen)

## 2026-07-09 (deploy-2026-07-09-04-15)

- Add Components::InputGroup and Components::ButtonGroup ([PR4722](https://github.com/MushroomObserver/mushroom-observer/pull/4722), @nimmolo)
- Fix strip_checkpoint SQL syntax error; document db/ checkpoint scripts ([PR4725](https://github.com/MushroomObserver/mushroom-observer/pull/4725), @nimmolo)
- Add Components::Navbar, InputGroup, and ButtonGroup ([PR4721](https://github.com/MushroomObserver/mushroom-observer/pull/4721), @nimmolo)
- Split Solid Queue into default + maintenance worker pools ([PR4727](https://github.com/MushroomObserver/mushroom-observer/pull/4727), @nimmolo)

## 2026-07-08 (deploy-2026-07-08-18-08)

- Rubocop 1.88.2 ([PR4724](https://github.com/MushroomObserver/mushroom-observer/pull/4724), @JoeCohen)
- Fix tracker never done ([PR4669](https://github.com/MushroomObserver/mushroom-observer/pull/4669), @JoeCohen)

## 2026-07-08 (deploy-2026-07-08-10-33)

- Make lang-tag test failures self-explanatory ([PR4723](https://github.com/MushroomObserver/mushroom-observer/pull/4723), @nimmolo)

## 2026-07-08 (deploy-2026-07-08-09-03)

- Split all Name::* module tests out of name_test.rb (#4708) ([PR4711](https://github.com/MushroomObserver/mushroom-observer/pull/4711), @nimmolo)

## 2026-07-07 (deploy-2026-07-07-21-55)

- Add (corrected) API2 error-constructor contract test lost from #4694 ([PR4718](https://github.com/MushroomObserver/mushroom-observer/pull/4718), @mo-nathan)
- DRY up observation field-slip handling; fix invalid-code path on create ([PR4715](https://github.com/MushroomObserver/mushroom-observer/pull/4715), @mo-nathan)
- Bump brakeman to 8.0.5 ([PR4698](https://github.com/MushroomObserver/mushroom-observer/pull/4698), @JoeCohen)
- Bump RuboCop to 1.88.1 ([PR4699](https://github.com/MushroomObserver/mushroom-observer/pull/4699), @JoeCohen)
- Defer field-slip creation in the add-images flow (prevent orphans) ([PR4717](https://github.com/MushroomObserver/mushroom-observer/pull/4717), @mo-nathan)

## 2026-07-06 (deploy-2026-07-06-23-12)

- Remove user_* viewer-format methods; thread user through bare methods ([PR4703](https://github.com/MushroomObserver/mushroom-observer/pull/4703), @nimmolo)

## 2026-07-06 (deploy-2026-07-06-22-14)

- Delete User.current entirely - APIKey/RssLog/SpeciesList/RtfLabels/PatternSearch + the whole mechanism ([PR4705](https://github.com/MushroomObserver/mushroom-observer/pull/4705), @nimmolo)

## 2026-07-06 (deploy-2026-07-06-17-45)

- Remove dead ActionView::LogSubscriber override ([PR4701](https://github.com/MushroomObserver/mushroom-observer/pull/4701), @mo-nathan)
- Convert Comment/Herbarium/GlossaryTerm/NameTracker/TranslationString/UserStats/LanguageExporter off User.current ([PR4700](https://github.com/MushroomObserver/mushroom-observer/pull/4700), @nimmolo)

## 2026-07-06 (deploy-2026-07-06-12-07)

- Coverage cleanup: remove dead API2::ParameterDeclaration duplicate ([PR4694](https://github.com/MushroomObserver/mushroom-observer/pull/4694), @mo-nathan)
- Remove remaining User.current reads (viewer-format) from Observation, Occurrence, Naming, Vote, Image ([PR4697](https://github.com/MushroomObserver/mushroom-observer/pull/4697), @nimmolo)

## 2026-07-06 (deploy-2026-07-06-06-25)

- Remove User.current attribution from Observation, Occurrence, Naming, Vote, Image ([PR4696](https://github.com/MushroomObserver/mushroom-observer/pull/4696), @nimmolo)

## 2026-07-06 (deploy-2026-07-06-05-15)

- Make Location display-name/place-name and sort order viewer-aware, not global ([PR4695](https://github.com/MushroomObserver/mushroom-observer/pull/4695), @nimmolo)

## 2026-07-06 (deploy-2026-07-06-02-00)

- Remove User.current from Name, NameDescription, Location, LocationDescription, and Interest ([PR4693](https://github.com/MushroomObserver/mushroom-observer/pull/4693), @nimmolo)

## 2026-07-05 (deploy-2026-07-05-23-22)

- Wrap Name::Merge#merge in a transaction; close correct_spelling race ([PR4689](https://github.com/MushroomObserver/mushroom-observer/pull/4689), @nimmolo)

## 2026-07-05 (deploy-2026-07-05-22-45)

- Cover uncovered app/models/image.rb lines; remove dead unique_format_name branch ([PR4692](https://github.com/MushroomObserver/mushroom-observer/pull/4692), @mo-nathan)
- Close remaining User.current reads in controllers/views; drop cop exemptions ([PR4688](https://github.com/MushroomObserver/mushroom-observer/pull/4688), @nimmolo)

## 2026-07-05 (deploy-2026-07-05-20-41)

- Reflection-resolution infrastructure: image dHash, iNat obs cache, reflected_at (#4585 phase 1) ([PR4677](https://github.com/MushroomObserver/mushroom-observer/pull/4677), @mo-nathan)

## 2026-07-05 (deploy-2026-07-05-20-26)

- Route bare Bootstrap col-* classes through Grid constants (#4663) ([PR4684](https://github.com/MushroomObserver/mushroom-observer/pull/4684), @nimmolo)

## 2026-07-05 (deploy-2026-07-05-19-38)

- Stop eager-loading .namings/.observations on Name show/edit/update ([PR4685](https://github.com/MushroomObserver/mushroom-observer/pull/4685), @nimmolo)

## 2026-07-05 (deploy-2026-07-05-18-41)

- Convert all Action Mailer templates from ERB to Phlex (#4676) ([PR4683](https://github.com/MushroomObserver/mushroom-observer/pull/4683), @nimmolo)

## 2026-07-05 (deploy-2026-07-05-07-09)

- Fix block_python.sh false positives; document the per-line coveralls endpoint ([PR4682](https://github.com/MushroomObserver/mushroom-observer/pull/4682), @nimmolo)
- Sidebar navbar/list-group split; ListGroup::LinkItem; language picker as inline collapse ([PR4675](https://github.com/MushroomObserver/mushroom-observer/pull/4675), @nimmolo)
- Merge Help::Block/Note into Components::Help; fix Kit-sugar gap in application_form/ ([PR4680](https://github.com/MushroomObserver/mushroom-observer/pull/4680), @nimmolo)

## 2026-07-04 (deploy-2026-07-04-22-39)

- Merge Phlex docs into phlex_reference.md; remove Views Kit-syntax extension ([PR4678](https://github.com/MushroomObserver/mushroom-observer/pull/4678), @nimmolo)

## 2026-07-04 (deploy-2026-07-04-15-26)

- Gate iNat imports on ExternalLinks; add recheck-all checkbox ([PR4665](https://github.com/MushroomObserver/mushroom-observer/pull/4665), @mo-nathan)

## 2026-07-04 (deploy-2026-07-04-07-18)

- Kit-syntax Icon sweep + Link/Tab conversions; fix stripped-icon regressions ([PR4670](https://github.com/MushroomObserver/mushroom-observer/pull/4670), @nimmolo)
- Flatten Components::ListGroup::Base to top-level ListGroup Kit component; sweep callers ([PR4672](https://github.com/MushroomObserver/mushroom-observer/pull/4672), @nimmolo)

## 2026-07-03 (deploy-2026-07-03-22-27)

- Replace hand-set Tab ids with the existing auto-derived class ([PR4661](https://github.com/MushroomObserver/mushroom-observer/pull/4661), @nimmolo)
- Sweep PaginatedResults callers to Kit syntax ([PR4668](https://github.com/MushroomObserver/mushroom-observer/pull/4668), @nimmolo)
- Fix 2 failing system tests: missing help id, stale .d-none selector ([PR4662](https://github.com/MushroomObserver/mushroom-observer/pull/4662), @nimmolo)
- location form: surface Google Maps geocode failures (#4535) ([PR4546](https://github.com/MushroomObserver/mushroom-observer/pull/4546), @nimmolo)

## 2026-07-03 (deploy-2026-07-03-22-10)

- Sweep 8 small top-level components to Kit syntax ([PR4667](https://github.com/MushroomObserver/mushroom-observer/pull/4667), @nimmolo)

## 2026-07-03 (deploy-2026-07-03-18-06)

- Persist inat_username before building imported observations ([PR4660](https://github.com/MushroomObserver/mushroom-observer/pull/4660), @mo-nathan)

## 2026-07-03 (deploy-2026-07-03-17-26)

- Fix UserStats per-field counter sign on delete ([PR4658](https://github.com/MushroomObserver/mushroom-observer/pull/4658), @mo-nathan)
- Gate SolidQueue Puma plugin to non-production ([PR4657](https://github.com/MushroomObserver/mushroom-observer/pull/4657), @mo-nathan)

## 2026-07-03 (deploy-2026-07-03-15-09)

- Track ignored iNat obs counts; show summary on Done ([PR4634](https://github.com/MushroomObserver/mushroom-observer/pull/4634), @nimmolo)
- iNaturalist imports: one persistent record per import ([PR4644](https://github.com/MushroomObserver/mushroom-observer/pull/4644), @mo-nathan)
- Batch iNat imports and broadcast `InatImport` status via Turbo, removing `InatImportJobTracker` ([PR4632](https://github.com/MushroomObserver/mushroom-observer/pull/4632), @nimmolo)

## 2026-07-03 (deploy-2026-07-03-14-16)

- Restore Turbo on CRUD buttons; scope session-toggle opt-out narrowly ([PR4655](https://github.com/MushroomObserver/mushroom-observer/pull/4655), @nimmolo)
- Turbo Stream in-place update for reviewer export-status toggle ([PR4654](https://github.com/MushroomObserver/mushroom-observer/pull/4654), @nimmolo)

## 2026-07-03 (deploy-2026-07-03-05-46)

- Add Components::Modal dispatcher; sweep callers to Kit/dispatcher API ([PR4650](https://github.com/MushroomObserver/mushroom-observer/pull/4650), @nimmolo)
- Add variant:/identifier: props to Components::Table; sweep callers to Kit syntax ([PR4651](https://github.com/MushroomObserver/mushroom-observer/pull/4651), @nimmolo)
- Prune phlex_conversions.md: remove ERB-specific sections ([PR4649](https://github.com/MushroomObserver/mushroom-observer/pull/4649), @nimmolo)
- Sweep render(Components::Alert.new) → Alert() Kit syntax ([PR4652](https://github.com/MushroomObserver/mushroom-observer/pull/4652), @nimmolo)
- Sweep render(Components::Button.new) → Button() Kit syntax ([PR4653](https://github.com/MushroomObserver/mushroom-observer/pull/4653), @nimmolo)

## 2026-07-03 (deploy-2026-07-03-01-45)

- BS4 pre-migration cleanup: panel-title, Accordion component, table column widths ([PR4645](https://github.com/MushroomObserver/mushroom-observer/pull/4645), @nimmolo)
- Link dispatcher + Kit sweep; fix Turbo/dropdown/logout regressions ([PR4648](https://github.com/MushroomObserver/mushroom-observer/pull/4648), @nimmolo)

## 2026-07-02 (deploy-2026-07-02-15-50)

- Sweep plain(" ") → whitespace in components and views ([PR4641](https://github.com/MushroomObserver/mushroom-observer/pull/4641), @nimmolo)

## 2026-07-02 (deploy-2026-07-02-14-31)

- Fix long copyright_holder error ([PR4643](https://github.com/MushroomObserver/mushroom-observer/pull/4643), @JoeCohen)

## 2026-07-02 (deploy-2026-07-02-14-27)

- Batch iNat imports and broadcast `InatImport` status via Turbo, removing `InatImportJobTracker` ([PR3107](https://github.com/MushroomObserver/mushroom-observer/pull/3107), @nimmolo)
- Close 3 coverage gaps (1 dead branch removed, 2 tested) ([PR4619](https://github.com/MushroomObserver/mushroom-observer/pull/4619), @mo-nathan)
- Batch iNat imports and broadcast `InatImport` status via Turbo, removing `InatImportJobTracker` ([PR4629](https://github.com/MushroomObserver/mushroom-observer/pull/4629), @nimmolo)
- Remove feature code accidentally pushed to main ([PR4633](https://github.com/MushroomObserver/mushroom-observer/pull/4633), @nimmolo)

## 2026-06-30 (deploy-2026-06-30-18-24)

- Glyphicon + raw button cleanup in Phlex views ([PR4623](https://github.com/MushroomObserver/mushroom-observer/pull/4623), @nimmolo)

## 2026-06-30 (deploy-2026-06-30-14-46)

- Fix nil observation_id in add_missing_views_corresponding_to_votes ([PR4600](https://github.com/MushroomObserver/mushroom-observer/pull/4600), @JoeCohen)
- Return message without throwing Error for bad /api2 root requests ([PR4612](https://github.com/MushroomObserver/mushroom-observer/pull/4612), @JoeCohen)
- Allow iNat import to match misspelled MO names by text_name ([PR4614](https://github.com/MushroomObserver/mushroom-observer/pull/4614), @JoeCohen)

## 2026-06-29 (deploy-2026-06-29-22-04)

- Fix 500 on unauthenticated request to  engine controller  ([PR4622](https://github.com/MushroomObserver/mushroom-observer/pull/4622), @JoeCohen)

## 2026-06-29 (deploy-2026-06-29-16-16)

- Drop dead skip_inat_update column; canonicalize schema.rb to production ([PR4626](https://github.com/MushroomObserver/mushroom-observer/pull/4626), @mo-nathan)

## 2026-06-29 (deploy-2026-06-29-13-14)

- Materialize MO↔iNat correspondences as typed ExternalLinks (#4565) ([PR4601](https://github.com/MushroomObserver/mushroom-observer/pull/4601), @mo-nathan)

## 2026-06-28 (deploy-2026-06-28-20-13)

- Extract Matrix::Box footer rendering into Footer module ([PR4618](https://github.com/MushroomObserver/mushroom-observer/pull/4618), @nimmolo)
- Add Grid constants for Bootstrap 3→4 column class migration ([PR4620](https://github.com/MushroomObserver/mushroom-observer/pull/4620), @nimmolo)

## 2026-06-28 (deploy-2026-06-28-13-04)

- Ignore invalid q[model] params instead of 500ing ([PR4615](https://github.com/MushroomObserver/mushroom-observer/pull/4615), @mo-nathan)
- Sweep raw target="_blank" anchors → Link::External / Link::Get ([PR4607](https://github.com/MushroomObserver/mushroom-observer/pull/4607), @nimmolo)
- Add Components::CollapseDiv; convert 6 inline collapse divs ([PR4616](https://github.com/MushroomObserver/mushroom-observer/pull/4616), @nimmolo)

## 2026-06-27 (deploy-2026-06-27-01-54)

- URL mode imports ([PR4478](https://github.com/MushroomObserver/mushroom-observer/pull/4478), @JoeCohen)

## 2026-06-26 (deploy-2026-06-26-18-26)

- Fix description show-page OOM: stop preloading all_users on public descriptions ([PR4608](https://github.com/MushroomObserver/mushroom-observer/pull/4608), @mo-nathan)
- Improvements to display of sequencing data ([PR4580](https://github.com/MushroomObserver/mushroom-observer/pull/4580), @jonkiparsky)

## 2026-06-26 (deploy-2026-06-26-17-47)

- Sweep raw glyphicon class strings → Icon components ([PR4606](https://github.com/MushroomObserver/mushroom-observer/pull/4606), @nimmolo)

## 2026-06-26 (deploy-2026-06-26-17-12)

- Refactor Map::Popup: use link components, move bbox query creation to caller ([PR4604](https://github.com/MushroomObserver/mushroom-observer/pull/4604), @nimmolo)

## 2026-06-26 (deploy-2026-06-26-11-11)

- Fix stale data-target assertions after collapse-trigger change ([PR4605](https://github.com/MushroomObserver/mushroom-observer/pull/4605), @nimmolo)

## 2026-06-26 (deploy-2026-06-26-10-55)

- Fix `InterestIcons`: one `<li>` per link ([PR4603](https://github.com/MushroomObserver/mushroom-observer/pull/4603), @nimmolo)

## 2026-06-26 (deploy-2026-06-26-10-53)

- Add pagination-strip weaving tests to PaginatedResultsTest ([PR4602](https://github.com/MushroomObserver/mushroom-observer/pull/4602), @nimmolo)

## 2026-06-26 (deploy-2026-06-26-09-29)

- Document Postfix→Gmail authenticated relay in production install ([PR4596](https://github.com/MushroomObserver/mushroom-observer/pull/4596), @mo-nathan)
- Add Link::CollapseToggle; sweep hand-rolled collapse triggers ([PR4594](https://github.com/MushroomObserver/mushroom-observer/pull/4594), @nimmolo)

## 2026-06-24 (deploy-2026-06-24-23-21)

- Extract paginated_results into Components::PaginatedResults ([PR4593](https://github.com/MushroomObserver/mushroom-observer/pull/4593), @nimmolo)

## 2026-06-24 (deploy-2026-06-24-22-18)

- Real-time Slack error alerts via exception_notification (#4595) ([PR4598](https://github.com/MushroomObserver/mushroom-observer/pull/4598), @mo-nathan)

## 2026-06-24 (deploy-2026-06-24-17-27)

- Sweep glyphicon / help-note / help-block / list-group raw class strings → Phlex components ([PR4588](https://github.com/MushroomObserver/mushroom-observer/pull/4588), @nimmolo)

## 2026-06-24 (deploy-2026-06-24-15-16)

- Bump actions/checkout from 6 to 7 ([PR4587](https://github.com/MushroomObserver/mushroom-observer/pull/4587), @app/dependabot)
- Bump nokogiri from 1.19.3 to 1.19.4 ([PR4581](https://github.com/MushroomObserver/mushroom-observer/pull/4581), @app/dependabot)
- Bump faraday from 2.14.2 to 2.14.3 ([PR4582](https://github.com/MushroomObserver/mushroom-observer/pull/4582), @app/dependabot)
- Bump concurrent-ruby from 1.3.6 to 1.3.7 ([PR4586](https://github.com/MushroomObserver/mushroom-observer/pull/4586), @app/dependabot)

## 2026-06-24 (deploy-2026-06-24-14-35)

- Fix obs-show crash on iNat import links (nil url) ([PR4590](https://github.com/MushroomObserver/mushroom-observer/pull/4590), @mo-nathan)

## 2026-06-24 (deploy-2026-06-24-04-33)

- Button component - new API and sweeping refactor ([PR4570](https://github.com/MushroomObserver/mushroom-observer/pull/4570), @nimmolo)

## 2026-06-22 (deploy-2026-06-22-21-58)

- Fix header icon/sorter regressions + flaky herbarium system test ([PR4577](https://github.com/MushroomObserver/mushroom-observer/pull/4577), @nimmolo)

## 2026-06-22 (deploy-2026-06-22-00-40)

- Add production-log route analysis scripts ([PR4573](https://github.com/MushroomObserver/mushroom-observer/pull/4573), @mo-nathan)
- Fix N+1 on observations/species_lists edit page ([PR4574](https://github.com/MushroomObserver/mushroom-observer/pull/4574), @mo-nathan)

## 2026-06-21 (deploy-2026-06-21-14-02)

- Drop Source table + source columns (#4299 phase 2) ([PR4572](https://github.com/MushroomObserver/mushroom-observer/pull/4572), @mo-nathan)

## 2026-06-21 (deploy-2026-06-21-13-54)

- Remediate orphaned iNat-imported images (#4543) ([PR4567](https://github.com/MushroomObserver/mushroom-observer/pull/4567), @mo-nathan)
- Revert #4567 — one-time remediation script + data file ([PR4571](https://github.com/MushroomObserver/mushroom-observer/pull/4571), @mo-nathan)
- Consolidate Source into ExternalLink relationship model (#4299 phase 1) ([PR4568](https://github.com/MushroomObserver/mushroom-observer/pull/4568), @mo-nathan)

## 2026-06-19 (deploy-2026-06-19-21-01)

- CRUD refactor: split InfoController#textile_sandbox into GET new + POST create ([PR4569](https://github.com/MushroomObserver/mushroom-observer/pull/4569), @nimmolo)

## 2026-06-19 (deploy-2026-06-19-17-16)

- Strip provenance-only history comments from Phlex views ([PR4566](https://github.com/MushroomObserver/mushroom-observer/pull/4566), @nimmolo)

## 2026-06-19 (deploy-2026-06-19-11-39)

- Sweep content_for helpers into Views::FullPageBase per-concern modules ([PR4564](https://github.com/MushroomObserver/mushroom-observer/pull/4564), @nimmolo)

## 2026-06-18 (deploy-2026-06-18-17-15)

- Promote Descriptions::Versions::Show to Views::FullPageBase ([PR4563](https://github.com/MushroomObserver/mushroom-observer/pull/4563), @nimmolo)

## 2026-06-18 (deploy-2026-06-18-16-42)

- Rip /search/advanced (the new Advanced is the per-controller search forms) ([PR4562](https://github.com/MushroomObserver/mushroom-observer/pull/4562), @nimmolo)
- Convert application + printable layouts to Phlex ([PR4561](https://github.com/MushroomObserver/mushroom-observer/pull/4561), @nimmolo)

## 2026-06-18 (deploy-2026-06-18-00-48)

- Update the nginx.conf and README_GOOGLE_CLOUD_STORAGE ([PR4558](https://github.com/MushroomObserver/mushroom-observer/pull/4558), @mo-nathan)
- Phlex hygiene: helper sweep + layouts/header + modal title + sorter/dropdown ([PR4557](https://github.com/MushroomObserver/mushroom-observer/pull/4557), @nimmolo)
- Components folder reorg (1/2): image/ + carousel/ + form_carousel/ + link/ + button/ + form/ + Icon ([PR4559](https://github.com/MushroomObserver/mushroom-observer/pull/4559), @nimmolo)
- test infra: parallel system tests + per-worker Capybara port ([PR4523](https://github.com/MushroomObserver/mushroom-observer/pull/4523), @nimmolo)
- Components folder reorg (2/2) + Components::Carousel primitive extraction ([PR4560](https://github.com/MushroomObserver/mushroom-observer/pull/4560), @nimmolo)

## 2026-06-17 (deploy-2026-06-17-05-48)

- rubocop follow-up A+B: TestMethodName via private + small-count manual cops ([PR4544](https://github.com/MushroomObserver/mushroom-observer/pull/4544), @nimmolo)
- rubocop: wire in rubocop-capybara + rubocop-minitest ([PR4539](https://github.com/MushroomObserver/mushroom-observer/pull/4539), @nimmolo)

## 2026-06-17 (deploy-2026-06-17-00-00)

- Record iNat image provenance structurally, not in original_name (#4529) ([PR4555](https://github.com/MushroomObserver/mushroom-observer/pull/4555), @mo-nathan)

## 2026-06-16 (deploy-2026-06-16-23-38)

- Add classification provenance audit script (roadmap Phase 2) ([PR4550](https://github.com/MushroomObserver/mushroom-observer/pull/4550), @mo-nathan)
- controllers: ERB→Phlex sweep for licenses, publications, interests, support, theme, policy, info, locations ([PR4547](https://github.com/MushroomObserver/mushroom-observer/pull/4547), @nimmolo)
- controllers: ERB→Phlex for rss_logs, sequences, translations, users + observation_views turbo_stream ([PR4548](https://github.com/MushroomObserver/mushroom-observer/pull/4548), @nimmolo)

## 2026-06-16 (deploy-2026-06-16-19-39)

- iNat write-back: admin per-import checkbox (replaces env toggle) ([PR4545](https://github.com/MushroomObserver/mushroom-observer/pull/4545), @mo-nathan)
- Guard nil verified date in user profile heading (#4551) ([PR4552](https://github.com/MushroomObserver/mushroom-observer/pull/4552), @mo-nathan)
- Fix blank-line handling in observation notes (import cleanup + show display) (#4536) ([PR4537](https://github.com/MushroomObserver/mushroom-observer/pull/4537), @mo-nathan)

## 2026-06-15 (deploy-2026-06-15-22-58)

- Containerize app for local development ([PR4512](https://github.com/MushroomObserver/mushroom-observer/pull/4512), @jonkiparsky)
- Read-only iNat import audit + migration inventory (#4213) ([PR4528](https://github.com/MushroomObserver/mushroom-observer/pull/4528), @mo-nathan)
- Document: never `cd` back to the session working directory in Bash ([PR4542](https://github.com/MushroomObserver/mushroom-observer/pull/4542), @mo-nathan)
- Serve maintenance-page logo past the maintenance gate (#4312) ([PR4541](https://github.com/MushroomObserver/mushroom-observer/pull/4541), @mo-nathan)
- ERB -> Phlex: images (index / show / EXIF / emails / licenses / votes) ([PR4538](https://github.com/MushroomObserver/mushroom-observer/pull/4538), @nimmolo)

## 2026-06-15 (deploy-2026-06-15-15-12)

(no merged PRs -- asset-only or config deploy)

## 2026-06-15 (deploy-2026-06-15-15-09)

- hooks: orphan-render guard + view_context ban + Phlex view fixes ([PR4540](https://github.com/MushroomObserver/mushroom-observer/pull/4540), @nimmolo)

## 2026-06-15 (deploy-2026-06-15-13-22)

- ERB -> Phlex: herbaria (index / show / curator_table) + Table heading row ([PR4532](https://github.com/MushroomObserver/mushroom-observer/pull/4532), @nimmolo)

## 2026-06-15 (deploy-2026-06-15-11-19)

- Honor "Species Name Override" from iNat (#4533) ([PR4534](https://github.com/MushroomObserver/mushroom-observer/pull/4534), @mo-nathan)

## 2026-06-14 (deploy-2026-06-14-23-08)

- phlex guardrails: helpers ban + on-save _Any/raw/html_safe hook + TrustedHtml move ([PR4531](https://github.com/MushroomObserver/mushroom-observer/pull/4531), @nimmolo)

## 2026-06-14 (deploy-2026-06-14-21-53)

- ERB -> Phlex: contributors index + legend ([PR4526](https://github.com/MushroomObserver/mushroom-observer/pull/4526), @nimmolo)
- ERB -> Phlex: glossary_terms (index / show / form / versions / images-remove) ([PR4527](https://github.com/MushroomObserver/mushroom-observer/pull/4527), @nimmolo)

## 2026-06-14 (deploy-2026-06-14-13-18)

- claude: add Rubocop pre-commit + Coveralls post-push hooks ([PR4525](https://github.com/MushroomObserver/mushroom-observer/pull/4525), @nimmolo)
- Weight imported naming votes by source confidence (#4212) ([PR4509](https://github.com/MushroomObserver/mushroom-observer/pull/4509), @mo-nathan)

## 2026-06-14 (deploy-2026-06-14-08-44)

- admin: convert remaining ERBs in app/views/controllers/admin to Phlex ([PR4521](https://github.com/MushroomObserver/mushroom-observer/pull/4521), @nimmolo)
- articles: convert app/views/controllers/articles ERBs to Phlex ([PR4522](https://github.com/MushroomObserver/mushroom-observer/pull/4522), @nimmolo)
- test: sweep assert_template → stable element / body-class assertions ([PR4524](https://github.com/MushroomObserver/mushroom-observer/pull/4524), @nimmolo)

## 2026-06-13 (deploy-2026-06-13-21-34)

- Import observations with by-nc-sa license ([PR4520](https://github.com/MushroomObserver/mushroom-observer/pull/4520), @JoeCohen)

## 2026-06-13 (deploy-2026-06-13-15-49)

- bump mo_acts_as_versioned 0.8.0 + drop :extend blocks ([PR4515](https://github.com/MushroomObserver/mushroom-observer/pull/4515), @nimmolo)
- Fix description form double-escaping source-name HTML entities ([PR4495](https://github.com/MushroomObserver/mushroom-observer/pull/4495), @mo-nathan)
- strict_loading: extract subtrees, refetch for destroy, fix stale Location merge ([PR4518](https://github.com/MushroomObserver/mushroom-observer/pull/4518), @nimmolo)

## 2026-06-13 (deploy-2026-06-13-09-29)

- enforce strict_loading_by_default on 9 low-risk models (#4510) ([PR4513](https://github.com/MushroomObserver/mushroom-observer/pull/4513), @nimmolo)

## 2026-06-13 (deploy-2026-06-13-06-44)

- herbarium_records + collection_numbers: convert all ERBs to Phlex ([PR4507](https://github.com/MushroomObserver/mushroom-observer/pull/4507), @nimmolo)
- Phlex views: queries → controllers; ContentPadded + MatrixTable sweep; rename ObjectFooter → VersionsFooter ([PR4508](https://github.com/MushroomObserver/mushroom-observer/pull/4508), @nimmolo)

## 2026-06-11 (deploy-2026-06-11-20-26)

- Collector identity, contract release: strip notes + enforce single source (#4211) ([PR4499](https://github.com/MushroomObserver/mushroom-observer/pull/4499), @mo-nathan)

## 2026-06-11 (deploy-2026-06-11-20-07)

- Collector identity, expand release: column + backfill (invisible) (#4211) ([PR4452](https://github.com/MushroomObserver/mushroom-observer/pull/4452), @mo-nathan)

## 2026-06-11 (deploy-2026-06-11-18-01)

- projects: convert remaining ERBs under views/controllers/projects to Phlex ([PR4505](https://github.com/MushroomObserver/mushroom-observer/pull/4505), @nimmolo)

## 2026-06-11 (deploy-2026-06-11-17-37)

- account: convert every ERB under controllers/account to Phlex ([PR4503](https://github.com/MushroomObserver/mushroom-observer/pull/4503), @nimmolo)

## 2026-06-11 (deploy-2026-06-11-15-53)

- top_nav: convert search_bar ERB to Phlex + split out PatternSearchForm ([PR4502](https://github.com/MushroomObserver/mushroom-observer/pull/4502), @nimmolo)

## 2026-06-11 (deploy-2026-06-11-14-57)

- projects/list_item: drop .list-group-item wrapper, let caller supply it ([PR4504](https://github.com/MushroomObserver/mushroom-observer/pull/4504), @nimmolo)

## 2026-06-11 (deploy-2026-06-11-13-31)

- field_slips: convert all controllers/field_slips ERBs to Phlex ([PR4501](https://github.com/MushroomObserver/mushroom-observer/pull/4501), @nimmolo)

## 2026-06-11 (deploy-2026-06-11-11-51)

- Purge register_output_helper from Phlex files (most are dead/superseded) ([PR4500](https://github.com/MushroomObserver/mushroom-observer/pull/4500), @nimmolo)

## 2026-06-11 (deploy-2026-06-11-03-20)

- Accept whitespace-delimited iNat ID lists and ignore header rows ([PR4468](https://github.com/MushroomObserver/mushroom-observer/pull/4468), @JoeCohen)

## 2026-06-10 (deploy-2026-06-10-22-05)

- Index users.inat_username and users.name for collector lookups ([PR4498](https://github.com/MushroomObserver/mushroom-observer/pull/4498), @mo-nathan)

## 2026-06-10 (deploy-2026-06-10-18-32)

- observations: drop unused user: prop from 4 Phlex views ([PR4496](https://github.com/MushroomObserver/mushroom-observer/pull/4496), @nimmolo)

## 2026-06-10 (deploy-2026-06-10-17-53)

- Drop check_index_sorting test helper + its callers + docstring refs ([PR4497](https://github.com/MushroomObserver/mushroom-observer/pull/4497), @nimmolo)

## 2026-06-10 (deploy-2026-06-10-11-15)

- Components::Map: consolidate make_map + helpers into one component ([PR4489](https://github.com/MushroomObserver/mushroom-observer/pull/4489), @nimmolo)

## 2026-06-10 (deploy-2026-06-10-00-33)

- Fix Name show panels rendering HTML entity codes instead of characters (#4491) ([PR4494](https://github.com/MushroomObserver/mushroom-observer/pull/4494), @mo-nathan)

## 2026-06-10 (deploy-2026-06-10-00-03)

- Bump net-imap from 0.6.4 to 0.6.4.1 ([PR4490](https://github.com/MushroomObserver/mushroom-observer/pull/4490), @app/dependabot)
- Bump puma from 8.0.1 to 8.0.2 ([PR4487](https://github.com/MushroomObserver/mushroom-observer/pull/4487), @app/dependabot)
- Fix advanced search: JSON-encode Stimulus Array values in top_nav (#4492) ([PR4493](https://github.com/MushroomObserver/mushroom-observer/pull/4493), @mo-nathan)

## 2026-06-09 (deploy-2026-06-09-18-50)

- Add request-scoped current_user + current_query helpers for Phlex views ([PR4488](https://github.com/MushroomObserver/mushroom-observer/pull/4488), @nimmolo)

## 2026-06-09 (deploy-2026-06-09-18-47)

- Phlexify observations/index + fix the MatrixBox cache pre-check ([PR4483](https://github.com/MushroomObserver/mushroom-observer/pull/4483), @nimmolo)

## 2026-06-08 (deploy-2026-06-08-22-17)

- Allow Name citation to be clickable link ([PR4486](https://github.com/MushroomObserver/mushroom-observer/pull/4486), @JoeCohen)

## 2026-06-08 (deploy-2026-06-08-15-20)

- Phlexify all remaining form-rendering ERBs under /observations ([PR4482](https://github.com/MushroomObserver/mushroom-observer/pull/4482), @nimmolo)

## 2026-06-08 (deploy-2026-06-08-15-00)

- Move context_nav into layout homes; phlexify top_nav; add Components::Dropdown ([PR4481](https://github.com/MushroomObserver/mushroom-observer/pull/4481), @nimmolo)

## 2026-06-08 (deploy-2026-06-08-12-05)

- Phlexify header partials + Header::FiltersHelper filter-caption chain ([PR4460](https://github.com/MushroomObserver/mushroom-observer/pull/4460), @nimmolo)
- Merge nimmo-phlexify-namings-domain into main (brings #4460's Phlex header + 12 other commits) ([PR4480](https://github.com/MushroomObserver/mushroom-observer/pull/4480), @nimmolo)

## 2026-06-08 (deploy-2026-06-08-11-11)

- Project.admin_power? requires the obs owner to be a trusting member (#4439) ([PR4446](https://github.com/MushroomObserver/mushroom-observer/pull/4446), @mo-nathan)

## 2026-06-08 (deploy-2026-06-08-05-34)

- species_lists/index + listing: use Components::ListGroup ([PR4476](https://github.com/MushroomObserver/mushroom-observer/pull/4476), @nimmolo)
- phlex.rb: drop dead Tabs::*Helper auto-include block ([PR4479](https://github.com/MushroomObserver/mushroom-observer/pull/4479), @nimmolo)

## 2026-06-08 (deploy-2026-06-08-04-33)

- Index sort options: hoist to controllers; delete 13 helpers ([PR4477](https://github.com/MushroomObserver/mushroom-observer/pull/4477), @nimmolo)

## 2026-06-08 (deploy-2026-06-08-02-13)

- Add script/coveralls_pr_check.py: per-file PR coverage checker ([PR4475](https://github.com/MushroomObserver/mushroom-observer/pull/4475), @nimmolo)
- Phlexify all remaining /names ERB views (incl. index) ([PR4474](https://github.com/MushroomObserver/mushroom-observer/pull/4474), @nimmolo)

## 2026-06-08 (deploy-2026-06-08-01-58)

- Body class: map create→new, update→edit (template-rendered, not action) ([PR4472](https://github.com/MushroomObserver/mushroom-observer/pull/4472), @nimmolo)
- NoAnyPhlexPropsTest: scan multi-line props with a paren stack ([PR4473](https://github.com/MushroomObserver/mushroom-observer/pull/4473), @nimmolo)

## 2026-06-08 (deploy-2026-06-08-00-15)

- copilot-review workflow: defensive token trim + reviewer slug fix ([PR4470](https://github.com/MushroomObserver/mushroom-observer/pull/4470), @nimmolo)
- Phlexify Names::Show + NamesHelper chain into Tab POROs + 3 Collections ([PR4469](https://github.com/MushroomObserver/mushroom-observer/pull/4469), @nimmolo)
- Sweep _Any prop violations + add regression guard test ([PR4471](https://github.com/MushroomObserver/mushroom-observer/pull/4471), @nimmolo)

## 2026-06-07 (deploy-2026-06-07-23-10)

(no merged PRs -- asset-only or config deploy)

## 2026-06-07 (deploy-2026-06-07-22-53)

- Improve coverage post deploy-2026-06-05-18-07 ([PR4453](https://github.com/MushroomObserver/mushroom-observer/pull/4453), @JoeCohen)
- Workflow requesting Copilot review on nimmolo's PRs ([PR4461](https://github.com/MushroomObserver/mushroom-observer/pull/4461), @JoeCohen)
- Bump rubocop-rails to 2.35.4 ([PR4463](https://github.com/MushroomObserver/mushroom-observer/pull/4463), @JoeCohen)
- Phlexify rest of observations/namings + dismantle ObservationsHelper ([PR4458](https://github.com/MushroomObserver/mushroom-observer/pull/4458), @nimmolo)
- Description#put_together_name: fix source_type ||= local-shadow bug ([PR4447](https://github.com/MushroomObserver/mushroom-observer/pull/4447), @nimmolo)

## 2026-06-06 (deploy-2026-06-06-11-41)

- Phlexify _section_update.erb: ApplicationController::SectionUpdater + inline panel callsites ([PR4459](https://github.com/MushroomObserver/mushroom-observer/pull/4459), @nimmolo)

## 2026-06-06 (deploy-2026-06-06-08-20)

- Phlexify comments-for-object panel + comment row; broadcasts render Phlex ([PR4456](https://github.com/MushroomObserver/mushroom-observer/pull/4456), @nimmolo)
- Move AccountPreferencesForm into Account::Preferences::Form namespace ([PR4457](https://github.com/MushroomObserver/mushroom-observer/pull/4457), @nimmolo)

## 2026-06-06 (deploy-2026-06-06-06-14)

- Phlexify the obs-show namings sub-panel + Votes::Form + Components::ListGroup ([PR4455](https://github.com/MushroomObserver/mushroom-observer/pull/4455), @nimmolo)

## 2026-06-06 (deploy-2026-06-06-05-48)

- Fix Use assert_nil if expecting nil ([PR4451](https://github.com/MushroomObserver/mushroom-observer/pull/4451), @JoeCohen)
- Sweep Components::Base helper registrations + absorb InternalLink into Tab ([PR4454](https://github.com/MushroomObserver/mushroom-observer/pull/4454), @nimmolo)

## 2026-06-05 (deploy-2026-06-05-18-07)

- Phlexify descriptions/ views folder; delete description + version helpers ([PR4449](https://github.com/MushroomObserver/mushroom-observer/pull/4449), @nimmolo)

## 2026-06-05 (deploy-2026-06-05-01-01)

- Phlex views: replace _Any / vague Array+Hash prop types with concrete types ([PR4448](https://github.com/MushroomObserver/mushroom-observer/pull/4448), @nimmolo)

## 2026-06-05 (deploy-2026-06-05-00-01)

- obs/show: convert all sub-partials to Phlex + extract Components::InlineModLinks ([PR4444](https://github.com/MushroomObserver/mushroom-observer/pull/4444), @nimmolo)

## 2026-06-04 (deploy-2026-06-04-15-03)

- Fix field slip editing when project prefix added after creation (#4436) ([PR4441](https://github.com/MushroomObserver/mushroom-observer/pull/4441), @mo-nathan)
- Add Field Slips sub-tab to project Admin tab (#4442) ([PR4445](https://github.com/MushroomObserver/mushroom-observer/pull/4445), @mo-nathan)

## 2026-06-04 (deploy-2026-06-04-13-05)

- test/components: routes proxy + render components directly (drop view_context.helper layer) ([PR4440](https://github.com/MushroomObserver/mushroom-observer/pull/4440), @nimmolo)

## 2026-06-04 (deploy-2026-06-04-12-09)

- Descriptions::List: inline list_descriptions, drop helper registration ([PR4438](https://github.com/MushroomObserver/mushroom-observer/pull/4438), @nimmolo)

## 2026-06-04 (deploy-2026-06-04-10-41)

- ERB→Phlex: observations/namings/{new,edit} ([PR4434](https://github.com/MushroomObserver/mushroom-observer/pull/4434), @nimmolo)
- ERB→Phlex: alt_descriptions panel + Descriptions::List view ([PR4437](https://github.com/MushroomObserver/mushroom-observer/pull/4437), @nimmolo)

## 2026-06-04 (deploy-2026-06-04-00-43)

(no merged PRs -- asset-only or config deploy)

## 2026-06-04 (deploy-2026-06-04-00-24)

- Relocate *_index_sorts; delete tabs/{locations,names}_helper.rb ([PR4432](https://github.com/MushroomObserver/mushroom-observer/pull/4432), @nimmolo)

## 2026-06-03 (deploy-2026-06-03-23-38)

- Tab POROs: project members Collections + relocate tabs/projects_helper ([PR4433](https://github.com/MushroomObserver/mushroom-observer/pull/4433), @nimmolo)

## 2026-06-03 (deploy-2026-06-03-22-04)

- Delete tabs/related_objects_helper ([PR4431](https://github.com/MushroomObserver/mushroom-observer/pull/4431), @nimmolo)

## 2026-06-03 (deploy-2026-06-03-21-11)

- testing.md: paginate coveralls source_files.json in audit snippet ([PR4428](https://github.com/MushroomObserver/mushroom-observer/pull/4428), @nimmolo)
- Tab POROs: sweep observations/names/locations adapter callers ([PR4429](https://github.com/MushroomObserver/mushroom-observer/pull/4429), @nimmolo)
- Tab POROs: name external links + delete object_link_helper URL builders ([PR4430](https://github.com/MushroomObserver/mushroom-observer/pull/4430), @nimmolo)

## 2026-06-03 (deploy-2026-06-03-15-29)

- Tab POROs: 5 small action-nav helpers + delete general_helper ([PR4425](https://github.com/MushroomObserver/mushroom-observer/pull/4425), @nimmolo)
- Tab POROs: sidebar batch (8 helpers, ~37 POROs) ([PR4427](https://github.com/MushroomObserver/mushroom-observer/pull/4427), @nimmolo)
- tabs/related_objects_helper: delete dead related_observations_tab ([PR4426](https://github.com/MushroomObserver/mushroom-observer/pull/4426), @nimmolo)

## 2026-06-02 (deploy-2026-06-02-18-19)

(no merged PRs -- asset-only or config deploy)

## 2026-06-02 (deploy-2026-06-02-17-53)

- Tab POROs: users + account + checklists batch ([PR4423](https://github.com/MushroomObserver/mushroom-observer/pull/4423), @nimmolo)

## 2026-06-02 (deploy-2026-06-02-17-27)

- Drop cross-form vestigial logic in description merge/move forms; close namings form coverage gap ([PR4420](https://github.com/MushroomObserver/mushroom-observer/pull/4420), @mo-nathan)
- Tab POROs: 12 small action-nav helpers (the big one with field slips) ([PR4421](https://github.com/MushroomObserver/mushroom-observer/pull/4421), @nimmolo)

## 2026-06-02 (deploy-2026-06-02-00-48)

- Tab POROs: close coverage gaps (delete dead delegators + cover edge cases) ([PR4418](https://github.com/MushroomObserver/mushroom-observer/pull/4418), @nimmolo)
- Coverage gaps: delete dead form/panel helpers, fix Herbarium#order_by_user ([PR4419](https://github.com/MushroomObserver/mushroom-observer/pull/4419), @nimmolo)
- Tab POROs: convert glossary_terms (3 single Tabs + 4 Collections) ([PR4415](https://github.com/MushroomObserver/mushroom-observer/pull/4415), @nimmolo)
- Tab POROs: convert descriptions (10 single Tabs + helper cleanup) ([PR4416](https://github.com/MushroomObserver/mushroom-observer/pull/4416), @nimmolo)
- Tab POROs: bundle (comments, collection_numbers, herbarium_records, sequences, images) ([PR4417](https://github.com/MushroomObserver/mushroom-observer/pull/4417), @nimmolo)

## 2026-06-01 (deploy-2026-06-01-13-15)

- Tab POROs leaves: convert general_helper + related_objects_helper ([PR4409](https://github.com/MushroomObserver/mushroom-observer/pull/4409), @nimmolo)
- Tab POROs: convert locations + locations/descriptions ([PR4412](https://github.com/MushroomObserver/mushroom-observer/pull/4412), @nimmolo)
- Tab POROs: convert names + names/descriptions (action tabs + 3 cross-domain externals) ([PR4411](https://github.com/MushroomObserver/mushroom-observer/pull/4411), @nimmolo)
- Tab POROs: convert observations (15 single Tabs + 12 Collections) ([PR4413](https://github.com/MushroomObserver/mushroom-observer/pull/4413), @nimmolo)
- Cleanup: delete tabs/species_lists_helper.rb + tabs/herbaria_helper.rb ([PR4414](https://github.com/MushroomObserver/mushroom-observer/pull/4414), @nimmolo)

## 2026-05-31 (deploy-2026-05-31-23-34)

- Fix prod 500: SearchController#pattern fallthrough when session return-to set ([PR4407](https://github.com/MushroomObserver/mushroom-observer/pull/4407), @nimmolo)
- Tab POROs: convert herbaria domain (5 Tabs + 5 Collections + 4 ERB shims) ([PR4408](https://github.com/MushroomObserver/mushroom-observer/pull/4408), @nimmolo)

## 2026-05-31 (deploy-2026-05-31-14-29)

- Tab POROs: convert species_lists domain ([PR4405](https://github.com/MushroomObserver/mushroom-observer/pull/4405), @nimmolo)
- Fix 2 system test failures (external_link helper + autocompleter wait) ([PR4406](https://github.com/MushroomObserver/mushroom-observer/pull/4406), @nimmolo)

## 2026-05-31 (deploy-2026-05-31-13-25)

- Foundational Tab POROs; convert Project domain ([PR4404](https://github.com/MushroomObserver/mushroom-observer/pull/4404), @nimmolo)

## 2026-05-31 (deploy-2026-05-31-11-43)

- Rubocop 1.87.0 ([PR4399](https://github.com/MushroomObserver/mushroom-observer/pull/4399), @JoeCohen)
- visual_groups: convert edit.html.erb to Phlex ([PR4398](https://github.com/MushroomObserver/mushroom-observer/pull/4398), @nimmolo)
- link_helper: extract icon_link_to + link_icon into Phlex components ([PR4400](https://github.com/MushroomObserver/mushroom-observer/pull/4400), @nimmolo)
- Components::Table: add row + body modes, explicit attributes hash; convert 5 Phlex tables ([PR4402](https://github.com/MushroomObserver/mushroom-observer/pull/4402), @nimmolo)
- link_helper: extract modal_link_to + external_link + active_link_to into Phlex components ([PR4401](https://github.com/MushroomObserver/mushroom-observer/pull/4401), @nimmolo)
- Add Components::NavTabs; convert project tab bars to use it ([PR4403](https://github.com/MushroomObserver/mushroom-observer/pull/4403), @nimmolo)

## 2026-05-30 (deploy-2026-05-30-11-34)

- testing.md: no cosmetic Bootstrap classes in component tests (with exception) + sweep ([PR4397](https://github.com/MushroomObserver/mushroom-observer/pull/4397), @nimmolo)

## 2026-05-30 (deploy-2026-05-30-11-23)

- account/preferences: convert form + action templates to Phlex ([PR4394](https://github.com/MushroomObserver/mushroom-observer/pull/4394), @nimmolo)
- shared/list_search: convert to Phlex Components::ListSearch ([PR4395](https://github.com/MushroomObserver/mushroom-observer/pull/4395), @nimmolo)
- Preferences form: fix two broken PUTs and move retroactive update links ([PR4396](https://github.com/MushroomObserver/mushroom-observer/pull/4396), @nimmolo)

## 2026-05-29 (deploy-2026-05-29-11-34)

- `Header::ContextNavHelper`: convert dropdown + sidebar builders to Phlex ([PR4392](https://github.com/MushroomObserver/mushroom-observer/pull/4392), @nimmolo)

## 2026-05-29 (deploy-2026-05-29-11-29)

- species_lists_controller: trim under 250 lines; drop ClassLength disable ([PR4393](https://github.com/MushroomObserver/mushroom-observer/pull/4393), @nimmolo)

## 2026-05-29 (deploy-2026-05-29-10-44)

- LightboxCaption: embed ImageVoteInterface; strengthen test coverage ([PR4388](https://github.com/MushroomObserver/mushroom-observer/pull/4388), @nimmolo)
- species_lists: convert remaining ERBs to Phlex; add `render_index_view` hook ([PR4389](https://github.com/MushroomObserver/mushroom-observer/pull/4389), @nimmolo)
- SpeciesList#sync_projects: move project-sync logic to the model ([PR4390](https://github.com/MushroomObserver/mushroom-observer/pull/4390), @nimmolo)
- Location.dubious_reasons_for: collapse 6-site duplicate pattern ([PR4391](https://github.com/MushroomObserver/mushroom-observer/pull/4391), @nimmolo)

## 2026-05-29 (deploy-2026-05-29-00-19)

- CrudButton: rename, subclasses, btn:/icon: defaults; sweep callers ([PR4387](https://github.com/MushroomObserver/mushroom-observer/pull/4387), @nimmolo)

## 2026-05-28 (deploy-2026-05-28-02-12)

- species_lists/write_in: convert to Phlex + fix AutocompleterField hidden-id slicing ([PR4386](https://github.com/MushroomObserver/mushroom-observer/pull/4386), @nimmolo)

## 2026-05-28 (deploy-2026-05-28-01-37)

- Bump rubocop-rails to 2.35.3 ([PR4383](https://github.com/MushroomObserver/mushroom-observer/pull/4383), @JoeCohen)
- ApplicationForm field helpers: accept String name for non-bound fields + sweep callers ([PR4382](https://github.com/MushroomObserver/mushroom-observer/pull/4382), @nimmolo)
- Field helpers: Symbol + explicit value: overrides the model attribute ([PR4384](https://github.com/MushroomObserver/mushroom-observer/pull/4384), @nimmolo)
- Restore link_icon / modal_link_to to AutocompleterField (Components::Input) ([PR4385](https://github.com/MushroomObserver/mushroom-observer/pull/4385), @nimmolo)

## 2026-05-27 (deploy-2026-05-27-16-29)

- checkbox_field: positional choices in Rails shape ([PR4374](https://github.com/MushroomObserver/mushroom-observer/pull/4374), @nimmolo)
- species_lists: convert 5 ERB forms + action templates to Phlex ([PR4375](https://github.com/MushroomObserver/mushroom-observer/pull/4375), @nimmolo)
- Centralize helper registrations + flatten Phlex view namespaces ([PR4376](https://github.com/MushroomObserver/mushroom-observer/pull/4376), @nimmolo)
- ProjectsHelper cleanup: inline alias-table rendering + relocate tabs ([PR4378](https://github.com/MushroomObserver/mushroom-observer/pull/4378), @nimmolo)
- Delete orphan public/graphql/schema.graphql ([PR4379](https://github.com/MushroomObserver/mushroom-observer/pull/4379), @nimmolo)
- Fix Digestor warnings at source: ERBTracker skip constant-style render args ([PR4380](https://github.com/MushroomObserver/mushroom-observer/pull/4380), @nimmolo)
- Inline project_alias link helpers into Widget; delete ProjectsHelper ([PR4381](https://github.com/MushroomObserver/mushroom-observer/pull/4381), @nimmolo)

## 2026-05-27 (deploy-2026-05-27-00-56)

- Views::Base: pre-register common page-chrome helpers ([PR4373](https://github.com/MushroomObserver/mushroom-observer/pull/4373), @nimmolo)

## 2026-05-26 (deploy-2026-05-26-16-15)

- Bundle update with Rails ~> 7.0 ([PR4326](https://github.com/MushroomObserver/mushroom-observer/pull/4326), @JoeCohen)

## 2026-05-26 (deploy-2026-05-26-16-10)

- Move 3 single-purpose forms from components/ to views/controllers/ ([PR4365](https://github.com/MushroomObserver/mushroom-observer/pull/4365), @nimmolo)
- Move Components::Checklist::* to Views::Controllers::Checklists::* ([PR4366](https://github.com/MushroomObserver/mushroom-observer/pull/4366), @nimmolo)
- Lock in two .claude/rules: PR bodies via --body-file + Phlex-conversion placement ([PR4367](https://github.com/MushroomObserver/mushroom-observer/pull/4367), @nimmolo)
- Move Components::Descriptions::* forms to Views::Controllers::Descriptions::* ([PR4368](https://github.com/MushroomObserver/mushroom-observer/pull/4368), @nimmolo)
- Move Components::Sidebar::* to Views::Layouts::Sidebar::* ([PR4370](https://github.com/MushroomObserver/mushroom-observer/pull/4370), @nimmolo)

## 2026-05-26 (deploy-2026-05-26-16-03)

- Update disconnecting db connection pool ([PR4256](https://github.com/MushroomObserver/mushroom-observer/pull/4256), @JoeCohen)

## 2026-05-26 (deploy-2026-05-26-14-40)

(no merged PRs -- asset-only or config deploy)

## 2026-05-26 (deploy-2026-05-26-11-10)

- SelectField: accept Rails-shape [label, value] pairs ([PR4364](https://github.com/MushroomObserver/mushroom-observer/pull/4364), @nimmolo)

## 2026-05-26 (deploy-2026-05-26-10-16)

- occurrences: move + consolidate OccurrenceForm + OccurrenceEditForm; fix 2 N+1s ([PR4345](https://github.com/MushroomObserver/mushroom-observer/pull/4345), @nimmolo)
- observations: move 6 forms to Views/ ([PR4357](https://github.com/MushroomObserver/mushroom-observer/pull/4357), @nimmolo)
- projects: move 17 forms/widgets to Views/ ([PR4361](https://github.com/MushroomObserver/mushroom-observer/pull/4361), @nimmolo)
- Layouts: introduce Views::Layouts namespace ([PR4362](https://github.com/MushroomObserver/mushroom-observer/pull/4362), @nimmolo)
- Fix #4360: cross-model q param renders unfiltered Image index ([PR4363](https://github.com/MushroomObserver/mushroom-observer/pull/4363), @nimmolo)

## 2026-05-25 (deploy-2026-05-25-13-57)

- glossary_terms: move 2 forms to Views/ ([PR4342](https://github.com/MushroomObserver/mushroom-observer/pull/4342), @nimmolo)
- herbaria: move 2 forms to Views/ ([PR4343](https://github.com/MushroomObserver/mushroom-observer/pull/4343), @nimmolo)
- inat_imports: move 2 forms to Views/ ([PR4344](https://github.com/MushroomObserver/mushroom-observer/pull/4344), @nimmolo)
- species_lists: move 3 forms to Views/ (4th stays — genuinely reusable) ([PR4346](https://github.com/MushroomObserver/mushroom-observer/pull/4346), @nimmolo)
- account: move 4 forms to Views/ ([PR4347](https://github.com/MushroomObserver/mushroom-observer/pull/4347), @nimmolo)
- admin: move 9 forms to Views/ ([PR4348](https://github.com/MushroomObserver/mushroom-observer/pull/4348), @nimmolo)
- Testing rule: fix coverage gaps on every touched file ([PR4350](https://github.com/MushroomObserver/mushroom-observer/pull/4350), @nimmolo)
- locations: move LocationForm to Views/ ([PR4351](https://github.com/MushroomObserver/mushroom-observer/pull/4351), @nimmolo)
- images: move 2 forms to Views/ (+ test for ImageOriginalLink) ([PR4353](https://github.com/MushroomObserver/mushroom-observer/pull/4353), @nimmolo)
- names: move 9 forms to Views/ ([PR4354](https://github.com/MushroomObserver/mushroom-observer/pull/4354), @nimmolo)
- Phlex conversion rule: watch for decorative Model.new passed to super ([PR4356](https://github.com/MushroomObserver/mushroom-observer/pull/4356), @nimmolo)
- ApplicationForm: derive form id from full controller path ([PR4355](https://github.com/MushroomObserver/mushroom-observer/pull/4355), @nimmolo)

## 2026-05-24 (deploy-2026-05-24-12-07)

- ModalTurboForm: look up form class via caller's controller_path ([PR4330](https://github.com/MushroomObserver/mushroom-observer/pull/4330), @nimmolo)
- sequences: move SequenceForm to Views/ ([PR4329](https://github.com/MushroomObserver/mushroom-observer/pull/4329), @nimmolo)
- collection_numbers: move CollectionNumberForm to Views/ ([PR4332](https://github.com/MushroomObserver/mushroom-observer/pull/4332), @nimmolo)
- field_slips: move FieldSlipForm to Views/ ([PR4333](https://github.com/MushroomObserver/mushroom-observer/pull/4333), @nimmolo)
- herbarium_records: move HerbariumRecordForm to Views/ ([PR4334](https://github.com/MushroomObserver/mushroom-observer/pull/4334), @nimmolo)
- publications: move PublicationForm to Views/ ([PR4335](https://github.com/MushroomObserver/mushroom-observer/pull/4335), @nimmolo)
- users/emails: move UserQuestionForm to Views/ ([PR4336](https://github.com/MushroomObserver/mushroom-observer/pull/4336), @nimmolo)
- translations: move TranslationForm to Views/ ([PR4337](https://github.com/MushroomObserver/mushroom-observer/pull/4337), @nimmolo)
- visual_groups: move VisualGroupForm to Views/ ([PR4338](https://github.com/MushroomObserver/mushroom-observer/pull/4338), @nimmolo)
- visual_models: move VisualModelForm to Views/ ([PR4339](https://github.com/MushroomObserver/mushroom-observer/pull/4339), @nimmolo)
- info: move TextileSandboxForm to Views/ ([PR4340](https://github.com/MushroomObserver/mushroom-observer/pull/4340), @nimmolo)
- licenses: move LicenseForm to Views/ ([PR4341](https://github.com/MushroomObserver/mushroom-observer/pull/4341), @nimmolo)

## 2026-05-24 (deploy-2026-05-24-10-15)

- Fix map cluster Show All returning nothing for shared-location observations ([PR4319](https://github.com/MushroomObserver/mushroom-observer/pull/4319), @mo-nathan)
- Inline filter form component + visual_groups filter refactor ([PR4320](https://github.com/MushroomObserver/mushroom-observer/pull/4320), @nimmolo)
- Phlex conversion rule: views/ vs components/ ([PR4324](https://github.com/MushroomObserver/mushroom-observer/pull/4324), @nimmolo)
- account/api_keys: Phlex edit/new views + Table component on index + activate-URL fix ([PR4321](https://github.com/MushroomObserver/mushroom-observer/pull/4321), @nimmolo)
- comments: move CommentForm to Views/; fix ModalTurboForm lookup + form-id derivation ([PR4328](https://github.com/MushroomObserver/mushroom-observer/pull/4328), @nimmolo)
- articles: move ArticleForm to Views/ ([PR4327](https://github.com/MushroomObserver/mushroom-observer/pull/4327), @nimmolo)
- images/licenses/edit: ERB → Phlex with FormObject ([PR4323](https://github.com/MushroomObserver/mushroom-observer/pull/4323), @nimmolo)

## 2026-05-22 (deploy-2026-05-22-19-35)

- Fix Name footer showing creator instead of last editor ([PR4257](https://github.com/MushroomObserver/mushroom-observer/pull/4257), @JoeCohen)

## 2026-05-21 (deploy-2026-05-21-19-04)

- Project + species_list membership, `ImagesEditForm` Phlex ([PR4315](https://github.com/MushroomObserver/mushroom-observer/pull/4315), @nimmolo)

## 2026-05-21 (deploy-2026-05-21-19-01)

- Fix and DRY `page_title` / `document_title` methods ([PR4317](https://github.com/MushroomObserver/mushroom-observer/pull/4317), @nimmolo)

## 2026-05-21 (deploy-2026-05-21-16-19)

- Replace top-nav [+] with green [+ Add] button (Fixes #3930) ([PR4302](https://github.com/MushroomObserver/mushroom-observer/pull/4302), @mo-nathan)
- Fix target-location Create-link flow in violations modal (Fixes #4304) ([PR4307](https://github.com/MushroomObserver/mushroom-observer/pull/4307), @mo-nathan)
- Maintenance page during deploy + restyle 404/422/500 with Amanita theme ([PR4313](https://github.com/MushroomObserver/mushroom-observer/pull/4313), @mo-nathan)

## 2026-05-21 (deploy-2026-05-21-08-45)

- SpeciesListForm: Phlex Superform replacing species_lists/_form.html.erb ([PR4310](https://github.com/MushroomObserver/mushroom-observer/pull/4310), @nimmolo)

## 2026-05-20 (deploy-2026-05-20-22-50)

- hidden_field: route both paths through HiddenField ([PR4314](https://github.com/MushroomObserver/mushroom-observer/pull/4314), @nimmolo)

## 2026-05-20 (deploy-2026-05-20-17-04)

- Fix map_controller race: openMap can fire before google.maps loads ([PR4311](https://github.com/MushroomObserver/mushroom-observer/pull/4311), @nimmolo)

## 2026-05-20 (deploy-2026-05-20-13-49)

- Stabilize Checklist::Contents coverage (seed-dependent line 72) ([PR4301](https://github.com/MushroomObserver/mushroom-observer/pull/4301), @mo-nathan)
- Delete Components::AddObsModal — controller renders Modal via Phlex view ([PR4300](https://github.com/MushroomObserver/mushroom-observer/pull/4300), @nimmolo)
- Modal: knobs for header/controller/body_class; refactor Confirm + Spinner ([PR4303](https://github.com/MushroomObserver/mushroom-observer/pull/4303), @nimmolo)
- Bump rubocop-rails to 2.35.2 ([PR4309](https://github.com/MushroomObserver/mushroom-observer/pull/4309), @JoeCohen)
- OccurrenceResolveForm: render via Modal :form_content slot (restore .modal-footer) ([PR4294](https://github.com/MushroomObserver/mushroom-observer/pull/4294), @nimmolo)

## 2026-05-19 (deploy-2026-05-19-10-07)

- TrustSettingsForm: Superform + render via ModalTurboForm ([PR4292](https://github.com/MushroomObserver/mushroom-observer/pull/4292), @nimmolo)
- TargetLocationForm: extract from ProjectViolationsForm + namespace under project[...] ([PR4296](https://github.com/MushroomObserver/mushroom-observer/pull/4296), @nimmolo)

## 2026-05-18 (deploy-2026-05-18-22-23)

- bundle update for May 18, 2026 ([PR4298](https://github.com/MushroomObserver/mushroom-observer/pull/4298), @mo-nathan)

## 2026-05-18 (deploy-2026-05-18-18-36)

- Bump faraday from 2.14.1 to 2.14.2 ([PR4295](https://github.com/MushroomObserver/mushroom-observer/pull/4295), @app/dependabot)

## 2026-05-18 (deploy-2026-05-18-13-33)

- Speed up Project show: memoize visible obs + widen show_includes ([PR4289](https://github.com/MushroomObserver/mushroom-observer/pull/4289), @mo-nathan)

## 2026-05-18 (deploy-2026-05-18-10-22)

- Test sweep: assert_match-on-HTML → selector assertions + catch-up coverage ([PR4291](https://github.com/MushroomObserver/mushroom-observer/pull/4291), @nimmolo)
- Components::Modal: add :form_content slot for form-wrapped body+footer ([PR4293](https://github.com/MushroomObserver/mushroom-observer/pull/4293), @nimmolo)

## 2026-05-18 (deploy-2026-05-18-00-48)

- Fix CheckboxField block-mode label association (#4286) ([PR4287](https://github.com/MushroomObserver/mushroom-observer/pull/4287), @mo-nathan)
- Coverage catch-up: ButtonStyleRadio + ImagesToRemoveForm + RadioField append-Proc ([PR4282](https://github.com/MushroomObserver/mushroom-observer/pull/4282), @nimmolo)
- Fix BS3 modal unclickable at narrow viewports (drop translate3d hack) ([PR4290](https://github.com/MushroomObserver/mushroom-observer/pull/4290), @nimmolo)
- project_violations: route radios through RadioField ([PR4277](https://github.com/MushroomObserver/mushroom-observer/pull/4277), @nimmolo)
- Convert field-slip form to Phlex (using FormNotes) ([PR4270](https://github.com/MushroomObserver/mushroom-observer/pull/4270), @nimmolo)
- OccurrenceResolveForm: Superform + drop OccurrenceResolveModal wrapper ([PR4279](https://github.com/MushroomObserver/mushroom-observer/pull/4279), @nimmolo)
- Activity-log filters: ButtonStyleCheckbox + caption fix + UX cleanup ([PR4276](https://github.com/MushroomObserver/mushroom-observer/pull/4276), @nimmolo)

## 2026-05-17 (deploy-2026-05-17-16-11)

- Fix OccurrenceResolveForm Add All submission (#4284) ([PR4285](https://github.com/MushroomObserver/mushroom-observer/pull/4285), @mo-nathan)

## 2026-05-17 (deploy-2026-05-17-14-54)

- RadioField: per-choice opts (disabled / append / label_block) ([PR4281](https://github.com/MushroomObserver/mushroom-observer/pull/4281), @nimmolo)
- Jdc rubocop 1 86 2 ([PR4283](https://github.com/MushroomObserver/mushroom-observer/pull/4283), @JoeCohen)

## 2026-05-17 (deploy-2026-05-17-12-18)

- Get all system tests green, fix "create herbarium on the fly" modal in create obs form ([PR4280](https://github.com/MushroomObserver/mushroom-observer/pull/4280), @nimmolo)

## 2026-05-17 (deploy-2026-05-17-11-30)

- Extract Components::Modal, rename ModalForm -> ModalTurboForm ([PR4278](https://github.com/MushroomObserver/mushroom-observer/pull/4278), @nimmolo)

## 2026-05-17 (deploy-2026-05-17-09-55)

- Convert images-to-remove form to Phlex ([PR4271](https://github.com/MushroomObserver/mushroom-observer/pull/4271), @nimmolo)

## 2026-05-17 (deploy-2026-05-17-00-29)

- Drop dead naming_form_reasons_* helpers ([PR4273](https://github.com/MushroomObserver/mushroom-observer/pull/4273), @nimmolo)
- Convert api-keys verified indicator to Phlex CheckboxField ([PR4272](https://github.com/MushroomObserver/mushroom-observer/pull/4272), @nimmolo)
- FormCarousel: real `thumb_image_id` radio + CSS-only active state ([PR4274](https://github.com/MushroomObserver/mushroom-observer/pull/4274), @nimmolo)
- Carousel thumb button: theme-aware active state ([PR4275](https://github.com/MushroomObserver/mushroom-observer/pull/4275), @nimmolo)

## 2026-05-16 (deploy-2026-05-16-10-49)

- Extract Components::FormNotes (shared Panel + notes textareas) ([PR4269](https://github.com/MushroomObserver/mushroom-observer/pull/4269), @nimmolo)

## 2026-05-15 (deploy-2026-05-15-19-28)

- Switch report rows from positional to named columns (#3637) ([PR4237](https://github.com/MushroomObserver/mushroom-observer/pull/4237), @mo-nathan)
- Imported-source banner + new-tab credit links ([PR4235](https://github.com/MushroomObserver/mushroom-observer/pull/4235), @mo-nathan)

## 2026-05-15 (deploy-2026-05-15-15-39)

- Fix more ERB↔Phlex form helper divergences (10 fixes) ([PR4268](https://github.com/MushroomObserver/mushroom-observer/pull/4268), @nimmolo)

## 2026-05-15 (deploy-2026-05-15-09-51)

- `number_field` & `password_field`: ERB/Phlex parity ([PR4267](https://github.com/MushroomObserver/mushroom-observer/pull/4267), @nimmolo)

## 2026-05-14 (deploy-2026-05-14-23-19)

- ERB/Phlex form-helper parity nits (issue #4258 items 0 + 5) ([PR4259](https://github.com/MushroomObserver/mushroom-observer/pull/4259), @nimmolo)
- Form labels: emit matching for= attrs across Phlex + ERB ([PR4261](https://github.com/MushroomObserver/mushroom-observer/pull/4261), @nimmolo)
- Rename ERB `hidden_field_with_label` → `read_only_field_with_label` ([PR4262](https://github.com/MushroomObserver/mushroom-observer/pull/4262), @nimmolo)
- TextareaField: honor monospace at component level ([PR4265](https://github.com/MushroomObserver/mushroom-observer/pull/4265), @nimmolo)
- Phlex form helpers honor `prefs: true` ([PR4266](https://github.com/MushroomObserver/mushroom-observer/pull/4266), @nimmolo)
- Occurrence forms: Rails-native Superform via AR-model nesting (group C of #4225) ([PR4250](https://github.com/MushroomObserver/mushroom-observer/pull/4250), @nimmolo)

## 2026-05-14 (deploy-2026-05-14-15-40)

- Fix Superform 0.7.0 attributes: keyword deprecation ([PR4260](https://github.com/MushroomObserver/mushroom-observer/pull/4260), @JoeCohen)

## 2026-05-14 (deploy-2026-05-14-10-36)

- Native text-year date helper; remove year-input Stimulus controller ([PR4255](https://github.com/MushroomObserver/mushroom-observer/pull/4255), @nimmolo)

## 2026-05-13 (deploy-2026-05-13-23-24)

- Align ERB and Phlex autocompleter HTML emission ([PR4253](https://github.com/MushroomObserver/mushroom-observer/pull/4253), @nimmolo)
- Add updated encoded credentials ([PR4251](https://github.com/MushroomObserver/mushroom-observer/pull/4251), @mo-nathan)
- Fix Phlex `SelectField` `option` with nil key ([PR4254](https://github.com/MushroomObserver/mushroom-observer/pull/4254), @nimmolo)

## 2026-05-12 (deploy-2026-05-12-21-48)

- Add assert_html_element_equivalent helper to ComponentTestCase ([PR4246](https://github.com/MushroomObserver/mushroom-observer/pull/4246), @nimmolo)
- Switch `superform` from @nimmolo's fork to upstream ~> 0.7.0 ([PR4247](https://github.com/MushroomObserver/mushroom-observer/pull/4247), @nimmolo)

## 2026-05-12 (deploy-2026-05-12-21-33)

- Enable bare select for superform `SelectField` (group B of #4225) ([PR4245](https://github.com/MushroomObserver/mushroom-observer/pull/4245), @nimmolo)

## 2026-05-11 (deploy-2026-05-11-12-00)

- Replace hand-rolled form inputs with helpers / FieldProxy (group A of #4225) ([PR4236](https://github.com/MushroomObserver/mushroom-observer/pull/4236), @nimmolo)

## 2026-05-11 (deploy-2026-05-11-10-46)

- Tolerate nil iNat credentials at module load ([PR4240](https://github.com/MushroomObserver/mushroom-observer/pull/4240), @mo-nathan)
- Skip ConfigTest#test_secrets when credentials cannot decrypt ([PR4242](https://github.com/MushroomObserver/mushroom-observer/pull/4242), @mo-nathan)
- Fix typo ([PR4239](https://github.com/MushroomObserver/mushroom-observer/pull/4239), @jonkiparsky)
- Make test setup resets unbypassable (#4238) ([PR4243](https://github.com/MushroomObserver/mushroom-observer/pull/4243), @mo-nathan)
- Fix undefined method error in sibling_sequences archive link ([PR4244](https://github.com/MushroomObserver/mushroom-observer/pull/4244), @mo-nathan)

## 2026-05-09 (deploy-2026-05-09-17-09)

- Keep synonym-only-observed targets in Unobserved (Fixes #4152) ([PR4204](https://github.com/MushroomObserver/mushroom-observer/pull/4204), @mo-nathan)
- Per-worker email-debug.log to fix parallel test pollution ([PR4233](https://github.com/MushroomObserver/mushroom-observer/pull/4233), @mo-nathan)
- Sources table + external_id migration for imported observations ([PR4230](https://github.com/MushroomObserver/mushroom-observer/pull/4230), @mo-nathan)

## 2026-05-08 (deploy-2026-05-08-18-08)

- Bump nokogiri from 1.19.2 to 1.19.3 ([PR4229](https://github.com/MushroomObserver/mushroom-observer/pull/4229), @app/dependabot)
- Bump css_parser from 1.21.1 to 2.1.0 ([PR4228](https://github.com/MushroomObserver/mushroom-observer/pull/4228), @app/dependabot)
- Harden iNat import against duplicates and back-link leak ([PR4223](https://github.com/MushroomObserver/mushroom-observer/pull/4223), @mo-nathan)

## 2026-05-07 (deploy-2026-05-07-22-58)

- Phlex `ProjectForm` - use `radio_field` helper for `dates_any` toggle ([PR4224](https://github.com/MushroomObserver/mushroom-observer/pull/4224), @nimmolo)
- Remove misleading field.hidden alias on ApplicationForm::Field ([PR4227](https://github.com/MushroomObserver/mushroom-observer/pull/4227), @nimmolo)
- Un-pin gem `mini-racer` ([PR4222](https://github.com/MushroomObserver/mushroom-observer/pull/4222), @nimmolo)

## 2026-05-05 (deploy-2026-05-05-19-31)

- Bump net-imap from 0.5.12 to 0.5.14 ([PR4207](https://github.com/MushroomObserver/mushroom-observer/pull/4207), @app/dependabot)

## 2026-05-04 (deploy-2026-05-04-21-01)

- Map iNat monomial complexes to MO Group names with parent genus ([PR4196](https://github.com/MushroomObserver/mushroom-observer/pull/4196), @JoeCohen)
- Prevent creation of non-fungi/slime-mold MO Names from iNat identification taxa ([PR4200](https://github.com/MushroomObserver/mushroom-observer/pull/4200), @JoeCohen)

## 2026-05-04 (deploy-2026-05-04-18-16)

- Cleanup project Summary tab (Fixes #4148) ([PR4199](https://github.com/MushroomObserver/mushroom-observer/pull/4199), @mo-nathan)

## 2026-05-02 (deploy-2026-05-02-16-47)

- Cleanup project locations tab (Fixes #4147) ([PR4193](https://github.com/MushroomObserver/mushroom-observer/pull/4193), @mo-nathan)

## 2026-05-02 (deploy-2026-05-02-12-46)

- Close coverage gaps from PRs #4191 and #4153 ([PR4192](https://github.com/MushroomObserver/mushroom-observer/pull/4192), @mo-nathan)
- Distinguish Site Admin from Project Admin (Fixes #4145) ([PR4188](https://github.com/MushroomObserver/mushroom-observer/pull/4188), @mo-nathan)

## 2026-05-01 (deploy-2026-05-01-20-30)

- Njw 4136 expand violations ([PR4191](https://github.com/MushroomObserver/mushroom-observer/pull/4191), @mo-nathan)

## 2026-05-01 (deploy-2026-05-01-20-20)

- Drop step 4 of name lookup; rely on classification data (#4154) ([PR4156](https://github.com/MushroomObserver/mushroom-observer/pull/4156), @mo-nathan)
- Obscure GPS in MyCoPortal export for gps_hidden observations ([PR4186](https://github.com/MushroomObserver/mushroom-observer/pull/4186), @JoeCohen)
- Include sub-taxa in project target-name matching (Fixes #4130) ([PR4153](https://github.com/MushroomObserver/mushroom-observer/pull/4153), @mo-nathan)
- Convert project target_names / target_locations widgets to Phlex ([PR4185](https://github.com/MushroomObserver/mushroom-observer/pull/4185), @mo-nathan)

## 2026-04-28 (deploy-2026-04-28-18-03)

- Smart Name version browser + audit Phase 2 versioning (#4166) ([PR4168](https://github.com/MushroomObserver/mushroom-observer/pull/4168), @mo-nathan)

## 2026-04-28 (deploy-2026-04-28-13-11)

- Repair + alert for stale observation vote_cache (#4171) ([PR4172](https://github.com/MushroomObserver/mushroom-observer/pull/4172), @mo-nathan)

## 2026-04-27 (deploy-2026-04-27-21-37)

- Suppress expected logger noise in safe_done test ([PR4164](https://github.com/MushroomObserver/mushroom-observer/pull/4164), @JoeCohen)
- Limit Add My Observations to 100 per click with count preview ([PR4135](https://github.com/MushroomObserver/mushroom-observer/pull/4135), @mo-nathan)

## 2026-04-27 (deploy-2026-04-27-18-37)

- Add missing indexes for slow queries surfaced by 2026-04-27 outage ([PR4177](https://github.com/MushroomObserver/mushroom-observer/pull/4177), @mo-nathan)

## 2026-04-27 (deploy-2026-04-27-10-54)

- Remove user_stats.checklist cache ([PR4146](https://github.com/MushroomObserver/mushroom-observer/pull/4146), @mo-nathan)

## 2026-04-26 (deploy-2026-04-26-14-41)

- Fix stuck InatImport when worker crashes ([PR4122](https://github.com/MushroomObserver/mushroom-observer/pull/4122), @JoeCohen)

## 2026-04-26 (deploy-2026-04-26-13-44)

- Phlexicize print labels ([PR4030](https://github.com/MushroomObserver/mushroom-observer/pull/4030), @JoeCohen)

## 2026-04-26 (deploy-2026-04-26-11-29)

- Map clustering + GPS trust fixes (#4159) ([PR4162](https://github.com/MushroomObserver/mushroom-observer/pull/4162), @mo-nathan)

## 2026-04-24 (deploy-2026-04-24-23-51)

- Fix MCP data report for GBIF ([PR4104](https://github.com/MushroomObserver/mushroom-observer/pull/4104), @JoeCohen)
- Fix MCP image report for GBIF ([PR4116](https://github.com/MushroomObserver/mushroom-observer/pull/4116), @JoeCohen)

## 2026-04-22 (deploy-2026-04-22-21-27)

- Cleanup name reporting on project checklist tab ([PR4138](https://github.com/MushroomObserver/mushroom-observer/pull/4138), @mo-nathan)
- Map popups: thumbnail + taxon + date + confidence; colored markers ([PR4140](https://github.com/MushroomObserver/mushroom-observer/pull/4140), @mo-nathan)

## 2026-04-22 (deploy-2026-04-22-21-07)

- Prevent duplicate comments and close modal reliably ([PR4132](https://github.com/MushroomObserver/mushroom-observer/pull/4132), @mo-nathan)

## 2026-04-21 (deploy-2026-04-21-12-23)

- Fix flaky herbarium-record create test ([PR4150](https://github.com/MushroomObserver/mushroom-observer/pull/4150), @mo-nathan)
- Bump erb gem to 6.0.4 ([PR4151](https://github.com/MushroomObserver/mushroom-observer/pull/4151), @JoeCohen)

## 2026-04-20 (deploy-2026-04-20-22-16)

- Show Location edit icon to any logged-in user ([PR4149](https://github.com/MushroomObserver/mushroom-observer/pull/4149), @mo-nathan)

## 2026-04-20 (deploy-2026-04-20-18-14)

- Project excluded_observations list and Exclude buttons ([PR4137](https://github.com/MushroomObserver/mushroom-observer/pull/4137), @mo-nathan)

## 2026-04-20 (deploy-2026-04-20-15-52)

- Fix fill in missing ranks ([PR4143](https://github.com/MushroomObserver/mushroom-observer/pull/4143), @JoeCohen)

## 2026-04-17 (deploy-2026-04-17-21-11)

- Remove duplicate text/html from nginx gzip_types ([PR4133](https://github.com/MushroomObserver/mushroom-observer/pull/4133), @mo-nathan)
- Fix add space between Name ranks ([PR4090](https://github.com/MushroomObserver/mushroom-observer/pull/4090), @JoeCohen)

## 2026-04-16 (deploy-2026-04-16-18-48)

- Group sub-locations under target locations ([PR4127](https://github.com/MushroomObserver/mushroom-observer/pull/4127), @mo-nathan)

## 2026-04-16 (deploy-2026-04-16-13-58)

- Opt into CodeQL file coverage on PRs via advanced setup workflow ([PR4096](https://github.com/MushroomObserver/mushroom-observer/pull/4096), @app/copilot-swe-agent)
- Fix blank images in matrix box after upload ([PR4124](https://github.com/MushroomObserver/mushroom-observer/pull/4124), @mo-nathan)

## 2026-04-14 (deploy-2026-04-14-11-59)

- Add running job check to deploy script ([PR4120](https://github.com/MushroomObserver/mushroom-observer/pull/4120), @mo-nathan)

## 2026-04-14 (deploy-2026-04-14-11-45)

- Rubocop 1 86 1 ([PR4121](https://github.com/MushroomObserver/mushroom-observer/pull/4121), @JoeCohen)

## 2026-04-11 (deploy-2026-04-11-19-52)

- Show project banner on observation index from query params ([PR4110](https://github.com/MushroomObserver/mushroom-observer/pull/4110), @mo-nathan)

## 2026-04-11 (deploy-2026-04-11-19-10)

- Fix N+1 queries on project updates index page ([PR4109](https://github.com/MushroomObserver/mushroom-observer/pull/4109), @mo-nathan)

## 2026-04-11 (deploy-2026-04-11-18-36)

- Optimize exclude_non_primary scope for large projects ([PR4108](https://github.com/MushroomObserver/mushroom-observer/pull/4108), @mo-nathan)

## 2026-04-11 (deploy-2026-04-11-17-28)

- Add target names/locations data model for Rare Fungi Challenges ([PR4101](https://github.com/MushroomObserver/mushroom-observer/pull/4101), @mo-nathan)

## 2026-04-10 (deploy-2026-04-10-13-02)

- Convert Project ERB views to Phlex components ([PR4084](https://github.com/MushroomObserver/mushroom-observer/pull/4084), @mo-nathan)

## 2026-04-10 (deploy-2026-04-10-12-53)

- Simplify iNat import source credit label ([PR4105](https://github.com/MushroomObserver/mushroom-observer/pull/4105), @mo-nathan)

## 2026-04-08 (deploy-2026-04-08-13-15)

- Bump addressable from 2.8.9 to 2.9.0 ([PR4103](https://github.com/MushroomObserver/mushroom-observer/pull/4103), @app/dependabot)

## 2026-04-08 (deploy-2026-04-08-03-15)

- Bump rack-session from 2.1.1 to 2.1.2 ([PR4102](https://github.com/MushroomObserver/mushroom-observer/pull/4102), @app/dependabot)

## 2026-04-07 (deploy-2026-04-07-16-27)

- Revive Exports to MyCoPortal ([PR4034](https://github.com/MushroomObserver/mushroom-observer/pull/4034), @JoeCohen)

## 2026-04-06 (deploy-2026-04-06-21-29)

- Bump github actions/checkout from v4 to v6 ([PR4089](https://github.com/MushroomObserver/mushroom-observer/pull/4089), @JoeCohen)
- Bump trilogy from 2.11.1 to 2.12.3 ([PR4093](https://github.com/MushroomObserver/mushroom-observer/pull/4093), @app/dependabot)

## 2026-04-06 (deploy-2026-04-06-19-04)

- Fix vote_cache display to apply sub-max boost consistently ([PR4071](https://github.com/MushroomObserver/mushroom-observer/pull/4071), @mo-nathan)
- Bump minitest-reporters from 1.7.1 to 1.8.0 ([PR4094](https://github.com/MushroomObserver/mushroom-observer/pull/4094), @app/dependabot)
- Add Occurrence model and migration (#3808) ([PR3988](https://github.com/MushroomObserver/mushroom-observer/pull/3988), @mo-nathan)

## 2026-04-02 (deploy-2026-04-02-23-09)

- Bump rack from 3.1.20 to 3.1.21 ([PR4083](https://github.com/MushroomObserver/mushroom-observer/pull/4083), @app/dependabot)

## 2026-04-02 (deploy-2026-04-02-18-30)

- Enable hot-reloading for Phlex view components ([PR4079](https://github.com/MushroomObserver/mushroom-observer/pull/4079), @mo-nathan)
- Fix false name warning in field slip Add Images workflow ([PR4081](https://github.com/MushroomObserver/mushroom-observer/pull/4081), @mo-nathan)
- Convert projects forms to Phlex component ([PR4076](https://github.com/MushroomObserver/mushroom-observer/pull/4076), @mo-nathan)

## 2026-04-02 (deploy-2026-04-02-17-29)

- Upgrade Ruby from 3.3.6 to 3.4.9 ([PR4074](https://github.com/MushroomObserver/mushroom-observer/pull/4074), @mo-nathan)

## 2026-04-01 (deploy-2026-04-01-14-57)

- Fix awkward grammar in iNat import confirmation explanation ([PR3993](https://github.com/MushroomObserver/mushroom-observer/pull/3993), @app/copilot-swe-agent)
- Bump rubocop from 1.85.1 to 1.86.0 ([PR4069](https://github.com/MushroomObserver/mushroom-observer/pull/4069), @app/dependabot)
- Fix prawn-svg deprecation warning ([PR4070](https://github.com/MushroomObserver/mushroom-observer/pull/4070), @mo-nathan)
- Import only licensed stuff ([PR3992](https://github.com/MushroomObserver/mushroom-observer/pull/3992), @JoeCohen)

## 2026-03-30 (deploy-2026-03-30-02-05)

- Bump google-cloud-storage from 1.58.0 to 1.59.0 ([PR4068](https://github.com/MushroomObserver/mushroom-observer/pull/4068), @app/dependabot)

## 2026-03-30 (deploy-2026-03-30-02-03)

- Bump terser from 1.2.6 to 1.2.7 ([PR4067](https://github.com/MushroomObserver/mushroom-observer/pull/4067), @app/dependabot)

## 2026-03-28 (deploy-2026-03-28-18-03)

- Validate iNat ExternalLink entire URL ([PR4066](https://github.com/MushroomObserver/mushroom-observer/pull/4066), @JoeCohen)

## 2026-03-28 (deploy-2026-03-28-03-43)

- Bump mcp from 0.8.0 to 0.9.2 ([PR4063](https://github.com/MushroomObserver/mushroom-observer/pull/4063), @app/dependabot)

## 2026-03-27 (deploy-2026-03-27-23-53)

- Resume adding external links to imports. ([PR4064](https://github.com/MushroomObserver/mushroom-observer/pull/4064), @JoeCohen)

## 2026-03-26 (deploy-2026-03-26-22-26)

- Bump Trilogy to 2.11.1 ([PR4059](https://github.com/MushroomObserver/mushroom-observer/pull/4059), @JoeCohen)

## 2026-03-25 (deploy-2026-03-25-14-22)

- Clear connection after fork ([PR4057](https://github.com/MushroomObserver/mushroom-observer/pull/4057), @JoeCohen)

## 2026-03-23 (deploy-2026-03-23-03-12)

- Bump webmock from 3.26.1 to 3.26.2 ([PR4052](https://github.com/MushroomObserver/mushroom-observer/pull/4052), @app/dependabot)
- Bump solid_queue from 1.3.2 to 1.4.0 ([PR4053](https://github.com/MushroomObserver/mushroom-observer/pull/4053), @app/dependabot)
- Bump trilogy from 2.10.0 to 2.11.0 ([PR4054](https://github.com/MushroomObserver/mushroom-observer/pull/4054), @app/dependabot)

## 2026-03-19 (deploy-2026-03-19-19-01)

- Bump bcrypt from 3.1.21 to 3.1.22 ([PR4047](https://github.com/MushroomObserver/mushroom-observer/pull/4047), @app/dependabot)

## 2026-03-19 (deploy-2026-03-19-13-04)

- Bump json from 2.18.1 to 2.19.2 ([PR4044](https://github.com/MushroomObserver/mushroom-observer/pull/4044), @app/dependabot)

## 2026-03-19 (deploy-2026-03-19-00-19)

- Bump loofah from 2.25.0 to 2.25.1 ([PR4043](https://github.com/MushroomObserver/mushroom-observer/pull/4043), @app/dependabot)

## 2026-03-17 (deploy-2026-03-17-18-48)

- Add missing database indexes and optimize checklist query ([PR4039](https://github.com/MushroomObserver/mushroom-observer/pull/4039), @mo-nathan)

## 2026-03-16 (deploy-2026-03-16-14-31)

- Fix just-created record test bug ([PR4029](https://github.com/MushroomObserver/mushroom-observer/pull/4029), @JoeCohen)
- Bump prawn-svg from 0.38.1 to 0.40.0 ([PR4037](https://github.com/MushroomObserver/mushroom-observer/pull/4037), @app/dependabot)
- Bump fastimage from 2.4.0 to 2.4.1 ([PR4038](https://github.com/MushroomObserver/mushroom-observer/pull/4038), @app/dependabot)

## 2026-03-13 (deploy-2026-03-13-02-19)

- Guard against nil user in Inat::Taxon#create_mo_name ([PR3977](https://github.com/MushroomObserver/mushroom-observer/pull/3977), @app/copilot-swe-agent)
- Fix grammar in inat/taxon.rb comment ([PR4003](https://github.com/MushroomObserver/mushroom-observer/pull/4003), @app/copilot-swe-agent)
- Fix flaky license create test ([PR4027](https://github.com/MushroomObserver/mushroom-observer/pull/4027), @JoeCohen)
- Document Phlex view patterns, form gotchas, and testing strategies ([PR4001](https://github.com/MushroomObserver/mushroom-observer/pull/4001), @mo-nathan)
- Add missing Name at supported rank ([PR3975](https://github.com/MushroomObserver/mushroom-observer/pull/3975), @JoeCohen)

## 2026-03-11 (deploy-2026-03-11-13-20)

- Phlexicize account profile form ([PR3994](https://github.com/MushroomObserver/mushroom-observer/pull/3994), @JoeCohen)

## 2026-03-11 (deploy-2026-03-11-12-13)

- Add `log` param to Name API, fix silent save failures in `save_parents` ([PR4008](https://github.com/MushroomObserver/mushroom-observer/pull/4008), @app/copilot-swe-agent)
- Revert "Add `log` param to Name API, fix silent save failures in `save_parents`" ([PR4011](https://github.com/MushroomObserver/mushroom-observer/pull/4011), @JoeCohen)
- Log creation of a Name via the API ([PR4007](https://github.com/MushroomObserver/mushroom-observer/pull/4007), @JoeCohen)

## 2026-03-09 (deploy-2026-03-09-11-15)

- Convert identify filter form to Phlex, remove orphaned naming ERB ([PR3989](https://github.com/MushroomObserver/mushroom-observer/pull/3989), @mo-nathan)

## 2026-03-09 (deploy-2026-03-09-01-59)

- Bump sorted_set from 1.0.3 to 1.1.0 ([PR4000](https://github.com/MushroomObserver/mushroom-observer/pull/4000), @app/dependabot)

## 2026-03-08 (deploy-2026-03-08-20-48)

- Fix thumbnail not reassigned when removed via edit form ([PR3996](https://github.com/MushroomObserver/mushroom-observer/pull/3996), @mo-nathan)

## 2026-03-07 (deploy-2026-03-07-13-43)

- Fix location.rb metrics offenses ([PR3990](https://github.com/MushroomObserver/mushroom-observer/pull/3990), @JoeCohen)

## 2026-03-07 (deploy-2026-03-07-10-38)

- Reverse FieldSlip-Observation relationship ([PR3986](https://github.com/MushroomObserver/mushroom-observer/pull/3986), @mo-nathan)

## 2026-03-06 (deploy-2026-03-06-22-08)

- Fix flaky MailDeliveryErrorLoggingTest in parallel runs ([PR3963](https://github.com/MushroomObserver/mushroom-observer/pull/3963), @mo-nathan)
- Bump rubocop to 1.85.1 ([PR3976](https://github.com/MushroomObserver/mushroom-observer/pull/3976), @JoeCohen)
- Standardize CLAUDE.md with init-style structure ([PR3973](https://github.com/MushroomObserver/mushroom-observer/pull/3973), @mo-nathan)
- Exclude projects/ directory from RuboCop ([PR3987](https://github.com/MushroomObserver/mushroom-observer/pull/3987), @mo-nathan)
- Ignore iNat non-myxo protozoa ([PR3944](https://github.com/MushroomObserver/mushroom-observer/pull/3944), @JoeCohen)

## 2026-03-02 (deploy-2026-03-02-22-21)

- Fix parameter shadowing in `OneOrTheOther#initialize` ([PR3957](https://github.com/MushroomObserver/mushroom-observer/pull/3957), @app/copilot-swe-agent)
- Fix file descriptor leak in UploadFromFile ([PR3958](https://github.com/MushroomObserver/mushroom-observer/pull/3958), @app/copilot-swe-agent)
- Fix NoMethodError: use `NodeSet#to_s` instead of `NodeSet#join` in session form extensions ([PR3959](https://github.com/MushroomObserver/mushroom-observer/pull/3959), @app/copilot-swe-agent)
- Fix NoMethodError from Style/MapJoin autocorrect on Nokogiri NodeSet ([PR3960](https://github.com/MushroomObserver/mushroom-observer/pull/3960), @app/copilot-swe-agent)
- Bump rubocop to 1.85.0 ([PR3956](https://github.com/MushroomObserver/mushroom-observer/pull/3956), @JoeCohen)
- Fix count for all superimporter's iNat observations ([PR3972](https://github.com/MushroomObserver/mushroom-observer/pull/3972), @JoeCohen)

## 2026-03-02 (deploy-2026-03-02-20-36)

- Fix missing review widgets on Help Identify page ([PR3962](https://github.com/MushroomObserver/mushroom-observer/pull/3962), @mo-nathan)

## 2026-03-02 (deploy-2026-03-02-15-02)

- Bump literal from 1.8.1 to 1.9.0 ([PR3967](https://github.com/MushroomObserver/mushroom-observer/pull/3967), @app/dependabot)

## 2026-03-02 (deploy-2026-03-02-14-59)

- Bump prawn-manual_builder from 0.3.1 to 0.5.0 ([PR3964](https://github.com/MushroomObserver/mushroom-observer/pull/3964), @app/dependabot)

## 2026-02-28 (deploy-2026-02-28-14-19)

- Bump brakeman to 8.0.4 ([PR3955](https://github.com/MushroomObserver/mushroom-observer/pull/3955), @JoeCohen)
- Fix superimporter preview estimate ([PR3946](https://github.com/MushroomObserver/mushroom-observer/pull/3946), @JoeCohen)

## 2026-02-24 (deploy-2026-02-24-23-38)

- Fix TOCTOU race condition in MailDeliveryErrorLoggingTest ([PR3952](https://github.com/MushroomObserver/mushroom-observer/pull/3952), @app/copilot-swe-agent)
- Fix order-dependent mail delivery test failure ([PR3951](https://github.com/MushroomObserver/mushroom-observer/pull/3951), @JoeCohen)
- Fix order-dependent translation test failure ([PR3950](https://github.com/MushroomObserver/mushroom-observer/pull/3950), @JoeCohen)
- Phlex ProjectViolations form ([PR3929](https://github.com/MushroomObserver/mushroom-observer/pull/3929), @JoeCohen)

## 2026-02-23 (deploy-2026-02-23-19-30)

- Convert Translation Edit form to Phlex ([PR3938](https://github.com/MushroomObserver/mushroom-observer/pull/3938), @JoeCohen)

## 2026-02-23 (deploy-2026-02-23-19-25)

- Bump solid_queue from 1.3.1 to 1.3.2 ([PR3947](https://github.com/MushroomObserver/mushroom-observer/pull/3947), @app/dependabot)

## 2026-02-22 (deploy-2026-02-22-09-58)

- 3852 remove queuedemail references ([PR3853](https://github.com/MushroomObserver/mushroom-observer/pull/3853), @JoeCohen)

## 2026-02-21 (deploy-2026-02-21-11-54)

- Enable raise_delivery_errors and log email failures ([PR3943](https://github.com/MushroomObserver/mushroom-observer/pull/3943), @mo-nathan)

## 2026-02-20 (deploy-2026-02-20-10-10)

- Bump nokogiri from 1.19.0 to 1.19.1 ([PR3941](https://github.com/MushroomObserver/mushroom-observer/pull/3941), @app/dependabot)

## 2026-02-17 (deploy-2026-02-17-16-48)

- Bump rack from 3.1.19 to 3.1.20 ([PR3936](https://github.com/MushroomObserver/mushroom-observer/pull/3936), @app/dependabot)

## 2026-02-17 (deploy-2026-02-17-14-41)

- Revert "Email outage recovery plan and scripts" ([PR3933](https://github.com/MushroomObserver/mushroom-observer/pull/3933), @mo-nathan)

## 2026-02-17 (deploy-2026-02-17-12-17)

- Email outage recovery plan and scripts ([PR3931](https://github.com/MushroomObserver/mushroom-observer/pull/3931), @mo-nathan)

## 2026-02-17 (deploy-2026-02-17-04-03)

- Delete Phlex form conversion tracker file ([PR3928](https://github.com/MushroomObserver/mushroom-observer/pull/3928), @JoeCohen)
- Make the "admin donations review form" more Superform-idiomatic ([PR3851](https://github.com/MushroomObserver/mushroom-observer/pull/3851), @nimmolo)

## 2026-02-16 (deploy-2026-02-16-01-17)

- Convert admin/donations/edit to Phlex component ([PR3845](https://github.com/MushroomObserver/mushroom-observer/pull/3845), @mo-nathan)

## 2026-02-16 (deploy-2026-02-16-00-15)

- Escape regex metacharacters in localized string assertions ([PR3842](https://github.com/MushroomObserver/mushroom-observer/pull/3842), @app/copilot-swe-agent)
- Rename misleading parameter in merge_form_param helper ([PR3843](https://github.com/MushroomObserver/mushroom-observer/pull/3843), @app/copilot-swe-agent)
- Bump rubocop to 1.84.2 ([PR3847](https://github.com/MushroomObserver/mushroom-observer/pull/3847), @JoeCohen)
- Jdc phlex import preview ([PR3849](https://github.com/MushroomObserver/mushroom-observer/pull/3849), @JoeCohen)

## 2026-02-13 (deploy-2026-02-13-23-13)

- Fix RuboCop style offenses in observations downloads controller ([PR3836](https://github.com/MushroomObserver/mushroom-observer/pull/3836), @app/copilot-swe-agent)
- Convert observations downloads form from ERB to Phlex ([PR3828](https://github.com/MushroomObserver/mushroom-observer/pull/3828), @JoeCohen)

## 2026-02-13 (deploy-2026-02-13-10-52)

- Fix modal close button visibility in dark themes ([PR3841](https://github.com/MushroomObserver/mushroom-observer/pull/3841), @mo-nathan)

## 2026-02-13 (deploy-2026-02-13-00-57)

- Update consensus algorithm to boost sub-max agreeing votes ([PR3816](https://github.com/MushroomObserver/mushroom-observer/pull/3816), @mo-nathan)

## 2026-02-12 (deploy-2026-02-12-16-34)

(no merged PRs -- asset-only or config deploy)

## 2026-02-09 (deploy-2026-02-09-22-35)

- Update form_conversion_tracker.md ([PR3835](https://github.com/MushroomObserver/mushroom-observer/pull/3835), @nimmolo)
- Bump faraday from 2.14.0 to 2.14.1 ([PR3839](https://github.com/MushroomObserver/mushroom-observer/pull/3839), @app/dependabot)

## 2026-02-09 (deploy-2026-02-09-06-48)

- Fix rubocop offenses after 1.84.0 → 1.84.1 upgrade ([PR3834](https://github.com/MushroomObserver/mushroom-observer/pull/3834), @app/copilot-swe-agent)
- Bump rubocop from 1.84.0 to 1.84.1 ([PR3832](https://github.com/MushroomObserver/mushroom-observer/pull/3832), @app/dependabot)
- Bump brakeman from 8.0.1 to 8.0.2 ([PR3833](https://github.com/MushroomObserver/mushroom-observer/pull/3833), @app/dependabot)
- Phlex `DescriptionForm`, plus `MergeForm`, `MoveForm`, `PermissionsForm` ([PR3787](https://github.com/MushroomObserver/mushroom-observer/pull/3787), @nimmolo)

## 2026-02-09 (deploy-2026-02-09-02-52)

- Fix radio_field attribute merge order to preserve value stringification ([PR3830](https://github.com/MushroomObserver/mushroom-observer/pull/3830), @app/copilot-swe-agent)
- Add regression test for Symbol radio field values ([PR3831](https://github.com/MushroomObserver/mushroom-observer/pull/3831), @app/copilot-swe-agent)
- Fix radio_field value attribute ([PR3829](https://github.com/MushroomObserver/mushroom-observer/pull/3829), @JoeCohen)

## 2026-02-08 (deploy-2026-02-08-03-12)

- Bump phlex from 2.4.0 to 2.4.1 ([PR3820](https://github.com/MushroomObserver/mushroom-observer/pull/3820), @app/dependabot)
- Phlex Superform: Use convenience field methods consistently ([PR3824](https://github.com/MushroomObserver/mushroom-observer/pull/3824), @nimmolo)
- Sync checkbox_field block handling and herbarium form ([PR3826](https://github.com/MushroomObserver/mushroom-observer/pull/3826), @nimmolo)

## 2026-02-07 (deploy-2026-02-07-02-15)

- Allow import_all as a user's first import ([PR3817](https://github.com/MushroomObserver/mushroom-observer/pull/3817), @JoeCohen)

## 2026-02-05 (deploy-2026-02-05-22-51)

- Phlex - Name classification/synonymy forms ([PR3782](https://github.com/MushroomObserver/mushroom-observer/pull/3782), @nimmolo)
- Convert modal email forms to build the form object internally ([PR3796](https://github.com/MushroomObserver/mushroom-observer/pull/3796), @nimmolo)

## 2026-02-04 (deploy-2026-02-04-18-29)

- End reliance on "Voucher Specimen Taken" ([PR3804](https://github.com/MushroomObserver/mushroom-observer/pull/3804), @JoeCohen)

## 2026-02-02 (deploy-2026-02-02-15-51)

- Bump rubocop from 1.82.1 to 1.84.0 ([PR3794](https://github.com/MushroomObserver/mushroom-observer/pull/3794), @app/dependabot)
- Bump brakeman from 7.1.2 to 8.0.1 ([PR3793](https://github.com/MushroomObserver/mushroom-observer/pull/3793), @app/dependabot)
- Bump turbo-rails from 2.0.21 to 2.0.23 ([PR3795](https://github.com/MushroomObserver/mushroom-observer/pull/3795), @app/dependabot)

## 2026-01-30 (deploy-2026-01-30-02-33)

- Fix potential account signup bug re: theme select, pt. 2 ([PR3789](https://github.com/MushroomObserver/mushroom-observer/pull/3789), @nimmolo)

## 2026-01-29 (deploy-2026-01-29-22-02)

- Fix signup silently failing when theme is invalid/empty ([PR3788](https://github.com/MushroomObserver/mushroom-observer/pull/3788), @nimmolo)

## 2026-01-29 (deploy-2026-01-29-01-27)

- Delete unused observation form ERB files ([PR3784](https://github.com/MushroomObserver/mushroom-observer/pull/3784), @nimmolo)
- Consolidate email form objects into reusable `FormObject::EmailRequest` ([PR3785](https://github.com/MushroomObserver/mushroom-observer/pull/3785), @nimmolo)
- Fix CI error when blocked_ips files don't exist ([PR3786](https://github.com/MushroomObserver/mushroom-observer/pull/3786), @nimmolo)

## 2026-01-28 (deploy-2026-01-28-19-56)

- Use `superform` fork with `radio_field` support ([PR3783](https://github.com/MushroomObserver/mushroom-observer/pull/3783), @nimmolo)

## 2026-01-28 (deploy-2026-01-28-09-30)

- Fix checklist column layout alignment issue ([PR3776](https://github.com/MushroomObserver/mushroom-observer/pull/3776), @mo-nathan)

## 2026-01-28 (deploy-2026-01-28-09-29)

- Phlex: use new `mark_safe` for `register_output_helper` ([PR3781](https://github.com/MushroomObserver/mushroom-observer/pull/3781), @nimmolo)
- Phlex `NameForm` — show `locked` field (admin only) ([PR3779](https://github.com/MushroomObserver/mushroom-observer/pull/3779), @nimmolo)

## 2026-01-27 (deploy-2026-01-27-07-18)

- Clean up bad code examples in Phlex components ([PR3780](https://github.com/MushroomObserver/mushroom-observer/pull/3780), @nimmolo)

## 2026-01-26 (deploy-2026-01-26-18-46)

- Bump phlex-rails from 2.3.1 to 2.4.0 ([PR3777](https://github.com/MushroomObserver/mushroom-observer/pull/3777), @app/dependabot)
- Bump puma from 7.1.0 to 7.2.0 ([PR3778](https://github.com/MushroomObserver/mushroom-observer/pull/3778), @app/dependabot)

## 2026-01-25 (deploy-2026-01-25-23-35)

- Fix field slip ID losing underscores when editing other fields ([PR3774](https://github.com/MushroomObserver/mushroom-observer/pull/3774), @mo-nathan)
- Cache location center coordinates on observations ([PR3771](https://github.com/MushroomObserver/mushroom-observer/pull/3771), @mo-nathan)
- Use bounding box matching for project location checklists ([PR3772](https://github.com/MushroomObserver/mushroom-observer/pull/3772), @mo-nathan)

## 2026-01-24 (deploy-2026-01-24-01-25)

- Extract iNat sequence detection logic ([PR3766](https://github.com/MushroomObserver/mushroom-observer/pull/3766), @JoeCohen)

## 2026-01-23 (deploy-2026-01-23-14-48)

- Clear naming reasons notes field when reason unchecked ([PR3764](https://github.com/MushroomObserver/mushroom-observer/pull/3764), @nimmolo)

## 2026-01-23 (deploy-2026-01-23-14-44)

- Vertical space between term definition and external searches ([PR3763](https://github.com/MushroomObserver/mushroom-observer/pull/3763), @JoeCohen)

## 2026-01-22 (deploy-2026-01-22-02-40)

- Restore naming reasons to obs form ([PR3760](https://github.com/MushroomObserver/mushroom-observer/pull/3760), @nimmolo)

## 2026-01-21 (deploy-2026-01-21-18-05)

- Bump rqrcode from 3.1.1 to 3.2.0 ([PR3748](https://github.com/MushroomObserver/mushroom-observer/pull/3748), @app/dependabot)
- Bump solid_queue from 1.3.0 to 1.3.1 ([PR3749](https://github.com/MushroomObserver/mushroom-observer/pull/3749), @app/dependabot)
- Bump turbo-rails from 2.0.20 to 2.0.21 ([PR3750](https://github.com/MushroomObserver/mushroom-observer/pull/3750), @app/dependabot)

## 2026-01-21 (deploy-2026-01-21-13-44)

- Add test coverage for FieldSlip API edge cases and XML rendering ([PR3754](https://github.com/MushroomObserver/mushroom-observer/pull/3754), @app/copilot-swe-agent)
- Fix uninitialized constant FileMissing in API2::Uploads ([PR3756](https://github.com/MushroomObserver/mushroom-observer/pull/3756), @mo-nathan)
- Refactor API page lengths to use level-based abstraction ([PR3755](https://github.com/MushroomObserver/mushroom-observer/pull/3755), @mo-nathan)
- Add FieldSlip API calls ([PR3752](https://github.com/MushroomObserver/mushroom-observer/pull/3752), @mo-nathan)

## 2026-01-16 (deploy-2026-01-16-18-07)

- 3427 relax import list limit ([PR3739](https://github.com/MushroomObserver/mushroom-observer/pull/3739), @JoeCohen)

## 2026-01-12 (deploy-2026-01-12-20-26)

- Bump trilogy from 2.9.0 to 2.10.0 ([PR3732](https://github.com/MushroomObserver/mushroom-observer/pull/3732), @app/dependabot)

## 2026-01-12 (deploy-2026-01-12-20-25)

(no merged PRs -- asset-only or config deploy)

## 2026-01-12 (deploy-2026-01-12-16-19)

- Bump solid_queue from 1.2.4 to 1.3.0 ([PR3734](https://github.com/MushroomObserver/mushroom-observer/pull/3734), @app/dependabot)
- Bump importmap-rails from 2.2.2 to 2.2.3 ([PR3730](https://github.com/MushroomObserver/mushroom-observer/pull/3730), @app/dependabot)
- Bump google-cloud-storage from 1.57.1 to 1.58.0 ([PR3733](https://github.com/MushroomObserver/mushroom-observer/pull/3733), @app/dependabot)

## 2026-01-09 (deploy-2026-01-09-22-38)

- Phlex `Table` component, `IpsManager` form ([PR3722](https://github.com/MushroomObserver/mushroom-observer/pull/3722), @nimmolo)

## 2026-01-09 (deploy-2026-01-09-20-26)

- Phlex `ObservationForm` ([PR3698](https://github.com/MushroomObserver/mushroom-observer/pull/3698), @nimmolo)

## 2026-01-09 (deploy-2026-01-09-20-24)

- Enable SimpleCov coverage reports by default with parallel test support ([PR3726](https://github.com/MushroomObserver/mushroom-observer/pull/3726), @mo-nathan)

## 2026-01-09 (deploy-2026-01-09-20-19)

- nimmo alterations to project banner ([PR3728](https://github.com/MushroomObserver/mushroom-observer/pull/3728), @nimmolo)
- Fix image upload file type validation ([PR3721](https://github.com/MushroomObserver/mushroom-observer/pull/3721), @nimmolo)
- Convert _project_banner.erb to Phlex ([PR3712](https://github.com/MushroomObserver/mushroom-observer/pull/3712), @mo-nathan)

## 2026-01-09 (deploy-2026-01-09-04-37)

- Convert _translators_credit partial to Phlex component ([PR3717](https://github.com/MushroomObserver/mushroom-observer/pull/3717), @mo-nathan)
- Fix intermittent TranslatorsCreditTest failure from test isolation issue ([PR3723](https://github.com/MushroomObserver/mushroom-observer/pull/3723), @mo-nathan)
- Update report test error diagnostic message ([PR3724](https://github.com/MushroomObserver/mushroom-observer/pull/3724), @nimmolo)
- Enable `simplecov` to run parallel tests with merged coverage results ([PR3725](https://github.com/MushroomObserver/mushroom-observer/pull/3725), @nimmolo)

## 2026-01-07 (deploy-2026-01-07-16-15)

- Fix Publications index Action menu ([PR3707](https://github.com/MushroomObserver/mushroom-observer/pull/3707), @JoeCohen)

## 2026-01-07 (deploy-2026-01-07-16-11)

- Convert account signup form to Phlex component ([PR3720](https://github.com/MushroomObserver/mushroom-observer/pull/3720), @JoeCohen)

## 2026-01-07 (deploy-2026-01-07-14-53)

- Address PR feedback: sidebar cache key ordering and test coverage ([PR3711](https://github.com/MushroomObserver/mushroom-observer/pull/3711), @mo-nathan)
- Convert admin banner change form to Phlex component ([PR3718](https://github.com/MushroomObserver/mushroom-observer/pull/3718), @JoeCohen)

## 2026-01-06 (deploy-2026-01-06-22-31)

- Obs form - fix EXIF transfer of date and location data ([PR3708](https://github.com/MushroomObserver/mushroom-observer/pull/3708), @nimmolo)

## 2026-01-06 (deploy-2026-01-06-08-59)

- Phlex `AdminSessionForm` ([PR3714](https://github.com/MushroomObserver/mushroom-observer/pull/3714), @nimmolo)

## 2026-01-06 (deploy-2026-01-06-01-04)

- Remove references to `current_user` helper in components ([PR3716](https://github.com/MushroomObserver/mushroom-observer/pull/3716), @nimmolo)

## 2026-01-06 (deploy-2026-01-06-00-20)

- Create `FormObject::Base` to remove boilerplate ([PR3715](https://github.com/MushroomObserver/mushroom-observer/pull/3715), @nimmolo)

## 2026-01-05 (deploy-2026-01-05-14-18)

- Fix sidebar cache to update when changing languages ([PR3710](https://github.com/MushroomObserver/mushroom-observer/pull/3710), @mo-nathan)

## 2026-01-05 (deploy-2026-01-05-14-07)

- Fix language switching in sidebar ([PR3709](https://github.com/MushroomObserver/mushroom-observer/pull/3709), @mo-nathan)

## 2026-01-05 (deploy-2026-01-05-13-51)

- Convert application sidebar to Phlex components ([PR3696](https://github.com/MushroomObserver/mushroom-observer/pull/3696), @mo-nathan)

## 2026-01-05 (deploy-2026-01-05-00-17)

- Bump rubocop-rails from 2.34.2 to 2.34.3 ([PR3705](https://github.com/MushroomObserver/mushroom-observer/pull/3705), @app/dependabot)
- Bump bcrypt from 3.1.20 to 3.1.21 ([PR3704](https://github.com/MushroomObserver/mushroom-observer/pull/3704), @app/dependabot)

## 2026-01-04 (deploy-2026-01-04-21-55)

- Convert login_layout partial to Phlex component ([PR3697](https://github.com/MushroomObserver/mushroom-observer/pull/3697), @mo-nathan)
- Fix map autozoom for locations ([PR3702](https://github.com/MushroomObserver/mushroom-observer/pull/3702), @nimmolo)

## 2026-01-04 (deploy-2026-01-04-03-24)

- Fix edit/destroy icon logic for Location show page ([PR3701](https://github.com/MushroomObserver/mushroom-observer/pull/3701), @nimmolo)

## 2026-01-03 (deploy-2026-01-03-22-57)

- Phlex `LocationForm`, `Map`, `FormCompassFields`, `FormElevationFields` ([PR3681](https://github.com/MushroomObserver/mushroom-observer/pull/3681), @nimmolo)
- Phlex `ModalForm` component ([PR3680](https://github.com/MushroomObserver/mushroom-observer/pull/3680), @nimmolo)
- Convert `namings`, `image_matrix` panels to use `Panel` component ([PR3695](https://github.com/MushroomObserver/mushroom-observer/pull/3695), @nimmolo)
- Create form_conversion_tracker.md ([PR3700](https://github.com/MushroomObserver/mushroom-observer/pull/3700), @nimmolo)
- Delete location form partials ([PR3699](https://github.com/MushroomObserver/mushroom-observer/pull/3699), @nimmolo)

## 2026-01-02 (deploy-2026-01-02-21-30)

- Delete form partials already replaced by components ([PR3692](https://github.com/MushroomObserver/mushroom-observer/pull/3692), @nimmolo)

## 2026-01-02 (deploy-2026-01-02-21-26)

- Remove `QueuedEmail` everywhere ([PR3683](https://github.com/MushroomObserver/mushroom-observer/pull/3683), @nimmolo)

## 2026-01-02 (deploy-2026-01-02-21-24)

- Phlex `ProjectAliasForm` `ProjectMemberForm` conversions ([PR3689](https://github.com/MushroomObserver/mushroom-observer/pull/3689), @nimmolo)

## 2026-01-02 (deploy-2026-01-02-04-37)

- Consolidate component test methods ([PR3686](https://github.com/MushroomObserver/mushroom-observer/pull/3686), @nimmolo)
- Update testing.md for component tests ([PR3687](https://github.com/MushroomObserver/mushroom-observer/pull/3687), @nimmolo)

## 2026-01-02 (deploy-2026-01-02-03-32)

- `CrudActionButton` and `ModalConfirm` Phlex components ([PR3678](https://github.com/MushroomObserver/mushroom-observer/pull/3678), @nimmolo)

## 2026-01-02 (deploy-2026-01-02-03-16)

- Convert form_location_feedback partial to Phlex component ([PR3668](https://github.com/MushroomObserver/mushroom-observer/pull/3668), @mo-nathan)
- Phlex `ModalProgressSpinner` ([PR3679](https://github.com/MushroomObserver/mushroom-observer/pull/3679), @nimmolo)

## 2026-01-02 (deploy-2026-01-02-01-35)

- Coverage and logic in CN, HR, Sequences controllers ([PR3684](https://github.com/MushroomObserver/mushroom-observer/pull/3684), @nimmolo)

## 2026-01-01 (deploy-2026-01-01-21-18)

- Fix TypeError when params[:q] is a String in set_project_ivar ([PR3672](https://github.com/MushroomObserver/mushroom-observer/pull/3672), @JoeCohen)

## 2026-01-01 (deploy-2026-01-01-14-35)

- Convert form_list_feedback partial to Phlex component ([PR3666](https://github.com/MushroomObserver/mushroom-observer/pull/3666), @mo-nathan)

## 2026-01-01 (deploy-2026-01-01-08-18)

- New `ComponentTestCase` ([PR3682](https://github.com/MushroomObserver/mushroom-observer/pull/3682), @nimmolo)

## 2026-01-01 (deploy-2026-01-01-04-59)

- Simplify modals_helper.rb by passing locals directly ([PR3677](https://github.com/MushroomObserver/mushroom-observer/pull/3677), @nimmolo)

## 2026-01-01 (deploy-2026-01-01-01-20)

- Delete `herbaria/_form.erb` ([PR3676](https://github.com/MushroomObserver/mushroom-observer/pull/3676), @nimmolo)

## 2026-01-01 (deploy-2026-01-01-00-27)

- Fix destroy buttons on show pages for observation associated records ([PR3675](https://github.com/MushroomObserver/mushroom-observer/pull/3675), @nimmolo)

## 2026-01-01 (deploy-2026-01-01-00-21)

- Fix autocompleter JS - should clear matching id when string changes ([PR3674](https://github.com/MushroomObserver/mushroom-observer/pull/3674), @nimmolo)
- Phlex HerbariumForm component ([PR3640](https://github.com/MushroomObserver/mushroom-observer/pull/3640), @nimmolo)
