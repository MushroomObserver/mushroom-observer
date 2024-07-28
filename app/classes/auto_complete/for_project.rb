# frozen_string_literal: true

class AutoComplete::ForProject < AutoComplete::ByWord
  def rough_matches(letter)
    projects = Project.select(:title, :id).distinct.
               where(Project[:title].matches("#{letter}%").
                 or(Project[:title].matches("% #{letter}%"))).
               order(title: :asc)

    # Turn the instances into hashes, and alter title key
    projects.map do |project|
      project = project.attributes.symbolize_keys
      { name: project[:title], id: project[:id] }
    end
  end
end
