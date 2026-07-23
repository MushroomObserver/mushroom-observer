# frozen_string_literal: true

# Sidebar indexes nav: herbaria index.
class Tab::Sidebar::Indexes::Herbaria < Tab::Base
  def title
    :herbaria.ti
  end

  def path
    herbaria_path
  end
end
