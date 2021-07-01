# WeTransfer Take Home



## Quickstart

* **To run the code locally:**

  * Please first ensure that you have Postgres installed and running on your machine, since we're relying on that as a backend database.
    * You'll first need to create a database called `bookings`.
    * Once `bookings` exists, you can use `schema.sql` to add the tables and some sample data using the following `psql` command: `psql -d bookings < schema.sql`
  * Next, run `bundle install` in the top level folder.
  * Finally, run `ruby room_booker.rb` and it'll spin up a local server. The `json_pp` command utility will be helpful for pretty printing the JSON docs at `/api/v1`, as will something like Postman's Pretty display option.

* **To see the online API documentation**:

  * Please either visit `https://nlicalzi-wetransfer.herokuapp.com/api/v1/` in your browser or run `curl https://nlicalzi-wetransfer.herokuapp.com/api/v1/ | json_pp` in your shell, returning the below:

  * ```json
    {
        "endpoints": [
            {
                "all_meetings": "GET /api/v1/meetings",
                "all_rooms": "GET /api/v1/rooms",
                "available_rooms": [
                    {
                        "path": "GET /api/v1/rooms?date=''&start_time=''&end_time=''",
                        "params": "[date: yyyy-mm-dd, start_time: hh:mm, end_time: hh:mm]",
                        "example": "GET /api/v1/rooms?date='2008-12-21'&start_time='09:00'&end_time='09:30'",
                        "note": "All params must have valid inputs or else the API will return the :all_rooms path instead."
                    }
                ],
                "meetings_for_room": "GET /api/v1/rooms/:id",
                "new_meeting": [
                    {
                        "path": "POST /api/v1/meetings",
                        "fmt": "requires a JSON payload like: { room_id: int, host_name: str (OPTIONAL), mtg_name: str, mtg_date: date, start_time: time, end_time: time }",
                        "sample_request_body": "{ 'room_id': 1, 'host_name': 'nicholas licalzi', 'mtg_name': 'weekly standup', 'mtg_date': '2021-06-30', 'start_time': '09:00:00', 'end_time': '09:30:00' }"
                    }
                ]
            }
        ]
    }
    ```

## Big Picture: Notes and Assumptions

- Built the API using Sinatra instead of Rails in API mode since Marvin mentioned that the Collect team builds on top of Sinatra.

- The API is hosted on Heroku (backed by a Postgres instance), and usable at: https://nlicalzi-wetransfer.herokuapp.com/api/v1/

- All times are tracked in GMT (UTC +0), we could add an `Employees` table with a `timezone` feature if needed, then use that to localize times for individuals.

- We're not worried about the capacity for a given `Room`, but if we were we could put a constaint on the number of employees that were able to sign up for a given meeting.

- Not currently an option to make a meeting recurring, but that functionality could be added without too much effort.

- DB Tables:

  - ```
                                            Table "public.meetings"
       Column   |          Type          | Collation| Nullable |                 Default                  
    ------------+------------------------+----------+----------+----------------------------------------
     mtg_id     | integer                |          | not null |nextval('meetings_mtg_id_seq'::regclass)
     room_id    | integer                |          | not null | 
     host_name  | text                   |          |          | 
     mtg_name   | text                   |          |          | 
     mtg_date   | date                   |          | not null | 
     start_time | time without time zone |          | not null | 
     end_time   | time without time zone |          | not null | 
    Indexes:
        "meetings_pkey" PRIMARY KEY, btree (mtg_id)
    Foreign-key constraints:
        "meetings_room_id_fkey" FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE
    
    bookings=# \d rooms
                                    Table "public.rooms"
      Column   |  Type   | Collation | Nullable |                Default                 
    -----------+---------+-----------+----------+----------------------------------------
     room_id   | integer |           | not null | nextval('rooms_room_id_seq'::regclass)
     room_name | text    |           |          | 
    Indexes:
        "rooms_pkey" PRIMARY KEY, btree (room_id)
    Referenced by:
        TABLE "meetings" CONSTRAINT "meetings_room_id_fkey" FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE
    ```

## How to design a system for booking a meeting room?

- A **person** should be able to *book* a **meeting room**. Their ability to make a **booking** depends on available meeting times for the room.
- A user wants to be able to see all of the rooms available for a given time:
  - `GET /api/v1/rooms`
- A user wants to see the currently booked meetings for a given room having `room_id`:

  - `GET /api/v1/rooms/:room_id`
- A user wants to be able to see all currently booked meetings:
  - `GET /api/v1/meetings`
- A user wants to see the available rooms for booking a given `date` and `start/end time`
  - `GET /api/v1/rooms?date='2008-12-21'&start_time='09:00'&end_time='09:30'`
- A user wants to book a room if it has available spots:
  - `POST /api/v1/meetings`, ensure that request is properly formatted with a valid JSON body.
- A user wants to delete a given meeting having `mtg_id`
  - `/api/v1/meetings/:mtg_id`