# frozen_string_literal: true

#  == Scopes
#
#  Ordering Scopes
#
#  order_by_user::
#  order_by_rss_log::
#  order_by_set::
#
module AbstractModel::OrderingScopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do # rubocop:disable Metrics/BlockLength
    # Dispatcher for Query's :order_by param, with (method) arg.
    # Example: create_query(:Observation, order_by: :created_at)
    # ...order_by dispatches to a scope called `:order_by_created_at`.
    # If no such scope exists, it simply orders by id: :desc (:asc if reverse).
    scope :order_by, lambda { |method|
      return all if method.to_sym == :none

      method ||= :default
      method = method.dup.to_s
      reverse = method.sub!(/^reverse_/, "")
      scope = order_initialize(method)
      scope = order_disambiguate(scope)
      scope = scope.reverse_order if reverse
      scope
    }

    scope :order_by_accession_number, lambda {
      return all unless klass == HerbariumRecord

      order(HerbariumRecord[:accession_number].asc)
    }

    scope :order_by_box_area, lambda {
      # "locations.box_area DESC"
      order(Location[:box_area].desc)
    }

    scope :order_by_code, lambda {
      # where << "herbaria.code != ''"
      # "herbaria.code ASC"
      where(Herbarium[:code].not_eq(nil)).order(Herbarium[:code].asc)
    }

    scope :order_by_code_then_date, lambda {
      return all unless klass == FieldSlip

      # "field_slips.code ASC, field_slips.created_at DESC, " \
      # "field_slips.id DESC"
      order(FieldSlip[:code].asc, FieldSlip[:created_at].desc)
    }

    scope :order_by_code_then_name, lambda {
      # "IF(herbaria.code = '', '~', herbaria.code) ASC, herbaria.name ASC"
      order(
        Herbarium[:code].eq(nil).
          when(true).then(Arel::Nodes.build_quoted("~")).
          when(false).then(Herbarium[:code]).asc, Herbarium[:name].asc
      )
    }

    scope :order_by_confidence, lambda {
      return all unless [Image, Observation].include?(klass)

      # add_join(:observation_images, :observations) if klass == Image
      joins(observation_images: :observation) if klass == Image
      # "observations.vote_cache DESC"
      order(Observation[:vote_cache].desc)
    }

    scope :order_by_contribution, lambda {
      return all unless klass == User

      # "users.contribution DESC" if klass == User
      order(User[:contribution].desc)
    }

    scope :order_by_copyright_holder, lambda {
      return all unless klass.column_names.include?("copyright_holder")

      # "#{klass.table_name}.copyright_holder ASC"
      order(arel_table[:copyright_holder].asc)
    }

    scope :order_by_created_at, lambda {
      return all unless klass.column_names.include?("created_at")

      # "#{klass.table_name}.created_at DESC"
      order(arel_table[:created_at].desc)
    }

    scope :order_by_date, lambda {
      if klass.column_names.include?("when")
        # "#{klass.table_name}.when DESC"
        order(arel_table[:when].desc)
      elsif klass.column_names.include?("created_at")
        # "#{klass.table_name}.created_at DESC"
        order(arel_table[:created_at].desc)
      end
    }

    scope :order_by_herbarium_label, lambda {
      return all unless klass == HerbariumRecord

      # "herbarium_records.initial_det ASC, " \
      # "herbarium_records.accession_number ASC"
      order(HerbariumRecord[:initial_det].asc,
            HerbariumRecord[:accession_number].asc)
    }

    scope :order_by_herbarium_name, lambda {
      return all unless klass == HerbariumRecord

      # add_join(:herbaria)
      # "herbaria.name ASC"
      joins(:herbarium).order(Herbarium[:name].asc)
    }

    # (for testing)
    scope :order_by_id, lambda {
      # "#{klass.table_name}.id ASC"
      order(arel_table[:id].asc)
    }

    scope :order_by_image_quality, lambda {
      return all unless klass == Image

      # "images.vote_cache DESC" if klass == Image
      order(Image[:vote_cache].desc)
    }

    scope :order_by_initial_det, lambda {
      return all unless klass == HerbariumRecord

      # "#{klass.table_name}.initial_det ASC"
      order(HerbariumRecord[:initial_det].asc)
    }

    scope :order_by_last_login, lambda {
      return all unless klass == User

      # "#{klass.table_name}.last_login DESC"
      order(User[:last_login].desc)
    }

    scope :order_by_location, lambda {
      return all unless klass.column_names.include?("location_id")

      # Join Users with null locations, else join records with locations
      scope = if klass == User
                # add_join(:locations!)
                left_outer_joins(:location)
              else
                # add_join(:locations)
                joins(:location)
              end
      scope.order_locations_by_name
    }

    scope :order_by_login, lambda {
      return all unless klass == User

      # "#{klass.table_name}.login ASC" if klass.column_names.include?("login")
      order(User[:login].asc)
    }

    # Could refactor so this is just `order_by_name` by class inheritance.
    # NOTE: scope `order_by_location` calls `order_locations_by_name` above,
    # so the latter should stay here. To avoid method duplication, we could
    # just have scope `Location.order_by_name` call `order_locations_by_name`.
    scope :order_by_name, lambda {
      order_by_name_method = "order_#{klass.name.underscore.pluralize}_by_name"
      if klass.respond_to?(order_by_name_method)
        send(order_by_name_method)
      else
        order_other_models_by_name(klass)
      end
    }

    scope :order_by_name_and_number, lambda {
      return all unless klass == CollectionNumber

      # "collection_numbers.name ASC, collection_numbers.number ASC"
      order(CollectionNumber[:name].asc, CollectionNumber[:number].asc)
    }

    scope :order_by_num_views, lambda {
      return all unless klass.column_names.include?("num_views")

      # "#{klass.table_name}.num_views DESC"
      order(arel_table[:num_views].desc)
    }

    scope :order_by_observation, lambda {
      return all unless klass.column_names.include?("observation_id")

      # "observation_id DESC" if klass.column_names.include?("observation_id")
      order(Observation[:id].desc)
    }

    scope :order_by_original_name, lambda {
      return all unless klass == Image

      # "images.original_name ASC" if klass == Image
      order(Image[:original_name].asc)
    }

    scope :order_by_owners_quality, lambda {
      return all unless klass == Image

      # add_join(:image_votes)
      # where << "image_votes.user_id = images.user_id"
      # "image_votes.value DESC"
      joins(:image_votes).where(ImageVote[:user_id].eq(Image[:user_id])).
        order(ImageVote[:value].desc)
    }

    scope :order_by_owners_thumbnail_quality, lambda {
      return all unless klass == Observation

      # add_join(:"images.thumb_image", :image_votes)
      # where << "images.user_id = observations.user_id"
      # where << "image_votes.user_id = observations.user_id"
      # "image_votes.value DESC, " \
      # "images.vote_cache DESC, " \
      # "observations.vote_cache DESC"
      joins(images: :image_votes).
        where(Observation[:thumb_image_id].eq(Image[:id])).
        where(Image[:user_id].eq(Observation[:user_id])).
        where(ImageVote[:user_id].eq(Observation[:user_id])).
        order(ImageVote[:value].desc, Image[:vote_cache].desc,
              Observation[:vote_cache].desc)
    }

    scope :order_by_records, lambda {
      return all unless klass == Herbarium

      # outer_join needed to show herbaria with no records
      # add_join(:herbarium_records!)
      # self.group = "herbaria.id"
      # "count(herbarium_records.id) DESC"
      left_outer_joins(:herbarium_records).group(Herbarium[:id]).
        order(HerbariumRecord[:id].count.desc)
    }

    scope :order_by_rss_log, lambda {
      return all unless klass.column_names.include?("rss_log_id")

      # use cached column if exists, and don't join
      # calling index method should include rss_logs
      if klass.column_names.include?("log_updated_at")
        # "#{klass.table_name}.log_updated_at DESC"
        order(arel_table[:log_updated_at].desc)
      else
        # add_join(:rss_logs)
        # "rss_logs.updated_at DESC"
        joins(:rss_log).order(RssLog[:updated_at].desc)
      end
    }

    scope :order_by_summary, lambda {
      return all unless klass.column_names.include?("summary")

      # "#{klass.table_name}.summary ASC"
      order(arel_table[:summary].asc)
    }

    scope :order_by_thumbnail_quality, lambda {
      return all unless klass == Observation

      # add_join(:"images.thumb_image")
      # "images.vote_cache DESC, observations.vote_cache DESC"
      joins(:images).where(Observation[:thumb_image_id].eq(Image[:id])).
        order(Image[:vote_cache].desc, Observation[:vote_cache].desc)
    }

    scope :order_by_title, lambda {
      return all unless klass.column_names.include?("title")

      # "#{klass.table_name}.title ASC" if klass.column_names.include?("title")
      order(arel_table[:title].asc)
    }

    scope :order_by_updated_at, lambda {
      return all unless klass.column_names.include?("updated_at")

      # "#{klass.table_name}.updated_at DESC"
      order(arel_table[:updated_at].desc)
    }

    scope :order_by_url, lambda {
      return all unless klass == ExternalLink

      # "external_links.url ASC" if klass == ExternalLink
      order(ExternalLink[:url].asc)
    }

    scope :order_by_user, lambda {
      # add_join(:users)
      # 'IF(users.name = "" OR users.name IS NULL, users.login, users.name) ASC'
      joins(:user).order(
        User[:name].when(nil).then(User[:login]).when("").then(User[:login]).
        else(User[:name]).asc
      )
    }

    scope :order_by_where, lambda {
      return all unless klass.column_names.include?("where")

      # "#{klass.table_name}.where ASC" if klass.column_names.include?("where")
      order(arel_table[:where].asc)
    }

    ####### methods dispatched from order_by_name

    scope :order_images_by_name, lambda {
      # add_join(:observation_images, :observations)
      # add_join(:observations, :names)
      # self.group = "images.id"
      # "MIN(names.sort_name) ASC, images.when DESC"
      joins(observation_images: { observation: :name }).
        group(Image[:id]).order(Name[:sort_name].min.asc, Image[:when].desc)
    }

    scope :order_location_descriptions_by_name, lambda {
      # add_join(:locations)
      # "locations.name ASC, location_descriptions.created_at ASC"
      joins(:location).
        order(Location[:name].asc, LocationDescription[:created_at].asc)
    }

    scope :order_locations_by_name, lambda {
      if User.current_location_format == "scientific"
        # "locations.scientific_name ASC"
        order(Location[:scientific_name].asc)
      else
        # "locations.name ASC"
        order(Location[:name].asc)
      end
    }

    scope :order_name_descriptions_by_name, lambda {
      # add_join(:names)
      # "names.sort_name ASC, name_descriptions.created_at ASC"
      joins(:name).order(Name[:sort_name].asc, NameDescription[:created_at].asc)
    }

    scope :order_names_by_name, lambda {
      # "names.sort_name ASC"
      order(Name[:sort_name].asc)
    }

    scope :order_observations_by_name, lambda {
      # add_join(:names)
      # "names.sort_name ASC, observations.when DESC"
      joins(:name).order(Name[:sort_name].asc, Observation[:when].desc)
    }

    scope :order_other_models_by_name, lambda {
      if klass.column_names.include?("name")
        # "#{klass.table_name}.name ASC"
        order(arel_table[:name].asc)
      elsif klass.column_names.include?("title")
        # "#{klass.table_name}.title ASC"
        order(arel_table[:title].asc)
      end
    }

    scope :order_by_set, lambda { |set|
      reorder(Arel::Nodes.build_quoted(set.join(",")) & arel_table[:id])
    }
  end

  # class methods here, `self` included
  module ClassMethods
    # Should not run if order_by_set is anywhere in the scope chain, because it
    # will mess with the order.
    # Could theoretically work if order_in_set runs last and calls `reorder`
    def order_initialize(method)
      scope = :"order_by_#{method}"
      return all unless klass.respond_to?(scope)

      scope
    end

    # Disambiguate order (by adding order(id: :desc). Useful when other
    # ordering scopes return groups of records. In AR, chained orders take
    # precedence in order of the chain, so if this is last (except in_set) it is
    # equivalent to calling them together: `order(some_column: :asc, id: :desc)`
    def order_disambiguate(scope)
      scope.order(arel_table[:id].desc)
    end
  end
end
