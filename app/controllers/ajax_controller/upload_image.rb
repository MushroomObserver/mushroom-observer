# frozen_string_literal: true

# see ajax_controller.rb
class AjaxController
  # Upload Image Template. Returns formatted HTML to be injected
  # when uploading multiple images on create observation
  def multi_image_template
    @user = session_user!
    @licenses = License.current_names_and_ids(@user.license)
    @image = Image.new(user: @user, when: Time.zone.now)
    render(partial: "/observations/form_multi_image_template")
  end

  # Uploads an image object without an observation.
  # Returns image as JSON object.
  def create_image_object
    @user = session_user!
    args = params[:image]
    image = create_and_upload_image(args)
    render_image(image, args)
  rescue StandardError => e
    render_errors(e.to_s, args)
  end

  private

  def render_image(image, args)
    name = args[:original_name].to_s
    flash_notice(:runtime_image_uploaded.t(name: name))
    render(json: image)
  end

  def render_errors(errors, args)
    name = args[:original_name].to_s
    errors += "\n" + :runtime_no_upload_image.t(name: name)
    logger.error("UPLOAD_FAILED: #{errors.inspect}")
    render(plain: errors.strip_html, status: :internal_server_error)
  end

  def create_and_upload_image(args)
    image = create_image(args)
    upload_image(image, args)
    return image if image.save && image.process_image

    raise image.formatted_errors.join("\n")
  ensure
    image.try(&:clean_up)
  end

  def create_image(args)
    Image.new(
      created_at: Time.zone.now,
      user: @user,
      when: image_date(args),
      license_id: args[:license].to_i,
      notes: args[:notes].to_s,
      copyright_holder: args[:copyright_holder].to_s,
      original_name: image_original_name(args)
    )
  end

  def upload_image(image, args)
    if args[:url].blank?
      image.image = args[:upload]
    else
      image.upload_from_url(args[:url])
    end
  end

  def image_original_name(args)
    return nil if @user.keep_filenames == :toss

    args[:original_name].to_s
  end

  def image_date(args)
    # TODO: handle invalid date
    hash = args[:when] || {}
    Date.new(hash["1i"].to_i,
             hash["2i"].to_i,
             hash["3i"].to_i)
  end
end
