# Проект 2


Необходимо сделать миграцию в отдельные логические таблицы, а затем собрать на них витрину данных. 
Это поможет оптимизировать нагрузку на хранилище и позволит аналитикам, 
перед которыми стоит задача построить анализ эффективности и прибыльности бизнеса, 
отвечать на точечные вопросы о тарифах вендоров, стоимости доставки в разные страны, 
количестве доставленных заказов за последнюю неделю.

Сейчас данные хранятся в одной таблице, shipping, где много дублирующейся и несистематизированной справочной информации. По сути там содержится весь лог доставки от момента оформления до выдачи заказа покупателю.

## Инструкция по выполнению проекта

1. Создайте справочник стоимости доставки в страны shipping_country_rates из данных, 
   указанных в shipping_country и shipping_country_base_rate, сделайте первичный ключ таблицы — серийный id, то есть серийный идентификатор каждой строчки. Важно дать серийному ключу имя «id». Справочник должен состоять из уникальных пар полей из таблицы shipping.

2. Создайте справочник тарифов доставки вендора по договору shipping_agreement из данных строки vendor_agreement_description через разделитель :.
Названия полей:
agreementid,
agreement_number,
agreement_rate,
agreement_commission.
Agreementid сделайте первичным ключом.
   
3. Создайте справочник о типах доставки shipping_transfer из строки shipping_transfer_description через разделитель :.
Названия полей:
transfer_type,
transfer_model,
shipping_transfer_rate .
Сделайте первичный ключ таблицы — серийный id.
   
4. Создайте таблицу shipping_info с уникальными доставками shippingid и свяжите её с созданными справочниками shipping_country_rates, 
   shipping_agreement, shipping_transfer и константной информацией о доставке shipping_plan_datetime , payment_amount , vendorid
   

5. Создайте таблицу статусов о доставке shipping_status и включите туда информацию из лога shipping (status , state). 
   Добавьте туда вычислимую информацию по фактическому времени доставки shipping_start_fact_datetime, 
   shipping_end_fact_datetime . 
   Отразите для каждого уникального shippingid его итоговое состояние доставки.
   
6. Создайте представление shipping_datamart на основании готовых таблиц для аналитики и включите в него:
shippingid
vendorid
transfer_type — тип доставки из таблицы shipping_transfer
full_day_at_shipping — количество полных дней, в течение которых длилась доставка. Высчитывается как:shipping_end_fact_datetime-shipping_start_fact_datetime.
is_delay — статус, показывающий просрочена ли доставка. Высчитывается как:shipping_end_fact_datetime >> shipping_plan_datetime → 1 ; 0
is_shipping_finish — статус, показывающий, что доставка завершена. Если финальный status = finished → 1; 0
delay_day_at_shipping — количество дней, на которые была просрочена доставка. Высчитыается как: shipping_end_fact_datetime >> shipping_end_plan_datetime → shipping_end_fact_datetime -− shipping_plan_datetime ; 0).
payment_amount — сумма платежа пользователя
vat — итоговый налог на доставку. Высчитывается как: payment_amount *∗ ( shipping_country_base_rate ++ agreement_rate ++ shipping_transfer_rate) .
profit — итоговый доход компании с доставки. Высчитывается как: payment_amount*∗ agreement_commission.
   

