$eolCom #
Set t /1*100/;
Set d /d1*d3/;

alias(d,dd);

Variables  MC_CDR(t), MC_EMI(t), Y(t,d), P_CDR(t), P_EMI(t), E_CDR(t), E_RES(t), COST_EMI(t), COST_CDR(t), E(t),GDP(t), G(t), MIU(t), WELFARE;

Parameter a_cdr, b_cdr, b_emi, sigma(t), w(t,d,*), y0(t,d), carbon_budget, ets(t), eta(*), year(t), t0;
Scalar ineq_aversion /1.45/;
Scalar time_preference /0.015/;

** define parameters
year(t) = 2025 + t.val;
t0 = 2025;


a_cdr = 100; #$/tonCO2
b_cdr = 100; #$/tonCO2

b_emi = 500;
 
sigma(t) = 4 * 1e-4; # expressed in tonCO2/$

* initialize terciles
y0(t,'d1') = 100 * 0.05 * 1e3;
y0(t,'d2') = 100 * 0.35 * 1e3;
y0(t,'d3') = 100 * 0.60 * 1e3;

eta('cdr') = 2;
eta('emi') = 0.8;
eta('g') = 1;

w(t,d,'cdr') = y0(t,d)**eta('cdr')/sum(dd,y0(t,dd)**eta('cdr'));
w(t,d,'emi') = y0(t,d)**eta('emi')/sum(dd,y0(t,dd)**eta('emi'));
w(t,d,'g') = y0(t,d)**eta('g')/sum(dd,y0(t,dd)**eta('g'));

$if set neutral_cdr w(t,d,'cdr') =  y0(t,d) / sum(dd,y0(t,dd)); w(t,d,'emi') =  y0(t,d) / sum(dd,y0(t,dd));

carbon_budget = 1000; 
ets(t) = 1e5;

** bound variables

Y.lo(t,d) = 1e-6;
E_CDR.lo(t) = 0;
E_CDR.up(t) = 10;
E_RES.lo(t) = 0;
MIU.lo(t) = 0;
MIU.up(t) = 1;

equation eq_government_balance, eq_total_income, eq_decile_income, eq_residual_emissions, eq_total_emissions, eq_carbon_budget, eq_cap_and_trade, eq_cdr_cost, eq_emi_cost, eq_cdr_marginal_cost, eq_emi_marginal_cost, eq_priceemi, eq_pricecdr, eq_welfare;

*** economy
eq_decile_income(t,d)..       Y(t,d) =E= y0(t,d) 
   + (P_CDR(t) * E_CDR(t) - COST_CDR(t)) * w(t,d,'cdr')
   - (P_EMI(t) * E_RES(t) + COST_EMI(t)) * w(t,d,'emi')
   + G(t) * w(t,d,'g');
   
eq_government_balance(t)..    G(t) =E= P_EMI(t) * E_RES(t) - P_CDR(t) * E_CDR(t);

eq_total_income(t)..          GDP(t) =E= sum(d, Y(t,d));

*** emissions
eq_residual_emissions(t)..    E_RES(t) =E= sigma(t) * GDP(t) * (1 - MIU(t));

eq_total_emissions(t)..       E(t) =E= E_RES(t) - E_CDR(t);

*** climate policy
eq_carbon_budget..            sum(t,E(t)) =L= carbon_budget;

eq_cap_and_trade(t)..         E(t) =L= ets(t);

*** costs
eq_cdr_cost(t)..             COST_CDR(t) =E= a_cdr * E_CDR(t) + b_cdr * power(E_CDR(t), 3) / 3;

eq_emi_cost(t)..             COST_EMI(t) =E= sigma(t) * GDP(t) * b_emi  * power( MIU(t), 3) / 3;

eq_cdr_marginal_cost(t)..    MC_CDR(t) =E= a_cdr + b_cdr * power(E_CDR(t), 2);

eq_emi_marginal_cost(t)..    MC_EMI(t) =E= b_emi * power(MIU(t), 2);

eq_priceemi(t)..             P_EMI(t) =E= MC_EMI(t);

eq_pricecdr(t)..             P_CDR(t) =E= MC_CDR(t);

*** objective function
eq_welfare..                WELFARE =E= sum((t,d), (Y(t,d)**(1-ineq_aversion) / (1-ineq_aversion) - 1) * 1/(1+time_preference)**(year(t)-t0) );


*** model definition

model cdr_inequality /all/;

solve cdr_inequality maximizing WELFARE using nlp;

execute_unload "results.gdx";

