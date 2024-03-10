-- Question 1
-- Create a materialized view to compute the average, min and max trip time between each taxi zone.
-- From this MV, find the pair of taxi zones with the highest average trip time. You may need to use the dynamic filter pattern for this.

CREATE MATERIALIZED VIEW mv_trip_time AS
WITH with_trip_time as (
     SELECT *, EXTRACT(EPOCH FROM (tpep_dropoff_datetime - tpep_pickup_datetime)) / 60 as trip_time from trip_data
)
SELECT MIN(trip_time) min_trip_time, MAX(trip_time) max_trip_time, AVG(trip_time) avg_trip_time, pulocationid, dolocationid 
FROM with_trip_time 
GROUP BY pulocationid, dolocationid;



WITH max_avg_trip_time AS (
    SELECT
        MAX(avg_trip_time) AS max_avg_trip_time
    FROM
        mv_trip_time
)

SELECT
    pulocationid,
    dolocationid,
    p_tz.Zone,
    do_tz.Zone,
    avg_trip_time
FROM max_avg_trip_time,
    mv_trip_time
JOIN taxi_zone p_tz
    ON mv_trip_time.pulocationid = p_tz.location_id
JOIN taxi_zone do_tz
    ON mv_trip_time.dolocationid = do_tz.location_id
WHERE
    mv_trip_time.avg_trip_time = max_avg_trip_time;



-- Bonus (no marks): Create an MV which can identify anomalies in the data. For example, if the average trip time between two zones is 1 minute, but the max trip time is 10 minutes and 20 minutes respectively.
CREATE MATERIALIZED VIEW trip_anomaly AS
    SELECT * FROM mv_trip_time
    WHERE avg_trip_time < (max_trip_time * 0.1);







-- Question 2..
-- Q2 Recreate the MV(s) in question 1, to also find the number of trips for the pair of taxi zones with the highest average trip time.
CREATE MATERIALIZED VIEW mv_trip_time_hightest_with_number AS
WITH with_trip_time as (
     SELECT *, EXTRACT(EPOCH FROM (tpep_dropoff_datetime - tpep_pickup_datetime)) / 60 as trip_time from trip_data
)
SELECT MIN(trip_time) min_trip_time, MAX(trip_time) max_trip_time, AVG(trip_time) avg_trip_time, pulocationid, dolocationid, COUNT(*) AS num_trips
FROM with_trip_time 
GROUP BY pulocationid, dolocationid;


WITH max_avg_trip_time AS (
    SELECT
        MAX(avg_trip_time) AS max_avg_trip_time_val
    FROM
        mv_trip_time_hightest_with_number
)

SELECT * FROM mv_trip_time_hightest_with_number, max_avg_trip_time
WHERE mv_trip_time_hightest_with_number.avg_trip_time = max_avg_trip_time.max_avg_trip_time_val;






-- Question 3
-- From the latest pickup time to 17 hours before, what are the top 3 busiest zones in terms of number of pickups? For example if the latest pickup time is 2020-01-01 17:00:00, then the query should return the top 3 busiest zones from 2020-01-01 00:00:00 to 2020-01-01 17:00:00.
WITH latest_pickup_time AS (
    SELECT MAX(tpep_pickup_datetime) AS latest_time
    FROM trip_data
),
-- Calculate the start time 17 hours before the latest pickup time
start_time AS (
    SELECT (latest_time - INTERVAL '17 hour') AS start_time, latest_time
    FROM latest_pickup_time
),
num_pickups_query as (
-- Query to find the top 3 busiest zones within the specified time range
SELECT pulocationid, dolocationid, COUNT(*) AS num_pickups
FROM trip_data, start_time
WHERE tpep_pickup_datetime >= start_time AND tpep_dropoff_datetime <= latest_time
GROUP BY pulocationid, dolocationid
ORDER BY num_pickups DESC
LIMIT 3
)

SELECT *, p_tz.Zone, do_tz.Zone 
FROM num_pickups_query
JOIN taxi_zone p_tz
    ON pulocationid = p_tz.location_id
JOIN taxi_zone do_tz
    ON dolocationid = do_tz.location_id;