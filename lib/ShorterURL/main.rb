require 'rubygems'
require 'sinatra'
require 'haml'
require 'ShorterURL/modles/modles.rb'


get '/'do
  haml :index
end

def get_remote_ip(env)
  if addr = env['HTTP_X_FORWARDED_FOR']
    addr.split(',').first.strip
  else
    env['REMOTE_ADDR']
  end
end
     
post '/' do
  uri = URI::parse(params[:original])
  custom = params[:custom].empty? ? nil : params[:custom]
  raise "Invalid URL" unless uri.kind_of? URI::HTTP or uri.kind_of?
  URI::HTTPS
  @link = Link.shorten(params[:original], custom)
  haml :index
end

get '/show/:short_url' do
  link = Link.first(:identifier => params[:short_url])
  link.visits << Visit.create(:ip => get_remote_ip(env))
  link.save
  redirect link.url.original, 301
end

['/info/:short_url', '/info/:short_url/:num_of_days', '/info/:short_url/:num_of_days/:map'].each do |path|
  get path do
    @link = Link.first(:identifier => params[:short_url])
    raise 'This link is not defined yet' unless @link
    @num_of_days = (params[:num_of_days] || 15).to_i
    @count_days_bar = Visit.count_days_bar(params[:short_url], @num_of_days)
    chart = Visit.count_country_chart(params[:short_url], params[:map] || 'world')
    @count_country_map = chart[:map]
    @count_country_bar = chart[:bar]
    haml :info
  end
end 