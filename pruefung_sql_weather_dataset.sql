create database if not exists weather;

use weather;

drop function if exists get_correlation_category;
drop function if exists get_uv_risk;

delimiter //

create function get_correlation_category(value decimal(3, 2))
returns varchar(20)
deterministic
begin 
    if abs(value) >= 0.5 then
        return 'strong correlation';
    elseif abs(value) >= 0.3 then
        return 'medium correlation';
    elseif abs(value) >= 0.1 then
        return 'small correlation';
    else
        return 'no significant correlation';
    end if;
end //

create function get_uv_risk(value integer)
returns varchar(30)
deterministic
begin
	if value >= 11 then
		return 'extreme risk';
	elseif value between 8 and 10 then 
		return 'very high risk';
	elseif value between 6 and 7 then 
		return 'high risk';
	elseif value between 3 and 5 then 
		return 'medium risk';
	elseif value between 1 and 2 then 
		return 'low risk';
	else 
		return 'no risk';
	end if; 
end //

delimiter ;

select gwr.country, gwr.timezone from GlobalWeatherRepository gwr
group by gwr.country, gwr.timezone
order by gwr.timezone, gwr.country;

-- average weather conditions by timezones and countries 2025
create or replace view v_grouped_timezones as 
select gwr.country, 
gwr.timezone, 
round(avg(gwr.temperature_celsius), 2) as avg_temperature_celsius,
round(avg(gwr.wind_kph)) as avg_wind_kph,
round(avg(gwr.gust_kph)) as avg_gusts_kph,
round(avg(gwr.pressure_mb), 1) as avg_pressure_millibars,
round(avg(gwr.humidity), 2) as avg_percentage_humidity,
round(avg(gwr.visibility_km)) as avg_visibility_km,
round(avg(gwr.cloud), 2) as avg_percentage_cloud_cover,
round(avg(gwr.feels_like_celsius), 2) as avg_feels_like_celsios,
round(avg(gwr.uv_index), 1) as avg_uv_index
from GlobalWeatherRepository gwr
where extract(year from gwr.last_updated) = 2025
group by gwr.country, gwr.timezone
order by 
case 
	when gwr.timezone like '%europe%' then 0
	else 1
end, gwr.country, gwr.timezone;

-- get the 10 hottest places in european timezone 2025
select vgt.country, 
round(avg(vgt.avg_temperature_celsius), 2) as avg_temperature_celsius,
dense_rank() over(order by avg(vgt.avg_temperature_celsius) desc) as `ranking`
from v_grouped_timezones vgt
where vgt.timezone like '%europe%'
group by vgt.country
order by `ranking`, vgt.country
limit 10;

-- get the 10 coldest places in european timezone 2025
select vgt.country, 
round(avg(vgt.avg_temperature_celsius), 2) as avg_temperature_celsius,
dense_rank() over(order by avg(vgt.avg_temperature_celsius)) as `ranking`
from v_grouped_timezones vgt 
where vgt.timezone like '%europe%'
group by vgt.country
order by `ranking`, vgt.country
limit 10;

-- get the 5 highest temperatures ever in 2025
select gwr.temperature_celsius as max_temperature_celsius,
gwr.location_name,
gwr.country,
gwr.last_updated
from GlobalWeatherRepository gwr
where extract(year from gwr.last_updated) = 2025
order by gwr.temperature_celsius desc 
limit 5;

-- get the 5 lowest temperatures ever in 2025
select gwr.temperature_celsius as max_temperature_celsius,
gwr.location_name,
gwr.country,
gwr.last_updated
from GlobalWeatherRepository gwr
where extract(year from gwr.last_updated) = 2025
order by gwr.temperature_celsius 
limit 5;

-- get strongest wind gust ever in 2025
select gwr.gust_kph as max_gusts_kph,
gwr.wind_kph,
gwr.location_name,
gwr.country,
gwr.last_updated
from GlobalWeatherRepository gwr 
where extract(year from gwr.last_updated) = 2025
order by gwr.gust_kph desc 
limit 1;

-- get lowest wind gust ever in 2025
select gwr.gust_kph as max_gusts_kph,
gwr.wind_kph,
gwr.location_name,
gwr.country,
gwr.last_updated
from GlobalWeatherRepository gwr 
where extract(year from gwr.last_updated) = 2025
order by gwr.gust_kph 
limit 1;

-- get the 10 locations with the most bad monthly average for air quality of carbon monoxide ever in 2025
select round(avg(gwr.air_quality_carbon_monoxide), 2) as avg_air_quality_carbon_monoxide,
gwr.location_name,
gwr.country,
extract(month from gwr.last_updated) as `month`
from GlobalWeatherRepository gwr 
where extract(year from gwr.last_updated) = 2025
group by gwr.location_name, gwr.country, extract(month from gwr.last_updated)
order by avg_air_quality_carbon_monoxide desc 
limit 10;

-- get the 10 locations with the smallest monthly average for air quality of carbon monoxide ever in 2025
select round(avg(gwr.air_quality_carbon_monoxide), 2) as avg_air_quality_carbon_monoxide,
gwr.location_name,
gwr.country,
extract(month from gwr.last_updated) as `month`
from GlobalWeatherRepository gwr 
where extract(year from gwr.last_updated) = 2025
group by gwr.location_name, gwr.country, extract(month from gwr.last_updated)
order by avg_air_quality_carbon_monoxide
limit 10;

-- calculate correlation between visibility in km and percentual humidity
select 
round((avg(gwr.visibility_km * gwr.humidity) - avg(gwr.visibility_km) * avg(gwr.humidity)) /
(stddev_pop(gwr.visibility_km) * stddev_pop(gwr.humidity)), 2) as c_visibility_km_VS_humidity
from GlobalWeatherRepository gwr into @corr_visibility_VS_humidity;

select @corr_visibility_VS_humidity as `Correlation value between visibility in km and humidity in percent`,
get_correlation_category(@corr_visibility_VS_humidity) as `Correlation category`;

-- calculate correlation between temperature in celsius and percentual humidity
select 
round((avg(gwr.temperature_celsius * gwr.humidity) - avg(gwr.temperature_celsius) * avg(gwr.humidity)) /
(stddev_pop(gwr.temperature_celsius) * stddev_pop(gwr.humidity)), 2) as c_temperature_celsius_VS_humidity 
from GlobalWeatherRepository gwr into @corr_temperature_VS_humidity;

select @corr_temperature_VS_humidity as `Correlation value between temperature in celsius and humidity in percent`,
get_correlation_category(@corr_temperature_VS_humidity) as `Correlation category`;

-- calculate correlation between feeled temperature in celsius and percentual humidity
select 
round((avg(gwr.feels_like_celsius * gwr.humidity) - avg(gwr.feels_like_celsius) * avg(gwr.humidity)) /
(stddev_pop(gwr.feels_like_celsius) * stddev_pop(gwr.humidity)), 2) as c_feels_like_celsius_VS_humidity 
from GlobalWeatherRepository gwr into @corr_feeled_temp_VS_humidity;

select @corr_feeled_temp_VS_humidity as `Correlation value between feeled temperature in celsius and humidity in percent`,
get_correlation_category(@corr_feeled_temp_VS_humidity) as `Correlation category`;

-- calculate correlation between air quality ozone and uv index
select 
round((avg(gwr.air_quality_Ozone * gwr.uv_index) - avg(gwr.air_quality_Ozone) * avg(gwr.uv_index)) /
(stddev_pop(gwr.air_quality_Ozone) * stddev_pop(gwr.uv_index)), 2) as c_ozone_VS_uv_index
from GlobalWeatherRepository gwr into @corr_ozone_VS_uv_index;

select @corr_ozone_VS_uv_index as `Correlation value between ozone and uv index`,
get_correlation_category(@corr_ozone_VS_uv_index) as `Correlation category`;

-- highest uv index ever in 2025
select max(gwr.uv_index) as max_uv_index,
gwr.location_name,
gwr.country
from GlobalWeatherRepository gwr
where extract(year from gwr.last_updated) = 2025
group by gwr.location_name, gwr.country
order by max(gwr.uv_index) desc
limit 1;

-- get percentual wind direction in Berlin 2025
-- expected: west should have the heighest value as it is known as the common weather direction
alter table GlobalWeatherRepository add column wind_direction_group varchar(8) after wind_direction;

update GlobalWeatherRepository
set wind_direction_group = 
case 
    -- North: 348.75° to 360° and 0° bis 11.25°
    when wind_degree >= 348.75 or wind_degree <= 11.25 then 'North'
    -- East: 78.75° to 101.25°
    when wind_degree between 78.75 and 101.25 then 'East'
    -- South: 168.75° to 191.25°
    when wind_degree between 168.75 and 191.25 then 'South'
    -- West: 258.75° to 281.25°
    when wind_degree between 258.75 and 281.25 then 'West'
    else null
end;

with wind_counts as (
    select 
        wind_direction_group,
        count(*) as count_per_type
    from GlobalWeatherRepository
    where location_name = 'Berlin'
    and extract(year from last_updated) = 2025
    and wind_direction_group is not null
    group by wind_direction_group
),
total_count as (
    select sum(count_per_type) as total_rows
    from wind_counts
)
select 
    wc.wind_direction_group,
    wc.count_per_type,
    round((wc.count_per_type * 100.0 / tc.total_rows), 2) as percentage
from wind_counts wc
cross join total_count tc
order by wc.count_per_type desc;

-- get count and percentage of risk level for uv index in Berlin 2025
with tb_risk_level as (
	select round(gwr.uv_index) as uv_index_rounded, 
	count(get_uv_risk(round(gwr.uv_index))) as ct_uv_risk_level,
	get_uv_risk(round(gwr.uv_index)) as uv_risk_level
	from GlobalWeatherRepository gwr 
	where gwr.location_name = 'Berlin' 
	and extract(year from gwr.last_updated) = 2025
	group by uv_index_rounded, gwr.uv_index, uv_risk_level
	order by 
	case
		when round(gwr.uv_index) >= 11 then 0
		when round(gwr.uv_index) between 8 and 10 then 1
		when round(gwr.uv_index) between 6 and 7 then 2
		when round(gwr.uv_index) between 3 and 5 then 3
		when round(gwr.uv_index) between 1 and 2 then 4
		else 5
	end
), tb_uv_risk_level_count as (
select rl.uv_index_rounded as uv_index_rounded,
	sum(rl.ct_uv_risk_level) as ct_uv_risk_level,
	rl.uv_risk_level as uv_risk_level
	from tb_risk_level rl
	group by rl.uv_index_rounded, rl.uv_risk_level
)
select sum(urlc.ct_uv_risk_level) as sum_uv_risk_level,
urlc.uv_risk_level, 
round(sum(urlc.ct_uv_risk_level) * 100 / 365, 2) as percentual_uv_risk_level
from tb_uv_risk_level_count urlc
group by urlc.uv_risk_level;