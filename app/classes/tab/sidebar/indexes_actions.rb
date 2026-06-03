# frozen_string_literal: true

# Sidebar "Indexes" section — glossary / herbaria / locations / names /
# projects. Shown only to logged-in users.
class Tab::Sidebar::IndexesActions < Tab::Collection
  private

  def tabs
    [Tab::Sidebar::Indexes::Glossary.new,
     Tab::Sidebar::Indexes::Herbaria.new,
     Tab::Sidebar::Indexes::Locations.new,
     Tab::Sidebar::Indexes::Names.new,
     Tab::Sidebar::Indexes::Projects.new]
  end
end
