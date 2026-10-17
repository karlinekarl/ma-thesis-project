$eolCom #

*** SETS
Sets    t 'time' /1*100/,
        d 'deciles' /d1*d3/,  #change number of sets to 10 later
        f 'economic flow' /emi, cdr, gov/; #added -> is correct? #emission reduction/carbon tax, carbon removal, governmental redistribution

** decile alias
Alias   (d,dd);


*** PARAMETERS
Scalars t0 'initial year' /2025/
        a_cdr 'xxx in $/tCO2' /100/,
        b_cdr 'xxx in $/tCO2' /100/,
        b_emi 'xxx in $/tCO2' /500/,
        carbon_budget 'carbon budget in GtCO2' /1000/,
        ineq_aversion 'inequality aversion' /1.45/,
        time_pref 'time preference' /0.015/;

Parameters
        year(t) 'year',
        sigma(t) 'carbon intensity of economy in tCO2/$',
        y0(t,d) 'initial income of decile d in $',
        eta(f) 'elasticity of flow f',
        #w(t,d,*)'share of * accruing to decile d',
        w(t,d,f) 'share of economic flow f accruing to decile d',
        ets(t) 'carbon price ???';            

** define parameters
year(t) = t0 + t.val; #stimmt das?
sigma(t) = 4 * 1e-4;
ets(t) = 1e5;

y0(t,'d1') = 100 * 0.05 * 1e3; #5% of gdp -> why *100?
y0(t,'d2') = 100 * 0.35 * 1e3; #35%
y0(t,'d3') = 100 * 0.60 * 1e3; #60%

eta("emi") = 0.8;        
eta('cdr') = 2;
eta("gov") = 1;

w(t,d,'emi') = y0(t,d)**eta('emi') / sum(dd,(y0(t,dd)**eta('emi')));
w(t,d,'cdr') = y0(t,d)**eta('cdr') / sum(dd,(y0(t,dd)**eta('cdr')));
w(t,d,'gov') = y0(t,d)**eta('gov') / sum(dd,(y0(t,dd)**eta('gov')));

$if set neutral_cdr w(t,d,'cdr') = y0(t,d) / sum(dd,y0(t,dd)); w(t,d,'emi') = y0(t,d) / sum(dd, y0(t,dd); #what does that mean??

***VARIABLES
Variables
        MC_EMI(t) 'xxx',
        MC_CDR(t) 'xxx',
        P_EMI(t) 'xxx',
        P_CDR(t) 'xxx',
        E_RES(t) 'xxx',
        E_CDR(t) 'xxx',
        COST_EMI(t) 'xxx',
        COST_CDR(t) 'xxx',
        E(t) 'total net emissions',
        
        Y(t,d) 'final income of decile d',
        G(t) 'governmental fiscal balance',
        GDP(t) 'xxx',
        MIU(t) 'controlled fraction of emissions (abatement rate)',
        WELFARE 'objective variable';
        
** bound variables
Y.lo(t,d) = 1e-6;
E_CDR.lo(t) = 0;
E_CDR.up(t) = 10;        
E_RES.lo(t) = 0;        
MIU.lo(t) = 0;
MIU.up(t) = 1;

Equations
        eq_decile_income 'xxx',        
        eq_gov_balance 'governmental balance',
        eq_total_income 'xxx',
        eq_res_emissions 'residual emissions',
        eq_total_emissions 'xxx',
        eq_carbon_budget 'xxx',
        eq_cap_and_trade 'xxx',
        eq_cdr_cost 'xxx',
        eq_emi_cost 'xxx',
        eq_cdr_marg_cost 'marginal costs of CDR',
        eq_emi_marg_cost 'marginal costs of abatement'
        eq_price_emi 'xxx',
        eq_price_cdr 'xxx',
        eq_welfare 'objective function';
        
** economy equations
eq_decile_income(t,d).. Y(t,d) =E= y0(t,d)
                                   - (P_EMI(t) * E_RES(t) + COST_EMI(t)) * w(t,d,'emi') #explain
                                   + (P_CDR(t) * E_CDR(t) - COST_CDR(t)) * w(t,d,'cdr')
                                   + G(t) * w(t,d,'gov');

eq_gov_balance(t)..     G(t) =E= P_EMI(t) * E_RES(t) - P_CDR(t) * E_CDR(t);

eq_total_income(t)..    GDP(t) =E= sum(d, Y(t,d));


** emission equations
eq_res_emissions(t)..   E_RES(t) =E= sigma(t) * GDP(t) * (1 - MIU(t)); #E_RES = E_baseline - E_abated

eq_total_emissions(t).. E(t) =E= E_RES(t) - E_CDR(t);


** climate policy constraints
eq_carbon_budget..      sum(t,E(t)) =L= carbon_budget;

eq_cap_and_trade(t)..   E(t) =L= ets(t);


** cost equations
eq_emi_cost(t)..        COST_EMI(t) =E= sigma(t) * GDP(t) + (b_emi * power(MIU(t), 3)) / 3; #is the + correct before it was * ?? otherwise MC is not correct
eq_cdr_cost(t)..        COST_CDR(t) =E= a_cdr * E_CDR(t) + (b_cdr * power(E_CDR(t), 3)) / 3;

eq_emi_marg_cost(t)..   MC_EMI(t) =E= b_emi * power(MIU(t), 2);
eq_cdr_marg_cost(t)..   MC_CDR(t) =E= a_cdr + b_cdr * power(E_CDR(t), 2);

eq_price_emi(t)..       P_EMI(t) =E= MC_EMI(t);   
eq_price_cdr(t)..       P_CDR(t) =E= MC_CDR(t);

** objective function
eq_welfare..            WELFARE =E= sum((t,d), (Y(t,d)**(1-ineq_aversion) / (1-ineq_aversion) - 1) * (1 / ((1 + time_pref)**(year(t) - t0)))); #t-t0 schreibweise überprüfen


*** MODEL
Model   cdr_inequality /all/;

solve cdr_inequality maximising WELFARE using NLP;
execute_unload "results.gdx";


