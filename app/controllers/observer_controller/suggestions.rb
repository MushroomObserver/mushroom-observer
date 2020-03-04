# see observer_controller.rb
class ObserverController
  def suggestions # :norobots:
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    @suggestions = best_matches(JSON.parse(params[:names].to_s)).
                   map { |name, prob| suggested_name_data(name, prob) }.
                   reject(&:nil?)
  end

  def best_matches(results)
    matches = {}
    results.each do |sub_results|
      next unless sub_results.is_a?(Array)

      sub_results.each do |name, prob|
flash_notice("result: [#{name.inspect}, #{prob.inspect}]")
        next if matches[name].present? && matches[name][1] >= prob

        matches[name] = [name, prob]
      end
    end
    matches.values.sort_by { |_name, prob| -prob }[0..4]
  end

  def suggested_name_data(name_str, prob)
flash_notice("best match: [#{name_str.inspect}, #{prob.inspect}]")
    name = best_matching_name(name_str)
    return nil if name.blank?

    [name, prob, *best_image(name)]
  end

  def best_matching_name(name_str)
    names = Name.where(text_name: name_str)
    return nil if names.empty?
    return names.first if names.length == 1

    names2 = names.reject(&:deprecated)
    return names2.first if names2.length == 1

    names = names2 unless names2.empty?
    name_with_most_observations(names)
  end

  def name_with_most_observations(names)
    name, count = names.inject([nil, -1]) do |best, name|
      count = name.observations.count
      best = [name, count] if count > best[1]
    end
    name
  end

  def best_image(name)
    id = Observation.connection.select_value %(
      SELECT o.id FROM observations o
      JOIN images i ON i.id = o.thumb_image_id
      WHERE o.name_id IN (#{name.synonym_ids.join(",")})
      AND o.vote_cache >= 2
      ORDER BY i.vote_cache DESC
      LIMIT 1
    )
    obs = Observation.safe_find(id)
    [obs, obs.try(&:thumb_image)]
  end
end
