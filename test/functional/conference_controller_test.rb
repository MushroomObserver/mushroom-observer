require File.expand_path(File.dirname(__FILE__) + '/../boot')

class ConferenceControllerTest < FunctionalTestCase
  # Replace this with your real tests.
  def test_truth
    assert true
  end

  def test_show_event
    msa = conference_events(:msa_annual_meeting)
    get_with_dump(:show_event, :id => msa.id)
    assert_response('show_event')
  end

  def test_index
    get_with_dump(:index)
    assert_response('index')
  end
  
  def test_create_event
    get(:create_event)
    assert_response(:redirect)

    make_admin
    get_with_dump(:create_event)
    assert_response('create_event')
  end
  
  def create_event_params
    return {
      :event => {
        :name => 'Cape Cod Foray',
        :location => 'Cape Cod, MA, USA',
        :description => 'Find 555 fungal friends for $50',
        'start(1i)'      => '2012',
        'start(2i)'      => '09',
        'start(3i)'      => '28',
        'end(1i)'      => '2012',
        'end(2i)'      => '09',
        'end(3i)'      => '28',
      }
    }
  end
  
  def test_create_event_post
    make_admin
    user = @rolf
    params = create_event_params
    post(:create_event, params)
    event = ConferenceEvent.find(:all, :order => "created_at DESC")[0]
    assert_equal(params[:event][:name], event.name)
    assert_equal(params[:event][:location], event.location)
    assert_equal(params[:event][:description], event.description)
    assert(event.start)
    assert(event.end)
    assert_response(:redirect)
  end
  
  def test_edit_event
    msa = conference_events(:msa_annual_meeting)
    get_with_dump(:edit_event, :id => msa.id)
    assert_response(:redirect)

    make_admin
    get_with_dump(:edit_event, :id => msa.id)
    assert_response('edit_event')
  end
  
  def test_edit_event_post
    msa = conference_events(:msa_annual_meeting)
    make_admin
    user = @rolf

    params = create_event_params
    params[:id] = msa.id
    post(:edit_event, params)
    event = ConferenceEvent.find(:all, :order => "created_at DESC")[0]
    assert_equal(params[:event][:name], event.name)
    assert_equal(params[:event][:location], event.location)
    assert_equal(params[:event][:description], event.description)
    assert(event.start)
    assert(event.end)
    assert_response(:redirect)
  end

  def test_register
    msa = conference_events(:msa_annual_meeting)
    get_with_dump(:register, :id => msa.id)
    assert_response('register')
  end

  def create_registration_params
    return {
      :id => conference_events(:msa_annual_meeting).id,
      :registration => {
        :name => 'Rolf Singer',
        :email => 'rolf@mo.com',
        :how_many => 4,
        :notes => "I like to eat meat!"
      }
    }
  end
  
  def test_register_post
    registrations = ConferenceRegistration.count
    params = create_registration_params
    post(:register, params)
    assert_equal(registrations + 1, ConferenceRegistration.count)
    registration = ConferenceRegistration.find(:all, :order => "created_at DESC")[0]
    assert_equal(params[:registration][:name], registration.name)
    assert_equal(params[:registration][:email], registration.email)
    assert_equal(params[:registration][:how_many], registration.how_many)
    assert_equal(params[:registration][:notes], registration.notes)
    assert_response(:redirect)
  end
  
  def test_reregister_post
    registrations = ConferenceRegistration.count
    previous_registration = conference_registrations(:njw_at_msa)
    params = create_registration_params
    params[:registration][:name] = previous_registration.name
    params[:registration][:email] = previous_registration.email
    post(:register, params)
    assert_equal(registrations, ConferenceRegistration.count)
    registration = ConferenceRegistration.find(:all, :order => "created_at DESC")[0]
    assert_equal(params[:registration][:name], registration.name)
    assert_equal(params[:registration][:email], registration.email)
    assert_equal(params[:registration][:how_many], registration.how_many)
    assert_equal(params[:registration][:notes], registration.notes)
    assert_response(:redirect)
  end

  def test_list_registrations
    msa = conference_events(:msa_annual_meeting)
    get(:list_registrations, :id => msa.id)
    assert_response(:redirect)

    make_admin
    get_with_dump(:list_registrations, :id => msa.id)
    assert_response('list_registrations')
  end
  
  def test_verify
    msa = conference_registrations(:njw_at_msa)
    get_with_dump(:verify, :id => msa.id)
    assert_response(:redirect)
  end
end
