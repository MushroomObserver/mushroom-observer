module Query::Modules::Ordering
  def initialize_order
    by = params[:by]
    # Let queries define custom order spec in "order", but have explicitly
    # passed-in "by" parameter take precedence.  If neither is given, then
    # fall back on the "default_order" finally.
    if by || order.blank?
      by ||= default_order
      by = by.dup
      reverse = !!by.sub!(/^reverse_/, "")
      result = initialize_order_specs(by)
      self.order = reverse ? reverse_order(result) : result
    end
  end

  def initialize_order_specs(by)
    table = model.table_name
    columns = model.column_names
    case by

    when "updated_at", "created_at", "last_login", "num_views"
      "#{table}.#{by} DESC" if columns.include?(by)

    when "date"
      if columns.include?("date")
        "#{table}.date DESC"
      elsif columns.include?("when")
        "#{table}.when DESC"
      elsif columns.include?("created_at")
        "#{table}.created_at DESC"
      end

    when "name"
      if model == Image
        add_join(:images_observations, :observations)
        add_join(:observations, :names)
        self.group = "images.id"
        "MIN(names.sort_name) ASC, images.when DESC"
      elsif model == Location
        if User.current_location_format == :scientific
          "locations.scientific_name ASC"
        else
          "locations.name ASC"
        end
      elsif model == LocationDescription
        add_join(:locations)
        "locations.name ASC, location_descriptions.created_at ASC"
      elsif model == Name
        "names.sort_name ASC"
      elsif model == NameDescription
        add_join(:names)
        "names.sort_name ASC, name_descriptions.created_at ASC"
      elsif model == Observation
        add_join(:names)
        "names.sort_name ASC, observations.when DESC"
      elsif columns.include?("sort_name")
        "#{table}.sort_name ASC"
      elsif columns.include?("name")
        "#{table}.name ASC"
      elsif columns.include?("title")
        "#{table}.title ASC"
      end

    when "title", "login", "summary", "copyright_holder", "where",
         "initial_det", "accession_number"
      "#{table}.#{by} ASC" if columns.include?(by)

    when "user"
      if columns.include?("user_id") || model == Herbarium
        add_join(:users)
        'IF(users.name = "" OR users.name IS NULL, users.login, users.name) ASC'
      end

    when "location"
      if columns.include?("location_id")
        # Join Users with null locations, else join records with locations
        model == User ? add_join(:locations!) : add_join(:locations)
        if User.current_location_format == :scientific
          "locations.scientific_name ASC"
        else
          "locations.name ASC"
        end
      end

    when "rss_log"
      if columns.include?("rss_log_id")
        add_join(:rss_logs)
        "rss_logs.updated_at DESC"
      end

    when "confidence"
      if model == Image
        add_join(:images_observations, :observations)
        "observations.vote_cache DESC"
      elsif model == Observation
        "observations.vote_cache DESC"
      end

    when "image_quality"
      "images.vote_cache DESC" if model == Image

    when "thumbnail_quality"
      if model == Observation
        add_join(:'images.thumb_image')
        "images.vote_cache DESC, observations.vote_cache DESC"
      end

    when "owners_quality"
      if model == Image
        add_join(:image_votes)
        where << "image_votes.user_id = images.user_id"
        "image_votes.value DESC"
      end

    when "owners_thumbnail_quality"
      if model == Observation
        add_join(:'images.thumb_image', :image_votes)
        where << "images.user_id = observations.user_id"
        where << "image_votes.user_id = observations.user_id"
        "image_votes.value DESC, " \
        "images.vote_cache DESC, " \
        "observations.vote_cache DESC"
      end

    when "observation"
      "observation_id DESC" if columns.include?("observation_id")

    when "contribution"
      "users.contribution DESC" if model == User

    when "original_name"
      "images.original_name ASC" if model == Image

    when "url"
      "external_links.url ASC" if model == ExternalLink

    when "herbarium_name"
      add_join(:herbaria)
      "herbaria.name ASC"

    when "herbarium_label"
      "herbarium_records.initial_det ASC, " \
      "herbarium_records.accession_number ASC"

    when "name_and_number"
      "collection_numbers.name ASC, collection_numbers.number ASC"

    when "code"
      where << "herbaria.code != ''"
      "herbaria.code ASC"

    when "code_then_name"
      "IF(herbaria.code = '', '~', herbaria.code) ASC, herbaria.name ASC"

    when "records"
      add_join(:herbarium_records)
      self.group = "herbaria.id"
      "count(herbarium_records.id) DESC"

    when "id" # (for testing)
      "#{table}.id ASC"

    else
      raise("Can't figure out how to sort #{model} by :#{by}.")
    end
  end

  def reverse_order(order)
    order.gsub(/(\s)(ASC|DESC)(,|\Z)/) do
      Regexp.last_match(1) +
        (Regexp.last_match(2) == "ASC" ? "DESC" : "ASC") +
        Regexp.last_match(3)
    end
  end
end
