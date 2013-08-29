class GlossaryController < ApplicationController
  before_filter :login_required, :except => [
    :index,
    :show_past_term,
    :show_term
  ]

  def show_term # :nologin:
    store_location
    @term = Term.find(params[:id].to_s)
  end

  def index # :nologin:
    store_location
    @terms = Term.find(:all, :order => :name)
  end

  def create_term # :norobots:
    if request.method == :post
      term = Term.new(:user => @user, :name => params[:term][:name], :description => params[:term][:description])
      image_args = {
        :copyright_holder => params[:copyright_holder],
        :when => Time.local(params[:date][:copyright_year]),
        :license => License.safe_find(params[:upload][:license_id]),
        :user => @user,
        :image => params[:term][:upload_image]
      }
      term.add_image(process_image(image_args))
      term.save
      redirect_to(:action => 'show_term', :id => term.id)
    else
      @copyright_holder = @user.name
      @copyright_year = Time.now.year
      @upload_license_id = @user.license_id
      @licenses = License.current_names_and_ids(@user.license)
    end
  end

  def process_image(args)
    image = nil
    name = nil
    upload = args[:image]
    if !upload.blank?
      name = upload.original_filename.force_encoding('utf-8') if upload.respond_to?(:original_filename)

      image = Image.new(args)
      if !image.save
        flash_object_errors(image)
      elsif !image.process_image
        logger.error("Unable to upload image")
        name = image.original_name
        name = '???' if name.empty?
        flash_error(:runtime_image_invalid_image.t(:name => name))
        flash_object_errors(image)
      else
        name = image.original_name
        name = "##{image.id}" if name.empty?
        flash_notice(:runtime_image_uploaded_image.t(:name => name))
      end
    end
    return image
  end
  
  def edit_term # :norobots:
    # Expand to any MO user, but make them owned and editable only by that user or an admin
    if is_in_admin_mode?
      if request.method == :post
        term = Term.find(params[:id].to_s)
        term.attributes = params[:term]
        term.user = @user
        term.save
        redirect_to(:action => 'show_term', :id => term.id)
      else
        @term = Term.find(params[:id].to_s)
      end
    else
      flash_error(:edit_term_not_allowed.l)
      redirect_to(:action => 'index')
    end
  end


  # Show past version of Term.  Accessible only from show_term page.
  def show_past_term # :nologin: :prefetch: :norobots:
    pass_query_params
    store_location
    if @term = find_or_goto_index(Term, params[:id].to_s)
      @term.revert_to(params[:version].to_i)
    end
  end

end
