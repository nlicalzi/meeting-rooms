CREATE TABLE rooms (
  room_id serial PRIMARY KEY,
  room_name text
);

INSERT INTO rooms(room_name) VALUES ('Manhattan'), ('Brooklyn'), ('Queens'), ('Bronx'), ('Staten Island');

CREATE TABLE meetings (
  mtg_id serial PRIMARY KEY,
  room_id int NOT NULL REFERENCES rooms (room_id) ON DELETE CASCADE,
  host_name text,
  mtg_name text,
  mtg_date date NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL
);


INSERT INTO meetings(room_id, host_name, mtg_name, mtg_date, start_time, end_time)
VALUES (2, 'WeTransfer team', 'Discussion: hiring Nick', '2021-07-01'::date, '09:00:00'::time, '09:30:00'::time);