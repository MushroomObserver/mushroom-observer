# frozen_string_literal: true

#  == EOL
#  eol_preview::
#  eol_data::
#  eol_expanded_review::
#  eol::

module Names
  class EolDataController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    ##########################################################################
    #
    #  :section: EOL Feed
    #
    ##########################################################################

    # Show the data getting sent to EOL
    def eol_preview
      @timer_start = Time.current
      eol_data(NameDescription.review_statuses.values_at("unvetted", "vetted"))
      @timer_end = Time.current
    end

    # Gather data for EOL feed.
    def eol_data(review_status_list)
      @names      = []
      @descs      = {} # name.id    -> [NameDescription, NmeDescription, ...]
      @image_data = {} # name.id    -> [img.id, obs.id, user.id, lic.id, date]
      @users      = {} # user.id    -> user.legal_name
      @licenses   = {} # license.id -> license.url
      @authors    = {} # desc.id    -> "user.legal_name, user.legal_name, ..."

      descs = NameDescription.
              where(review_status: review_status_list).
              where(NameDescription[:gen_desc].not_blank).
              where(ok_for_export: true).
              where(public: true)

      # Fill in @descs, @users, @authors, @licenses.
      descs.each do |desc|
        name_id = desc.name_id.to_i
        @descs[name_id] ||= []
        @descs[name_id] << desc
        authors = NameDescriptionAuthor.where(name_description_id: desc.id).
                  pluck(:user_id)
        authors = [desc.user_id] if authors.empty?
        authors.each do |author|
          @users[author.to_i] ||= User.find(author).legal_name
        end
        @authors[desc.id] = authors.map { |id| @users[id.to_i] }.join(", ")
        @licenses[desc.license_id] ||= desc.license.url if desc.license_id
      end

      # Get corresponding names.
      name_ids = @descs.keys.map(&:to_s).join(",")
      @names = Name.where(id: name_ids).order(:sort_name, :author).to_a

      # Get corresponding images.
      image_data = Observation.joins(:images).
                   where(name_id: name_ids).
                   where(Observation[:vote_cache] >= 2.4).
                   where(Image[:vote_cache] >= 2).
                   where(Image[:ok_for_export] == true).
                   order(Observation[:vote_cache]).
                   select(Observation[:name_id], ObservationImage[:image_id],
                          ObservationImage[:observation_id], Image[:user_id],
                          Image[:license_id], Image[:created_at]).to_a

      # Fill in @image_data, @users, and @licenses.
      image_data.each do |row|
        name_id    = row["name_id"].to_i
        user_id    = row["user_id"].to_i
        license_id = row["license_id"].to_i
        image_datum = row.values_at("image_id", "id", "user_id",
                                    "license_id", "created_at")
        @image_data[name_id] ||= []
        @image_data[name_id].push(image_datum)
        @users[user_id] ||= User.find(user_id).legal_name
        @licenses[license_id] ||= License.find(license_id).url
      end
    end

    def eol_expanded_review
      @timer_start = Time.current
      @data = EolData.new
    end
    # TODO: Add ability to preview synonyms?
    # TODO: List stuff that's almost ready.
    # TODO: Add EOL logo on pages getting exported
    #   show_name and show_descriptions for description info
    #   show_name, observations/show and show_image for images
    # EOL preview from Name page
    # Improve the Name page
    # Review unapproved descriptions

    # Send stuff to eol.
    def eol
      @max_secs = params[:max_secs] ? params[:max_secs].to_i : nil
      @timer_start = Time.current
      @data = EolData.new
      render_xml(layout: false)
    end
  end
end
