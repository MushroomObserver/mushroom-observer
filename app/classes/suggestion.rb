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
    @sum ||= @probs.sum(0.0)
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

  # Nimmo note: rails t -n /ObserverControllerTest#test_suggestions/
  def example_image_obs
    # id = Observation.connection.select_value(%(
    #   SELECT o.id FROM observations o
    #   JOIN images i ON i.id = o.thumb_image_id
    #   WHERE o.name_id IN (#{@name.synonym_ids.join(",")})
    #   AND o.vote_cache >= 2
    #   ORDER BY o.vote_cache + i.vote_cache DESC
    #   LIMIT 1
    # ))

    # Joining the Arel tables explicitly on(x) generates a clean INNER JOIN:
    #
    # SELECT `observations`.`id` FROM `observations`
    # INNER JOIN `images` ON `images`.`id` = `observations`.`thumb_image_id`
    # WHERE (`observations`.`name_id` = 981143639)
    # AND (`observations`.`vote_cache` >= 2.0)
    # ORDER BY (`observations`.`vote_cache` + `images`.`vote_cache`) DESC
    # LIMIT 1

    o_i_inner_join = Observation.arel_table.join(Image.arel_table).
                     on(Image[:id].eq(Observation[:thumb_image_id]))

    # Below we just return the observation itself, not the id then safe_find(id)
    # Note: Ruby 2.7 will allow endless ranges like (vote_cache: 2..)
    Observation.joins(o_i_inner_join.join_sources).
      where(name_id: @name.synonym_ids, vote_cache: 2..Float::INFINITY).
      order((Observation[:vote_cache] + Image[:vote_cache]).desc).limit(1).first
  end
end
