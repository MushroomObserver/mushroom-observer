# frozen_string_literal: true

# see app/controllers/names_controller.rb
class NamesController

  ############################################################################
  #
  #  :section: EOL Feed
  #
  ############################################################################

  # Show the data getting sent to EOL
  def eol_preview
    @timer_start = Time.current
    eol_data(NameDescription.review_statuses.values_at(:unvetted, :vetted))
    @timer_end = Time.current
  end

  def eol_description_conditions(review_status_list)
    # name descriptions that are exportable.
    rsl = review_status_list.join("', '")
    "review_status IN ('#{rsl}') AND " \
                 "gen_desc IS NOT NULL AND " \
                 "ok_for_export = 1 AND " \
                 "public = 1"
  end

  # Gather data for EOL feed.
  def eol_data(review_status_list)
    @names      = []
    @descs      = {} # name.id    -> [NameDescription, NmeDescription, ...]
    @image_data = {} # name.id    -> [img.id, obs.id, user.id, lic.id, date]
    @users      = {} # user.id    -> user.legal_name
    @licenses   = {} # license.id -> license.url
    @authors    = {} # desc.id    -> "user.legal_name, user.legal_name, ..."

    descs = NameDescription.where(
      eol_description_conditions(review_status_list)
    )

    # Fill in @descs, @users, @authors, @licenses.
    descs.each do |desc|
      name_id = desc.name_id.to_i
      @descs[name_id] ||= []
      @descs[name_id] << desc
      authors = Name.connection.select_values(%(
        SELECT user_id FROM name_descriptions_authors
        WHERE name_description_id = #{desc.id}
      )).map(&:to_i)
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
    image_data = Name.connection.select_all %(
      SELECT name_id, image_id, observation_id, images.user_id,
             images.license_id, images.created_at
      FROM observations, images_observations, images
      WHERE observations.name_id IN (#{name_ids})
      AND observations.vote_cache >= 2.4
      AND observations.id = images_observations.observation_id
      AND images_observations.image_id = images.id
      AND images.vote_cache >= 2
      AND images.ok_for_export
      ORDER BY observations.vote_cache
    )
    image_data = image_data.to_a

    # Fill in @image_data, @users, and @licenses.
    image_data.each do |row|
      name_id    = row["name_id"].to_i
      user_id    = row["user_id"].to_i
      license_id = row["license_id"].to_i
      image_datum = row.values_at("image_id", "observation_id", "user_id",
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
  #   show_name, show_observation and show_image for images
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
