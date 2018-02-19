require 'bundler'
Bundler.require

require 'sinatra/config_file'

require 'net/http'
require 'uri'
require 'json'


if ENV['GB2S_CONFIG_PATH'].nil?
 puts 'Please set ENVs: GB2S_CONFIG_PATH'
 exit 1
end


configure do
  set :server, :puma
end


class App < Sinatra::Base
  register Sinatra::ConfigFile

  configure :development do
    Bundler.require :development
    register Sinatra::Reloader
  end

  ::Logger.class_eval { alias :write :'<<' }
  access_logger = ::Logger.new(File.join(settings.root, 'log', 'access.log'))
  error_logger = File.new(File.join(settings.root, 'log', 'error.log'), 'a+')
  error_logger.sync = true

  configure do
    use ::Rack::CommonLogger, access_logger
  end

  before {
    env["rack.errors"] =  error_logger
  }

  def logger
    @logger ||= Logger.new("#{settings.root}/log/trace.log")
  end


  config_file ENV['GB2S_CONFIG_PATH']

  Slack.configure do |config|
    config.token = settings.slack_api_token
  end


  # Action ------------------------------------------------------------

  post '/gitbucket2slack_hook/:token' do
    slack_url = settings.token2slack[params[:token]]
    if slack_url.nil?
      status 404
      body ''
      return
    end

    data_hash = JSON.parse(request.body.read)

    # load user id data from local file.
    user_name_to_id_hash = {}
    if File.exist?(user_name_to_id_file_path)
      user_name_to_id_hash = File.open(user_name_to_id_file_path) do |io|
        JSON.load(io)
      end
    end

    # check new mention user and update user id from slack.
    mention_names = search_mention_names_from_json(data_hash)
    if mention_names.select{ |x| user_name_to_id_hash[x].nil? }.size > 0
      user_name_to_id_hash = update_json_file
    end

    # replace gitbucket's mention to slack's mention
    if data_hash['action'] == 'opened'
      unless data_hash.dig(*%w/issue body/).nil?
        data_hash['issue']['body'] = replace_mention_names(data_hash['issue']['body'], user_name_to_id_hash)
      end

      unless data_hash.dig(*%w/pull_request body/).nil?
        data_hash['pull_request']['body'] = replace_mention_names(data_hash['pull_request']['body'], user_name_to_id_hash)
      end

    elsif data_hash['action'] == 'created' || data_hash['action'] == 'create'
      unless data_hash.dig(*%w/comment body/).nil?
        data_hash['comment']['body'] = replace_mention_names(data_hash['comment']['body'], user_name_to_id_hash)
      end
    end

    # resend to slack
    uri  = URI.parse(slack_url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Post.new(uri.path)
      request.set_form_data(payload: data_hash.to_json)
      http.request(request)
    end

    status 200
    body ''
  end


  not_found do
    'not_found'
  end

  error do
    'error'
  end


  # ------------------------------------------------------------
  private

  def user_name_to_id_file_path
    File.join(settings.root, 'tmp', 'slack_user_name_to_id.json')
  end

  def update_json_file
    client = Slack::Web::Client.new

    user_name_to_id_hash = {}
    client.users_list.members.each do |member|
      name = member.profile.display_name
      name = member.name if name.nil? || name.empty?
      user_name_to_id_hash[name] = member.id
    end

    File.open(user_name_to_id_file_path, 'w', 0600) do |file|
      file.write(user_name_to_id_hash.to_json)
    end

    logger.info 'Updated slack_user_name_to_id.json file.'

    return user_name_to_id_hash
  end

  def search_mention_names_from_json(data_hash)
    names = []
    if data_hash['action'] == 'opened'
      unless data_hash.dig(*%w/issue body/).nil?
        names.concat(search_mention_names_from_text(data_hash['issue']['body']))
      end

      unless data_hash.dig(*%w/pull_request body/).nil?
        names.concat(search_mention_names_from_text(data_hash['pull_request']['body']))
      end

    elsif data_hash['action'] == 'created' || data_hash['action'] == 'create'
      # action == create: pull request source diff comment
      unless data_hash.dig(*%w/comment body/).nil?
        names.concat(search_mention_names_from_text(data_hash['comment']['body']))
      end
    end

    return names.uniq
  end

  def search_mention_names_from_text(text)
    text.scan(/@([a-zA-Z0-9\.\-_]+)/).flatten
  end

  def replace_mention_names(org_text, user_name_to_id_hash)
    org_text.gsub(/@([a-zA-Z0-9\.\-_]+)/) {
      (!user_name_to_id_hash[$1].nil? && !user_name_to_id_hash[$1].empty?) ? "<@#{user_name_to_id_hash[$1]}>" : "@#{$1}"
    }
  end
end
