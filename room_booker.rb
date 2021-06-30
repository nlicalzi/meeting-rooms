require "date"
require "sinatra"
require "sinatra/json"

require_relative "database_persistence"

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect
end

helpers do
  def room_available?(payload)
    # ensure that there is no other meeting in room_id with an overlapping time range
    @storage.get_conflicting_meetings(
      payload["room_id"], payload["mtg_date"], payload["start_time"], payload["end_time"]
    ).empty?
  end

  def valid_time?(time)
    # ensure that time matches hh:mm
    !!(time =~ /\d{2}:\d{2}/) 
  end

  def valid_date?(date)
    # ensure that date matches yyyy-mm-dd
    !!(date =~ /\d{4}-\d{2}-\d{2}/) 
  end

  def valid_room?(room_id)
    # ensure that the selected room_id exists in the database
    @storage.all_rooms
            .map { |room| room["room_id"].to_i}
            .include?(room_id)
  end

  def valid_mtg_payload?(payload)
    p room_available?(payload) &&
      valid_room?(payload["room_id"]) &&
      valid_date?(payload["mtg_date"]) &&
      valid_time?(payload["start_time"]) &&
      valid_time?(payload["end_time"])
  end
end

not_found do
  redirect "/api/v1" # bad paths should redirect to "/"
end

get "/api/v1" do
  json :endpoints => [
    :all_meetings => "GET /api/v1/meetings",
    :all_rooms => "GET /api/v1/rooms",
    :available_rooms => [
      :path => "GET /api/v1/rooms?date=''&start_time=''&end_time=''",
      :params => "[date: yyyy-mm-dd, start_time: hh:mm, end_time: hh:mm]",
      :example => "GET /api/v1/rooms?date='2008-12-21'&start_time='09:00'&end_time='09:30'",
      :note => "All params must have valid inputs or else the API will return the :all_rooms path instead."
    ],
    :meetings_for_room => "GET /api/v1/rooms/:id",
    :new_meeting => [
      :path => "POST /api/v1/meetings",
      :fmt => 
        "requires a JSON payload like: { room_id: int, host_name: str (OPTIONAL), mtg_name: str, mtg_date: date, start_time: time, end_time: time }",
      :sample_request_body =>
        "{ 'room_id': 1, 'host_name': 'nicholas licalzi', 'mtg_name': 'weekly standup', 'mtg_date': '2021-06-30', 'start_time': '09:00:00', 'end_time': '09:30:00' }"
    ]
  ]
end

get "/api/v1/meetings" do
  json :meetings => @storage.all_meetings
end

post "/api/v1/meetings" do
  payload = JSON.parse(request.body.read)

  if valid_mtg_payload?(payload)
    json :meeting => @storage.create_meeting(payload)
    status 201
  else
    halt 400, "ERROR: invalid payload. Please ensure that your request body is properly formatted. GET /api/v1 for formatting details."
  end
end

delete "/api/v1/meetings/:mtg_id" do
  mtg_id = params[:mtg_id].to_i
  if !@storage.delete_meeting(mtg_id).cmd_tuples.zero?
    status 204
  else
    halt 400, "ERROR: meeting with id #{mtg_id} not found."
  end
end

get "/api/v1/rooms" do
  date = params['date']
  start_time = params['start_time']
  end_time = params['end_time']

  if valid_date?(date) && valid_time?(start_time) && valid_time?(end_time)
    json :available_rooms => @storage.get_available_rooms(date, start_time, end_time)
  else
    json :all_rooms => @storage.all_rooms
  end
end

get "/api/v1/rooms/:id" do
  room_id = params[:id].to_i
  json :meetings => @storage.find_meetings_for_room(room_id)
end