# frozen_string_literal: true

# "List All Herbaria" link — surfaces on the herbaria index when
# the user is currently viewing the nonpersonal-filtered subset,
# giving a way back to the full list.
class Tab::Herbarium::ListAll < Tab::Base
  def title
    :herbarium_index_list_all_herbaria.l
  end

  def path
    herbaria_path
  end

  def model
    Herbarium
  end
end
