select * from swiggy_data

-- Data validation & cleaning
-- Null check

select
     sum(case when State is null then 1 else 0 end) as null_State,
	 sum(case when City is null then 1 else 0 end) as null_City,
	 sum(case when Order_Date is null then 1 else 0 end) as null_Order_Date,
	 sum(case when Restaurant_Name is null then 1 else 0 end) as null_Restaurant_Name,
	 sum(case when Location is null then 1 else 0 end) as null_Location,
	 sum(case when Category is null then 1 else 0 end) as null_Category,
	 sum(case when Dish_Name is null then 1 else 0 end) as null_Dish_Name,
	 sum(case when Price_INR is null then 1 else 0 end) as null_Price_INR,
	 sum(case when Rating is null then 1 else 0 end) as null_Rating,
	 sum(case when Rating_Count is null then 1 else 0 end) as null_Rating_Count
from swiggy_data;

--Blank/Empty String Check

select * from swiggy_data
where State = '' and City = '' and Order_Date = '' and Restaurant_Name = '' and Location =''
and Category = '' and Dish_Name = '' and Price_INR = ''; 

select * from swiggy_data
where State = '' or City = '' or Order_Date = '' or Restaurant_Name = '' or Location =''
or Category = '' or Dish_Name = '' or Price_INR = '';

--Duplicate Detection

select
State,City,Order_Date,Restaurant_Name,Location,Category,Dish_Name,Price_INR,
Rating,Rating_Count,count(*) as cnt
from swiggy_data
group by
State,City,Order_Date,Restaurant_Name,Location,Category,Dish_Name,Price_INR,
Rating,Rating_Count
having count(*) > 1;

--Duplicate Removal

with cte as (
select *, row_number() over( partition by
State,City,Order_Date,Restaurant_Name,Location,Category,Dish_Name,Price_INR,
Rating,Rating_Count
order by (select null)
)as rn
from swiggy_data
)
delete from cte where rn > 1; 

--Dimensional Modelling (Star Schema)
-- Creating Dimensional Tables

--dim_date
create table dim_date( 
date_id int identity(1,1) primary key,
full_date date,
year smallint,
month smallint,
month_name varchar(25),
quarter tinyint,
day tinyint,
week tinyint)

--dim_location
create table dim_location(
location_id int identity(1,1) primary key,
state varchar(100),
city varchar(100),
location varchar(200))

--dim_restaurant
create table dim_restaurant(
restaurant_id int identity(1,1) primary key,
restaurant_name varchar(200))

--dim_category
create table dim_category(
category_id int identity(1,1) primary key,
category varchar(200))

--dim_dish
create table dim_dish(
dish_id int identity(1,1) primary key,
dish_name varchar(200))

--fact_table
create table fact_swiggy_orders(
order_id int identity(1,1) primary key,

date_id int,
location_id int,
restaurant_id int,
category_id int,
dish_id int,

price_INR decimal(10,2),
rating decimal(4,2),
rating_count int,

foreign key (date_id) references dim_date(date_id),
foreign key (location_id) references dim_location(location_id),
foreign key (restaurant_id) references dim_restaurant(restaurant_id),
foreign key (category_id) references dim_category(category_id),
foreign key (dish_id) references dim_dish(dish_id));

--Insert data in tables   select top 1 * from swiggy_data

--dim_date table
insert into dim_date(full_date,year,month,month_name,quarter,day,week)
select distinct
Order_Date,
year(Order_Date),
month(Order_Date),
datename(month,Order_Date),
datepart(quarter,Order_Date),
day(Order_Date),
datepart(week,Order_Date)
from swiggy_data where Order_Date is not null;

--dim_location table select * from dim_location
insert into dim_location(state,city,location)
select distinct
State,
City,
Location
from swiggy_data; 

--dim_restaurant 
insert into dim_restaurant(restaurant_name)
select distinct
Restaurant_Name
from swiggy_data;

--dim_category
insert into dim_category(category)
select distinct
Category
from swiggy_data;

--dim_dish
insert into dim_dish(dish_name)
select distinct
Dish_Name
from swiggy_data

--fact_table
insert into fact_swiggy_orders(date_id,location_id,restaurant_id,category_id,
dish_id,price_INR,rating,rating_count)
select
dd.date_id,
location_id,
restaurant_id,
category_id,
dish_id,
sd.price_INR,               -- select top 1 * from swiggy_data
sd.rating,
sd.rating_count
from 
swiggy_data sd 
join dim_date dd on dd.full_date             = sd.Order_Date
join dim_location dl on dl.state             = sd.State and
                        dl.city              = sd.City  and
						dl.location          = sd.Location
join dim_restaurant dr on dr.restaurant_name = sd.Restaurant_Name
join dim_category dc on dc.category          = sd.Category
join dim_dish ddi on ddi.dish_name           = sd.Dish_Name
                    
--tables join
select * from fact_swiggy_orders fso
join dim_date dd on dd.date_id = fso.date_id
join dim_location dl on dl.location_id = fso.location_id
join dim_restaurant dr on dr.restaurant_id = fso.restaurant_id
join dim_category dc on dc.category_id = fso.category_id
join dim_dish ddi on ddi.dish_id = fso.dish_id

--KPI development
--Basic KPI

--Total Orders
select count(*) as Total_Orders from fact_swiggy_orders

--Total Revenue(INR Million)
select format(sum(convert(float,price_INR))/1000000,'N2') + '$' as Total_Revenue_In_Million from fact_swiggy_orders 

--Average Dish Price
select format(avg(convert(float,price_INR)),'N2') + ' INR'as Average_Dish_Price from fact_swiggy_orders

--Average Rating
select avg(rating) as Average_Rating from fact_swiggy_orders

--Deep-Dive Business Analysis

--Monthly Order Trends
select 
dd.year,dd.month,dd.month_name,count(*) as Total
from fact_swiggy_orders fso join dim_date dd on fso.date_id = dd.date_id
group by dd.year,dd.month,dd.month_name;

--Quarterly Order Trends
select 
dd.year,dd.quarter,count(*) as Total
from fact_swiggy_orders fso join dim_date dd on fso.date_id = dd.date_id
group by dd.year,dd.quarter

--Year Wise Growth
select 
dd.year,count(*) as Total
from fact_swiggy_orders fso join dim_date dd on fso.date_id = dd.date_id
group by dd.year

--Day-Of-Week Patterns
select 
datename(WEEKDAY,dd.full_date) as Day_Name,count(*) as Total
from fact_swiggy_orders fso join dim_date dd on fso.date_id = dd.date_id
group by datename(WEEKDAY,dd.full_date),datepart(WEEKDAY,dd.full_date)
order by datepart(WEEKDAY,dd.full_date);

--Location Based Analysis

--Top 10 Cities By Order
select top 10
dl.city,count(*) as Total 
from fact_swiggy_orders fso join dim_location dl on fso.location_id = dl.location_id
group by dl.city order by count(*) desc;

--Revenue Contribution by states
select
dl.state,sum(fso.price_INR) as Total 
from fact_swiggy_orders fso join dim_location dl on fso.location_id = dl.location_id
group by dl.state order by sum(fso.price_INR) desc;

--Top 10 Restaurants by revenue and orders
select top 10
dr.restaurant_name,sum(fso.price_INR) as Total_Revenue,count(*) as Total  
from fact_swiggy_orders fso join dim_restaurant dr on fso.restaurant_id = dr.restaurant_id
group by dr.restaurant_name order by sum(fso.price_INR) desc;

--Top Categories
select 
dc.category,count(*) as Total_Orders  
from fact_swiggy_orders fso join dim_category dc on fso.category_id = dc.category_id
group by dc.category order by Total_Orders desc;

--Most Ordered Dishes
select 
dd.dish_name,count(*) as Order_Count  
from fact_swiggy_orders fso join dim_dish dd on fso.dish_id = dd.dish_id
group by dd.dish_name order by Order_Count desc;

--Cuisine performance (Orders + Avg Rating)
select
dc.category,count(*) as Total_Orders,avg(fso.rating) as Avg_Rating 
from fact_swiggy_orders fso join dim_category dc on fso.category_id = dc.category_id
group by dc.category order by Total_Orders desc;


--Customer Spending Insights
--Total Orders Distributed By Price Range  select top 1 * from fact_swiggy_orders
select
   case 
       when convert(float,price_INR) < 100 then 'under 100'
	   when convert(float,price_INR) between 100 and 199 then '100 - 199'
	   when convert(float,price_INR) between 200 and 299 then '200 - 299'
	   when convert(float,price_INR) between 300 and 399 then '300 - 399'
	   else '500+'
   end as Price_Range,
   count(*) as Total_Orders
from fact_swiggy_orders
   group by
   case 
	   when convert(float,price_INR) < 100 then 'under 100'
	   when convert(float,price_INR) between 100 and 199 then '100 - 199'
	   when convert(float,price_INR) between 200 and 299 then '200 - 299'
	   when convert(float,price_INR) between 300 and 399 then '300 - 399'
	   else '500+'
   end
order by Total_Orders desc;

--Ratings Analysis
select
rating,count(*) as Rating_Count 
from fact_swiggy_orders
group by rating order by Rating_Count desc

