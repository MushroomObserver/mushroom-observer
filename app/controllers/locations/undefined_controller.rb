# frozen_string_literal: true

# Undefined locations: free-text Observation#where strings with no
# matching Location record. Split out of LocationsController#index
# into a separate page, independent of that index's filter/sort state.
module Locations
  class UndefinedController < ApplicationController
    before_action :login_required

    def index
      @pagination_data = letter_pagination_data(:letter, :page, 50)
      @undef_data = paginate_undefined_locations
      render(Views::Controllers::Locations::Undefined::Index.new(
               pagination_data: @pagination_data, undef_data: @undef_data
             ))
    end

    private

    def paginate_undefined_locations
      query = create_query(:Observation, location_undefined: true)
      data = query.paginate(@pagination_data)
      @pagination_data.used_letters =
        data.map { |obs| obs[:where][0, 1] }.uniq
      data = filter_by_letter(data)
      @pagination_data.num_total = data.length
      data = data[@pagination_data.from..@pagination_data.to]
      attach_undef_counts(data)
    end

    # `Query#paginate` windows the page before this filter narrows it
    # further, so `num_total`/the page window get recomputed
    # afterward -- see the call site.
    def filter_by_letter(data)
      letter = params[:letter].to_s.downcase
      return data if letter.blank?

      data.select { |obs| obs[:where][0, 1].downcase == letter }
    end

    # `Observation.location_undefined` already groups by `where`, so
    # each row in `data` is the representative observation for one
    # unique unmatched location string. `Query#paginate` strips the
    # per-group count during ID rehydration, so look it up via a
    # single aggregated query, then emit `[representative_obs, count]`
    # tuples -- what the view expects.
    def attach_undef_counts(observations)
      wheres = observations.map { |obs| obs[:where] } # rubocop:disable Rails/Pluck
      counts = ::Observation.where(where: wheres, location_id: nil).
               group(:where).count
      observations.map { |obs| [obs, counts[obs[:where]] || 1] }
    end
  end
end
