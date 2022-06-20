


-- 1
DROP TABLE IF EXISTS public.shipping_country_rates cascade; -- поправил с Cascade

-- справочник shipping_country_rates
CREATE TABLE public.shipping_country_rates(
id serial,
shipping_country text,
shipping_country_base_rate NUMERIC(14,3),

PRIMARY KEY (id)
);

-- Миграция данных
INSERT INTO public.shipping_country_rates
(shipping_country, shipping_country_base_rate)

select distinct shipping_country,shipping_country_base_rate 
from shipping s 
;

--select * from shipping_country_rates
    
-- 2
DROP TABLE IF EXISTS public.shipping_agreement cascade ;

-- справочник shipping_agreement 
CREATE TABLE public.shipping_agreement(
agreementid bigint, -- исправил с serial на bigint
agreement_number text,
agreement_rate numeric(14,2), -- тут хватает 2 знака
agreement_commission numeric(14,2), -- тут тоже хватает 2 знака

primary key (agreementid)
)
;

insert into public.shipping_agreement 
(agreementid, agreement_number, agreement_rate, agreement_commission )

select distinct
(regexp_split_to_array(vendor_agreement_description, ':+'))[1]::bigint as agreementid
,(regexp_split_to_array(vendor_agreement_description, ':+'))[2]::text as agreement_number
,(regexp_split_to_array(vendor_agreement_description, ':+'))[3]::numeric(14,2) as agreement_rate
,(regexp_split_to_array(vendor_agreement_description, ':+'))[4]::numeric(14,2) as agreement_commission
from shipping s 
;

--select * from shipping_agreement s ;



-- 3
DROP TABLE IF EXISTS public.shipping_transfer cascade;

-- справочник shipping_transfer 
CREATE TABLE public.shipping_transfer(
id serial,
transfer_type text,
transfer_model text,
shipping_transfer_rate numeric(14,3),

primary key (id)
)
;

insert into public.shipping_transfer
(transfer_type, transfer_model, shipping_transfer_rate)

select distinct 
(regexp_split_to_array(shipping_transfer_description, ':+'))[1] as transfer_type,
(regexp_split_to_array(shipping_transfer_description, ':+'))[2] as transfer_model,
shipping_transfer_rate 
from shipping s 
order by 1,2,3
;

--select * from shipping_transfer;




-- 4
DROP TABLE IF EXISTS public.shipping_info cascade ;

-- справочник shipping_info 
CREATE TABLE public.shipping_info(
shippingid bigint,
vendorid bigint,
payment_amount NUMERIC(14,2),
shipping_plan_datetime TIMESTAMP,
transfer_type_id bigint,
shipping_country_id bigint,
agreementid bigint,

primary key (shippingid),
FOREIGN KEY (shipping_country_id) REFERENCES shipping_country_rates(id) ON UPDATE cascade,
FOREIGN KEY (transfer_type_id) REFERENCES shipping_transfer(id) ON UPDATE cascade,
FOREIGN KEY (agreementid) REFERENCES shipping_agreement(agreementid) ON UPDATE cascade
);



insert into public.shipping_info
(shippingid, vendorid, payment_amount, shipping_plan_datetime, transfer_type_id, shipping_country_id, agreementid)

select
distinct s.shippingid, s.vendorid, s.payment_amount, s.shipping_plan_datetime,
t.id as transfer_type_id,
c.id as shipping_country_id,
a.agreementid
from
(
	select distinct 
	shippingid ,
	vendorid ,
	payment_amount, 
	shipping_plan_datetime ,
	
	(regexp_split_to_array(shipping_country, ':+'))[1] as shipping_country,
	(regexp_split_to_array( shipping_transfer_description, ':+'))[1] as transfer_type,
	(regexp_split_to_array( shipping_transfer_description, ':+'))[2] as transfer_model,
	(regexp_split_to_array(vendor_agreement_description, ':+'))[1]::int as agreementid
	from shipping s
	
) s
left join shipping_country_rates c on c.shipping_country = s.shipping_country
left join shipping_agreement a on a.agreementid = s.agreementid
left join shipping_transfer t on t.transfer_type = s.transfer_type and s.transfer_model = t.transfer_model
order by 1,2,3,4,5,6,7
;

--select * from shipping_info ;


-- 5
DROP TABLE IF EXISTS public.shipping_status  cascade ;

-- справочник shipping_status  
CREATE TABLE public.shipping_status (
shippingid bigint,
status text,
state text,
shipping_start_fact_datetime timestamp,
shipping_end_fact_datetime timestamp
);


with ft as 
(	
	select distinct shippingid ,
	status,
	state,
	
	case 
		when min(state_datetime) over(partition by shippingid) = state_datetime  then state_datetime -- ну тогда я просто беру 1 статус без доп уточнений
		else null 
	end as shipping_start_fact_datetime
	,case 
		when max(state_datetime) over(partition by shippingid) = state_datetime  then state_datetime -- тут последний без уточнения без доп уточнений, я так понял
		else null 
	end as shipping_end_fact_datetime
	from shipping s 
),
st as 
(
	select ft.shippingid, -- тут первоначальный id заказа
	st.status, st.state, -- тут нужен последний статус и стейт заказа, поэтому тянем из 2й табл
	ft.shipping_start_fact_datetime,
	st.shipping_end_fact_datetime
	from (
			select * from ft 
			where shipping_start_fact_datetime is not null
		 ) ft
	left join (
				select * from ft 
				where shipping_end_fact_datetime is not null
			  ) st on st.shippingid = ft.shippingid
)


-- заливаем
insert into public.shipping_status 
select * from st
;


-- проверка
--select status, state, count(*) from shipping_status group by 1,2 order by 3 desc ;

--select count(*), count(distinct shippingid) from public.shipping_status
--union all
--select count(*), count(distinct shippingid) from public.shipping_info;



CREATE OR REPLACE view shipping_datamart as 
--create view as shipping_datamart as  

select si.shippingid, si.vendorid, 
st.transfer_type,
DATE_PART('day', AGE(ss.shipping_end_fact_datetime, ss.shipping_start_fact_datetime)) as full_day_at_shipping,
case 
	when si.shipping_plan_datetime < ss.shipping_end_fact_datetime then 1
	else 0
end as is_delay,
case 
	when ss.status = 'finished' then 1 
	else 0 
end as is_shipping_finish,
case
	when si.shipping_plan_datetime < ss.shipping_end_fact_datetime then coalesce(DATE_PART('day', AGE(ss.shipping_end_fact_datetime, si.shipping_plan_datetime)),0)  
	else 0
end as delay_day_at_shipping,
si.payment_amount,
(si.payment_amount * (scr.shipping_country_base_rate + sa.agreement_rate + st.shipping_transfer_rate)) as vat, -- убрал округление
(si.payment_amount  * sa.agreement_commission) as profit -- убрал округление
from shipping_info si
left join shipping_transfer st on st.id = si.transfer_type_id 
left join shipping_status ss on ss.shippingid  = si.shippingid 
left join shipping_country_rates scr ON scr.id  = si.shipping_country_id 
left join shipping_agreement sa on sa.agreementid  = si.agreementid 

;

-- Проверка 
--select count(*) from shipping_datamart;
--select * from shipping_datamart;


