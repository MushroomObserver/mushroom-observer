# frozen_string_literal: true

module Projects
  # Shared logic for grouping project locations under target
  # locations by name suffix.
  module LocationGrouping
    private

    def build_grouped_locations(project)
      obs_locs = project.locations.distinct.to_a
      target_locs = project.target_locations.order(:scientific_name).to_a
      sorted_obs = obs_locs.sort_by(&:scientific_name)
      return [[], sorted_obs] if target_locs.empty?

      groups = build_target_groups(obs_locs, target_locs)
      grouped_ids = collect_grouped_ids(groups, target_locs)
      ungrouped = sorted_obs.reject do |l|
        grouped_ids.include?(l.id)
      end
      [groups, ungrouped]
    end

    def build_target_groups(obs_locs, target_locs)
      target_locs.map do |target|
        subs = find_sub_locations(obs_locs, target)
        build_group(target, subs)
      end
    end

    def collect_grouped_ids(groups, target_locs)
      ids = Set.new(target_locs.map(&:id))
      groups.each do |g|
        g[:sub_locations].each { |loc| ids.add(loc.id) }
      end
      ids
    end

    def find_sub_locations(obs_locs, target)
      suffix = ", #{target.name}"
      obs_locs.select do |loc|
        loc.id != target.id && loc.name.end_with?(suffix)
      end.sort_by(&:scientific_name)
    end

    def build_group(target, sub_locations)
      { target: target, sub_locations: sub_locations }
    end

    def observation_counts(project)
      project.visible_observations.
        where.not(location_id: nil).
        group(:location_id).count
    end

    def empty_grouping
      [[], []]
    end
  end
end
