# Form Conversion Tracker

Track progress converting ERB forms (`form_with`/`form_for`) to Phlex Superform components.

## Forms To Convert

### Admin Forms (1)

| File | Form | Status |
| ---- | ---- | ------ |
| `admin/donations/edit.html.erb` | Donations admin | |

### Description Forms (3)

| File | Form | Status |
| ---- | ---- | ------ |
| `descriptions/_form_permissions.html.erb` | Edit permissions | |
| `descriptions/_form_move.html.erb` | Move description | |
| `descriptions/_form_merge.html.erb` | Merge descriptions | |

### Observation Forms (4)

| File | Form | Status |
| ---- | ---- | ------ |
| `observations/images/edit.html.erb` | Edit image metadata | |
| `observations/downloads/_form.html.erb` | Download observations | |
| `observations/namings/_form.erb` | Propose naming | |
| `observations/identify/_form_identify_filter.html.erb` | Identify filter | |

### Species List Forms (8)

| File | Form | Status |
| ---- | ---- | ------ |
| `species_lists/_form.html.erb` | Create/edit species list | |
| `species_lists/uploads/new.html.erb` | Upload species list | |
| `species_lists/name_lists/_form.erb` | Name list form | |
| `species_lists/observations/_form.html.erb` | Add observations | |
| `species_lists/write_in/_form.html.erb` | Write-in form | |
| `species_lists/downloads/_form_print_labels.html.erb` | Print labels | |
| `species_lists/downloads/_form_species_list_report.html.erb` | Export report | |
| `species_lists/projects/edit.html.erb` | Edit project membership | |

### Project Forms (3)

| File | Form | Status |
| ---- | ---- | ------ |
| `projects/_form.html.erb` | Create/edit project | |
| `projects/violations/index.html.erb` | Violations form | |
| `projects/field_slips/new.html.erb` | Project field slips | |

### Account Forms (4)

| File | Form | Status |
| ---- | ---- | ------ |
| `account/profile/_form.html.erb` | Edit profile | |
| `account/preferences/edit.html.erb` | Edit preferences | |
| `account/api_keys/new.html.erb` | Create API key | |
| `account/api_keys/edit.html.erb` | Edit API key | |

### Other Forms (7)

| File | Form | Status |
| ---- | ---- | ------ |
| `herbaria/show.html.erb` | Add curator | |
| `images/licenses/edit.html.erb` | Bulk update licenses | |
| `field_slips/_form.html.erb` | Field slip (2 forms) | |
| `field_slips/index.html.erb` | Field slip search | |
| `visual_groups/edit.html.erb` | Visual group image filter | |
| `support/donate.html.erb` | Donation form | |
| `translations/_form.erb` | Translation edit | |
| `inat_imports/new.html.erb` | iNat import | |

### Shared Partials (4)

| File | Form | Status |
| ---- | ---- | ------ |
| `shared/_images_to_remove.erb` | Remove images | |
| `shared/_images_to_reuse.erb` | Reuse images | |
| `shared/_list_search.html.erb` | Search dispatch | |
| `application/top_nav/_search_bar.html.erb` | Top nav search | |

## In Progress / Other PRs

| File | Form | PR/Status |
| ---- | ---- | --------- |
| `observations/_form.html.erb` | Main observation form | In progress PR |
| `names/synonyms/approve/new.html.erb` | Approve name | nimmo-phlex-name-classification-forms |
| `names/synonyms/deprecate/new.html.erb` | Deprecate name | nimmo-phlex-name-classification-forms |
| `names/synonyms/edit.html.erb` | Edit synonyms | nimmo-phlex-name-classification-forms |
| `names/lifeforms/edit.html.erb` | Edit lifeform | nimmo-phlex-name-classification-forms |
| `names/lifeforms/propagate/edit.html.erb` | Propagate lifeform | nimmo-phlex-name-classification-forms |
| `names/classification/inherit/new.html.erb` | Inherit classification | nimmo-phlex-name-classification-forms |
| `names/classification/edit.html.erb` | Edit classification | nimmo-phlex-name-classification-forms |

## To Be Deleted

| File | Reason |
| ---- | ------ |
| `search/advanced.html.erb` | Feature being removed |

## Completed Conversions

| Component | Replaces | Date |
| --------- | -------- | ---- |
| `NameForm` | `names/_form.html.erb` | |
| `AccountSignupForm` | `account/new.html.erb` | 2025-01-07 |
| `AdminSessionForm` | `admin/session/edit.html.erb` | 2026-01-05 |
| `BannerForm` | `admin/banners/index.html.erb` | 2026-01-07 |
| `ArticleForm` | `articles/_form.html.erb` | 2026-01-03 |
| `VisualGroupForm` | `visual_groups/_form.html.erb` | 2026-01-03 |
| `VisualModelForm` | `visual_models/_form.html.erb` | 2026-01-03 |
| `LocationForm` | `locations/_form.erb` | 2026-01-03 |
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
| `Descriptions::AuthorRequestForm` | `descriptions/author_requests/new.html.erb` | 2026-01-28 |
| Email forms (5) | Various email request forms | 2026-01-28 |
| `DescriptionForm` | `names/descriptions/_form.html.erb`, `locations/descriptions/_form.html.erb`, `descriptions/_fields_for_description.html.erb` | 2026-01-28 |

### Email Form Object Consolidation (2026-01-28)

Consolidated 5 email form objects into single `FormObject::EmailRequest`:
- Deleted: `CommercialInquiry`, `MergeRequest`, `NameChangeRequest`, `ProjectAdminRequest`, `WebmasterQuestion`
- All email forms now use `params[:email][:message]` consistently
- Added `form_class` prop to `ModalForm` for explicit form component lookup
- Standardized field names: `notes`/`content` → `message`, `email` → `reply_to`

## Notes

- All paths are relative to `app/views/controllers/`
- Modal forms were converted as part of the modal form conversion project
- Some forms may have multiple `form_with` calls (e.g., field_slips has 2)
- Total: 46 ERB files with forms found
