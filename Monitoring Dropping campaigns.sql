#SQL project: Monitoring the process of dropping campaign offers in the Credit limit increase campaign analysis
#Background: the banks sends 5400 offers to its customers and provide the opportunity to increase
#their current credit limit. When a customer receives the offer, she/he will call the bank. 
#The customer service person will check the customer's status at the time of call, and decide 
#whether to approve or declind the offer. After dropping the campaign, the bank starts to monitor 
#the campaign.
#Base table: includes the base population which the banks selects to provide this offer. 
#call_record table: has the call records from these customers by day. The bank uses call record 
#to eavluate the response rate 
#Decision Table: has the final decision ragarding each offer. AP=approval DL=decline
#change_record table: has the credit limit change record in the system 
#Letter table: the bank needs to send approval or decline letter to customers accordingly. 
#For example, if the customer speaks English, the bank must send letter in English. The correct
#letter code:
#English approval letter =AE001, English Decline Letter = RE001
#French Approval Letter = AE002, French Decline Letter = RE002 

#skim each table 
select * from base;
select * from call_record;
select * from change_record;
select * from decision;
select * from letter;
select count(*) from base;
select count(*) from call_record;
select count(*) from decision;
select count(*) from letter;
select count(*) from change_record;


select call_date, count(acct_num) from call_record group by 1;
select decision_status, count(*) from decision group by 1;
select change_date, count(*) from change_record group by 1;


#below are the monitoring requests from 'your manager': 
#check response rate by date 
select c.call_date,count(distinct c.acct_num)
from call_record as c group by 1;


#Check overall approval rate and decline rate 
select 
sum(case when decision_status = 'AP' then 1 else 0 end) / count(acct_decision_id) as approval_rate,
sum(case when decision_status = 'DL' then 1 else 0 end) / count(acct_decision_id) as decline_rate
from decision;



# for approved accounts, check whether their credit limit has been changed correctly based on the offer_amount
SELECT A.* FROM
(select base.acct_num, 
base.credit_limit,base.offer_amount, 
d.decision_status,
c.credit_limit_after,
base.credit_limit+base.offer_amount-credit_limit_after as mismatch
from
base 
left join
decision d
on base.acct_num=d.acct_decision_id
left join
change_record as c
on
base.acct_num=c.account_number
where decision_status='AP') A
WHERE A.MISMATCH <> 0;

#Check whether letter has been sent out for each approved or declined customers. 
SELECT * FROM (
select base.acct_num,
d.decision_status, 
d.decision_date,
l.letter_code, l.Letter_trigger_date, 
datediff(decision_date,Letter_trigger_date) as letter_mis
from
base
left join
decision d
on base.acct_num=d.acct_decision_id
left join
letter l
on 
base.acct_num=l.account_number
where decision_status is not null) A
where letter_mis > 0 or letter_trigger_date is NULL;

#Check whether the letter is correctly sent out to each customer based on language and decision. 
SELECT * FROM
(select base.acct_num as acct_num, base.offer_amount, d.decision_status, d.decision_date,
l.language, l.letter_code,
case when decision_status='DL' and language='French' then 'RE002'
	 WHEN decision_status='AP' and language='French' then 'AE002'
     WHEN decision_status='DL' and language='English' then 'RE001'
     WHEN decision_status='AP' and language='English' then 'AE001'
     END AS letter_code2
from
base
left join
decision d
on base.acct_num=d.acct_decision_id
left join
letter l
on 
base.acct_num=l.account_number
where decision_status is not null) A
WHERE A.letter_code <> A.letter_code2;


#Final monitoring:create a final monitoring report for this part of analysis to the manager 
select base.acct_num,
base.credit_limit,
base.offer_amount,
d.decision_status,
d.decision_date,
l.Letter_trigger_date, 
l.letter_code,
l.language,
c.credit_limit_after, 
case when decision_status='AP' and
base.credit_limit+base.offer_amount-credit_limit_after <> 0 then 1
else 0 end as mismatch_flag,
case when datediff(decision_date,Letter_trigger_date) > 0 then 1 else 0 end as missing_letter_flag,
case when decision_status='DL' and language='French' and l.letter_code <> 'RE002' then 1
	 WHEN decision_status='AP' and language='French' and l.letter_code <> 'AE002' then 1 
     WHEN decision_status='DL' and language='English' and l.letter_code <> 'RE001' then 1
     WHEN decision_status='AP' and language='English' and l.letter_code <> 'AE001' then 1
     ELSE 0
     END AS wrong_letter_flag 
from
base
left join
decision d
on base.acct_num=d.acct_decision_id
left join
change_record c
on
base.acct_num=c.account_number
left join
letter l
on 
base.acct_num=l.account_number
where decision_status is not null;


