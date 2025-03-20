# frozen_string_literal: true

module Query::ScopeModules::Ordering
  def initialize_order
    by = params[:by]
    # Let queries define custom order spec in "order", but have explicitly
    # passed-in "by" parameter take precedence.  If neither is given, then
    # fall back on the "default_order" finally.
    return unless by || order.blank?

    by ||= default_order
    by = by.dup.to_s
    reverse = !!by.sub!(/^reverse_/, "")
    initialize_order_specs(by)
    add_order_disambiguation
    @scopes = @scopes.reverse_order if reverse
  end

  def initialize_order_specs(by)
    return if params[:id_in_set].present?

    sorting_method = "sort_by_#{by}"
    unless Query::ScopeModules::Ordering.private_method_defined?(sorting_method)
      raise(
        "Can't figure out how to sort #{model.name.pluralize} by :#{by}."
      )
    end

    send(sorting_method, model)
  end

  def add_order_disambiguation
    return if params[:id_in_set].present?

    @scopes = @scopes.order(model.arel_table[:id].desc)
  end

  #####################

  private

  ####### methods dispatched from initialize_order_specs

  def sort_by_accession_number(model)
    return unless model == HerbariumRecord

    @scopes = @scopes.order(HerbariumRecord[:accession_number].asc)
  end

  def sort_by_box_area(_model)
    # "locations.box_area DESC"
    @scopes = @scopes.order(Location[:box_area].desc)
  end

  def sort_by_code(_model)
    # where << "herbaria.code != ''"
    # "herbaria.code ASC"
    @scopes = @scopes.where(Herbaria[:code].not_eq(nil)).
              order(Herbaria[:code].asc)
  end

  def sort_by_code_then_date(_model)
    return unless model == FieldSlip

    # "field_slips.code ASC, field_slips.created_at DESC, " \
    # "field_slips.id DESC"
    @scopes = @scopes.order(FieldSlip[:code].asc, FieldSlip[:created_at].desc)
  end

  def sort_by_code_then_name(_model)
    # "IF(herbaria.code = '', '~', herbaria.code) ASC, herbaria.name ASC"
    @scopes = @scopes.order(
      Herbaria[:code].eq(nil).
        when(true).then(Arel::Nodes.build_quoted("~").asc, Herbaria[:name].asc).
        when(false).then(Herbaria[:code].asc, Herbaria[:name].asc)
    )
  end

  def sort_by_confidence(model)
    return unless [Image, Observation].include?(model)

    # add_join(:observation_images, :observations) if model == Image
    @scopes = @scopes.joins(observation_images: :observation) if model == Image
    # "observations.vote_cache DESC"
    @scopes = @scopes.order(Observation[:vote_cache].desc)
  end

  def sort_by_contribution(model)
    return unless model == User

    # "users.contribution DESC" if model == User
    @scopes = @scopes.order(User[:contribution].desc)
  end

  def sort_by_copyright_holder(model)
    return unless model.column_names.include?("copyright_holder")

    # "#{model.table_name}.copyright_holder ASC"
    @scopes = @scopes.order(model.arel_table[:copyright_holder].asc)
  end

  def sort_by_created_at(model)
    return unless model.column_names.include?("created_at")

    # "#{model.table_name}.created_at DESC"
    @scopes = @scopes.order(model.arel_table[:created_at].desc)
  end

  def sort_by_date(model)
    if model.column_names.include?("when")
      # "#{model.table_name}.when DESC"
      @scopes = @scopes.order(model.arel_table[:when].desc)
    elsif model.column_names.include?("created_at")
      # "#{model.table_name}.created_at DESC"
      @scopes = @scopes.order(model.arel_table[:created_at].desc)
    end
  end

  def sort_by_herbarium_label(_model)
    return unless model == HerbariumRecord

    # "herbarium_records.initial_det ASC, " \
    # "herbarium_records.accession_number ASC"
    @scopes = @scopes.order(HerbariumRecords[:initial_det].asc,
                            HerbariumRecords[:accession_number].asc)
  end

  def sort_by_herbarium_name(_model)
    return unless model == HerbariumRecord

    # add_join(:herbaria)
    # "herbaria.name ASC"
    @scopes = @scopes.joins(:herbarium).order(Herbaria[:name].asc)
  end

  # (for testing)
  def sort_by_id(model)
    # "#{model.table_name}.id ASC"
    @scopes = @scopes.order(model.arel_table[:id].asc)
  end

  def sort_by_image_quality(model)
    return unless model == Image

    # "images.vote_cache DESC" if model == Image
    @scopes = @scopes.order(Image[:vote_cache].desc)
  end

  def sort_by_initial_det(model)
    return unless model == HerbariumRecord

    # "#{model.table_name}.initial_det ASC"
    @scopes = @scopes.order(HerbariumRecord[:initial_det].asc)
  end

  def sort_by_last_login(model)
    return unless model == User

    # "#{model.table_name}.last_login DESC"
    @scopes = @scopes.order(User[:last_login].desc)
  end

  def sort_by_location(model)
    return unless model.column_names.include?("location_id")

    # Join Users with null locations, else join records with locations
    @scopes = if model == User
                # add_join(:locations!)
                @scopes.left_outer_joins(:location)
              else
                # add_join(:locations)
                @scopes.joins(:location)
              end
    sort_locations_by_name
  end

  def sort_by_login(model)
    return unless model == User

    # "#{model.table_name}.login ASC" if model.column_names.include?("login")
    @scopes = @scopes.order(User[:login].asc)
  end

  def sort_by_name(model)
    sort_by_name_method = "sort_#{model.name.underscore.pluralize}_by_name"
    if ::Query::Modules::Ordering.private_method_defined?(
      sort_by_name_method
    )
      send(sort_by_name_method)
    else
      sort_other_models_by_name(model)
    end
  end

  def sort_by_name_and_number(_model)
    return unless model == CollectionNumber

    # "collection_numbers.name ASC, collection_numbers.number ASC"
    @scopes = @scopes.order(CollectionNumber[:name].asc,
                            CollectionNumber[:number].asc)
  end

  def sort_by_num_views(model)
    return unless model.column_names.include?("num_views")

    # "#{model.table_name}.num_views DESC"
    @scopes = @scopes.order(model.arel_table[:num_views].desc)
  end

  def sort_by_observation(model)
    return unless model.column_names.include?("observation_id")

    # "observation_id DESC" if model.column_names.include?("observation_id")
    @scopes = @scopes.order(Observation[:id].desc)
  end

  def sort_by_original_name(model)
    return unless model == Image

    # "images.original_name ASC" if model == Image
    @scopes = @scopes.order(Image[:original_name].asc)
  end

  def sort_by_owners_quality(model)
    return unless model == Image

    # add_join(:image_votes)
    # where << "image_votes.user_id = images.user_id"
    # "image_votes.value DESC"
    @scopes = @scopes.joins(:image_votes).
              where(ImageVote[:user_id].eq(Image[:user_id])).
              order(ImageVote[:value].desc)
  end

  # rubocop:disable Metrics/AbcSize
  def sort_by_owners_thumbnail_quality(model)
    return unless model == Observation

    # add_join(:"images.thumb_image", :image_votes)
    # where << "images.user_id = observations.user_id"
    # where << "image_votes.user_id = observations.user_id"
    # "image_votes.value DESC, " \
    # "images.vote_cache DESC, " \
    # "observations.vote_cache DESC"
    @scopes = @scopes.joins(images: :image_votes).
              where(Observation[:thumb_image_id].eq(Image[:id])).
              where(Image[:user_id].eq(Observation[:user_id])).
              where(ImageVote[:user_id].eq(Observation[:user_id])).
              order(ImageVote[:value].desc, Image[:vote_cache].desc,
                    Observation[:vote_cache].desc)
  end
  # rubocop:enable Metrics/AbcSize

  def sort_by_records(_model)
    return unless model == Herbarium

    # outer_join needed to show herbaria with no records
    # add_join(:herbarium_records!)
    # self.group = "herbaria.id"
    # "count(herbarium_records.id) DESC"
    @scopes = @scopes.left_outer_joins(:herbarium_records).
              group(Herbaria[:id]).order(HerbariumRecord[:id].count.desc)
  end

  def sort_by_rss_log(model)
    return unless model.column_names.include?("rss_log_id")

    # use cached column if exists, and don't join
    # calling index method should include rss_logs
    @scopes = if model.column_names.include?("log_updated_at")
                # "#{model.table_name}.log_updated_at DESC"
                @scopes.order(model.arel_table[:log_updated_at].desc)
              else
                # add_join(:rss_logs)
                # "rss_logs.updated_at DESC"
                @scopes.joins(:rss_log).order(RssLog[:updated_at].desc)
              end
  end

  def sort_by_summary(model)
    return unless model.column_names.include?("summary")

    # "#{model.table_name}.summary ASC"
    @scopes = @scopes.order(model.arel_table[:summary].asc)
  end

  def sort_by_thumbnail_quality(model)
    return unless model == Observation

    # add_join(:"images.thumb_image")
    # "images.vote_cache DESC, observations.vote_cache DESC"
    @scopes = @scopes.joins(:images).
              where(Observation[:thumb_image_id].eq(Image[:id])).
              order(Image[:vote_cache].desc, Observation[:vote_cache].desc)
  end

  def sort_by_title(model)
    return unless model.column_names.include?("title")

    # "#{model.table_name}.title ASC" if model.column_names.include?("title")
    @scopes = @scopes.order(model.arel_table[:title].asc)
  end

  def sort_by_updated_at(model)
    return unless model.column_names.include?("updated_at")

    # "#{model.table_name}.updated_at DESC"
    @scopes = @scopes.order(model.arel_table[:updated_at].desc)
  end

  def sort_by_url(model)
    return unless model == ExternalLink

    # "external_links.url ASC" if model == ExternalLink
    @scopes = @scopes.order(ExternalLink[:url].asc)
  end

  def sort_by_user(_model)
    # add_join(:users)
    # 'IF(users.name = "" OR users.name IS NULL, users.login, users.name) ASC'
    @scopes = @scopes.joins(:user).
              order(User[:name].
                    when(nil).then(User[:login]).when("").then(User[:login]).
                    else(User[:name]).asc)
  end

  def sort_by_where(model)
    return unless model.column_names.include?("where")

    # "#{model.table_name}.where ASC" if model.column_names.include?("where")
    @scopes = @scopes.order(model.arel_table[:where].asc)
  end

  ####### methods dispatched from sort_by_name

  def sort_images_by_name
    # add_join(:observation_images, :observations)
    # add_join(:observations, :names)
    # self.group = "images.id"
    # "MIN(names.sort_name) ASC, images.when DESC"
    @scopes = @scopes.joins(observation_images: { observation: :name }).
              group(Image[:id]).
              order(Name[:sort_name].min.asc, Image[:when].desc)
  end

  def sort_location_descriptions_by_name
    # add_join(:locations)
    # "locations.name ASC, location_descriptions.created_at ASC"
    @scopes = @scopes.joins(:location).
              order(Location[:name].asc, LocationDescription[:created_at].asc)
  end

  def sort_locations_by_name
    @scopes = if User.current_location_format == "scientific"
                # "locations.scientific_name ASC"
                @scopes.order(Location[:scientific_name].asc)
              else
                # "locations.name ASC"
                @scopes.order(Location[:name].asc)
              end
  end

  def sort_name_descriptions_by_name
    # add_join(:names)
    # "names.sort_name ASC, name_descriptions.created_at ASC"
    @scopes = @scopes.joins(:name).
              order(Name[:sort_name].asc, NameDescription[:created_at].asc)
  end

  def sort_names_by_name
    # "names.sort_name ASC"
    @scopes = @scopes.order(Name[:sort_name].asc)
  end

  def sort_observations_by_name
    # add_join(:names)
    # "names.sort_name ASC, observations.when DESC"
    @scopes = @scopes.joins(:name).
              order(Name[:sort_name].asc, Observation[:when].desc)
  end

  def sort_other_models_by_name(model)
    if model.column_names.include?("name")
      # "#{model.table_name}.name ASC"
      @scopes = @scopes.order(model.arel_table[:name].asc)
    elsif model.column_names.include?("title")
      # "#{model.table_name}.title ASC"
      @scopes = @scopes.order(model.arel_table[:title].asc)
    end
  end
end
