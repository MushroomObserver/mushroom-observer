# frozen_string_literal: true

require("test_helper")

class Mutations::ImageUrlsTest < ActionDispatch::IntegrationTest
  # Tests the ImageUrls interface, implemented by several Types::Models

  def test_get_user_thumbnail_urls
    query_string = <<-GRAPHQL
        query findThumb($login: String!){
          user(login: $login) {
            name
            imgSrcThumb
            imgSrcSm
            imgSrcMed
            imgSrcLg
            imgSrcHuge
            imgSrcFull
          }
        }
    GRAPHQL

    user = users(:rolf)

    result = MushroomObserverSchema.execute(
      query_string, variables: { login: user.login }
    )
    user_result = result["data"]["user"]

    # Make sure the query worked
    assert_equal(user.name, user_result["name"])

    thumb_url = Image.url(:thumbnail, user.image_id)
    small_url = Image.url(:small, user.image_id)
    medium_url = Image.url(:medium, user.image_id)
    large_url = Image.url(:large, user.image_id)
    huge_url = Image.url(:huge, user.image_id)
    full_size_url = Image.url(:full_size, user.image_id)

    assert_equal(thumb_url, user_result["imgSrcThumb"],
                 "imgSrcThumb Works")
    assert_equal(small_url, user_result["imgSrcSm"],
                 "imgSrcSm Works")
    assert_equal(medium_url, user_result["imgSrcMed"],
                 "imgSrcMed Works")
    assert_equal(large_url, user_result["imgSrcLg"],
                 "imgSrcLg Works")
    assert_equal(huge_url, user_result["imgSrcHuge"],
                 "imgSrcHuge Works")
    assert_equal(full_size_url, user_result["imgSrcFull"],
                 "imgSrcFull Works")
  end
end
