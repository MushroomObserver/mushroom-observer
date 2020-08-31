# frozen_string_literal: true

# create and edit Glossary terms
class GlossaryTermsController < ApplicationController
  before_action :login_required, except: [
    :index,
    :show_past,
    :show
  ]
  before_action :store_location, only: [:index, :show, :destroy]
  before_action :pass_query_params, only: [:destroy, :show_past]

  # ---------- Actions to Display data (index, show, etc.) ---------------------

  def index
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
    @copyright_holder = @user.name
    @copyright_year = Time.now.utc.year
    @upload_license_id = @user.license_id
    @licenses = License.current_names_and_ids(@user.license)
  end

  def edit
    @glossary_term = GlossaryTerm.find(params[:id].to_s)
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def create
    glossary_term = \
      GlossaryTerm.new(user: @user, name: params[:glossary_term][:name],
                       description: params[:glossary_term][:description])

    if params[:glossary_term][:upload_image]
      glossary_term.add_image(process_image(image_args))
    end
    glossary_term.save
    redirect_to(glossary_term_path(glossary_term.id))
  end

  def update
    glossary_term = GlossaryTerm.find(params[:id].to_s)
    glossary_term.attributes = params[:glossary_term].
                               permit(:name, :description)
    glossary_term.user = @user
    glossary_term.save
    redirect_to(glossary_term_path(glossary_term.id))
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
    if @glossary_term = find_or_goto_index(GlossaryTerm, params[:id].to_s)
      if params[:version]
        @glossary_term.revert_to(params[:version].to_i)
      else
        flash_error(:show_past_location_no_version.t)
        redirect_to(glossary_term_path(@glossary_term.id))
      end
    end
  end

  # ---------- Public methods (unrouted) ---------------------------------------

  ##############################################################################

  private

  # --------- Filters

  # --------- Other private methods

  def image_args
    Rails.env.test? ? permit_upload_image_param : strong_upload_image_param
  end

  def strong_upload_image_param
    args = {
      copyright_holder: params[:copyright_holder],
      when: Time.local(params[:date][:copyright_year]).utc,
      license: License.safe_find(params[:upload][:license_id]),
      user: @user,
      image: params[:glossary_term][:upload_image]
    }
  end

  def permit_upload_image_param
    args = strong_upload_image_param
    # Remove "permitted: false" from this param so that model can mass assign it
    args[:image] = params[:glossary_term][:upload_image][:image]
    args
  end

  def process_image(args)
    return unless (upload = args[:image])

    if upload.respond_to?(:original_filename)
      name = upload.original_filename.force_encoding("utf-8")
    end

    image = Image.new(args)
    save_or_flash(image)

    image
  end

  def save_or_flash(image)
    if !image.save
      flash_object_errors(image)
    elsif !image.process_image
      logger.error("Unable to upload image")
      name = image.original_name
      name = "???" if name.empty?
      flash_error(:runtime_image_invalid_image.t(name: name))
      flash_object_errors(image)
    else
      name = image.original_name
      name = "##{image.id}" if name.empty?
      flash_notice(:runtime_image_uploaded_image.t(name: name))
    end
  end
end
