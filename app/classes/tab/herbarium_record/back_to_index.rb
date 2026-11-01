# frozen_string_literal: true

# "Back to herbarium_records index" link (used by the edit form when
# arriving from the index). Carries the current Query through.
class Tab::HerbariumRecord::BackToIndex < Tab::Base
  def initialize(index_filter: nil)
    super()
    @index_filter = index_filter
  end

  def title
    :edit_herbarium_record_back_to_index.l
  end

  def path
    if @index_filter
      herbarium_records_path(**@index_filter)
    else
      herbarium_records_path
    end
  end
end
