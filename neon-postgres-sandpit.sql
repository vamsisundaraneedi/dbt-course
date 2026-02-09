SELECT * FROM demo_dw.fact_sales;
SELECT * FROM demo_dw.dim_date;
SELECT min(full_date), max(full_date) FROM demo_dw.dim_date;
SELECT * FROM demo_dw.dim_product;
SELECT * FROM demo_dw.dim_customer;
SELECT distinct customer_id, customer_nk FROM demo_dw.dim_customer order by customer_id DESC;
SELECT min(created_at), max(created_at) FROM demo_dw.dim_customer;

select * from demo_dw.fact_sales where customer_id not in (select customer_id from demo_dw.dim_customer);
select * from demo_dw.fact_sales where product_id not in (select product_id from demo_dw.dim_product);
SELECT distinct category,brand FROM demo_dw.dim_product;
SELECT * FROM demo_dw.dim_customer;
SELECT customer_id, customer_nk, first_name, last_name, email, state, segment FROM demo_dw.dim_customer;
SELECT product_id, product_nk, product_name, category, brand, base_price, is_active FROM demo_dw.dim_product;
select * from demo_dw.fact_sales;
select distinct created_at from demo_dw.fact_sales order by created_at desc;
select count(*) from demo_dw.fact_sales;


select * from new_dw.src_customer;
select * from new_dw.src_product;
select * From new_dw.src_sales;

select * from new_dw.dim_customer;
select * from new_dw.dim_product;
select * from new_dw.fact_sales;

select count(*) from new_dw.fact_sales as f inner join demo_dw.dim_date as d on f.date_id = d.date_id;
select count(*) from new_dw.fact_sales;
select distinct created_at, fact_created_at from new_dw.fact_sales order by created_at desc;

SELECT * FROM demo_dw.dim_customer LIMIT 100;
SELECT * FROM demo_dw.dim_customer where customer_id = 1;
update demo_dw.dim_customer
set state = 'NY', created_at = now() where customer_id = 1;
SELECT distinct customer_id, customer_nk FROM demo_dw.dim_customer order by customer_id DESC;
SELECT customer_id, count(*) FROM demo_dw.dim_customer GROUP BY customer_id having count(*)>1;
SELECT min(customer_id), max(customer_id) FROM demo_dw.dim_customer;
SELECT min(created_at), max(created_at) FROM demo_dw.dim_customer;


select * from new_dw.src_cdc_customer;
select * from new_dw.src_cdc_customer where customer_id = 1;
select * from new_dw.src_cdc_customer where dbt_valid_to is not null;

