# frozen_string_literal: true

# Sidebar indexes nav: herbaria index.
class Tab::Sidebar::Indexes::Herbaria < Tab::Base
  def title
    :HERBARIA.t
  end

  def path
    herbaria_path
  end

  def html_options
    { id: "nav_herbaria_link" }
  end
end
