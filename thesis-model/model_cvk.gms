$eolCom #
* money in bln$ (1e9 $) and emissions in GtCO2 (1e9 tCO2)

*** NUMBER OF DECILES (compile-time switch)
* Default is 3 households (terciles, 5% / 35% / 60% of income). To run with one household, call GAMS with --ndec=1.
* For more deciles later: raise ndec and add the income shares of the extra deciles in the dec_share block below.
$if not set ndec $set ndec 3

*** SETS
Sets    t 'time' /1*100/,
        d 'deciles' /d1*d%ndec%/,  #change number of sets to 10 deciles later
        f 'economic flow' /emi, cdr, gov/; #emission reduction/carbon tax, carbon removal, governmental redistribution (set added -> correct?)

** last period (used for the terminal condition on capital)
Set tlast(t) 'last period';
tlast(t) = yes$(ord(t) = card(t));

** decile alias
Alias   (d,dd);

*** PARAMETERS
Scalars t0 'initial year' /2025/,
        a_cdr 'baseline cost of CDR in $/tCO2' /100/,
        b_cdr 'marginal removal cost in $/tCO2' /100/,
        b_emi 'marginal abatement cost at full abatement (MIU = 1)in $/tCO2' /500/,
        carbon_budget 'carbon budget in GtCO2' /1000/,
        ineq_aversion 'inequality aversion' /1.45/,     #curvature of welfare function
        time_pref 'pure rate of social time preference' /0.015/;        #welfare weight on future gen vs current gen

*** GROWTH MODEL PARAMETERS (new): production Y = A * K^alpha * L^(1-alpha), capital K(t+1) = (1-delta)*K(t) + I(t)
Scalars alpha 'capital share in Cobb-Douglas production' /0.3/,
        delta 'annual depreciation rate of capital' /0.08/,     #share of the capital stock that wears out each year
        k_y0  'initial capital-output ratio K(0)/Y(0)' /2.8/,   #target range 2.5-3.5; 2.8 is close to what the model itself settles at (K/Y about 2.9), so no jump or dip at the start
        pop_growth 'annual growth rate of the population (labour)' /0.005/,     #set to 0 for constant labour
        A     'total factor productivity (calibrated below)',
        K0    'initial capital stock in bln$ (calibrated below)',
        k_term 'minimum capital-output ratio K/Y in every period and after the last period' /2.75/;

Parameters
        year(t) 'calendar year',
        L(t) 'labour = population index, 1 in the first period (exogenous)',
        dec_share(d) 'share of decile d in baseline income and in investment',
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

* income shares of the households: with one household it gets everything; with 3 the old 5% / 35% / 60% split
$ifthen %ndec%==1
dec_share('d1') = 1;
$elseif %ndec%==3
dec_share('d1') = 0.05;
dec_share('d2') = 0.35;
dec_share('d3') = 0.60;
$else
$error Add the income shares of the deciles to the dec_share block for this value of ndec
$endif
y0(t,d) = dec_share(d) * 100 * 1e3; #100 trillion $ GDP (100 bln * 1e3 = 100 trillion $), split by decile. Now only used for calibration and for the shares w

** labour: exogenous population path, an index that is 1 in the first period and grows by pop_growth per year.
** Kept on its own line so that it can later be replaced by an endogenous labour variable.
L(t) = (1 + pop_growth)**(t.val - 1);

** calibration of production: A and initial capital K0
** K0 follows from the capital-output ratio; A is chosen so that output in period 1 equals the old exogenous income (100 trillion $)
K0 = k_y0 * sum(d, y0('1',d));
A  = sum(d, y0('1',d)) / (K0**alpha * L('1')**(1 - alpha));

** terminal condition on capital (equations eq_k_floor and eq_terminal below). A finite horizon tempts the agent to eat up the
** capital stock in the last decades (capital has no value after period T). So capital must stay at least k_term * output,
** also for the stock left after the last period. k_term = 2.75 is just below the initial ratio (2.8) and below the ratio the model
** chooses by itself (K/Y of about 2.8-3.0), so the floor does not bind in the middle of the horizon, only at the end.
** Reference: steady-state ratio of a Ramsey model without productivity growth is alpha/(delta+time_pref) = 3.16.
** A target above the path the model chooses forces a sudden saving spike in the last period (tested with 3.16: sav. rate 42% in the last year).

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
        
        Y_PROD(t) 'gross output from Cobb-Douglas production in bln$, before climate policy',
        Y(t,d) 'final income of decile d in bln$ (share of gross output plus policy terms)',
        C(t,d) 'consumption of decile d in bln$ (income minus its share of investment)',      #only consumption enters welfare
        G(t) 'governmental fiscal balance in bln$',
        GDP(t) 'total income of economy in bln$ = sum of decile incomes',       # 100 trillion $
        K(t) 'capital stock at the start of period t in bln$',      #state variable (new)
        I(t) 'investment in bln$',      #decision variable (new): the agent chooses how much to save
        MIU(t) 'controlled fraction of emissions (abatement rate)',     #decision variable
        WELFARE 'objective variable';

** bound variables
C.lo(t,d) = 1e-6;       #consumption stays positive (it enters a fractional power in welfare)
K.lo(t) = 1e-6;     #strictly positive, since K enters a fractional power
K.fx('1') = K0;     #initial capital stock is given
I.lo(t) = 0;        #upper bound I <= GDP is the equation eq_invest_cap
** starting values for the solver (a decent guess: replace depreciation, no growth)
K.l(t) = K0;
I.l(t) = delta * K0;
Y_PROD.l(t) = sum(d, y0('1',d));
GDP.l(t) = sum(d, y0('1',d));
E_CDR.lo(t) = 0;        
E_CDR.up(t) = 10; #in GtCO2
E_RES.lo(t) = 0;        
MIU.lo(t) = 0;
MIU.up(t) = 1;

Equations
        eq_capital 'capital accumulation',
        eq_invest_cap 'investment cannot exceed output',
        eq_terminal 'terminal condition on capital',
        eq_k_floor 'minimum capital-output ratio in every period',
        eq_production 'Cobb-Douglas production',
        eq_decile_income 'decile income',
        eq_consumption 'decile consumption',
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
** capital and investment (new)
eq_capital(t)$(ord(t) < card(t)).. K(t+1) =E= (1 - delta) * K(t) + I(t);        #part of the stock depreciates, investment adds new capital

eq_invest_cap(t)..      I(t) =L= GDP(t);        #0 <= I <= Y

* capital floor in every period (see terminal condition remarks above): prevents running capital down towards the end
eq_k_floor(t)..         K(t) =G= k_term * Y_PROD(t);      #gross output, not GDP: otherwise the agent could lower the floor by spending more on abatement

* terminal condition: the stock left after the last period, K(T+1) = (1-delta)*K(T) + I(T), must be at least k_term * Y_PROD(T)
eq_terminal..           sum(tlast, (1 - delta) * K(tlast) + I(tlast)) =G= k_term * sum(tlast, Y_PROD(tlast));

** production (new): gross output from capital and labour
eq_production(t)..      Y_PROD(t) =E= A * K(t)**alpha * L(t)**(1 - alpha);

** decile income: the original equation, only the exogenous starting income y0 is replaced by the decile's share of produced output
eq_decile_income(t,d).. Y(t,d) =E= dec_share(d) * Y_PROD(t)                                     #share of output (replaces exogenous starting income y0)
                                   - (P_EMI(t) * E_RES(t) + COST_EMI(t)) * w(t,d,'emi')         #firms pass carbon costs to households
                                   + (P_CDR(t) * E_CDR(t) - COST_CDR(t)) * w(t,d,'cdr')         #CDR profits are distributed to households
                                   + G(t) * w(t,d,'gov');                                       #government transfer

** consumption (new): income minus the decile's share of investment, so that sum over deciles of C = GDP - I
eq_consumption(t,d)..   C(t,d) =E= Y(t,d) - dec_share(d) * I(t);

eq_gov_balance(t)..     G(t) =E= P_EMI(t) * E_RES(t) - P_CDR(t) * E_CDR(t);     #government collects from emitters and pays CDR providers

eq_total_income(t)..    GDP(t) =E= sum(d, Y(t,d));      #Y = sum of the decile incomes (unchanged)


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
eq_welfare..            WELFARE =E= sum((t,d), (C(t,d)**(1-ineq_aversion) / (1-ineq_aversion) - 1) * (1 / ((1 + time_pref)**(year(t) - t0))));


*** MODEL
Model   cdr_inequality /all/;

solve cdr_inequality maximising WELFARE using NLP;

*** REPORT (new): paths of the main growth variables
Parameters rep(t,*) 'growth paths (money in bln$)';
rep(t,'K')        = K.l(t);
rep(t,'Y_PROD')   = Y_PROD.l(t);
rep(t,'GDP')      = GDP.l(t);
rep(t,'I')        = I.l(t);
rep(t,'sav_rate') = I.l(t) / GDP.l(t);
rep(t,'C_total')  = sum(d, C.l(t,d));
rep(t,'K/Y')      = K.l(t) / GDP.l(t);
rep(t,'MIU')      = MIU.l(t);
display rep;

Parameter rep_c(t,d) 'consumption by decile in bln$';
rep_c(t,d) = C.l(t,d);
display rep_c;

execute_unload "results.gdx";


