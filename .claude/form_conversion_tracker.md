# Form Conversion Tracker

Track progress converting ERB forms (`form_with`/`form_for`) to Phlex Superform components.

## Forms To Convert

### Admin Forms (2)

| File | Form | Status |
| ---- | ---- | ------ |
| `admin/blocked_ips/edit.html.erb` | Block/unblock IPs (2 forms) | |
| `admin/donations/edit.html.erb` | Donations admin | |

### Name Forms (8)

| File | Form | Status |
| ---- | ---- | ------ |
| `names/classification/inherit/new.html.erb` | Inherit classification | Done |
| `names/classification/edit.html.erb` | Edit classification | Done |
| `names/lifeforms/propagate/edit.html.erb` | Propagate lifeform | Done |
| `names/lifeforms/edit.html.erb` | Edit lifeform | Done |
| `names/descriptions/_form.html.erb` | Name description | |
| `names/synonyms/deprecate/new.html.erb` | Deprecate name | Done |
| `names/synonyms/approve/new.html.erb` | Approve name | Done |
| `names/synonyms/edit.html.erb` | Edit synonyms | Done |

### Observation Forms (5)

| File | Form | Status |
| ---- | ---- | ------ |
| `observations/_form.html.erb` | Main observation form | |
| `observations/images/edit.html.erb` | Edit image metadata | |
| `observations/downloads/_form.html.erb` | Download observations | |
| `observations/namings/_form.erb` | Propose naming | |
| `observations/identify/_form_identify_filter.html.erb` | Identify filter | |

### Species List Forms (7)

| File | Form | Status |
| ---- | ---- | ------ |
| `species_lists/_form.html.erb` | Create/edit species list | |
| `species_lists/uploads/new.html.erb` | Upload species list | |
| `species_lists/name_lists/_form.erb` | Name list form | |
| `species_lists/observations/_form.html.erb` | Add observations | |
| `species_lists/write_in/_form.html.erb` | Write-in form | |
| `species_lists/downloads/_form_print_labels.html.erb` | Print labels | |
| `species_lists/downloads/_form_species_list_report.html.erb` | Export report | |

### Location Forms (1)

| File | Form | Status |
| ---- | ---- | ------ |
| `locations/descriptions/_form.html.erb` | Location description | |

### Description Forms (3)

| File | Form | Status |
| ---- | ---- | ------ |
| `descriptions/_form_permissions.html.erb` | Edit permissions | |
| `descriptions/_form_move.html.erb` | Move description | |
| `descriptions/_form_merge.html.erb` | Merge descriptions | |

### Account Forms (4)

| File | Form | Status |
| ---- | ---- | ------ |
| `account/profile/_form.html.erb` | Edit profile | |
| `account/preferences/edit.html.erb` | Edit preferences | |
| `account/api_keys/new.html.erb` | Create API key | |
| `account/api_keys/edit.html.erb` | Edit API key | |

### Other Forms (10)

| File | Form | Status |
| ---- | ---- | ------ |
| `herbaria/show.html.erb` | Add curator | |
| `images/licenses/edit.html.erb` | Bulk update licenses | |
| `field_slips/_form.html.erb` | Field slip (2 forms) | |
| `field_slips/index.html.erb` | Field slip search | |
| `search/advanced.html.erb` | Advanced search | |
| `visual_groups/edit.html.erb` | Visual group image filter | |
| `support/donate.html.erb` | Donation form | |
| `translations/_form.erb` | Translation edit | |

### Shared Partials (4)

| File | Form | Status |
| ---- | ---- | ------ |
| `shared/_images_to_remove.erb` | Remove images | |
| `shared/_images_to_reuse.erb` | Reuse images | |
| `shared/_list_search.html.erb` | Search dispatch | |
| `application/top_nav/_search_bar.html.erb` | Top nav search | |

## Completed Conversions

Forms that have been fully converted to Phlex components:

| Component | Replaces | Date |
| --------- | -------- | ---- |
| `AccountSignupForm` | account/new.html.erb` | 20250107 [Convert account signup form to Phlex component #3720](https://github.com/MushroomObserver/mushroom-observer/pull/3720) |
| `AdminSessionForm` | `admin/session/edit.html.erb` | 2026-01-05 |
| `BannerForm` | `admin/banners/index.html.erb` | 2026-01-07 |
| `ArticleForm` | `articles/_form.html.erb` | 2026-01-03 |
| `VisualGroupForm` | `visual_groups/_form.html.erb` | 2026-01-03 |
| `VisualModelForm` | `visual_models/_form.html.erb` | 2026-01-03 |
| `LocationForm` | `locations/_form.erb` | 2026-01-03 |
| `InatImportForm` | `inat_imports/new.html.erb` | 2026-02-12 |
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
| `NameClassificationForm` | `names/classification/edit.html.erb` | 2026-01-27 |
| `NameInheritClassificationForm` | `names/classification/inherit/new.html.erb` | 2026-01-27 |
| `NameLifeformForm` | `names/lifeforms/edit.html.erb` | 2026-01-27 |
| `NamePropagateLifeformForm` | `names/lifeforms/propagate/edit.html.erb` | 2026-01-27 |
| `NameApproveSynonymForm` | `names/synonyms/approve/new.html.erb` | 2026-01-27 |
| `NameDeprecateSynonymForm` | `names/synonyms/deprecate/new.html.erb` | 2026-01-27 |
| `NameEditSynonymForm` | `names/synonyms/edit.html.erb` | 2026-01-27 |
| `Descriptions::AuthorRequestForm` | `descriptions/author_requests/new.html.erb` | 2026-01-28 |
| ... and 17 modal forms | | |

### Email Form Object Consolidation (2026-01-28)

Consolidated 5 email form objects into single `FormObject::EmailRequest`:
- Deleted: `CommercialInquiry`, `MergeRequest`, `NameChangeRequest`, `ProjectAdminRequest`, `WebmasterQuestion`
- All email forms now use `params[:email][:message]` consistently
- Added `form_class` prop to `ModalForm` for explicit form component lookup
- Standardized field names: `notes`/`content` → `message`

## Notes

- All paths are relative to `app/views/controllers/`
- Modal forms were converted as part of the modal form conversion project
- Some forms may have multiple `form_with` calls (e.g., field_slips has 2)
