{{
  config(
    materialized = 'table'
    )
}}
select ticket_no, flight_id, fare_conditions, amount from
 {{ ref('staging_flights__ticket_flights') }}
