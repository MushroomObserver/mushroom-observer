class ConferenceController < ApplicationController
  
  # TODO: Add count to ConferenceRegistration
  def register
    store_location
    event = ConferenceEvent.find(params[:id])
    if request.method == :post
      registration = ConferenceRegistration.new(params[:registration])
      registration.conference_event = event
      registration.save
      flash_notice(:register_success.l(:name => event.name, :how_many => registration.how_many))
      redirect_to(:action => 'show_event', :id => event.id)
    else
      @event = event
    end
  end

  def list_registrations
    if is_in_admin_mode?
      @event = ConferenceEvent.find(params[:id])
      @hello = "Hello"
    else
      flash_error(:list_registrations_not_allowed.l)
      redirect_to(:action => 'index')
    end
  end

  # allow editing of registration based on email address
  # send confirmation email upon creation and edit
  # Have users own ConferenceEvents rather than admin
  # Owners can delete ConferenceEvents
  
  # Creating a conference event should be RESTful, but I'm not sure what our conventions are at this point
  def show_event
    store_location
    @event = ConferenceEvent.find(params[:id])
    @registration_count = @event.how_many
  end

  def index
    store_location
    @events = ConferenceEvent.find(:all)
  end
  
  def create_event
    if is_in_admin_mode? # Probably should be expanded to any MO user
      if request.method == :post
        event = ConferenceEvent.new(params[:event])
        event.save
        redirect_to(:action => 'show_event', :id => event.id)
      end
    else
      flash_error(:create_event_not_allowed.l)
      redirect_to(:action => 'index')
    end
  end
  
  def edit_event # Expand to any MO user, but make them owned and editable only by that user or an admin
    if is_in_admin_mode?
      if request.method == :post
        event = ConferenceEvent.find(params[:id])
        event.attributes = params[:event]
        event.save
        redirect_to(:action => 'show_event', :id => event.id)
      else
        @event = ConferenceEvent.find(params[:id])
      end
    else
      flash_error(:edit_event_not_allowed.l)
      redirect_to(:action => 'index')
    end
  end
end
