require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require "tilt/erubis"

JOBS = { webdev: "Web Developer",
         photo: "Photographer",
         phil: "Philosopher" }.freeze

not_found do
  redirect '/'
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
