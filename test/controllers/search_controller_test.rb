require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end
  def test_single_doi_search
    get '/search/'
  end
  def test_multi_doi_search
  end
end
