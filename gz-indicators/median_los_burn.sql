WITH cte_first_consultation AS (
	SELECT 
		DISTINCT ON (patient_program_id) patient_program_id,
		location_name,
		admission_status
	FROM first_consultation fc
	ORDER BY patient_program_id, date_created DESC),
cte_cohort AS (
	SELECT 
		ppdd.patient_id,
		ppdd.patient_program_id,
		ppdd.age_during_enrollment,
		CASE 
			WHEN ppdd.age_during_enrollment::int <5 THEN '<5'
			WHEN ppdd.age_during_enrollment::int >=5 AND ppdd.age_during_enrollment::int <15 THEN '5-15'
			WHEN ppdd.age_during_enrollment::int >=15 AND ppdd.age_during_enrollment::int <45 THEN '15-45'
			WHEN ppdd.age_during_enrollment::int >=45 THEN '>45'
			ELSE NULL 
		END AS age_group_during_enrollment,
		CASE 
			WHEN pdd.gender = 'M' THEN 'Male'
			WHEN pdd.gender = 'F' THEN 'Female'
			ELSE NULL 
		END AS sex,
		CASE 
			WHEN ppdd.program_id = 1 THEN 'Trauma'
			WHEN ppdd.program_id = 2 THEN 'Burn'
		END AS program_name,
		ppdd.date_enrolled,
		ppdd.date_completed,
		ppdd.program_outcome,
		abs(ppdd.date_completed::date - ppdd.date_enrolled::date) AS los_days,
		cfc.location_name
	FROM patient_program_data_default ppdd 
	LEFT OUTER JOIN person_details_default pdd 
		ON ppdd.patient_id = pdd.person_id
	LEFT OUTER JOIN cte_first_consultation cfc 
		ON ppdd.patient_program_id = cfc.patient_program_id
	WHERE ppdd.voided = 'false' AND ppdd.program_id = 2 AND ppdd.date_completed IS NOT NULL)
SELECT 
	DATE_TRUNC('Month', cc.date_completed) AS record_month,
	percentile_cont(0.5) WITHIN GROUP (ORDER BY cc.los_days) AS alos
FROM cte_cohort cc
WHERE cc.date_completed > date_trunc('month', CURRENT_DATE) - INTERVAL '1 year'
GROUP BY DATE_TRUNC('Month', cc.date_completed)