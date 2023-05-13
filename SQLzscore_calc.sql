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
	"per_unempl", 
	(100 - per_unempl) as employment_percentage,
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
),


zscore_stops AS (
SELECT sa2_code, 
	stops_total,
	(stops_total - (select avg(stops_total) from filtered_stops) / (select stddev(stops_total) from filtered_stops) ) as z_score_stops
FROM filtered_stops
), 

zscore_businesses AS (
SELECT sa2_code, 
	retail_total_businesses,
	(retail_total_businesses - (select avg(retail_total_businesses) from filtered_businesses) / (select stddev(retail_total_businesses) from filtered_businesses) ) as z_score_retail, 
	health_total_businesses,
	(health_total_businesses - (select avg(health_total_businesses) from filtered_businesses) / (select stddev(health_total_businesses) from filtered_businesses) ) as z_score_health 
FROM filtered_businesses
),

zscore_pol AS (
SELECT sa2_code21, 
	polling_total,
	(polling_total - (select avg(polling_total) from filtered_pol) / (select stddev(polling_total) from filtered_pol) ) as z_score_pol
FROM filtered_pol
), 

zscore_primary AS (
SELECT sa2_code21, 
	primary_catchments,
	(primary_catchments - (select avg(primary_catchments) from filtered_primary) / (select stddev(primary_catchments) from filtered_primary) ) as z_score_primary
FROM filtered_primary
),

zscore_secondary AS (
SELECT sa2_code21, 
	secondary_catchments,
	(secondary_catchments - (select avg(secondary_catchments) from filtered_secondary) / (select stddev(secondary_catchments) from filtered_secondary) ) as z_score_secondary
FROM filtered_secondary
), 

zscore_future AS (
SELECT sa2_code21, 
	future_catchments,
	(future_catchments - (select avg(future_catchments) from filtered_future) / (select stddev(future_catchments) from filtered_future) ) as z_score_future
FROM filtered_future
), 

zscore_toilets AS (
SELECT sa2_code21, 
	toilet_total,
	(toilet_total - (select avg(toilet_total) from filtered_toilets) / (select stddev(toilet_total) from filtered_toilets) ) as z_score_toilets
FROM filtered_toilets
), 

zscore_employment AS (
SELECT sa2_code, 
	employment_percentage,
	(employment_percentage - (select avg(employment_percentage) from filtered_unemployment) / (select stddev(employment_percentage) from filtered_unemployment) ) as z_score_employment
FROM filtered_unemployment
),

zscore_traffic AS (
SELECT sa2_code21, 
	traffic_camera_count,
	(traffic_camera_count - (select avg(traffic_camera_count) from filtered_traffic) / (select stddev(traffic_camera_count) from filtered_traffic) ) as z_score_traffic
FROM filtered_traffic
) 



SELECT 
	sa2_boundaries.sa2_code21, 
	stops_total, 
	z_score_stops,
	retail_total_businesses,
	z_score_retail,
	health_total_businesses, 
	z_score_health,
	polling_total,
	z_score_pol,
	primary_catchments, 
	z_score_primary,
	secondary_catchments, 
	z_score_secondary,
	future_catchments, 
	z_score_future
	--(COALESCE(stops_total, 0) + COALESCE(retail_total_businesses, 0) + COALESCE(health_total_businesses, 0) + COALESCE(polling_total, 0) + COALESCE(primary_catchments, 0) + COALESCE(secondary_catchments, 0) + COALESCE(future_catchments, 0)) AS x_val
FROM sa2_boundaries
LEFT JOIN zscore_stops
ON sa2_boundaries.sa2_code21 = zscore_stops.sa2_code
LEFT JOIN zscore_businesses 
ON sa2_boundaries.sa2_code21 = zscore_businesses.sa2_code
LEFT JOIN zscore_pol 
ON sa2_boundaries.sa2_code21 = zscore_pol.sa2_code21
LEFT JOIN zscore_primary 
ON sa2_boundaries.sa2_code21 = zscore_primary.sa2_code21
LEFT JOIN zscore_secondary
ON sa2_boundaries.sa2_code21 = zscore_secondary.sa2_code21
LEFT JOIN zscore_future
ON sa2_boundaries.sa2_code21 = zscore_future.sa2_code21




/*

select sa2_code21, 
	traffic_camera_count,
	(traffic_camera_count - zscore_traffic.traffic_cam_avg) / zscore_traffic.traffic_cam_sd as z_score_polling
from filtered_traffic, zscore_traffic
order by traffic_camera_count


*/