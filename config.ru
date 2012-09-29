require 'rubygems'
require 'bundler'

Bundler.require

class Frontend < Sinatra::Base
  FOLLOW_BRANCHES = %w(master stage)

  yml = YAML::load(File.open("settings.yml"))

  set :auth_token, yml["auth_token"]

  campfire_api_key = yml["campfire_api_key"]
  campfire_room_id = yml["campfire_room_id"]
  campfire_domain = yml["campfire_domain"]
  campfire = Tinder::Campfire.new(campfire_domain, :token => campfire_api_key)

  set :campfire_room, campfire.find_room_by_id(campfire_room_id)

  helpers do
    def authorize(auth_token)
      settings.auth_token.to_s == auth_token
    end
  end

  post "/" do
    if authorize(params[:auth_token])

      raise "Campfire room not found: #{campfire_room_id}" if settings.campfire_room.nil?

      json = JSON.parse(request.body.read)

      branch = json["ref"].split("/").last
      if FOLLOW_BRANCHES.include?(branch)
        repo = json["repository"]["name"]
        repo_url = json["repository"]["url"]
        repo_ref = json["repository"]["ref"]
        commits = json["commits"]
        commits.map! do |commit|
          "#{commit["message"]} at #{commit["url"]} by #{commit["author"]["name"]}"
        end

        settings.campfire_room.speak "Changes pushed to #{repo}:#{repo_ref}:#{branch} at #{repo_url}"
        settings.campfire_room.paste commits.join("\n")
      end
    else
      halt 403
    end
  end

end

run Frontend