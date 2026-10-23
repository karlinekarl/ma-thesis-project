$eolCom #
* money in bln$ (1e9 $and emissions in GtCO2 (1e9 tCO2)

*** SETS
Sets    t 'time' /1*100/,
        d 'deciles' /d1*d3/,  #change number of sets to 10 deciles later
        f 'economic flow' /emi, cdr, gov/; #emission reduction/carbon tax, carbon removal, governmental redistribution (set added -> correct?)

** decile alias
Alias   (d,dd);

*** PARAMETERS
Scalars t0 'initial year' /2025/,
        a_cdr 'baseline cost of CDR in $/tCO2' /100/,
        b_cdr 'marginal removal cost in $/tCO2' /100/,
        b_emi 'marginal abatement cost at full abatement (MIU = 1)in $/tCO2' /500/,
        carbon_budget 'carbon budget in GtCO2' /1000/,
        ineq_aversion 'inequality aversion across deciles within a period' /0.5/,     #curvature of the Atkinson aggregation over deciles (must not equal 1)
        ies 'elasticity of intertemporal substitution' /1.45/,     #curvature of welfare across time is 1/ies (must not equal 1)
        time_pref 'pure rate of social time preference' /0.015/;        #welfare weight on future gen vs current gen

Parameters
        year(t) 'calendar year',
        sigma(t) 'carbon intensity of economy in tCO2/$',       #for every dollar of GDP, sigma tCO2 are emitted
        y0(t,d) 'initial income of decile d in year t in billion $',
        eta(f) 'distribution elasticity of flow f',  #how unequally flows are distributed across deciles
        #w(t,d,*)'share of * accruing to decile d',
        w(t,d,f) 'share of economic flow f accruing to decile d',
        ets(t) 'cap on total emissions in GtCO2';            

** define parameters
year(t) = t0 + t.val;  #year 2026-2125
sigma(t) = 4 * 1e-4;
ets(t) = 1e5;

y0(t,'d1') = 0.05 * 100 * 1e3; #5% of 100 trillion $ GDP (100 bln * 1e3 = 100 trillion $)
y0(t,'d2') = 0.35 * 100 * 1e3; #35%
y0(t,'d3') = 0.60 * 100 * 1e3; #60%

eta("emi") = 0.8;       #regressive distribution of abatement costs (poor bear larger share than income share)
eta('cdr') = 2;         #distribution of carbon removal (CDR profits go disproportionately to rich)
eta("gov") = 1;         #proportional distribution of governmental redistribution

w(t,d,'emi') = y0(t,d)**eta('emi') / sum(dd,(y0(t,dd)**eta('emi')));
w(t,d,'cdr') = y0(t,d)**eta('cdr') / sum(dd,(y0(t,dd)**eta('cdr')));
w(t,d,'gov') = y0(t,d)**eta('gov') / sum(dd,(y0(t,dd)**eta('gov')));

$if set neutral_cdr w(t,d,'cdr') = y0(t,d) / sum(dd,y0(t,dd)); w(t,d,'emi') = y0(t,d) / sum(dd, y0(t,dd)); #sets distribution of CDR revenues and abatement costs to be proportional to income (neutral distribution)

***VARIABLES
Variables
        MC_EMI(t) 'marginal costs of abatement',
        MC_CDR(t) 'marginal costs of carbon removal',
        P_EMI(t) 'carbon price on residual emissions',
        P_CDR(t) 'price of carbon removal',
        E_RES(t) 'residual emissions in GtCO2',
        E_CDR(t) 'carbon dioxide removal in GtCO2',
        COST_EMI(t) 'cost of emission reduction in bln$',
        COST_CDR(t) 'cost of carbon removal in bln$',
        E(t) 'total net emissions in GtCO2',
        
        Y(t,d) 'final income of decile d in bln$',
        G(t) 'governmental fiscal balance in bln$',
        GDP(t) 'total income of economy in bln$',       # 100 trillion $
        MIU(t) 'controlled fraction of emissions (abatement rate)',     #decision variable
        WELFARE 'objective variable';
        
** bound variables
Y.lo(t,d) = 1e-6;
E_CDR.lo(t) = 0;        
E_CDR.up(t) = 10; #in GtCO2
E_RES.lo(t) = 0;        
MIU.lo(t) = 0;
MIU.up(t) = 1;

Equations
        eq_decile_income 'decile income',
        eq_gov_balance 'governmental balance',
        eq_total_income 'total income',
        eq_res_emissions 'residual emissions',
        eq_total_emissions 'total emissions',
        eq_carbon_budget 'carbon budget',
        eq_cap_and_trade 'cap and trade',
        eq_cdr_cost 'cost of carbon removal',
        eq_emi_cost 'cost of emission reduction',
        eq_cdr_marg_cost 'marginal costs of carbon removal',
        eq_emi_marg_cost 'marginal costs of abatement',
        eq_price_emi 'price on residual emissions',
        eq_price_cdr 'price of carbon removal',
        eq_welfare 'objective function';
        
** economy equations
eq_decile_income(t,d).. Y(t,d) =E= y0(t,d)                                                      #starting income
                                   - (P_EMI(t) * E_RES(t) + COST_EMI(t)) * w(t,d,'emi')         #firms pass carbon costs to households
                                   + (P_CDR(t) * E_CDR(t) - COST_CDR(t)) * w(t,d,'cdr')         #CDR profits are distributed to households
                                   + G(t) * w(t,d,'gov');                                       #government transfer

eq_gov_balance(t)..     G(t) =E= P_EMI(t) * E_RES(t) - P_CDR(t) * E_CDR(t);     #government collects from emitters and pays CDR providers

eq_total_income(t)..    GDP(t) =E= sum(d, Y(t,d));


** emission equations
eq_res_emissions(t)..   E_RES(t) =E= sigma(t) * GDP(t) * (1 - MIU(t));  #baseline emissions times unabated share (baseline - abated)

eq_total_emissions(t).. E(t) =E= E_RES(t) - E_CDR(t);


** climate policy constraints
eq_carbon_budget..      sum(t,E(t)) =L= carbon_budget;

eq_cap_and_trade(t)..   E(t) =L= ets(t);


** cost equations
eq_emi_cost(t)..        COST_EMI(t) =E= sigma(t) * GDP(t) * (b_emi * power(MIU(t), 3)) / 3;     #integral of MC_EMI over abated tons (sigma(t) * GDP(t) * MIU(t))
eq_cdr_cost(t)..        COST_CDR(t) =E= a_cdr * E_CDR(t) + (b_cdr * power(E_CDR(t), 3)) / 3;

eq_emi_marg_cost(t)..   MC_EMI(t) =E= b_emi * power(MIU(t), 2);
eq_cdr_marg_cost(t)..   MC_CDR(t) =E= a_cdr + b_cdr * power(E_CDR(t), 2);

eq_price_emi(t)..       P_EMI(t) =E= MC_EMI(t);   
eq_price_cdr(t)..       P_CDR(t) =E= MC_CDR(t);

** objective function
*  within each period, deciles are aggregated to an equally-distributed-equivalent income (Atkinson, inequality aversion):
*      Y_EDE(t) = ( sum(d, Y(t,d)**(1-ineq_aversion)) / card(d) )**(1/(1-ineq_aversion))
*  the EDE incomes are then aggregated over time with CRRA utility (curvature 1/ies) and discounted:
*      WELFARE = sum(t, Y_EDE(t)**(1-1/ies) / (1-1/ies) / (1+time_pref)**(year(t)-t0))
eq_welfare..            WELFARE =E= sum(t, (sum(d, Y(t,d)**(1-ineq_aversion)) / card(d))**((1-1/ies) / (1-ineq_aversion))
                                           / (1-1/ies)
                                           / ((1 + time_pref)**(year(t) - t0)));


*** MODEL
Model   cdr_inequality /all/;

solve cdr_inequality maximising WELFARE using NLP;
execute_unload "results.gdx";


