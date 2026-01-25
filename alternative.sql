create database if not exists bank;

use bank;

select min(person_age), max(person_age) from credit_risk_dataset;

select person_age, person_home_ownership, loan_intent from credit_risk_dataset
order by person_age desc;

/* 
 * unrealistic values found for person_age
 * 3x 144 years old; 2x 123 years old
 */

create or replace view filtered_dataset as 
select * from credit_risk_dataset 
where person_age < 123;

select cb_person_cred_hist_length from filtered_dataset
order by cb_person_cred_hist_length desc;

select cb_person_default_on_file from filtered_dataset
group by cb_person_default_on_file;

select loan_status from filtered_dataset
where loan_status is null;

select loan_amnt from filtered_dataset 
order by loan_amnt desc
limit 5;

select loan_amnt from filtered_dataset 
order by loan_amnt
limit 5;

select person_income, person_age from filtered_dataset 
order by person_income desc
limit 10;

select person_home_ownership, count(person_home_ownership) from filtered_dataset
group by person_home_ownership 
order by person_home_ownership;

select * from filtered_dataset 
where person_home_ownership = 'other';

select cb_person_cred_hist_length from filtered_dataset
order by cb_person_cred_hist_length desc;

select loan_percent_income from filtered_dataset
order by loan_percent_income desc 
limit 5;

select loan_percent_income from filtered_dataset 
order by loan_percent_income 
limit 5;

/* 
 * found loan_percent_income with value 0
 */

select person_age, person_home_ownership, loan_amnt, loan_percent_income from filtered_dataset  
where loan_percent_income = 0
order by person_age desc;

/* 
 * high risk: person_emp_length = 0 to 6
 * medium risk: person_emp_length = 7 to 12
 * low risk: person_emp_length = > 12
 * 
 * high risk: cb_person_cred_hist_length = 19 to 30
 * medium risk: cb_person_cred_hist_length = 7 to 18
 * low risk: cb_person_cred_hist_length = < 7
 * 
 * high risk: loan_int_rate is null -> why do we have these values in the database?
 * 
 * high risk: loan_status = 0
 * low risk: loan_status = 1
 */
