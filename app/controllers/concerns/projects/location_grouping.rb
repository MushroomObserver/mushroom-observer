# frozen_string_literal: true

module Projects
  # Shared logic for grouping project locations under target
  # locations by name suffix.
  module LocationGrouping
    private

    def build_grouped_locations(project)
      obs_locs = project.locations.distinct.to_a
      targets = sorted_targets(project)
      sorted_obs = obs_locs.sort_by(&:scientific_name)
      return [[], sorted_obs] if targets.empty?

      groups = build_groups(obs_locs, targets)
      grouped_ids = collect_grouped_ids(groups, targets)
      ungrouped = sorted_obs.reject do |l|
        grouped_ids.include?(l.id)
      end
      [groups, ungrouped]
    end

    def sorted_targets(project)
      project.target_locations.
        order(:scientific_name).to_a
    end

    def build_groups(obs_locs, targets)
      assignments = assign_to_targets(obs_locs, targets)
      targets.map do |target|
        subs = (assignments[target.id] || []).
               sort_by(&:scientific_name)
        { target: target, sub_locations: subs }
      end
    end

    # Assign each observed location to its most specific
    # (longest name) matching target to avoid duplicates.
    def assign_to_targets(obs_locs, targets)
      assignments = {}
      obs_locs.each do |loc|
        best = most_specific_target(loc, targets)
        next unless best

        (assignments[best.id] ||= []) << loc
      end
      assignments
    end

    def most_specific_target(loc, targets)
      matches = targets.select do |t|
        loc.id != t.id && loc.name.end_with?(", #{t.name}")
      end
      matches.max_by { |t| t.name.length }
    end

    def collect_grouped_ids(groups, target_locs)
      ids = Set.new(target_locs.map(&:id))
      groups.each do |g|
        g[:sub_locations].each { |loc| ids.add(loc.id) }
      end
      ids
    end

    def observation_counts(project)
      project.visible_observations.
        where.not(location_id: nil).
        group(:location_id).count
    end
  end
end
