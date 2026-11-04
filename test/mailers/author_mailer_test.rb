# frozen_string_literal: true

require("test_helper")

class AuthorMailerTest < MailerTestCase
  def test_build_html
    object = names(:coprinus_comatus).description
    rolf.update!(email_html: true)

    mail = AuthorMailer.build(sender: katrina, receiver: rolf, object:,
                              subject: "Please do something or other",
                              message: "and this is why...").message

    assert_includes(mail.to, rolf.email)
    assert_equal(katrina.email, mail.reply_to.first)
    assert_html_mail(mail)
    body = mail.body.to_s
    assert_includes(body, "and this is why")
    assert_includes(body,
                    "https://mushroomobserver.org/users/#{katrina.id}")
  end

  def test_build_text
    object = names(:coprinus_comatus).description
    rolf.update!(email_html: false)

    mail = AuthorMailer.build(sender: katrina, receiver: rolf, object:,
                              subject: "Please do something or other",
                              message: "and this is why...").message

    assert_text_mail(mail)
    assert_includes(mail.body.to_s, "and this is why")
  end

  # The "Make sender an author" link opens the review page with the
  # sender preselected.
  def test_add_author_link_is_routable
    object = names(:coprinus_comatus).description
    rolf.update!(email_html: false)

    mail = AuthorMailer.build(sender: katrina, receiver: rolf, object:,
                              subject: "Credit", message: "Please").message

    url = mail.body.to_s[%r{https://mushroomobserver\.org/descriptions/\S+}]
    uri = URI.parse(url)
    assert_equal({ controller: "descriptions/authors", action: "show" },
                 Rails.application.routes.recognize_path(uri.path).
                   slice(:controller, :action))
    assert_equal({ "id" => object.id.to_s, "type" => "name_description",
                   "add" => katrina.id.to_s },
                 Rack::Utils.parse_query(uri.query))
  end
end
