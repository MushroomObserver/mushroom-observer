# encoding: utf-8

class ConferenceRegistration < AbstractModel
  belongs_to :conference_event
  
  def describe()
    result = :conference_registration_email.t + ': ' + self.email + "\n" +
      :conference_registration_name.t + ': ' + self.name + "\n" +
      :conference_registration_how_many.t + ': ' + self.how_many.to_s + "\n"
    result += :conference_registration_notes.t + ': ' + self.notes + "\n" if self.notes
    result
  end
  
  def update_from_params(params)
    self.name = params[:name]
    self.how_many = params[:how_many]
    self.notes = params[:notes]
  end
end
