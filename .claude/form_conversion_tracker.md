# Form Conversion Tracker

Track progress converting ERB forms (`form_with`/`form_for`) to Phlex Superform components.

## Forms To Convert

### Admin Forms (3)

| File | Form | Status |
|------|------|--------|
| `admin/blocked_ips/edit.html.erb` | Block/unblock IPs (2 forms) | |
| `admin/donations/edit.html.erb` | Donations admin | |
| `admin/banners/index.html.erb` | Banner management | 20260106 converted form to `app/components/banner_form.rb` |

### Name Forms (8)

| File | Form | Status |
|------|------|--------|
| `names/classification/inherit/new.html.erb` | Inherit classification | |
| `names/classification/edit.html.erb` | Edit classification | |
| `names/lifeforms/propagate/edit.html.erb` | Propagate lifeform | |
| `names/lifeforms/edit.html.erb` | Edit lifeform | |
| `names/descriptions/_form.html.erb` | Name description | |
| `names/synonyms/deprecate/new.html.erb` | Deprecate name | |
| `names/synonyms/approve/new.html.erb` | Approve name | |
| `names/synonyms/edit.html.erb` | Edit synonyms | |

### Observation Forms (5)

| File | Form | Status |
|------|------|--------|
| `observations/_form.html.erb` | Main observation form | |
| `observations/images/edit.html.erb` | Edit image metadata | |
| `observations/downloads/_form.html.erb` | Download observations | |
| `observations/namings/_form.erb` | Propose naming | |
| `observations/identify/_form_identify_filter.html.erb` | Identify filter | |

### Species List Forms (7)

| File | Form | Status |
|------|------|--------|
| `species_lists/_form.html.erb` | Create/edit species list | |
| `species_lists/uploads/new.html.erb` | Upload species list | |
| `species_lists/name_lists/_form.erb` | Name list form | |
| `species_lists/observations/_form.html.erb` | Add observations | |
| `species_lists/write_in/_form.html.erb` | Write-in form | |
| `species_lists/downloads/_form_print_labels.html.erb` | Print labels | |
| `species_lists/downloads/_form_species_list_report.html.erb` | Export report | |

### Location Forms (1)

| File | Form | Status |
|------|------|--------|
| `locations/descriptions/_form.html.erb` | Location description | |

### Description Forms (4)

| File | Form | Status |
|------|------|--------|
| `descriptions/author_requests/new.html.erb` | Request authorship | |
| `descriptions/_form_permissions.html.erb` | Edit permissions | |
| `descriptions/_form_move.html.erb` | Move description | |
| `descriptions/_form_merge.html.erb` | Merge descriptions | |

### Account Forms (5)

| File | Form | Status |
|------|------|--------|
| `account/new.html.erb` | Create account | |
| `account/profile/_form.html.erb` | Edit profile | |
| `account/preferences/edit.html.erb` | Edit preferences | |
| `account/api_keys/new.html.erb` | Create API key | |
| `account/api_keys/edit.html.erb` | Edit API key | |

### Other Forms (10)

| File | Form | Status |
|------|------|--------|
| `herbaria/show.html.erb` | Add curator | |
| `images/licenses/edit.html.erb` | Bulk update licenses | |
| `field_slips/_form.html.erb` | Field slip (2 forms) | |
| `field_slips/index.html.erb` | Field slip search | |
| `search/advanced.html.erb` | Advanced search | |
| `visual_groups/edit.html.erb` | Visual group image filter | |
| `support/donate.html.erb` | Donation form | |
| `translations/_form.erb` | Translation edit | |
| `inat_imports/new.html.erb` | iNat import | |

### Shared Partials (4)

| File | Form | Status |
|------|------|--------|
| `shared/_images_to_remove.erb` | Remove images | |
| `shared/_images_to_reuse.erb` | Reuse images | |
| `shared/_list_search.html.erb` | Search dispatch | |
| `application/top_nav/_search_bar.html.erb` | Top nav search | |

## Completed Conversions

Forms that have been fully converted to Phlex components:

| Component | Replaces | Date |
|-----------|----------|------|
| `AdminSessionForm` | `admin/session/edit.html.erb` | 2026-01-05 |
| `ArticleForm` | `articles/_form.html.erb` | 2026-01-03 |
| `VisualGroupForm` | `visual_groups/_form.html.erb` | 2026-01-03 |
| `VisualModelForm` | `visual_models/_form.html.erb` | 2026-01-03 |
| `LocationForm` | `locations/_form.erb` | 2026-01-03 |
| `NameForm` | `names/_form.html.erb` | |
| `HerbariumRecordForm` | `herbarium_records/_form.erb` | |
| `CommentForm` | `comments/_form.erb` | |
| `NamingForm` | Modal naming form | |
| `SequenceForm` | Modal sequence form | |
| `CollectionNumberForm` | Modal collection number | |
| `ExternalLinkForm` | `observations/external_links/_form.erb` | |
| `HerbariumForm` | `herbaria/_form.html.erb` | |
| `GlossaryTermForm` | Modal glossary term | |
| `ProjectMemberForm` | `projects/members/_form.html.erb` | |
| `ProjectAliasForm` | Modal project alias | |
| ... and 17 modal forms | | |

## Notes

- All paths are relative to `app/views/controllers/`
- Modal forms were converted as part of the modal form conversion project
- Some forms may have multiple `form_with` calls (e.g., field_slips has 2)
