# frozen_string_literal: true

#
#  = Locationable Concern
#
#  This is a module of reusable methods that can be included by controllers that
#  deal with associated locations, where the location may be created on the fly
#  in the create form. (Why not "locatable"? It could be otherwise locatable.)
#    - ObservationsController
#    - HerbariaController
#    - Account::ProfileController
#    - ProjectsController
#
#  The controller must follow some conventions:
#    - send its main object ivar (@observation, etc) to the methods
#    - use a `@location` ivar
#    - set the `@user` ivar
#    - use the `@any_errors` ivar to halt the save process
#
#  == Methods
#
#  create_location_object_if_new(object):: Create a new Location associated with
#    the object, if necessary
#
#  place_name_exists?(object):: Check if the location name exists in the db, and
#    if so, set the location_id
#
#  try_to_save_location_if_new(object):: Save the location only if it is new
#
#  save_location(object):: Save the location only (at this point rest of form is
#    okay)
#
################################################################################

module Locationable
  extend ActiveSupport::Concern

  included do
    # By now we should have an object (pass the ivar!), and maybe a "-1"
    # location_id, indicating a new Location if accompanied by bounding box
    # lat/lng. If the location name does not exist already, and the bounding box
    # is present, create a new @location, and associate it with the @object.
    def create_location_object_if_new(object)
      # Resets the location_id to MO's existing Location if it already exists.
      return false if place_name_exists?(object)

      # Ensure we have the minimum necessary to create a new location
      return false unless (attributes = location_attributes(object))
      return false if (place_name = params.dig(object.type_tag,
                                               :place_name)).blank?

      # Add optional attributes. :notes not implemented yet.
      [:high, :low, :notes].each do |key|
        if (val = params.dig(:location, key)).present?
          attributes[key] = val
        end
      end

      @location = Location.new(attributes)
      # Calculate the area of the box in case we want to reject vague locations
      # (method included via Mappable::BoxMethods)
      @location.box_area = @location.calculate_area
      # With a Location instance, we can use the `display_name=` setter method,
      # which figures out scientific/postal format of user input and sets
      # location `name` and `scientific_name` accordingly.
      @location.display_name = place_name
    end

    def location_attributes(object)
      return false unless object.location_id == -1 &&
                          (north = params.dig(:location, :north)).present? &&
                          (south = params.dig(:location, :south)).present? &&
                          (east = params.dig(:location, :east)).present? &&
                          (west = params.dig(:location, :west)).present?

      # Ignore hidden attribute even if the obs is hidden, because saving a
      # Location with `hidden: true` fuzzes the lat/lng bounds unpredictably.
      { hidden: false, user_id: @user.id,
        north:, south:, east:, west: }
    end

    # Check if we somehow got a location name that exists in the db, but didn't
    # get a location_id, or the location name is out of sync with the
    # location_id. (This should not usually happen with the autocompleter). If
    # it happens, match the obs to the existing Location by name. If the user
    # was trying to create a new Location with the existing name, use the
    # existing location and flash that we did that, returning `true` so we can
    # bail on creating a "new" location, but go ahead with the observation save.
    # rubocop:disable Metrics/CyclomaticComplexity
    def place_name_exists?(object)
      name = Location.user_format(@user, object.place_name)
      location = Location.find_by(name: name)
      if !object.location_id&.positive? && location ||
         (location && (object.location_id != location&.id))
        if object.location_id == -1
          flash_warning(:runtime_location_already_exists.t(name: name))
        end
        object.location_id = location.id
        return true
      end

      false
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def try_to_save_location_if_new(object)
      return if @any_errors || !@location&.new_record? || save_location(object)

      @any_errors = true
    end

    # Save location only (at this point rest of form is okay).
    def save_location(object)
      if save_with_log(@user, @location)
        # Associate the location with the observation
        object.location_id = @location.id
        # flash_notice(:runtime_location_success.t(id: @location.id))
        true
      else
        # Failed to create location
        flash_object_errors(@location)
        false
      end
    end
  end
end
