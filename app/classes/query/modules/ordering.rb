# frozen_string_literal: true

module Query::Modules::Ordering
  def initialize_order
    # Let callers explicitly send in an order statement.
    # This is not sanitized or validated.
    if params[:order].present?
      self.order = params[:order]
      return
    end

    initialize_order_by_param
  end

  # Let queries define custom order spec in "order", but have explicitly
  # passed-in "order_by" parameter take precedence. If neither `order` nor
  # `order_by` is given, then fall back on the "default_order" finally.
  def initialize_order_by_param
    order_by = params[:order_by]
    return unless order_by || order.blank?

    order_by ||= default_order
    order_by = order_by.dup
    reverse = order_by.to_s.sub!(/^reverse_/, "")
    result = initialize_order_specs(order_by)
    self.order = reverse ? reverse_order(result) : result
  end

  def initialize_order_specs(order_by)
    sorting_method = "order_by_#{order_by}"
    unless ::Query::Modules::Ordering.private_method_defined?(
      sorting_method
    )
      raise(
        "Can't figure out how to order #{model.name.pluralize} by :#{order_by}."
      )
    end

    send(sorting_method, model)
  end

  def reverse_order(order)
    order.gsub(/(\s)(ASC|DESC)(,|\Z)/) do
      Regexp.last_match(1) +
        (Regexp.last_match(2) == "ASC" ? "DESC" : "ASC") +
        Regexp.last_match(3)
    end
  end

  #####################

  private

  ####### methods dispatched from initialize_order_specs

  def order_by_accession_number(model)
    return unless model.column_names.include?("accession_number")

    "#{model.table_name}.accession_number ASC"
  end

  def order_by_box_area(_model)
    "locations.box_area DESC"
  end

  def order_by_code(_model)
    where << "herbaria.code != ''"
    "herbaria.code ASC"
  end

  def order_by_code_then_date(_model)
    "field_slips.code ASC, field_slips.created_at DESC, " \
    "field_slips.id DESC"
  end

  def order_by_code_then_name(_model)
    "IF(herbaria.code = '', '~', herbaria.code) ASC, herbaria.name ASC"
  end

  def order_by_confidence(model)
    if model == Image
      add_join(:observation_images, :observations)
      "observations.vote_cache DESC"
    elsif model == Observation
      "observations.vote_cache DESC"
    end
  end

  def order_by_contribution(model)
    "users.contribution DESC" if model == User
  end

  def order_by_copyright_holder(model)
    return unless model.column_names.include?("copyright_holder")

    "#{model.table_name}.copyright_holder ASC"
  end

  def order_by_created_at(model)
    return unless model.column_names.include?("created_at")

    "#{model.table_name}.created_at DESC"
  end

  def order_by_date(model)
    if model.column_names.include?("when")
      "#{model.table_name}.when DESC"
    elsif model.column_names.include?("created_at")
      "#{model.table_name}.created_at DESC"
    end
  end

  def order_by_herbarium_label(_model)
    "herbarium_records.initial_det ASC, " \
    "herbarium_records.accession_number ASC"
  end

  def order_by_herbarium_name(_model)
    add_join(:herbaria)
    "herbaria.name ASC"
  end

  # (for testing)
  def order_by_id(model)
    "#{model.table_name}.id ASC"
  end

  def order_by_image_quality(model)
    "images.vote_cache DESC" if model == Image
  end

  def order_by_initial_det(model)
    return unless model.column_names.include?("initial_det")

    "#{model.table_name}.initial_det ASC"
  end

  def order_by_last_login(model)
    return unless model.column_names.include?("last_login")

    "#{model.table_name}.last_login DESC"
  end

  def order_by_location(model)
    return unless model.column_names.include?("location_id")

    # Join Users with null locations, else join records with locations
    model == User ? add_join(:locations!) : add_join(:locations)
    order_locations_by_name
  end

  def order_by_login(model)
    "#{model.table_name}.login ASC" if model.column_names.include?("login")
  end

  def order_by_name(model)
    order_by_name_method = "order_#{model.name.underscore.pluralize}_by_name"
    if ::Query::Modules::Ordering.private_method_defined?(
      order_by_name_method
    )
      send(order_by_name_method)
    else
      order_other_models_by_name(model)
    end
  end

  def order_by_name_and_number(_model)
    "collection_numbers.name ASC, collection_numbers.number ASC"
  end

  def order_by_num_views(model)
    return unless model.column_names.include?("num_views")

    "#{model.table_name}.num_views DESC"
  end

  def order_by_observation(model)
    "observation_id DESC" if model.column_names.include?("observation_id")
  end

  def order_by_original_name(model)
    "images.original_name ASC" if model == Image
  end

  def order_by_owners_quality(model)
    return unless model == Image

    add_join(:image_votes)
    where << "image_votes.user_id = images.user_id"
    "image_votes.value DESC"
  end

  def order_by_owners_thumbnail_quality(model)
    return unless model == Observation

    add_join(:"images.thumb_image", :image_votes)
    where << "images.user_id = observations.user_id"
    where << "image_votes.user_id = observations.user_id"
    "image_votes.value DESC, " \
    "images.vote_cache DESC, " \
    "observations.vote_cache DESC"
  end

  def order_by_records(_model)
    # outer_join needed to show herbaria with no records
    add_join(:herbarium_records!)
    self.group = "herbaria.id"
    "count(herbarium_records.id) DESC"
  end

  def order_by_rss_log(model)
    return unless model.column_names.include?("rss_log_id")

    # use cached column if exists, and don't join
    # calling index method should include rss_logs
    if model.column_names.include?("log_updated_at")
      "#{model.table_name}.log_updated_at DESC"
    else
      add_join(:rss_logs)
      "rss_logs.updated_at DESC"
    end
  end

  def order_by_summary(model)
    return unless model.column_names.include?("summary")

    "#{model.table_name}.summary ASC"
  end

  def order_by_thumbnail_quality(model)
    return unless model == Observation

    add_join(:"images.thumb_image")
    "images.vote_cache DESC, observations.vote_cache DESC"
  end

  def order_by_title(model)
    "#{model.table_name}.title ASC" if model.column_names.include?("title")
  end

  def order_by_updated_at(model)
    return unless model.column_names.include?("updated_at")

    "#{model.table_name}.updated_at DESC"
  end

  def order_by_url(model)
    "external_links.url ASC" if model == ExternalLink
  end

  def order_by_user(_model)
    add_join(:users)
    'IF(users.name = "" OR users.name IS NULL, users.login, users.name) ASC'
  end

  def order_by_where(model)
    "#{model.table_name}.where ASC" if model.column_names.include?("where")
  end

  ####### methods dispatched from order_by_name

  def order_images_by_name
    add_join(:observation_images, :observations)
    add_join(:observations, :names)
    self.group = "images.id"
    "MIN(names.sort_name) ASC, images.when DESC"
  end

  def order_location_descriptions_by_name
    add_join(:locations)
    "locations.name ASC, location_descriptions.created_at ASC"
  end

  def order_locations_by_name
    if User.current_location_format == "scientific"
      "locations.scientific_name ASC"
    else
      "locations.name ASC"
    end
  end

  def order_name_descriptions_by_name
    add_join(:names)
    "names.sort_name ASC, name_descriptions.created_at ASC"
  end

  def order_names_by_name
    "names.sort_name ASC"
  end

  def order_observations_by_name
    add_join(:names)
    "names.sort_name ASC, observations.when DESC"
  end

  def order_other_models_by_name(model)
    if model.column_names.include?("name")
      "#{model.table_name}.name ASC"
    elsif model.column_names.include?("title")
      "#{model.table_name}.title ASC"
    end
  end
end
