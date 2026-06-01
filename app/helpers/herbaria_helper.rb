# frozen_string_literal: true

module HerbariaHelper
  # Sort options for the herbaria index page. The nonpersonal-only
  # subset drops the "user" sort (there is no personal user on
  # nonpersonal herbaria). Used by the index ERB / Phlex views via
  # `add_sorter` and re-included into `Tabs::HerbariumRecordsHelper`
  # for the herbarium-records index's sort dropdown.
  def herbaria_index_sorts(query: nil)
    return nonpersonal_herbaria_index_sorts if query&.params&.dig(:nonpersonal)

    full_herbaria_index_sorts
  end

  def full_herbaria_index_sorts
    [
      ["records",     :sort_by_records.t],
      ["curator",     :sort_by_curator.t],
      ["code",        :sort_by_code.t],
      ["name",        :sort_by_name.t],
      ["user",        :sort_by_user.t],
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t]
    ].freeze
  end

  def nonpersonal_herbaria_index_sorts
    # must dup a frozen array, this is new ruby 3 policy
    sorts = full_herbaria_index_sorts.map(&:clone)
    sorts.reject! { |x| x[0] == "user" }
  end
end
