# frozen_string_literal: true

# The pre-Phlex `DescriptionsHelper` composed the show-page details
# panel, alt-descriptions list, authors block, export/review footer,
# and version/title pieces. All of those moved to:
#
#   - `Views::Controllers::Descriptions::DetailsAndAltsPanel`
#   - `Views::Controllers::Descriptions::AuthorsAndEditorsPanel`
#   - `Views::Controllers::Descriptions::NotesPanels`
#   - `Views::Controllers::Descriptions::List`
#   - `Components::DescriptionModLinks`
#   - `Components::PreviousVersion`
#   - `Components::LicenseBadge`
#
# Only `descriptions_index_sorts` survives, because the controller-test
# sort-coverage harness in `test/general_extensions.rb#index_sorts`
# looks up sorts as `helpers.<controller>_index_sorts`. The harness
# would need refactoring to consume sorts from the action template
# directly; deferring that, this one helper stays so the existing
# sort tests keep working.
module DescriptionsHelper
  def descriptions_index_sorts
    [
      ["name",       :sort_by_name.l],
      ["created_at", :sort_by_created_at.l],
      ["updated_at", :sort_by_updated_at.l],
      ["user",       :sort_by_user.l],
      ["num_views",  :sort_by_num_views.l]
    ].freeze
  end
end
