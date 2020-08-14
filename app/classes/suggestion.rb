# frozen_string_literal: true

class Suggestion
  attr_reader :name

  def self.analyze(data)
    matches = {}
    data.each do |image_data|
      next unless image_data.is_a?(Array)

      image_data.each do |name, prob|
        if matches[name]
          matches[name].add_data(prob)
        else
          matches[name] = Suggestion.new(name, prob)
        end
      end
    end
    matches.values
  end

  def initialize(name, prob)
    @name  = best_matching_name(name)
    @probs = [prob]
  end

  def add_data(prob)
    @probs << prob
  end

  def image_obs
    @image_obs ||= example_image_obs
  end

  def max
    @max ||= @probs.max
  end

  def sum
    @sum ||= @probs.inject(0.0) { |sum, val| sum + val }
  end

  def confident?
    max >= 50
  end

  def useless?
    max < 5
  end

  ######################################################################

  private

  def best_matching_name(name_str)
    names = Name.where(text_name: name_str)
    return Name.unknown if names.empty?
    return names.first  if names.length == 1

    names2 = names.reject(&:deprecated)
    return names2.first if names2.length == 1

    names = names2 unless names2.empty?
    name_with_most_observations(names)
  end

  def name_with_most_observations(names)
    best_name = nil
    best_count = -1
    names.each do |name|
      count = name.observations.count
      next if count <= best_count

      best_name = name
      best_count = count
    end
    best_name
  end

  def example_image_obs
    id = Observation.connection.select_value(%(
      SELECT o.id FROM observations o
      JOIN images i ON i.id = o.thumb_image_id
      WHERE o.name_id IN (#{@name.synonym_ids.join(",")})
      AND o.vote_cache >= 2
      ORDER BY o.vote_cache + i.vote_cache DESC
      LIMIT 1
    ))
    Observation.safe_find(id)
  end
end
