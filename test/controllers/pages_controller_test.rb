require 'test_helper'

class PagesControllerTest < ActionController::TestCase
  test "should get home" do
    get :home
    assert_response :success
  end

  test "should get web-developer" do
    get :web-developer
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
