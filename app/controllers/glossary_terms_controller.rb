# frozen_string_literal: true

# create and edit Glossary terms
class GlossaryTermsController < ApplicationController
  before_action :login_required, except: [:index, :show, :show_past]
  before_action :store_location, except: [:create, :update, :destroy]

  # ---------- Actions to Display data (index, show, etc.) ---------------------

  def index
    # Index should be paged with alpha and number tabs
    # See https://www.pivotaltracker.com/story/show/167657202
    # Glossary should be query-able
    # See https://www.pivotaltracker.com/story/show/167809123
    @glossary_terms = GlossaryTerm.includes(thumb_image: :image_votes).
                      order(:name)
  end

  def show
    @glossary_term = GlossaryTerm.find(params[:id].to_s)
    @canonical_url = glossary_term_url
    @layout = calc_layout_params
    @objects = @glossary_term.images
  end

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def new
    @glossary_term = GlossaryTerm.new
    init_image_form_instance_variables
  end

  def edit
    @glossary_term = GlossaryTerm.find(params[:id].to_s)
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def create
    @glossary_term = GlossaryTerm.new(
      user: @user,
      name: params[:glossary_term][:name],
      description: params[:glossary_term][:description]
    )
    return reload_form("new") unless image_and_term_saves_smooth?

    redirect_to(glossary_term_path(@glossary_term.id))
  end

  def update
    @glossary_term = GlossaryTerm.find(params[:id].to_s)
    @glossary_term.attributes = params[:glossary_term].
                                permit(:name, :description)
    @glossary_term.user = @user

    return reload_form("edit") unless @glossary_term.save

    redirect_to(glossary_term_path(@glossary_term.id))
  end

  def destroy
    return unless (@glossary_term = GlossaryTerm.find(params[:id]))

    unless in_admin_mode?
      flash_warning(:permission_denied.t)
      return redirect_to(glossary_term_path(@glossary_term.id))
    end

    if @glossary_term.destroy
      flash_notice(
        :runtime_destroyed_id.t(type: GlossaryTerm, value: params[:id])
      )
      redirect_to(glossary_terms_path)
    else
      redirect_to(glossary_term_path(@glossary_term.id))
    end
  end

  # ---------- Non-standard REST Actions ---------------------------------------

  # Show past version of GlossaryTerm.
  # Accessible only from show_glossary_term page.
  def show_past
    unless (@glossary_term = find_or_goto_index(GlossaryTerm, params[:id].to_s))
      return
    end

    @glossary_term.revert_to(params[:version].to_i)
  end

  # ---------- Public methods (unrouted) ---------------------------------------

  ##############################################################################

  private

  # --------- Filters

  # --------- Other private methods

  def init_image_form_instance_variables
    @copyright_holder ||= @user.name
    @copyright_year ||= Time.now.utc.year
    @upload_license_id ||= @user.license_id
    # rubocop:disable Naming/MemoizedInstanceVariableName
    # RuboCop wants to name the ivar "@update_image_form_instance_variables"
    @licenses ||= License.current_names_and_ids(@user.license)
    # rubocop:enable Naming/MemoizedInstanceVariableName
  end

  def reload_form(form)
    add_glossary_term_error_messages_to_flash
    init_image_form_instance_variables
    render(form)
  end

  def add_glossary_term_error_messages_to_flash
    @glossary_term.errors.messages.values.each do |val|
      # flash_error takes a string; val is a hash, e.g. ["message"]
      flash_error(val.first)
    end
  end

  # Process any image together with @glossary_term,
  # returning truthy if neither fails
  # They must be processed together to correctly validate GlossaryTerm and
  # allow backing out Image if GlossaryTerm is invalid
  def image_and_term_saves_smooth?
    # If no upload file specified, only issue is the term
    return @glossary_term.save unless upload?

    # return false if image processing fails
    return unless (saved_image = process_upload(image_args))

    @glossary_term.add_image(saved_image)
    return if @glossary_term.save # happy path

    # term failed, so clean up the orphaned (unassociated) image
    # and its flash notice ("Successfully uploaded image ...")
    saved_image.try(:destroy)
    flash_clear
    false
  end

  def upload?
    params[:glossary_term][:upload_image]
  end

  def process_upload(args)
    return unless (upload = args[:image])

    if upload.respond_to?(:original_filename)
      upload.original_filename.force_encoding("utf-8")
    end

    image = Image.new(args)
    save_or_flash(image)
  end

  def save_or_flash(image)
    if !image.save
      flash_object_errors(image)
      nil
    elsif !image.process_image
      logger.error("Unable to upload image")
      name = image.original_name
      name = "???" if name.empty?
      flash_error(:runtime_image_invalid_image.t(name: name))
      flash_object_errors(image)
      nil
    else
      name = image.original_name
      name = "##{image.id}" if name.empty?
      flash_notice(:runtime_image_uploaded_image.t(name: name))
      image
    end
  end

  # --- Mass Assignment

  # Permit mass assignment of image arguments for testing purposes
  def image_args
    Rails.env.test? ? permit_upload_image_param : strong_upload_image_param
  end

  def strong_upload_image_param
    {
      copyright_holder: params[:copyright_holder],
      when: Time.local(params[:date][:copyright_year]).utc,
      license: License.safe_find(params[:upload][:license_id]),
      user: @user,
      image: params[:glossary_term][:upload_image]
    }
  end

  # Remove "permitted: false" from this param so that model can mass assign it
  # Do this only in test environment
  def permit_upload_image_param
    args = strong_upload_image_param
    args[:image] = params[:glossary_term][:upload_image][:image]
    args
  end
end
