# frozen_string_literal: true

#  == Scopes
#
#  Ordering Scopes
#
#  order_by(method)::   Dispatcher for Query's :order_by param.
#  order_by_set::       Special order called by the :id_in_set scope
#
module AbstractModel::OrderingScopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do
    # Dispatcher for Query's :order_by param. Expects a (method) arg.
    # Example:
    #   create_query(:Observation, order_by: :created_at)
    # or:
    #   Observation.order_by(:created_at)
    #
    # ...dispatches to a private method called `:order_by_created_at`,
    # which is basically just a scope. If no method by that name exists,
    # this will only add `order(id: :desc)` (:asc if reverse).
    #
    # IMPORTANT: USE THIS SCOPE whenever possible in the app and tests.
    # The private methods called by it do not include the last step that
    # resolves order within grouped results consistently.
    scope :order_by, lambda { |method|
      return all if method.to_sym == :none

      method ||= :default # :order_by_default must be defined for each model
      method = method.dup.to_s
      reverse = method.sub!(/^reverse_/, "") # sub! returns boolean
      scope = :"order_by_#{method}"
      return all unless model.private_methods(false).include?(scope)

      # Call `scoping` with `model.send(:method)` here, because the private
      # class methods below are otherwise inaccessible to a `scope` proc.
      scope = scoping { model.send(scope) }
      scope = scope.reverse_order if reverse
      # Order grouped results from other scopes by adding order(id: :desc). If
      # this `:desc` is contrary to a previous order_by(:id) it will be ignored.
      scope = scope.order(arel_table[:id].desc)
      scope
    }

    # Special ordering for scope `:id_in_set`, requires arg for `set` of ids.
    # Should run last after any other scopes, because it needs to reset order
    scope :order_by_set, lambda { |set|
      reorder(Arel::Nodes.build_quoted(set.join(",")) & arel_table[:id])
    }
  end

  # class methods here, `self` included
  module ClassMethods
    private

    # NOTE: For predictable results, DO NOT CALL THESE METHODS DIRECTLY
    # unless for some reason you need scopes without the ambiguity-resolving
    # secondary order added above, `order(id: :desc)`.
    #
    def order_by_accession_number
      return all unless self == HerbariumRecord

      order(HerbariumRecord[:accession_number].asc)
    end

    def order_by_box_area
      order(Location[:box_area].desc)
    end

    def order_by_code
      where(Herbarium[:code].not_eq("")).order(Herbarium[:code].asc)
    end

    def order_by_code_then_date
      return all unless self == FieldSlip

      order(FieldSlip[:code].asc, FieldSlip[:created_at].desc)
    end

    def order_by_code_then_name
      order(
        Herbarium[:code].eq("").
          when(true).then(Arel::Nodes.build_quoted("~")).
          when(false).then(Herbarium[:code]).asc, Herbarium[:name].asc
      )
    end

    def order_by_confidence
      return all unless [Image, Observation].include?(self)

      scope = all
      if self == Image
        scope = scope.joins(observation_images: :observation).distinct
      end
      scope.order(Observation[:vote_cache].desc)
    end

    def order_by_contribution
      return all unless self == User

      order(User[:contribution].desc)
    end

    def order_by_copyright_holder
      return all unless column_names.include?("copyright_holder")

      order(arel_table[:copyright_holder].asc)
    end

    def order_by_created_at
      return all unless column_names.include?("created_at")

      order(arel_table[:created_at].desc)
    end

    def order_by_curator
      joins(:curators).distinct.order(
        User[:name].when(nil).then(User[:login]).when("").then(User[:login]).
        else(User[:name]).asc
      )
    end

    def order_by_date
      if column_names.include?("when")
        order(arel_table[:when].desc)
      elsif column_names.include?("created_at")
        order(arel_table[:created_at].desc)
      end
    end

    def order_by_herbarium_label
      return all unless self == HerbariumRecord

      order(HerbariumRecord[:initial_det].asc,
            HerbariumRecord[:accession_number].asc)
    end

    def order_by_herbarium_name
      return all unless self == HerbariumRecord

      joins(:herbarium).distinct.order(Herbarium[:name].asc)
    end

    # (for testing)
    def order_by_id
      order(arel_table[:id].asc)
    end

    def order_by_image_quality
      return all unless self == Image

      order(Image[:vote_cache].desc)
    end

    def order_by_initial_det
      return all unless self == HerbariumRecord

      order(HerbariumRecord[:initial_det].asc)
    end

    def order_by_last_login
      return all unless self == User

      order(User[:last_login].desc)
    end

    def order_by_location
      return all unless column_names.include?("location_id")

      scope = order_locations_by_name
      # Join Users with null locations, else join records with locations
      if self == User
        scope.left_outer_joins(:location).distinct
      else
        scope.joins(:location).distinct
      end
    end

    def order_by_login
      return all unless self == User

      order(User[:login].asc)
    end

    # Could refactor so this is just `order_by_name` by class inheritance.
    # NOTE: scope `order_by_location` calls `order_locations_by_name` above,
    # so the latter should stay here. To avoid method duplication, we could
    # just have scope `Location.order_by_name` call `order_locations_by_name`.
    def order_by_name
      order_by_name_method = :"order_#{name.underscore.pluralize}_by_name"
      if private_methods(false).include?(order_by_name_method)
        send(order_by_name_method)
      else
        order_other_models_by_name
      end
    end

    def order_by_name_and_number
      return all unless self == CollectionNumber

      order(CollectionNumber[:name].asc, CollectionNumber[:number].asc)
    end

    def order_by_num_views
      return all unless column_names.include?("num_views")

      order(arel_table[:num_views].desc)
    end

    def order_by_observation
      return all unless column_names.include?("observation_id")

      order(arel_table[:observation_id].desc)
    end

    def order_by_original_name
      return all unless self == Image

      order(Image[:original_name].asc)
    end

    def order_by_owners_quality
      return all unless self == Image

      joins(:image_votes).where(ImageVote[:user_id].eq(Image[:user_id])).
        distinct.order(ImageVote[:value].desc)
    end

    def order_by_owners_thumbnail_quality # rubocop:disable Metrics/AbcSize
      return all unless self == Observation

      joins(images: :image_votes).distinct.
        where(Observation[:thumb_image_id].eq(Image[:id])).
        where(Image[:user_id].eq(Observation[:user_id])).
        where(ImageVote[:user_id].eq(Observation[:user_id])).
        order(ImageVote[:value].desc, Image[:vote_cache].desc,
              Observation[:vote_cache].desc)
    end

    def order_by_records
      return all unless self == Herbarium

      # outer_join needed to show herbaria with no records
      left_outer_joins(:herbarium_records).group(Herbarium[:id]).distinct.
        order(HerbariumRecord[:id].count.desc)
    end

    def order_by_rss_log
      return all unless column_names.include?("rss_log_id")

      # use cached column if exists, and don't join
      # calling index method should include rss_logs
      if column_names.include?("log_updated_at")
        order(arel_table[:log_updated_at].desc)
      else
        joins(:rss_log).order(RssLog[:updated_at].desc).distinct
      end
    end

    def order_by_summary
      return all unless column_names.include?("summary")

      order(arel_table[:summary].asc)
    end

    def order_by_thumbnail_quality
      return all unless self == Observation

      left_outer_joins(:images).where(
        Observation[:thumb_image_id].eq(Image[:id]).or(Image[:id].eq(nil))
      ).distinct.order(Image[:vote_cache].desc, Observation[:vote_cache].desc)
    end

    def order_by_title
      return all unless column_names.include?("title")

      order(arel_table[:title].asc)
    end

    def order_by_updated_at
      return all unless column_names.include?("updated_at")

      order(arel_table[:updated_at].desc)
    end

    def order_by_url
      return all unless self == ExternalLink

      order(ExternalLink[:url].asc)
    end

    def order_by_user
      joins(:user).distinct.order(
        User[:name].when(nil).then(User[:login]).when("").then(User[:login]).
        else(User[:name]).asc
      )
    end

    def order_by_where
      return all unless column_names.include?("where")

      order(arel_table[:where].asc)
    end

    ####### methods dispatched from order_by_name

    def order_images_by_name
      joins(observation_images: { observation: :name }).distinct.
        group(Image[:id]).
        order(Arel.sql("MIN(`names`.`sort_name`) ASC"), Image[:when].desc)
    end

    def order_location_descriptions_by_name
      joins(:location).distinct.
        order(Location[:name].asc, LocationDescription[:created_at].asc)
    end

    def order_locations_by_name
      if User.current_location_format == "scientific"
        order(Location[:scientific_name].asc)
      else
        order(Location[:name].asc)
      end
    end

    def order_name_descriptions_by_name
      joins(:name).distinct.
        order(Name[:sort_name].asc, NameDescription[:created_at].asc)
    end

    def order_names_by_name
      order(Name[:sort_name].asc)
    end

    def order_observations_by_name
      joins(:name).distinct.order(Name[:sort_name].asc, Observation[:when].desc)
    end

    def order_other_models_by_name
      if column_names.include?("name")
        order(arel_table[:name].asc)
      elsif column_names.include?("title")
        order(arel_table[:title].asc)
      else
        order_by_default
      end
    end
  end
end
