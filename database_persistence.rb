require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV["DATABASE_URL"])
    else
      PG.connect(dbname: "bookings")
    end

    @logger = logger
  end

  def find_meeting(mtg_id)
    sql = "SELECT * FROM meetings WHERE mtg_id = $1;"
    query(sql, mtg_id).entries
  end

  def get_conflicting_meetings(room_id, date, mtg_start, mtg_end)
    sql = 'SELECT * FROM meetings WHERE room_id = $1 AND mtg_date = $2 AND (start_time, end_time) OVERLAPS ($3::time, $4::time);'
    query(sql, room_id, date, mtg_start, mtg_end).entries
  end

  def get_available_rooms(date, mtg_start, mtg_end)
    subquery = "SELECT room_id FROM meetings WHERE mtg_date = $1 AND (start_time, end_time) OVERLAPS ($2::time, $3::time)"
    sql = "SELECT room_id, room_name FROM rooms WHERE room_id NOT IN (#{subquery});"
    query(sql, date, mtg_start, mtg_end).entries
  end

  def find_meetings_for_room(room_id)
    sql = "SELECT * FROM meetings WHERE room_id = $1;"
    query(sql, room_id).entries
  end

  def all_meetings
    sql = "SELECT * FROM meetings;"
    query(sql).entries
  end

  def all_rooms
    sql = "SELECT * FROM rooms;"
    query(sql).entries
  end

  def create_meeting(info)      
    @db.prepare(
      "insert",
      "INSERT INTO meetings (room_id, host_name, mtg_name, mtg_date, start_time, end_time) " +
      "VALUES ($1,$2,$3,$4,$5,$6);"
    )

    @db.exec_prepared("insert", [
        info["room_id"], info["host_name"], info["mtg_name"],
        info["mtg_date"], info["start_time"], info["end_time"]
      ])
  end

  def delete_meeting(mtg_id)
    sql = "DELETE FROM meetings WHERE mtg_id = $1;"
    query(sql, mtg_id)
  end

  def disconnect
    # @db.exec("DEALLOCATE query")
    @db.close
  end

  private
  def query(statement, *params)
    @logger.info("#{statement}: #{params}")

    @db.prepare("query", statement)
    @db.exec_prepared("query", params)
  end
end