# frozen_string_literal: true

class Autocomplete::ForProject < Autocomplete::ByWord
  def rough_matches(letter)
    projects = Project.select(:title, :id).distinct.
               where(Project[:title].matches("#{letter}%").
                 or(Project[:title].matches("% #{letter}%"))).
               order(title: :asc)

    matches_array(projects)
  end

  def exact_match(string)
    project = Project.select(:title, :id).distinct.
              where(Project[:title].eq(string)).first
    return [] unless project

    matches_array([project])
  end

  # Turn the instances into hashes, and alter title key
  def matches_array(projects)
    projects.map do |project|
      project = project.attributes.symbolize_keys
      { name: project[:title], id: project[:id] }
    end
  end
end
