# frozen_string_literal: true

require 'date'
require 'sinatra'
require 'sinatra/json'

require_relative 'database_persistence'

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistence.rb'
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect
end

helpers do
  # Ensure that there is no other meeting with an overlapping time range for the given room payload
  def room_available?(payload)
    @storage.get_conflicting_meetings(
      payload['room_id'], payload['mtg_date'], payload['start_time'], payload['end_time']
    ).empty?
  end

  # Ensure that time matches hh:mm
  def valid_time?(time)
    !!(time =~ /\d{2}:\d{2}/)
  end

  # Ensure that date matches yyyy-mm-dd
  def valid_date?(date)
    !!(date =~ /\d{4}-\d{2}-\d{2}/)
  end

  # Ensure that the selected room_id exists in the database
  def valid_room?(room_id)
    @storage.all_rooms
            .map { |room| room['room_id'].to_i }
            .include?(room_id.to_i)
  end

  # Use our other predefined helper methods to ensure that a given payload is fully valid and insertable
  def valid_mtg_payload?(payload)
    valid_room?(payload['room_id']) &&
      valid_date?(payload['mtg_date']) &&
      valid_time?(payload['start_time']) &&
      valid_time?(payload['end_time'])
  end
end

# Bad paths should redirect to "/api/v1" where the docs live
not_found do
  redirect '/api/v1'
end

# Baseline path, features the API docs in JSON form
get '/api/v1' do
  json endpoints: [
    rooms: 'GET /api/v1/rooms',
    available_rooms: [
      path: "GET /api/v1/rooms?date=''&start_time=''&end_time=''",
      params: '[date: yyyy-mm-dd, start_time: hh:mm, end_time: hh:mm]',
      example: "GET /api/v1/rooms?date='2008-12-21'&start_time='09:00'&end_time='09:30'",
      note: 'All params must have valid inputs or else the API will return the :all_rooms path instead.'
    ],
    meetings_for_room: 'GET /api/v1/rooms/:id',
    all_meetings: 'GET /api/v1/meetings',
    new_meeting: [
      path: 'POST /api/v1/meetings',
      fmt: 'requires a JSON payload like: { room_id: int, host_name: str (OPTIONAL), mtg_name: str, mtg_date: date, '\
           'start_time: time, end_time: time }',
      sample_request_body: "{ 'room_id': 1, 'host_name': 'nicholas licalzi', 'mtg_name': 'weekly standup', "\
                           "'mtg_date': '2021-06-30', 'start_time': '09:00:00', 'end_time': '09:30:00' }"
    ],
    delete_meeting: 'DELETE /api/v1/meetings/:mtg_id'
  ]
end

# Display all booked meetings
get '/api/v1/meetings' do
  json meetings: @storage.all_meetings
end

# Create a new meeting by passing a (valid) JSON payload in the request body
post '/api/v1/meetings' do
  payload = JSON.parse(request.body.read)

  if valid_mtg_payload?(payload) && room_available?(payload)
    json meeting: @storage.create_meeting(payload)
    status 201
  elsif !room_available?(payload)
    halt 400, 'ERROR: meeting room is already booked for the specified time. Please try another room.'
  else
    halt 400,
         'ERROR: invalid payload. Please ensure that your request body is properly formatted. '\
         'GET /api/v1 for formatting details.'
  end
end

# Delete a given meeting having mtg_id
delete '/api/v1/meetings/:mtg_id' do
  mtg_id = params[:mtg_id].to_i
  if !@storage.delete_meeting(mtg_id).cmd_tuples.zero?
    status 204
  else
    halt 400, "ERROR: meeting with id #{mtg_id} not found."
  end
end

# Display all existing rooms
# OPTIONAL: filter by date/start/end time like so: /api/v1/rooms?date=''&start_time=''&end_time=''
get '/api/v1/rooms' do
  date = params['date']
  start_time = params['start_time']
  end_time = params['end_time']

  if valid_date?(date) && valid_time?(start_time) && valid_time?(end_time)
    json available_rooms: @storage.get_available_rooms(date, start_time, end_time)
  else
    json all_rooms: @storage.all_rooms
  end
end

# Display meetings for a given room having room_id
get '/api/v1/rooms/:room_id' do
  room_id = params[:room_id].to_i
  json meetings: @storage.find_meetings_for_room(room_id)
end
