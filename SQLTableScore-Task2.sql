
WITH filtered_stops AS (
	SELECT sa2_boundaries.sa2_code21 AS sa2_code, COUNT(*) AS stops_total FROM sa2_boundaries 
	JOIN stops
	ON ST_Contains(sa2_boundaries.geom, stops.geom)
	GROUP BY sa2_code21
),
	
filtered_businesses AS (
	SELECT a.sa2_code, a.sa2_name, a.total_businesses AS retail_total_businesses, b.total_businesses as health_total_businesses
	FROM businesses a, businesses b
	WHERE a.sa2_code = b.sa2_code
	AND a.industry_name = 'Health Care and Social Assistance' AND b.industry_name = 'Retail Trade'
), 

filtered_pol AS (
	SELECT sa2_code21, count(*) AS polling_total FROM sa2_boundaries 
	JOIN polling
	ON ST_Contains(sa2_boundaries.geom, polling.geom)
	GROUP BY sa2_code21
), 
	
filtered_primary AS ( 
	select sa2_code21, COUNT(catchments_primary.use_id) AS primary_catchments FROM sa2_boundaries 
	join catchments_primary
	on ST_intersects(sa2_boundaries.geom, catchments_primary.geom)
	group by sa2_code21
), 

filtered_secondary AS (
	SELECT sa2_code21, COUNT(*) AS secondary_catchments FROM sa2_boundaries 
	JOIN catchments_secondary
	ON ST_Intersects(sa2_boundaries.geom, catchments_secondary.geom)
	GROUP BY sa2_code21
), 

filtered_future AS (
	SELECT sa2_code21, COUNT(*) AS future_catchments FROM sa2_boundaries 
	JOIN catchments_future
	ON ST_intersects(sa2_boundaries.geom, catchments_future.geom)
	GROUP BY sa2_code21
),

filtered_toilets AS (
	SELECT sa2_code21, COUNT(*) AS toilet_total FROM sa2_boundaries 
	JOIN toilets
	ON ST_contains(sa2_boundaries.geom, toilets.geom)
	GROUP BY sa2_code21

),

filtered_unemployment AS (
	SELECT population.sa2_code, 
	population.sa2_name, 
	per_unempl, 
	ROUND(1000 - ((per_unempl / 100) * 1000)) as employment_rate_per_1000,
	(total_people - "0-4_people" - "5-9_people" - "10-14_people") AS adult_population, 
	ROUND(((total_people - "0-4_people" - "5-9_people" - "10-14_people") - ((per_unempl / 100) * (total_people - "0-4_people" - "5-9_people" - "10-14_people")))) AS total_employed 
	FROM  population
	join unemployment
	ON population.sa2_code = unemployment.sa2_code
),

filtered_traffic as (
	SELECT sa2_code21, sa2_name21, COUNT(*) AS traffic_camera_count FROM sa2_boundaries 
	JOIN traffic
	ON ST_intersects(sa2_boundaries.geom, traffic.geom)
	GROUP BY sa2_code21, sa2_name21
)


SELECT 
	sa2_boundaries.sa2_code21, 
	stops_total, 
	retail_total_businesses, 
	health_total_businesses, 
	polling_total, 
	primary_catchments, 
	secondary_catchments, 
	future_catchments, 
	(COALESCE(stops_total, 0) + COALESCE(retail_total_businesses, 0) + COALESCE(health_total_businesses, 0) + COALESCE(polling_total, 0) + COALESCE(primary_catchments, 0) + COALESCE(secondary_catchments, 0) + COALESCE(future_catchments, 0)) AS x_val
FROM sa2_boundaries
LEFT JOIN filtered_stops
ON sa2_boundaries.sa2_code21 = filtered_stops.sa2_code
LEFT JOIN filtered_businesses 
ON sa2_boundaries.sa2_code21 = filtered_businesses.sa2_code
LEFT JOIN filtered_pol 
ON sa2_boundaries.sa2_code21 = filtered_pol.sa2_code21
LEFT JOIN filtered_primary 
ON sa2_boundaries.sa2_code21 = filtered_primary.sa2_code21
LEFT JOIN filtered_secondary
ON sa2_boundaries.sa2_code21 = filtered_secondary.sa2_code21
LEFT JOIN filtered_future
ON sa2_boundaries.sa2_code21 = filtered_future.sa2_code21

