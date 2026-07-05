# frozen_string_literal: true

# Ask reviewers for authorship credit.
class Views::Mailers::AuthorMailer < Views::Mailers::Base
  prop :subject, ::String
  prop :sender, ::User
  prop :object, ::Description
  prop :message, ::String

  class Html < self
    include Views::Mailers::StandardMessageBody
  end

  class Text < self
    include Views::Mailers::StandardMessageBody
  end

  private

  def intro
    :email_author_request_intro.l(
      user: @sender.legal_name, email: @sender.email,
      object: @object.parent.unique_format_name
    )
  end

  def handy_links = :email_handy_links.l

  def links
    type = @object.type_tag
    [[:author_request_add_author.t,
      "#{MO.http_domain}/descriptions/authors/#{@object.id}" \
      "?type=#{type}&add=#{@sender.id}"],
     [:email_links_show_user.t, "#{MO.http_domain}/users/#{@sender.id}"],
     [:email_links_latest_changes.t, MO.http_domain]]
  end
end
