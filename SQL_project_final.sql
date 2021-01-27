
CREATE TABLE t_valeria_listkova_projekt_SQL_final 
SELECT
/*vytvoreni tabulky obsahujici promenne date, country, confirmed, test_performed*/
	cbdiff.date,
	cbdiff.country,
	cbdiff.confirmed,
	ctests.tests_performed,
/*přidání dalších proměnných - viz níže*/
	rel.total_population,
	countr.iso3,
	countr.population_density,
	countr.median_age_2018,
	econom.GDP,
	econom.gini,
	econom.mortaliy_under5,
	relig.religion,
	relig.share_of_religions,
	lifeexp.life_exp_diff,
	weat.avg_temp,
	hours.hours,
	wind.max_wind,
/*vytvoření proměnných weekdays/weekends a season*/
	CASE WHEN DAYOFWEEK(cbdiff.date) > 1 AND DAYOFWEEK(cbdiff.date) < 7 THEN 1
			ELSE 0 END AS 'weekdays/weekends',
	CASE WHEN MONTH(cbdiff.date) > 3 AND MONTH(cbdiff.date) < 5 THEN 0
		 WHEN MONTH(cbdiff.date) > 6 AND MONTH(cbdiff.date) < 8 THEN 1
		 WHEN MONTH(cbdiff.date) > 9 AND MONTH(cbdiff.date) < 11 THEN 2
			ELSE 3 END AS 'season'
FROM covid19_basic_differences cbdiff 
/*přioijení proměnné test_performed*/
JOIN covid19_tests AS ctests 
	ON cbdiff.country = ctests.country 
	AND cbdiff.date = ctests.date
/*přioijení proměnné total_population*/
JOIN (SELECT
			country,
			SUM(population) AS 'total_population'
		FROM religions rel 
		WHERE `year` = 2020
		GROUP BY country) rel
	ON cbdiff.country = rel.country
/*přioijení proměnné iso3, population_density, median_age*/
JOIN countries AS countr
	ON cbdiff.country = countr.country
/*připojení proměnné iso3, population_density, median_age*/
JOIN (SELECT 
			country,
			GDP,
			gini,
			mortaliy_under5
		FROM economies e 
		WHERE `year` = 2018) econom
	ON cbdiff.country = econom.country
/*připojení proměnné iso3, religion, share_of_religion*/
LEFT JOIN (SELECT
				rel.country,
				rel.religion,
				rel.population,
				totpop.Total_population,
				ROUND((COALESCE(rel.population/ NULLIF(totpop.Total_population,0), 0))*100, 2) AS Share_of_religions
			FROM religions rel
			JOIN (SELECT
						*,
						SUM(population) AS 'Total_population'
					FROM religions rel 
					WHERE `year` = 2020
					GROUP BY country) totpop
			    ON rel.country = totpop.country
				AND rel.year = totpop.year) relig
	ON cbdiff.country = relig.country
/*připojení proměnné life_exp_diff*/
JOIN (WITH life_exp AS
		(SELECT
			*,
			LAG (life_expectancy) OVER (ORDER BY country) AS prev_life_exp,
			life_expectancy - LAG (life_expectancy) OVER (ORDER BY country) AS life_exp_diff
		FROM life_expectancy le
		WHERE `year` = 1965
			OR `year` = 2015)
		SELECT 
			*
		 FROM life_exp
         WHERE `year` = 2015) lifeexp
	ON cbdiff.country = lifeexp.country
/*připojení proměnné life_exp_diff*/
JOIN (WITH weather_tab AS 
		(SELECT 	
			coun.country,
			w.city,
			w.date,
			w.hour,
			w.temp,
			w.temp * 2 AS temp21_2,
			LAG (w.temp, 2) OVER (ORDER BY w.date) AS temp15,
			LAG (w.temp, 5) OVER (ORDER BY w.date) AS temp6,
			(w.temp * 2 + LAG (w.temp) OVER (ORDER BY w.date) + LAG (w.temp, 2) OVER (ORDER BY w.date)) / 4 AS avg_temp
		FROM weather w
		JOIN countries AS coun 
		ON w.city = coun.capital_city
		ORDER BY w.date, w.city)
	  SELECT 
			*
	  FROM t_val_listkova_weather 
      WHERE hour = 21) weat
	ON cbdiff.country = weat.country
/*připojení proměnné hours*/
JOIN (SELECT 	
		coun.country,
		lt.iso3,
		w.city,
		w.hour,
		w.date,
		w.rain,
		COUNT(hour) AS hours
	  FROM weather w
	  JOIN countries AS coun 
	  	ON w.city = coun.capital_city
      JOIN lookup_table AS lt 
		ON coun.country = lt.country
	  WHERE rain > 0
      GROUP BY coun.country, w.date
      ORDER BY w.date) hours
    ON countr.iso3 = hours.iso3
    	AND cbdiff.date = hours.date
/*připojení proměnné max.wind*/
JOIN (SELECT 	
		coun.country,
		lt.iso3,
		w.date,
		MAX(wind) AS max_wind
	  FROM weather w
      JOIN countries AS coun 
	  	ON w.city = coun.capital_city
 	  JOIN lookup_table AS lt 
		ON coun.country = lt.country
	  GROUP BY coun.country, w.date) wind
	ON countr.iso3 = wind.iso3
		AND cbdiff.date = wind.date
