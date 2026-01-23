create database if not exists weather;

use weather;

select gwr.country, gwr.timezone from GlobalWeatherRepository gwr
group by gwr.country, gwr.timezone
order by gwr.timezone, gwr.country;

-- average weather conditions by timezones and countries 2025
create or replace view v_grouped_timezones as 
select gwr.country, 
gwr.timezone, 
round(avg(gwr.temperature_celsius), 2) as avg_temperature_celsius, 
gwr.wind_direction,
round(avg(gwr.gust_kph)) as avg_gusts_kph,
round(avg(gwr.pressure_mb), 1) as avg_pressure_millibars,
round(avg(gwr.humidity), 2) as avg_percentage_humidity,
round(avg(gwr.visibility_km)) as avg_visibility_km,
round(avg(gwr.cloud), 2) as avg_percentage_cloud_cover,
round(avg(gwr.feels_like_celsius), 2) as avg_feels_like_celsios,
round(avg(gwr.uv_index), 1) as avg_uv_index
from GlobalWeatherRepository gwr
where extract(year from gwr.last_updated) = 2025
group by gwr.country, gwr.timezone, gwr.wind_direction
order by 
case 
	when gwr.timezone like '%europe%' then 0
	else 1
end, gwr.timezone, gwr.country;

-- get the 10 hottest places in european timezones 2025
select vgt.country, 
round(avg(vgt.avg_temperature_celsius), 2) as avg_temperature_celsius,
dense_rank() over(order by avg(vgt.avg_temperature_celsius) desc) as `ranking`
from v_grouped_timezones vgt
where vgt.timezone like '%europe%'
group by vgt.country
order by `ranking`, vgt.country
limit 10;

-- get the 10 coldest places in european timezones 2025
select vgt.country, 
round(avg(vgt.avg_temperature_celsius), 2) as avg_temperature_celsius,
dense_rank() over(order by avg(vgt.avg_temperature_celsius)) as `ranking`
from v_grouped_timezones vgt 
where vgt.timezone like '%europe%'
group by vgt.country
order by `ranking`, vgt.country
limit 10;