module Query::Modules::Joining
  JOIN_CONDITIONS = {
    api_keys: {
      users: :user_id
    },
    articles: {
      rss_logs: :rss_log_id,
      users: :user_id
    },
    collection_numbers: {
      users: :user_id
    },
    collection_numbers_observations: {
      collection_numbers: :collection_number_id,
      observations: :observation_id
    },
    comments: {
      location_descriptions: :target,
      locations: :target,
      name_descriptions: :target,
      names: :target,
      observations: :target,
      projects: :target,
      species_lists: :target,
      users: :user_id
    },
    donations: {
      users: :user_id
    },
    external_links: {
      external_sites: :external_site_id,
      observations: :observation_id,
      users: :user_id
    },
    external_sites: {
      projects: :project_id
    },
    glossary_terms: {
      :"images.thumb_image" => :thumb_image_id,
      rss_logs: :rss_log_id,
      users: :user_id
    },
    glossary_terms_images: {
      images: :image_id,
      glossary_terms: :glossary_term_id
    },
    herbaria: {
      locations: :location_id,
      users: :personal_user_id
    },
    herbaria_curators: {
      herbaria: :herbarium_id,
      users: :user_id
    },
    image_votes: {
      images: :image_id,
      users: :user_id
    },
    images: {
      users: :user_id,
      licenses: :license_id
    },
    images_observations: {
      images: :image_id,
      observations: :observation_id
    },
    images_projects: {
      images: :image_id,
      projects: :project_id
    },
    interests: {
      locations: :target,
      names: :target,
      observations: :target,
      users: :user_id
    },
    location_descriptions: {
      locations: :location_id,
      users: :user_id
    },
    location_descriptions_admins: {
      location_descriptions: :location_description_id,
      user_groups: :user_group_id
    },
    location_descriptions_authors: {
      location_descriptions: :location_description_id,
      users: :user_id
    },
    location_descriptions_editors: {
      location_descriptions: :location_description_id,
      users: :user_id
    },
    location_descriptions_readers: {
      location_descriptions: :location_description_id,
      user_groups: :user_group_id
    },
    location_descriptions_versions: {
      location_descriptions: :location_description_id
    },
    location_descriptions_writers: {
      location_descriptions: :location_description_id,
      user_groups: :user_group_id
    },
    locations: {
      licenses: :license_id,
      :"location_descriptions.default" => :description_id,
      rss_logs: :rss_log_id,
      users: :user_id
    },
    locations_versions: {
      locations: :location_id
    },
    name_descriptions: {
      names: :name_id,
      users: :user_id
    },
    name_descriptions_admins: {
      name_descriptions: :name_description_id,
      user_groups: :user_group_id
    },
    name_descriptions_authors: {
      name_descriptions: :name_description_id,
      users: :user_id
    },
    name_descriptions_editors: {
      name_descriptions: :name_description_id,
      users: :user_id
    },
    name_descriptions_readers: {
      name_descriptions: :name_description_id,
      user_groups: :user_group_id
    },
    name_descriptions_versions: {
      name_descriptions: :name_description_id
    },
    name_descriptions_writers: {
      name_descriptions: :name_description_id,
      user_groups: :user_group_id
    },
    names: {
      licenses: :license_id,
      :"name_descriptions.default" => :description_id,
      rss_logs: :rss_log_id,
      users: :user_id,
      :"users.reviewer" => :reviewer_id
    },
    names_versions: {
      names: :name_id
    },
    naming_reasons: {
      namings: :naming_id
    },
    namings: {
      names: :name_id,
      observations: :observation_id,
      users: :user_id
    },
    notifications: {
      names: :obj,
      users: :user_id
    },
    observations: {
      locations: :location_id,
      names: :name_id,
      rss_logs: :rss_log_id,
      users: :user_id,
      :"images.thumb_image" => :thumb_image_id,
      :"image_votes.thumb_image" => [:thumb_image_id, :image_id]
    },
    observations_projects: {
      observations: :observation_id,
      projects: :project_id
    },
    observations_species_lists: {
      observations: :observation_id,
      species_lists: :species_list_id
    },
    herbarium_records_observations: {
      observations: :observation_id,
      herbarium_records: :herbarium_record_id
    },
    projects: {
      users: :user_id,
      rss_logs: :rss_log_id,
      user_groups: :user_group_id,
      :"user_groups.admin_group" => :admin_group_id
    },
    projects_species_lists: {
      projects: :project_id,
      species_lists: :species_list_id
    },
    publications: {
      users: :user_id
    },
    rss_logs: {
      locations: :location_id,
      names: :name_id,
      observations: :observation_id,
      species_lists: :species_list_id
    },
    sequences: {
      observations: :observation_id,
      users: :user_id
    },
    species_lists: {
      locations: :location_id,
      rss_logs: :rss_log_id,
      users: :user_id
    },
    herbarium_records: {
      herbaria: :herbarium_id,
      users: :user_id
    },
    user_groups_users: {
      user_groups: :user_group_id,
      users: :user_id
    },
    users: {
      images: :image_id,
      licenses: :license_id,
      locations: :location_id
    },
    votes: {
      namings: :naming_id,
      observations: :observation_id,
      users: :user_id
    }
  }.freeze

  # Create SQL "JOIN ON" clause to join two tables.  Tack on an exclamation to
  # make it an outer join.  Tack on ".field" to specify alternate association.
  def calc_join_condition(from, to, done)
    from = from.sub(/\..*/, "")
    to = to.dup
    do_outer = to.sub!(/!$/, "")

    result = []
    unless done.include?(to)
      done << to

      # Check for "forward" join first, e.g., if joining from observatons to
      # rss_logs, use "observations.rss_log_id = rss_logs.id", because that will
      # take advantage of the primary key on rss_logs.id.
      if col = (JOIN_CONDITIONS[from.to_sym] && JOIN_CONDITIONS[from.to_sym][to.to_sym])
        to.sub!(/\..*/, "")
        target_table = to

      # Now look for "reverse" join.  (In the above example, and this was how it
      # used to be, it would be "observations.id = rss_logs.observation_id".)
      elsif col = (JOIN_CONDITIONS[to.to_sym] && JOIN_CONDITIONS[to.to_sym][from.to_sym])
        to.sub!(/\..*/, "")
        target_table = to
        from, to = to, from
      else
        raise("Don't know how to join from #{from} to #{to}.")
      end

      # By default source table column is just "id"; enter both target and source
      # columns explcitly by making join table value an Array.
      if col.is_a?(Array)
        col1, col2 = *col
      else
        col1 = col
        col2 = :id
      end

      # Calculate conditions.
      if !col1.to_s.match(/_id$/)
        conds = "#{from}.#{col1}_id = #{to}.id AND " \
                "#{from}.#{col1}_type = '#{to.singularize.camelize}'"
      else
        conds = "#{from}.#{col1} = #{to}.#{col2}"
      end

      # Put the whole JOIN clause together.
      if do_outer
        result << ["LEFT OUTER JOIN `#{target_table}` ON #{conds}"]
      else
        result << ["JOIN `#{target_table}` ON #{conds}"]
      end
    end
    result
  end
end
