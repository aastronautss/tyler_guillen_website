require 'test_helper'

class PagesControllerTest < ActionController::TestCase
  test "should get webdev" do
    get :webdev
    assert_response :success
  end

  test "should get photographer" do
    get :photographer
    assert_response :success
  end

  test "should get philosopher" do
    get :philosopher
    assert_response :success
  end

end
