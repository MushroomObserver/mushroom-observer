# frozen_string_literal: true

class AutoComplete::ForProject < AutoComplete::ByWord
  def rough_matches(letter)
    projects = Project.select(:title, :id).distinct.
               where(Project[:title].matches("#{letter}%").
                 or(Project[:title].matches("% #{letter}%"))).
               order(title: :asc).pluck(:title, :id)

    projects.map! { |name, id| { name: name, id: id } }
  end
end
