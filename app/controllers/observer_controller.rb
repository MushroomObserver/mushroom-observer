require 'find'

class ObserverController < ApplicationController

  # Default page
  def index
    list_observations
    render :action => 'list_observations'
  end

  # Various -> list_observations.rhtml
  def list_observations
    @observation_pages, @observations = paginate(:observations,
                                                 :order => "'when' desc",
                                                 :per_page => 10)
  end

  # show_observation.rhtml
  def show_observation
    @observation = Observation.find(params[:id])
  end

  # list_observations.rhtml -> new_observation.rhtml
  def new_observation
    @observation = Observation.new
    @observation.what = 'Unknown'
  end

  # new_observation.rhtml -> list_observations.rhtml
  def create_observation
    @observation = Observation.new(params[:observation])
    @observation.created = Time.now
    if @observation.save
      flash[:notice] = 'Observation was successfully created.'
      redirect_to :action => 'edit_observation', :id => @observation
    else
      render :action => 'new_observation'
    end
  end

  # list_observation.rhtml, show_observation.rhtml -> edit_observation.rhtml
  def edit_observation
    @observation = Observation.find(params[:id])
    session[:observation] = @observation
  end

  # edit_observation.rhtml -> show_observation.rhtml
  # Updates modified and saves changes
  def update_observation
    @observation = Observation.find(params[:id])
    if @observation.update_attributes(params[:observation])

      thumb = params[:thumbnail]
      if thumb
        thumb.each do |index, id|
          logger.warn(sprintf("+*+*+*+ %s", id))
          @observation.thumb_image_id = id
        end
      end

      # Why does this work and the following line doesn't?
      # Tested with 'obs_mod' rather than 'modified'.  Same effect.
      @observation.modified = Time.new
      # @observation.touch
      @observation.save

      flash[:notice] = 'Observation was successfully updated.'
      redirect_to :action => 'show_observation', :id => @observation
    else
      render :action => 'edit_observation'
    end
  end

  # list_observations.rhtml -> destroy -> list_observations.rhtml
  def destroy_observation
    Observation.find(params[:id]).destroy
    redirect_to :action => 'list_observations'
  end

  ## Image support

  # Various -> list_images.rhtml
  def list_images
    @image_pages, @images = paginate(:images,
                                     :order => "'when' desc",
                                     :per_page => 10)
  end

  # list_images -> show_image.rhtml
  # Thumbnails should hook up to this
  def show_image
    @image = Image.find(params[:id])
  end

  # list_images.rhtml, show_image.rhtml -> edit_image.rhtml
  def edit_image
    @image = Image.find(params[:id])
  end

  # edit_image.rhtml -> update_image -> show_image.rhtml
  def update_image
    @image = Image.find(params[:id])
    if @image.update_attributes(params[:image])
      flash[:notice] = 'Image was successfully updated.'
      redirect_to :action => 'show_image', :id => @image
    else
      render :action => 'edit_image'
    end
  end

  # list_images.rhtml -> list_images.rhtml
  # Should this be allowed?  How do we cleanup corresponding observations?
  def destroy_image
    Image.find(params[:id]).destroy
    redirect_to :action => 'list_images'
  end

  # edit_observation.rhtml -> add_image.rhtml
  def add_image
    @observation = Observation.find(params[:id])
    session[:observation] = @observation
    @img = Image.new
  end

  # add_image.rhtml -> edit_observation.rhtml
  def save_image
    @img = Image.new(params[:image])
    observation = session[:observation]
    if @img.save
      if @img.save_image
	observation.add_image(@img)
        observation.save
        redirect_to(:action => 'edit_observation', :id => observation.id)
      else
        logger.error("Unable to save image")
        flash[:notice] = 'Invalid image'
        redirect_to(:action => 'edit_observation', :id => observation.id)
      end
    else
      render(:action => :add_image)
    end
  end

  # image loader
  # edit_image.rhtml, show_image.rhtml
  def image
    @img = Image.find(params[:id])
    send_data(@img.get_image,
              :filename => @img.title,
              :type => @img.content_type,
              :disposition => "inline")
  end

  # thumbnail loader
  # list_images.rhtml, (select_images.rhtml)
  def img_thumb
    @img = Image.find(params[:id])
    send_data(@img.get_thumbnail,
              :filename => @img.title,
              :type => @img.content_type,
              :disposition => "inline")
  end

  JPEG_PAT = /\/([A-Za-z]+)\/([A-Za-z]+)\/([0-9-]+)-(.+).jpg$/

  def load_image_directory
    dir = '/Users/velosa/Fungi/mushrooms-big/Agaricus'
    Find.find(dir) do |f|
      match = JPEG_PAT.match(f)
      if match:
	genus = match[1]
	species = match[2]
	date = match[3]
	count = match[4]
      end
    end
  end
end
