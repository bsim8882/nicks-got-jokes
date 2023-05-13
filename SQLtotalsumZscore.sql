WITH filtered_stops AS (
	SELECT sa2_boundaries.sa2_code21 AS sa2_code, COUNT(*) AS stops_total FROM sa2_boundaries 
	JOIN stops
	ON ST_Contains(sa2_boundaries.geom, stops.geom)
	GROUP BY sa2_code21
),

filtered_businesses AS (
	SELECT a.sa2_code, 
		a.sa2_name, 
		a.total_businesses AS retail_total_businesses, 
		b.total_businesses as health_total_businesses, total_people, 
		(cast(b.total_businesses as float) / total_people) * 1000 as health_businesses_per_1000, 
		(cast(a.total_businesses as float) / total_people) * 1000 as retail_businesses_per_1000 
	FROM businesses a, businesses b, population
	WHERE a.sa2_code = b.sa2_code and b.sa2_code = population.sa2_code
	AND a.industry_name = 'Health Care and Social Assistance' AND b.industry_name = 'Retail Trade'
	and total_people >= 100
), 

filtered_pol AS (
	SELECT sa2_code21, count(*) AS polling_total FROM sa2_boundaries 
	JOIN polling
	ON ST_Contains(sa2_boundaries.geom, polling.geom)
	GROUP BY sa2_code21
), 
	
filtered_primary AS ( 
	select sa2_code21, 
		COUNT(catchments_primary.use_id) AS primary_catchments
	FROM sa2_boundaries 
	join catchments_primary
	on ST_intersects(sa2_boundaries.geom, catchments_primary.geom)
	group by sa2_code21
), 

primary_reduced_population as (
select sa2_code,
	(cast(primary_catchments as float)/("0-4_people" + "5-9_people" + "10-14_people" + "15-19_people") ) * 1000 as primary_per_1000
	from filtered_primary
	join population 
	on filtered_primary.sa2_code21 = population.sa2_code
	where total_people >= 100	
),

filtered_secondary AS (
	SELECT sa2_code21, COUNT(*) AS secondary_catchments FROM sa2_boundaries 
	JOIN catchments_secondary
	ON ST_Intersects(sa2_boundaries.geom, catchments_secondary.geom)
	GROUP BY sa2_code21
), 

secondary_reduced_population as (
select sa2_code,
	(cast(secondary_catchments as float)/("0-4_people" + "5-9_people" + "10-14_people" + "15-19_people") ) * 1000 as secondary_per_1000
	from filtered_secondary
	join population 
	on filtered_secondary.sa2_code21 = population.sa2_code
	where total_people >= 100	
),

filtered_future AS (
	SELECT sa2_code21, COUNT(*) AS future_catchments FROM sa2_boundaries 
	JOIN catchments_future
	ON ST_intersects(sa2_boundaries.geom, catchments_future.geom)
	GROUP BY sa2_code21
),

future_reduced_population as (
select sa2_code,
	(cast(future_catchments as float)/("0-4_people" + "5-9_people" + "10-14_people" + "15-19_people") ) * 1000 as future_per_1000
	from filtered_future
	join population 
	on filtered_future.sa2_code21 = population.sa2_code
	where total_people >= 100	
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
	where total_people >= 100
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
	(stops_total - (select avg(stops_total) from filtered_stops)) / (select stddev(stops_total) from filtered_stops) as z_score_stops
FROM filtered_stops
), 

zscore_businesses AS (
SELECT sa2_code, 
	retail_total_businesses, 
	(retail_businesses_per_1000 - (select avg(retail_businesses_per_1000) from filtered_businesses)) / (select stddev(retail_businesses_per_1000) from filtered_businesses) as z_score_retail, 
	health_total_businesses,
	(health_businesses_per_1000 - (select avg(health_businesses_per_1000) from filtered_businesses)) / (select stddev(health_businesses_per_1000) from filtered_businesses) as z_score_health 
FROM filtered_businesses
),

zscore_pol AS (
SELECT sa2_code21, 
	polling_total,
	(polling_total - (select avg(polling_total) from filtered_pol)) / (select stddev(polling_total) from filtered_pol) as z_score_pol
FROM filtered_pol
), 

zscore_primary AS (
SELECT sa2_code, 
	primary_per_1000,
	(primary_per_1000 - (select avg(primary_per_1000) from primary_reduced_population)) / (select stddev(primary_per_1000) from primary_reduced_population) as z_score_primary
FROM primary_reduced_population
),

zscore_secondary AS (
SELECT sa2_code, 
	secondary_per_1000,
	(secondary_per_1000 - (select avg(secondary_per_1000) from secondary_reduced_population)) / (select stddev(secondary_per_1000) from secondary_reduced_population) as z_score_secondary
FROM secondary_reduced_population
),

zscore_future AS (
SELECT sa2_code, 
	future_per_1000,
	(future_per_1000 - (select avg(future_per_1000) from future_reduced_population)) / (select stddev(future_per_1000) from future_reduced_population) as z_score_future
FROM future_reduced_population
),

zscore_toilets AS (
SELECT sa2_code21, 
	toilet_total,
	(toilet_total - (select avg(toilet_total) from filtered_toilets)) / (select stddev(toilet_total) from filtered_toilets) as z_score_toilets
FROM filtered_toilets
), 

zscore_employment AS (
SELECT sa2_code, 
	employment_percentage,
	(employment_percentage - (select avg(employment_percentage) from filtered_unemployment)) / (select stddev(employment_percentage) from filtered_unemployment) as z_score_employment
FROM filtered_unemployment
),

zscore_traffic AS (
SELECT sa2_code21, 
	traffic_camera_count,
	(traffic_camera_count - (select avg(traffic_camera_count) from filtered_traffic)) / (select stddev(traffic_camera_count) from filtered_traffic) as z_score_traffic
FROM filtered_traffic
), 


total_zscore as ( 
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
		primary_per_1000, 
		z_score_primary,
		secondary_per_1000, 
		z_score_secondary,
		future_per_1000, 
		z_score_future,
		(COALESCE(z_score_stops, 0) + COALESCE(z_score_retail, 0) + COALESCE(z_score_health, 0) + COALESCE(z_score_pol, 0) + COALESCE(z_score_primary, 0) + COALESCE(z_score_secondary, 0) + COALESCE(z_score_future, 0)) AS x_val
	FROM sa2_boundaries
	LEFT JOIN zscore_stops
	ON sa2_boundaries.sa2_code21 = zscore_stops.sa2_code
	LEFT JOIN zscore_businesses 
	ON sa2_boundaries.sa2_code21 = zscore_businesses.sa2_code
	LEFT JOIN zscore_pol 
	ON sa2_boundaries.sa2_code21 = zscore_pol.sa2_code21
	LEFT JOIN zscore_primary 
	ON sa2_boundaries.sa2_code21 = zscore_primary.sa2_code
	LEFT JOIN zscore_secondary
	ON sa2_boundaries.sa2_code21 = zscore_secondary.sa2_code
	LEFT JOIN zscore_future
	ON sa2_boundaries.sa2_code21 = zscore_future.sa2_code
)

select * from total_zscore



/*
SELECT sa2_code, 
	retail_total_businesses,
	(retail_total_businesses - (select avg(retail_total_businesses) from filtered_businesses) / (select stddev(retail_total_businesses) from filtered_businesses) ) as z_score_retail, 
	health_total_businesses,
	(health_businesses_per_1000 - (select avg(health_businesses_per_1000) from filtered_businesses) / (select stddev(health_businesses_per_1000) from filtered_businesses) ) as z_score_health 
FROM filtered_businesses
*/


/*
SELECT population.sa2_code, 
	population.sa2_name, 
	total_people,
	total_businesses
	FROM  population
	join businesses
	ON population.sa2_code = businesses.sa2_code
	where industry_name = 'Health Care and Social Assistance'
	order by total_people desc
*/