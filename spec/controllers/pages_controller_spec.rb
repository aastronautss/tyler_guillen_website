require 'rails_helper'

describe PagesController do
  describe '#show' do
    %w(home webdev photo contact).each do |page|
      context "on GET to /#{page}" do
        before { get :show, params: { id: page } }

        it { should respond_with(:success) }
        it { should render_template(page) }
      end
    end
  end
end
