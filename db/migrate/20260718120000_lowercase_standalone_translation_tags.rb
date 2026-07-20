# frozen_string_literal: true

# Lowercase every ALL-CAPS (or Title-Case) tag #4843's sweep found with
# no pre-existing lowercase counterpart to fall back on: 5 theme-name
# tags (Agaricus/Amanita/BlackOnWhite/Cantharellaceae/Hygrocybe) plus
# 69 standalone tags (OK/DQA/CURATOR/... -- see #4843 for the full
# audit). Each of these has translated content in some subset of
# languages that a plain en.txt key rename would NOT move in the
# database -- only `TranslationString.rename_tags` does that. Without
# this migration, the next `rails lang:update` after this PR ships
# would delete every language's row still sitting under the old tag,
# since `strip` removes any `translation_strings` row whose tag isn't
# in `config/locales/en.txt` (and the old ALL-CAPS/Title-Case key
# never will be again).
#
# Run this before `rails lang:update`, not after.
class LowercaseStandaloneTranslationTags < ActiveRecord::Migration[7.2]
  RENAMES = {
    Agaricus: :agaricus,
    Amanita: :amanita,
    BlackOnWhite: :black_on_white,
    Cantharellaceae: :cantharellaceae,
    Hygrocybe: :hygrocybe,
    ACTIONS: :actions,
    ADD_ALL: :add_all,
    ADD_TO: :add_to,
    ALT: :alt,
    ANNOTATIONS: :annotations,
    AREA: :area,
    CHECKLISTS: :checklists,
    COLLECTOR: :collector,
    CONNECTED_TO: :connected_to,
    CONSENSUS: :consensus,
    CONSTRAINTS: :constraints,
    CONTRIBUTORS: :contributors,
    COPIED: :copied,
    COPY_THIS_ID: :copy_this_id,
    COPY_THIS_NAME: :copy_this_name,
    COPY_THIS_SEQUENCE: :copy_this_sequence,
    COUNTERPART: :counterpart,
    CREATED_BY: :created_by,
    CURATOR: :curator,
    CURATORS: :curators,
    DONATIONS: :donations,
    DQA: :dqa,
    EDITING: :editing,
    EXTERNAL_ID: :external_id,
    FILENAME: :filename,
    GOTO: :goto,
    ID_BY: :id_by,
    IDENTIFY: :identify,
    IMPORT: :import,
    INAT_IMPORT_JOB_TRACKERS: :inat_import_job_trackers,
    INAT_IMPORTS: :inat_imports,
    INDEX_OBJECT: :index_object,
    INFO: :info,
    INFORMATION: :information,
    INTERESTS: :interests,
    LAT: :lat,
    LAT_LON: :lat_lon,
    LNG: :lng,
    MAXIMUM: :maximum,
    MENU: :menu,
    NEXT_OBJECT: :next_object,
    OBSERVATION_FIELDS: :observation_fields,
    OBSERVED: :observed,
    OK: :ok,
    OPEN: :open,
    ORIGINAL: :original,
    PAGE: :page,
    PAGES: :pages,
    PIVOTAL: :pivotal,
    PLACE: :place,
    POLICY: :policy,
    PREV_OBJECT: :prev_object,
    PROJECT_ALIAS: :project_alias,
    PROJECT_ALIASES: :project_aliases,
    RECORD: :record,
    RELATIONSHIP: :relationship,
    SAVING: :saving,
    SEARCHES: :searches,
    SECONDS: :seconds,
    SEE_MESSAGE_BELOW: :see_message_below,
    SKIP: :skip,
    SUBMITTING: :submitting,
    TARGET_TYPE: :target_type,
    TEST: :test,
    TEST_PAGES: :test_pages,
    THEME: :theme,
    UNDER_DEVELOPMENT: :under_development,
    UPDATING: :updating,
    URL: :url
  }.freeze

  def up
    TranslationString.rename_tags(RENAMES)
  end

  def down
    TranslationString.rename_tags(RENAMES.invert)
  end
end
