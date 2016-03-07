require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require "tilt/erubis"

JOBS = { webdev: "Web Developer",
         photo: "Photographer",
         phil: "Philosopher" }.freeze

def nonexistent_role?
  !JOBS.keys.include? @role
end

def nonexistent_subpage?
  !File.exist? "views/#{@subpage}.erb"
end

def render_role_subpage
  if nonexistent_role?
    redirect '/'
  elsif nonexistent_subpage?
    status 404
  else
    erb @subpage, layout: :main_layout
  end
end

helpers do
  def webdev_links
    { "/webdev/about" => "About",
      "/webdev/contact" => "Contact" }
  end

  def photo_links
    { "/photo/portfolio" => "Portfolio",
      "/photo/about" => "About",
      "/photo/contact" => "Contact" }
  end

  def phil_links
    { "/phil/about" => "About",
      "/phil/contact" => "Contact" }
  end
end

not_found do
  @role ? erb("#{@role}_not_found".to_sym, layout: :main_layout) : redirect('/')
end

get '/' do
  erb :splash, layout: :splash_layout
end

get '/:role' do
  @role = params[:role].to_sym

  if JOBS.keys.include? @role
    erb @role, layout: :main_layout
  else
    redirect '/'
  end
end

get '/:role/:page' do
  @role = params[:role].to_sym
  @subpage = (params[:role] + "_" + params[:page]).to_sym

  render_role_subpage
end
