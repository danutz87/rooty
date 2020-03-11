class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  def intro
    @new_node = Node.new
    if params[:route]
      @route = Route.find(params[:route])
      calculate_distance(@route)
      while @route.distance < 4000 || @route.distance > 6000
        @route.define_nodes(5)
        calculate_distance(@route.reload)
      end
    else
      @paths = []
      @nodes = [{longitude: -122.486052, latitude: 37.830348}]
      @route = nil
    end
  end

  def home
    @new_node = Node.new
    if params[:route]
      @route = Route.find(params[:route])
      calculate_distance(@route)
      while @route.distance < 4000 || @route.distance > 6000
        @route.define_nodes(5)
        calculate_distance(@route.reload)
      end
    else
      @paths = []
      @nodes = [{longitude: -122.486052, latitude: 37.830348}]
      @route = nil
    end
  end

  def profile
    participants = Participant.where(user: current_user)
    @events = current_user.events_joined
    @routes = current_user.routes
    @event = Event.new
    @requests = current_user.friend_requests
  end

  private

  def calculate_distance(route)
    @paths = []
      @route = route
      @nodes = route.nodes
      @markers = []
      @nodes.each do |node|
        @markers << {
          lat: node.latitude,
          lng: node.longitude
        } if node.real
      end
      distance = 0
      time = 0
      if route.form == "Circular"
        @nodes.each_with_index do |node, index|
          response = RestClient.get "https://api.mapbox.com/directions/v5/mapbox/cycling/#{@nodes[index-1].longitude},#{@nodes[index-1].latitude};#{node.longitude},#{node.latitude}?geometries=geojson&exclude=ferry&access_token=#{ENV['MAPBOX_API_KEY']}"
          repos = JSON.parse(response) # => repos is an `Array` of `Hashes`.
          node.distance = repos['routes'].first['distance']
          node.time = repos['routes'].first['duration']
          distance += node.distance
          time += node.time
          node.save!
          @paths << (repos['routes'].first['geometry']['coordinates'])
        end
      else
        number = 1
        while number < @nodes.length do
          response = RestClient.get "https://api.mapbox.com/directions/v5/mapbox/cycling/#{@nodes[number-1].longitude},#{@nodes[number-1].latitude};#{@nodes[number].longitude},#{@nodes[number].latitude}?geometries=geojson&exclude=ferry&access_token=#{ENV['MAPBOX_API_KEY']}"
          repos = JSON.parse(response) # => repos is an `Array` of `Hashes`.
          @nodes[number].distance = repos['routes'].first['distance']
          @nodes[number].save!
          distance += @nodes[number].distance
          @nodes[number].time = repos['routes'].first['duration']
          time += @nodes[number].time
          @paths << (repos['routes'].first['geometry']['coordinates'])
          number += 1
        end
      end
      route.distance = distance
      route.time = (time / 60).round
      route.save
  end
end
