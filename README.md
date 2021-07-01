# "Book a Room" Backend Service



## Project Motivation

This code was produced in response to a given prompt (and mock page design):

* A small company has an internal system to handle their meeting rooms. Write a simple backend that handles the following user scenarios:
  * A **user** wants to be able to **see all of the rooms available**.
  * A **user** wants to **book a room** if it has **available spots**.

My approach to the problem was to build an MVP consisting of a Sinatra API backed by a Postgres database, and rely on two primary entities (or tables): the **rooms** that are available and the **meetings** that have been booked for those rooms. A meeting must have an ID, assigned room, a date, as well as a start time and an end time (as well as an optional meeting name and host name), while a room has an ID and a name. 

## Quickstart

* **To run the code locally:**

  * Clone the repository.
  * Please first ensure that you have Postgres installed and running on your machine, since we're relying on that as a backend database.
    * You'll first need to create a database called `bookings`.
    * Once `bookings` exists, you can use `schema.sql` to add the tables and some sample data using the following `psql` command: `psql -d bookings < schema.sql`
  * Next, run `bundle install` in the top level folder.
  * Finally, run `ruby room_booker.rb` and it'll spin up a local server. The `json_pp` command utility will be helpful for pretty printing the JSON docs at `/api/v1`, as will something like Postman's Pretty display option.

* **To see the online API documentation**:

  * Please either visit `https://nlicalzi-wetransfer.herokuapp.com/api/v1/` in your browser or run `curl https://nlicalzi-wetransfer.herokuapp.com/api/v1/ | json_pp` in your shell, returning something like the below:

  * ```json
    {
        "endpoints": [
            {
                "rooms": "GET /api/v1/rooms",
                "available_rooms": [
                    {
                        "path": "GET /api/v1/rooms?date=''&start_time=''&end_time=''",
                        "params": "[date: yyyy-mm-dd, start_time: hh:mm, end_time: hh:mm]",
                        "example": "GET /api/v1/rooms?date='2008-12-21'&start_time='09:00'&end_time='09:30'",
                        "note": "All params must have valid inputs or else the API will return the :all_rooms path instead."
                    }
                ],
                "meetings_for_room": "GET /api/v1/rooms/:id",
                "all_meetings": "GET /api/v1/meetings",
                "new_meeting": [
                    {
                        "path": "POST /api/v1/meetings",
                        "fmt": "requires a JSON payload like: { room_id: int, host_name: str (OPTIONAL), mtg_name: str, mtg_date: date, start_time: time, end_time: time }",
                        "sample_request_body": "{ 'room_id': 1, 'host_name': 'nicholas licalzi', 'mtg_name': 'weekly standup', 'mtg_date': '2021-06-30', 'start_time': '09:00:00', 'end_time': '09:30:00' }"
                    }
                ],
                "delete_meeting": "DELETE /api/v1/meetings/:mtg_id"
            }
        ]
    }
    ```

## Notes and Assumptions

- I built this API using Sinatra instead of Rails in API mode since Marvin mentioned that the team builds on top of Sinatra. The API is hosted on Heroku (backed by a Postgres instance), and usable at: https://nlicalzi-wetransfer.herokuapp.com/api/v1/

- There are quite a few validation steps throughout the codebase, but I make the assumption that there would be some frontend validation as well (perhaps a date picker or time input, etc.). Having the validation exist at the API level as well means that users could choose to interact solely with the API instead of the frontend.

- The business logic is contained in `room_booker.rb`, while the logic for interacting with the database layer is abstracted out into `database_persistence.rb`. This lets us potentially change databases etc. more easily in the future, since that logic is less tightly coupled with the business logic. 

  - Versioning the API (currently our API URI is prepended with `/api/v1`) may seem like overkill, but it accomplishes a similar thing: future flexibility.

- All times are tracked in GMT (UTC +0), we could add an `Employees` table with a `timezone` feature if needed, then use that to localize times for individuals.

- We're not worried about the capacity for a given `Room`, but if we were we could put a constaint on the number of employees that were able to sign up for a given meeting, assuming we added the `Employees` table mentioned above and made a join table between `Employees` and `Meetings` to represent the `Many:Many` relationship they would have.

- There is not currently an option to make a meeting recurring, but that functionality could be added without too much effort.

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

## What does a system for booking a meeting room entail?

- **Top level goal:** 
  - A user should be able to **book** a **meeting room**. Their ability to make a **booking** depends on *available meeting times* for the **room**. 
- How does this API satisfy that goal?
  - If a user wants to see a list of the rooms in the system:
    - Send a request to `GET /api/v1/rooms`
  - If a user wants to see the available rooms for booking, given a `date` and `start_time` and `end_time` as query parameters:
    - Send a request to `GET /api/v1/rooms?date='2008-12-21'&start_time='09:00'&end_time='09:30'`
  - If a user wants to see the currently booked meetings for a given room having `room_id`:
    - Send a request to `GET /api/v1/rooms/:room_id`
  - If a user wants to be able to see all currently booked meetings:
    - Send a request to `GET /api/v1/meetings`
  - If a user wants to book a room if it is available:
    - Send a request to `POST /api/v1/meetings`, ensure that request is properly formatted with a valid JSON body.
    - Sample raw `POST` request body:
      - `{ 'room_id': 2, 'host_name': 'Nicholas LiCalzi', 'mtg_name': 'Weekly Standup', 'mtg_date': '2021-07-01', 'start_time': '09:00:00', 'end_time': '09:30:00' }`
  - If a user wants to delete a given meeting having `mtg_id`
    - Send a request to `DELETE /api/v1/meetings/:mtg_id`